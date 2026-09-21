import AppKit
import Combine

/// Owns only opt-in Talk input. No provider calls, persistent storage or OCR.
@MainActor
final class SpatialContextRecorder: ObservableObject {
    enum Status { case idle, preparing, recording, released, discarded, limited }
    @Published private(set) var status: Status = .idle
    @Published private(set) var trail: [SpatialPointerSample] = []
    @Published private(set) var displayFrame: CGRect?
    @Published private(set) var retainedSceneCount = 0
    private(set) var owner: ConversationTurnContext?
    private var path: SpatialPath?
    private var baseline: VisualTurnContext?
    private var verifiedScene: SpatialSceneEvidence?
    private var sceneHistory: [SpatialSceneEvidence] = []
    private var omittedScenes = 0
    private var revision = 0
    private var generation = UUID()
    private var timer: Timer?
    private var monitors: [Any] = []
    private var captureTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var displayObserver: NSObjectProtocol?
    private var isHolding = false
    private var isSealed = false
    private var lastCaptureAttempt: TimeInterval = -.infinity
    private var baselineFailure: SpatialDeliveryState = .baselineUnavailable
    private(set) var lastAttachmentState: SpatialDeliveryState = .notRequested
    private let clock: () -> TimeInterval
    private let capture: () async throws -> VisualTurnContext
    private let pointer: () -> CGPoint
    private let allowed: () -> Bool
    private let installEventSources: Bool
    var onCancelInput: (() -> Void)?

