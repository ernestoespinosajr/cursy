import AppKit
import AudioToolbox
import AVFoundation
import Combine
import CoreAudio
import os

nonisolated struct HomeMicrophoneDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let audioID: AudioDeviceID
}

nonisolated enum HomeMicrophoneRoute {
    static let preferenceKey = "preferredMicrophoneUID"
    static func devices() -> [HomeMicrophoneDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var identifiers = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &identifiers) == noErr else { return [] }
        return identifiers.compactMap { identifier in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(identifier, &streams, 0, nil, &streamSize) == noErr, streamSize > 0,
                  let uid = string(identifier, selector: kAudioDevicePropertyDeviceUID),
                  let name = string(identifier, selector: kAudioObjectPropertyName) else { return nil }
            return HomeMicrophoneDevice(id: uid, name: name, audioID: identifier)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private static func string(_ device: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
    static func apply(to engine: AVAudioEngine,
                      selectedUID: String = UserDefaults.standard.string(forKey: preferenceKey) ?? "") throws {
        // A fresh engine already follows the system input. Reassigning its HAL
        // device during lazy I/O construction can invalidate that graph.
        guard let deviceID = try overrideDeviceID(selectedUID: selectedUID, availableDevices: devices) else { return }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var defaultDevice = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultDevice) == noErr,
           !needsOverride(requested: deviceID, systemDefault: defaultDevice) { return }
        let unit = engine.inputNode.auAudioUnit
        if unit.deviceID != deviceID { try unit.setDeviceID(deviceID) }
    }
    static func needsOverride(requested: AudioDeviceID, systemDefault: AudioDeviceID) -> Bool {
        requested != systemDefault
    }
    static func overrideDeviceID(selectedUID: String, availableDevices: () -> [HomeMicrophoneDevice]) throws -> AudioDeviceID? {
        guard !selectedUID.isEmpty else { return nil }
        guard let deviceID = availableDevices().first(where: { $0.id == selectedUID })?.audioID else {
            throw NSError(domain: "CursyMicrophone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Selected microphone unavailable. Choose another input in Settings."])
        }
        return deviceID
    }
}

protocol MicrophoneTestCapturing: Actor {
    func start(selectedUID: String, level: @escaping @Sendable (Double) -> Void,
               routeChanged: @escaping @Sendable () -> Void) async throws
    func stop() async
}

/// Owns all blocking graph operations away from AppKit. No samples leave the tap.
private actor MicrophoneTestCapture: MicrophoneTestCapturing {
    private var engine: AVAudioEngine?
    private var configurationObserver: NSObjectProtocol?
    func start(selectedUID: String, level: @escaping @Sendable (Double) -> Void,
               routeChanged: @escaping @Sendable () -> Void) throws {
        try Task.checkCancellation()
        stop()
        let engine = AVAudioEngine()
        try HomeMicrophoneRoute.apply(to: engine, selectedUID: selectedUID)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw URLError(.cannotOpenFile) }
        let tap: AVAudioNodeTapBlock = { buffer, _ in
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
            let rms = sqrt(sum / Float(buffer.frameLength))
            level(Double(min(1, max(0, (20 * log10(max(rms, 0.0001)) + 60) / 60))))
        }
        if #available(macOS 27.0, *) {
            try input.installAudioTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, time in
                tap(AVAudioPCMBuffer(copying: buffer), time)
            }
        } else { input.installTap(onBus: 0, bufferSize: 1024, format: nil, block: tap) }
        self.engine = engine
        do {
            try Task.checkCancellation()
            try engine.start()
            try Task.checkCancellation()
            configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                object: engine, queue: nil) { _ in routeChanged() }
        } catch { stop(); throw error }
    }
    func stop() {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        engine = nil
    }
}

