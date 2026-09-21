import Foundation
import Testing
@testable import Cursy

@Suite("Microphone route safety")
struct HomeMicrophoneRouteTests {
    @MainActor @Test func permissionDenialNeverOpensInput() async throws {
        let capture = FakeMicrophoneCapture()
        let microphone = HomeMicrophone(capture: capture, permission: { false })
        microphone.start(canStart: { true })
        try await waitUntil { !microphone.ownsInput }
        #expect(await capture.starts == 0)
        #expect(!microphone.ownsInput)
        #expect(microphone.notice != nil)
    }
    @MainActor @Test func cancellationBeforePermissionNeverStartsLateCapture() async throws {
        let capture = FakeMicrophoneCapture()
        let microphone = HomeMicrophone(capture: capture, permission: {
            try? await Task.sleep(for: .milliseconds(25))
            return true
        })
        microphone.start(canStart: { true })
        microphone.stop()
        try await waitUntil { !microphone.ownsInput }
        #expect(await capture.starts == 0)
        #expect(!microphone.ownsInput)
    }
    @MainActor @Test func repeatedStartAndLateMeterCannotReopenStoppedTest() async throws {
        let capture = FakeMicrophoneCapture()
        let microphone = HomeMicrophone(capture: capture, permission: { true })
        microphone.start(canStart: { true })
        microphone.start(canStart: { true })
        try await waitUntil { await capture.starts == 1 }
        #expect(await capture.starts == 1)
        #expect(microphone.isStarting && !microphone.isTesting)
        await capture.emit(0.5)
        try await waitUntil { microphone.isTesting }
        #expect(microphone.isTesting)
        microphone.stop()
        await capture.emit(0.8)
        try await waitUntil { !microphone.ownsInput }
        #expect(!microphone.ownsInput)
        #expect(microphone.level == 0)
    }
    @MainActor @Test func eligibilityIsCheckedAgainAfterPermission() async throws {
        let capture = FakeMicrophoneCapture()
        let microphone = HomeMicrophone(capture: capture, permission: { true })
        var allowed = true
        microphone.start(canStart: { allowed })
        allowed = false
        try await waitUntil { !microphone.ownsInput }
        #expect(await capture.starts == 0)
        #expect(!microphone.ownsInput)
    }
    @MainActor private func waitUntil(_ condition: @MainActor () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Microphone lifecycle did not settle")
    }
    @Test func explicitBuiltInAlreadyDefaultNeedsNoReassignment() {
        #expect(!HomeMicrophoneRoute.needsOverride(requested: 20, systemDefault: 20))
        #expect(HomeMicrophoneRoute.needsOverride(requested: 30, systemDefault: 20))
    }
    @Test func defaultDoesNotEnumerateOrOverrideHardware() throws {
        var enumerated = false
        let result = try HomeMicrophoneRoute.overrideDeviceID(selectedUID: "") {
            enumerated = true
            return []
        }
        #expect(result == nil)
        #expect(!enumerated)
    }
    @Test func explicitInputUsesUIDNotDisplayName() throws {
        let devices = [HomeMicrophoneDevice(id: "first", name: "Mic", audioID: 20),
                       HomeMicrophoneDevice(id: "second", name: "Mic", audioID: 30)]
        #expect(try HomeMicrophoneRoute.overrideDeviceID(selectedUID: "second", availableDevices: { devices }) == 30)
    }
    @Test func disconnectedInputDoesNotSilentlyChooseAnother() {
        #expect(throws: (any Error).self) {
            try HomeMicrophoneRoute.overrideDeviceID(selectedUID: "missing", availableDevices: { [] })
        }
    }
}

private actor FakeMicrophoneCapture: MicrophoneTestCapturing {
    private(set) var starts = 0
    private var level: (@Sendable (Double) -> Void)?
    func start(selectedUID: String, level: @escaping @Sendable (Double) -> Void,
               routeChanged: @escaping @Sendable () -> Void) async throws {
        try Task.checkCancellation()
        starts += 1
        self.level = level
    }
    func stop() {}
    func emit(_ value: Double) { level?(value) }
}