    init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         capture: @escaping () async throws -> VisualTurnContext = {
             try await VisualCaptureRequest().run(capture: {
                 try await CompanionScreenCaptureUtility.captureCursorScreen(logCapture: false)
             })
         }, pointer: @escaping () -> CGPoint = { NSEvent.mouseLocation },
         allowed: @escaping () -> Bool = { CGPreflightScreenCaptureAccess() },
         installEventSources: Bool = true) {
        self.clock = clock
        self.capture = capture
        self.pointer = pointer
        self.allowed = allowed
        self.installEventSources = installEventSources
    }

    func begin(owner: ConversationTurnContext) {
        cancel()
        guard allowed() else { return }
        self.owner = owner
        lastAttachmentState = .notRequested
        baselineFailure = .baselineUnavailable
        revision = 0
        path = SpatialPath(startedAt: clock())
        isHolding = true
        status = .preparing
        if installEventSources {
            displayObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.invalidate() }
                }
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.invalidate() }
                })
            let notifications: [Notification.Name] = [NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.willSleepNotification]
            for name in notifications {
                workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
                    forName: name, object: nil, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.onCancelInput?()
                            self?.cancel()
                        }
                    })
            }
            // Listen only; never consume keys, perform clicks or modify the real cursor.
            let mask: NSEvent.EventTypeMask = [.scrollWheel, .leftMouseDown, .rightMouseDown, .leftMouseDragged, .keyDown]
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
                self?.handle(event)
            }) { monitors.append(monitor) }
            if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
                self?.handle(event)
                return event
            }) { monitors.append(monitor) }
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        let expectedGeneration = generation
        expiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.generation == expectedGeneration else { return }
            self.discard(.limited)
        }
        requestBaseline()
    }

    private func handle(_ event: NSEvent) {
        guard isHolding else { return }
        if event.type == .keyDown, event.keyCode == 53 {
            onCancelInput?()
            cancel()
        } else {
            // Do not store keys or event text. Any potentially changing input revokes
            // the previous scene before another baseline is allowed to collect points.
            invalidate()
        }
    }

    func invalidate(reason: SpatialDeliveryState = .geometryChanged) {
        guard isHolding, let startedAt = path?.startedAt else { return }
        if reason == .geometryChanged || reason == .regionChanged { archiveVerifiedScene() }
        else { verifiedScene = nil }
        revision += 1
        baseline = nil
        baselineFailure = reason
        path = SpatialPath(startedAt: startedAt)
        trail = []
        displayFrame = nil
        status = .preparing
        // Let scrolling/dragging settle; mouse-move alone does not invalidate.
        lastCaptureAttempt = clock()
    }

    func sample() {
        guard isHolding, let startedAt = path?.startedAt else { return }
        guard allowed() else { cancel(reason: .permissionRevoked); return }
        guard clock() - startedAt < SpatialPath.durationLimit else {
            discard(.limited)
            return
        }
        guard let baseline else { requestBaseline(); return }
        let point = pointer()
        guard baseline.displayFrame.contains(point) else { invalidate(); return }
        path?.append(globalPoint: point, displayFrame: baseline.displayFrame, at: clock())
        trail = path?.samples ?? []
        // Content-free checks detect scene changes even without scroll events.
        // At most one local snapshot per second; none invokes a model.
        if clock() - lastCaptureAttempt >= 1 { requestBaseline() }
    }

    private func requestBaseline() {
        guard isHolding, captureTask == nil, clock() - lastCaptureAttempt >= 0.5,
              allowed() else { return }
        lastCaptureAttempt = clock()
        let expectedGeneration = generation
        let expectedRevision = revision
        let captureStartedAt = clock()
        captureTask = Task { [weak self] in
            guard let self else { return }
            guard !Task.isCancelled, self.generation == expectedGeneration,
                  self.isHolding, self.allowed() else {
                self.finishCapture()
                return
            }
            do {
                let context = try await self.capture()
                guard !Task.isCancelled, self.generation == expectedGeneration,
                      self.revision == expectedRevision, self.isHolding, self.allowed(),
                      context.imageData.count <= 1_048_576,
                      context.displayFrame.contains(self.pointer()) else {
                    if self.generation == expectedGeneration, self.isHolding { self.invalidate() }
                    self.finishCapture()
                    return
                }
                if let baseline = self.baseline, let path = self.path {
                    let changed = !context.hasSameSpatialGeometry(as: baseline)
                        || self.sceneChanged(baseline, context, region: path.evidenceRegion)
                    if changed {
                        self.archiveVerifiedScene()
                        self.revision += 1
                        self.path = SpatialPath(startedAt: path.startedAt)
                        self.trail = []
                    } else if let owner = self.owner {
                        // Samples collected AFTER capture began are not verified by
                        // this image. Never archive an unverified tail on scene change.
                        let observed = max(0, Int((captureStartedAt - path.startedAt) * 1000))
                        let samples = path.samples.filter { $0.milliseconds <= observed }
                        if !samples.isEmpty {
                            self.verifiedScene = SpatialSceneEvidence(imageData: context.imageData,
                                packet: self.packet(context: context, owner: owner, samples: samples),
                                observedMilliseconds: observed)
                        }
                    }
                }
                self.baseline = context
                self.displayFrame = context.displayFrame
                self.status = .recording
            } catch {
                if self.generation == expectedGeneration, self.isHolding {
                    self.invalidate(reason: .captureFailed)
                }
            }
            self.finishCapture()
        }
    }

    private func sceneChanged(_ before: VisualTurnContext, _ after: VisualTurnContext, region: CGRect?) -> Bool {
        guard let before = try? VisualSceneFingerprint(imageData: before.imageData),
              let after = try? VisualSceneFingerprint(imageData: after.imageData) else { return true }
        return after.differs(from: before, region: region ?? CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    private func finishCapture() {
        // A replacement cannot start while this slot is non-nil, even on reset.
        // Only the sole in-flight task releases it; generation gates its evidence.
        captureTask = nil
    }

    private func packet(context: VisualTurnContext, owner: ConversationTurnContext,
                        samples: [SpatialPointerSample]) -> SpatialContextPacket {
        SpatialContextPacket(sessionID: owner.sessionID.rawValue.uuidString,
            turnID: owner.turnID.rawValue.uuidString, captureID: context.captureID,
            displayID: context.displayID, sceneRevision: revision,
            imageWidth: context.imageWidth, imageHeight: context.imageHeight,
            points: SpatialPath.simplified(samples, limit: SpatialPath.exportLimit).map {
                [$0.x, $0.y, Double($0.milliseconds)]
            })
    }

    private func archiveVerifiedScene() {
        if let verifiedScene {
            sceneHistory.append(verifiedScene)
            if sceneHistory.count > SpatialSceneEvidence.historyLimit {
                sceneHistory.removeFirst()
                omittedScenes += 1
            }
        } else if path?.samples.isEmpty == false {
            omittedScenes += 1
        }
        verifiedScene = nil
        retainedSceneCount = sceneHistory.count
    }

    func release() {
        guard isHolding else { return }
        sample()
        isHolding = false
        stopEventSources()
        trail = []
        if status != .limited { status = .released }
    }

    /// Drain the baseline before the normal final screenshot; no parallel capture
    /// or mixing a late sample with a new turn. One caller seals once per turn.
    func drainCapture() async { await captureTask?.value }

    func attach(to context: VisualTurnContext, owner: ConversationTurnContext) -> VisualTurnContext {
        var result = context
        result.spatialHistory = []
        result.omittedSpatialScenes = 0
        guard self.owner != nil else { return result }
        result.spatialSessionID = owner.sessionID
        result.spatialTurnID = owner.turnID
        result.spatialRevision = revision
        guard self.owner == owner else { return omit(.ownerMismatch, from: result) }
        guard !isHolding else { return omit(.stillRecording, from: result) }
        guard !isSealed else { return omit(.alreadyConsumed, from: result) }
        isSealed = true
        defer {
            baseline = nil; path = nil; trail = []; verifiedScene = nil
            sceneHistory = []; retainedSceneCount = 0; omittedScenes = 0
            expiryTask?.cancel(); expiryTask = nil
        }
        guard allowed() else { return omit(.permissionRevoked, from: result) }
        guard status != .limited else { return omit(.expired, from: result) }
        guard let path else { return omit(.noSamples, from: result) }
        guard clock() - path.startedAt < SpatialPath.durationLimit else { return omit(.expired, from: result) }
        result.spatialHistory = sceneHistory
        result.omittedSpatialScenes = omittedScenes
        guard let baseline else { return omit(baselineFailure, from: result) }
        guard let region = path.evidenceRegion else { return omit(.noSamples, from: result) }
        guard context.hasSameSpatialGeometry(as: baseline) else { return omit(.geometryChanged, from: result) }
        guard let before = try? VisualSceneFingerprint(imageData: baseline.imageData),
              let after = try? VisualSceneFingerprint(imageData: context.imageData) else {
            return omit(.imageUnreadable, from: result)
        }
        guard !after.differs(from: before, region: region) else { return omit(.regionChanged, from: result) }
        result.spatialInput = packet(context: context, owner: owner, samples: path.samples)
        result.spatialDeliveryState = .attached
        lastAttachmentState = .attached
        SpatialDiagnostics.record(.attachment, context: result, collectedSamples: path.samples.count)
        return result
    }

    private func omit(_ reason: SpatialDeliveryState, from context: VisualTurnContext) -> VisualTurnContext {
        var result = context
        result.spatialInput = nil
        result.spatialDeliveryState = reason
        result.spatialInputNotice = "Spatial input was requested but has no verified current-scene path (\(reason.rawValue)). Do not infer a location from previous gestures. For an unresolved 'this/here/these', ask the user to point again while speaking. Explicit named targets can still be located in the current image."
        if isSealed, context.spatialTurnID == owner?.turnID { status = .discarded }
        lastAttachmentState = reason
        SpatialDiagnostics.record(.attachment, context: result, collectedSamples: path?.samples.count ?? 0)
        return result
    }

    func cancel(reason: SpatialDeliveryState = .cancelled) {
        if let owner, !isSealed {
            SpatialDiagnostics.terminated(owner: owner, state: reason, sampleCount: path?.samples.count ?? 0)
        }
        generation = UUID()
        expiryTask?.cancel(); expiryTask = nil
        captureTask?.cancel()
        // Keep the task until drained, so the next capture waits for its completion.
        isHolding = false
        isSealed = false
        owner = nil
        baseline = nil
        verifiedScene = nil
        sceneHistory = []
        retainedSceneCount = 0
        omittedScenes = 0
        path = nil
        trail = []
        displayFrame = nil
        lastCaptureAttempt = -.infinity
        status = .idle
        stopEventSources(includingLifecycle: true)
    }

    private func discard(_ status: Status) {
        isHolding = false
        baseline = nil
        verifiedScene = nil
        sceneHistory = []
        retainedSceneCount = 0
        omittedScenes = 0
        path = nil
        trail = []
        displayFrame = nil
        self.status = status
        stopEventSources()
    }

    private func stopEventSources(includingLifecycle: Bool = false) {
        timer?.invalidate(); timer = nil
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        if includingLifecycle {
            workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
            workspaceObservers.removeAll()
            if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
            displayObserver = nil
        }
    }
}