@MainActor
final class HomeMicrophone: ObservableObject {
    @Published private(set) var devices: [HomeMicrophoneDevice] = []
    @Published private(set) var isTesting = false
    @Published private(set) var isStarting = false
    @Published private(set) var isStopping = false
    @Published private(set) var level: Double = 0
    @Published private(set) var notice: String?
    @Published private(set) var selectedUID = UserDefaults.standard.string(forKey: HomeMicrophoneRoute.preferenceKey) ?? ""
    private let capture: any MicrophoneTestCapturing
    private let permission: @MainActor () async -> Bool
    private var startup: Task<Void, Never>?
    private var generation = UUID()
    private var deadline: Task<Void, Never>?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private let logger = Logger(subsystem: "Cursy", category: "MicrophoneTest")
    var ownsInput: Bool { isStarting || isTesting || isStopping }
    init(capture: any MicrophoneTestCapturing = MicrophoneTestCapture(),
         permission: @escaping @MainActor () async -> Bool = {
             if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                 return await AVCaptureDevice.requestAccess(for: .audio)
             }
             return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
         }) {
        self.capture = capture
        self.permission = permission
    }
    var missingSelection: Bool { !selectedUID.isEmpty && !devices.contains(where: { $0.id == selectedUID }) }
    func refresh() { devices = HomeMicrophoneRoute.devices() }
    func observeDevices() {
        refresh()
        guard deviceListener == nil else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refresh()
                if self?.missingSelection == true { self?.stop(); self?.notice = "Micrófono desconectado · Microphone disconnected" }
            }
        }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener) == noErr {
            deviceListener = listener
        }
    }
    func endObservation() {
        stop()
        if let deviceListener {
            var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, deviceListener)
        }
        deviceListener = nil
    }
    func select(_ uid: String) {
        stop()
        selectedUID = uid
        UserDefaults.standard.set(uid, forKey: HomeMicrophoneRoute.preferenceKey)
        notice = nil
    }
    func stop() {
        generation = UUID()
        let stopToken = generation
        startup?.cancel()
        startup = nil
        deadline?.cancel()
        deadline = nil
        let needsRelease = ownsInput
        isStarting = false
        isTesting = false
        level = 0
        guard needsRelease else { return }
        isStopping = true
        Task { [weak self, capture] in
            await capture.stop()
            guard let self, self.generation == stopToken else { return }
            self.isStopping = false
        }
    }
    func start(canStart: @escaping () -> Bool) {
        guard !ownsInput, canStart() else { return }
        generation = UUID()
        let token = generation
        notice = nil
        isStarting = true
        let selectedUID = selectedUID
        let permission = permission
        startup = Task { [weak self, capture] in
            guard !Task.isCancelled else { return }
            let granted = await permission()
            guard let self, self.generation == token else { return }
            guard canStart() else { self.stop(); return }
            guard granted else { self.stop(); self.notice = "Permite el micrófono en Privacidad · Allow microphone in Privacy"; return }
            // Permission prompts are not device stalls. Start the independent
            // watchdog only once permission is granted, before touching CoreAudio.
            self.deadline = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard let self, self.generation == token, self.isStarting else { return }
                self.stop()
                self.notice = "El micrófono no respondió. Cerrando la prueba… · Microphone timed out. Closing test…"
            }
            do {
                try await capture.start(selectedUID: selectedUID, level: { [weak self] power in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        self.isStarting = false
                        self.isTesting = true
                        self.level = power
                    }
                }, routeChanged: { [weak self] in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        self.stop()
                        self.notice = "Entrada cambiada. Repite la prueba · Input changed. Retry the test"
                    }
                })
                guard self.generation == token else { return }
                // Do not cancel the startup watchdog until real input arrives.
                self.startup = nil
                Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                    guard self?.generation == token else { return }
                    self?.stop()
                }
            } catch {
                guard self.generation == token else { return }
                self.logger.error("Microphone test start failed: \((error as NSError).code, privacy: .public)")
                self.stop()
                self.notice = "No se pudo abrir el micrófono · Couldn't open microphone"
            }
        }
    }
}
