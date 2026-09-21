import AppKit
import ImageIO
import os

/// A bounded visual lease, separate from the completed voice turn.
struct VisualObservationBudget {
    let startedAt: TimeInterval
    private(set) var firstPointAt: TimeInterval?
    private(set) var refreshCount = 0
    var deadline: TimeInterval { min(startedAt + 30, firstPointAt.map { $0 + 5 } ?? .infinity) }
    func isAlive(at time: TimeInterval) -> Bool { time < deadline }
    mutating func pointed(at time: TimeInterval) { if firstPointAt == nil { firstPointAt = time } }
    mutating func reserveRefresh(at time: TimeInterval) -> Bool {
        guard isAlive(at: time), refreshCount < 2 else { return false }
        refreshCount += 1
        return true
    }
}

/// Downsampled luminance only: no OCR or semantic recognition. Never uploaded.
struct VisualSceneFingerprint {
    static let width = 320
    static let height = 200
    let pixels: [UInt8]

    init(pixels: [UInt8]) { self.pixels = pixels }

    init(imageData: Data) throws {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw URLError(.cannotDecodeContentData)
        }
        var pixels = [UInt8](repeating: 0, count: Self.width * Self.height)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: Self.width,
                height: Self.height, bitsPerComponent: 8, bytesPerRow: Self.width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
            return true
        }
        guard rendered else { throw URLError(.cannotDecodeContentData) }
        self.pixels = pixels
    }

    func differs(from other: Self, region: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> Bool {
        difference(from: other, region: region).changed
    }

    func difference(from other: Self, region: CGRect) -> (changed: Bool, pixels: Int) {
        guard pixels.count == Self.width * Self.height, other.pixels.count == pixels.count,
              !region.isNull, !region.isEmpty else { return (true, 0) }
        let left = max(0, min(Self.width - 1, Int(region.minX * Double(Self.width))))
        let right = max(left + 1, min(Self.width, Int(ceil(region.maxX * Double(Self.width)))))
        let top = max(0, min(Self.height - 1, Int(region.minY * Double(Self.height))))
        let bottom = max(top + 1, min(Self.height, Int(ceil(region.maxY * Double(Self.height)))))
        let threshold = max(12, Int(Double((right - left) * (bottom - top)) * 0.004))
        var changed = 0
        for row in top..<bottom {
            for column in left..<right {
                let index = row * Self.width + column
                if abs(Int(pixels[index]) - Int(other.pixels[index])) > 18 {
                    changed += 1
                }
            }
        }
        return (changed >= threshold, changed)
    }
}

@MainActor
final class VisualObservation {
    enum EndReason: String { case cancelled, expired, exhausted, unavailable, noTarget }
    enum Status { case analyzing, updating, pointed, ended(EndReason) }
    enum InvalidationReason: String { case scroll, pixels, geometry, captureInterrupted, explicit }
    let id = UUID()
    private(set) var revision = 0
    private(set) var context: VisualTurnContext
    private(set) var ended = false
    private(set) var budget: VisualObservationBudget
    private var referenceRevision = 0
    private var lastAppliedSampleID: String?
    private var lastAppliedScopeRevision = -1
    private var scopeRevision = 0
    private var reference: VisualSceneFingerprint
    private var latest: (context: VisualTurnContext, fingerprint: VisualSceneFingerprint)?
    private var stableSince: TimeInterval
    private var target: PointingTarget?
    private var scopeResolved = false
    private var scopeWindow: CapturedWindowEvidence?
    private var nativeScopeFrame: CGRect?
    private var pendingScrollPoints: [CGPoint] = []
    private var scrollOverflow = false
    private var diagnosticEvents: [String] = []
    private var followUpEnabled = false
    private var monitorTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var followUpTask: Task<Void, Never>?
    private var captureTask: Task<VisualTurnContext, Error>?
    private var eventMonitor: Any?
    private let clock: () -> TimeInterval
    private let capture: () async throws -> VisualTurnContext
    private let waitForStability: () async throws -> Void
    private let allowed: () -> Bool
    private let clearPoint: () -> Void
    private let status: (Status) -> Void
    private let locate: (VisualTurnContext, String) async throws -> PointingTarget?
    private let publish: (PointingTarget, VisualTurnContext) -> Bool
    private let logger = Logger(subsystem: "com.hellocursy.Cursy", category: "VisualObservation")

    init(context: VisualTurnContext,
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         capture: @escaping () async throws -> VisualTurnContext = {
             try await VisualCaptureRequest().run(capture: {
                 try await CompanionScreenCaptureUtility.captureCursorScreen(logCapture: false)
             })
         },
         waitForStability: @escaping () async throws -> Void = { try await Task.sleep(for: .milliseconds(500)) },
         allowed: @escaping () -> Bool,
         clearPoint: @escaping () -> Void,
         status: @escaping (Status) -> Void,
         locate: @escaping (VisualTurnContext, String) async throws -> PointingTarget?,
         publish: @escaping (PointingTarget, VisualTurnContext) -> Bool) throws {
        self.context = context
        // Historical images belong to interpretation of the submitted utterance,
        // never to the live pointing lease or silent relocalization after it ends.
        self.context.spatialHistory = []
        self.context.omittedSpatialScenes = 0
        self.reference = try VisualSceneFingerprint(imageData: context.imageData)
        self.clock = clock
        self.capture = capture
        self.waitForStability = waitForStability
        self.allowed = allowed
        self.clearPoint = clearPoint
        self.status = status
        self.locate = locate
        self.publish = publish
        budget = VisualObservationBudget(startedAt: clock())
        stableSince = clock()
    }

    var isDirty: Bool { referenceRevision != revision }
    var isPointCurrent: Bool { alive && !isDirty && target != nil }
    var alive: Bool { !ended && allowed() && budget.isAlive(at: clock()) }

    func start() {
        status(.analyzing)
        scheduleDeadline()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.recordScroll(at: location)
            }
        }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                guard let self else { return }
                guard self.alive else { self.stop(.expired); return }
                do {
                    try await self.poll()
                    self.scheduleFollowUpIfNeeded()
                } catch {
                    if !self.ended { self.stop(.unavailable) }
                    return
                }
            }
        }
    }

    func stop(_ reason: EndReason = .cancelled) {
        guard !ended else { return }
        ended = true
        revision += 1
        monitorTask?.cancel(); monitorTask = nil
        deadlineTask?.cancel(); deadlineTask = nil
        followUpTask?.cancel(); followUpTask = nil
        captureTask?.cancel(); captureTask = nil
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        latest = nil
        target = nil
        scopeWindow = nil
        nativeScopeFrame = nil
        pendingScrollPoints.removeAll()
        reference = VisualSceneFingerprint(pixels: [])
        context = VisualTurnContext(captureID: context.captureID, displayID: context.displayID,
            displayFrame: context.displayFrame, capturedAt: context.capturedAt,
            imageData: Data(), imageWidth: context.imageWidth, imageHeight: context.imageHeight)
        clearPoint()
        status(.ended(reason))
        // Emit only after observation stops. A visible console is screen content too.
        for event in diagnosticEvents {
            logger.notice("Observation diagnostic id=\(self.id.uuidString, privacy: .public) \(event, privacy: .public)")
        }
        diagnosticEvents.removeAll()
        logger.notice("Observation ended id=\(self.id.uuidString, privacy: .public) reason=\(reason.rawValue, privacy: .public) refreshes=\(self.budget.refreshCount)")
    }

    func invalidate(reason: InvalidationReason = .explicit, changedPixels: Int = 0) {
        guard alive else { return }
        let wasDirty = isDirty
        revision += 1
        stableSince = clock()
        clearPoint()
        status(.updating)
        // Log changes, not every sample: a visible debug console must not feed itself.
        if !wasDirty, diagnosticEvents.count < 12 {
            diagnosticEvents.append("reason=\(reason.rawValue) display=\(context.displayID) window=\(scopeWindow?.windowID ?? 0) changedPixels=\(changedPixels)")
        }
    }

    func recordScroll(at point: CGPoint) {
        guard alive, context.displayFrame.contains(point) else { return }
        guard scopeResolved else {
            if pendingScrollPoints.count < 64 { pendingScrollPoints.append(point) }
            else { scrollOverflow = true }
            return
        }
        if comparisonFrame.contains(point) { invalidate(reason: .scroll) }
    }

    /// The model chooses the relevant window. Never guess it from the foreground app.
    /// Initial samples are retained, but unrelated pixels cannot spend retries before this choice.
    func prepareScope(for target: PointingTarget?, context expected: VisualTurnContext) {
        guard alive, context.captureID == expected.captureID else { return }
        scopeRevision += 1
        scopeResolved = true
        scopeWindow = context.capturedWindows.first { $0.id == target?.windowID }
        nativeScopeFrame = nil
        if scopeWindow == nil, let identifier = target?.nativeControlID,
           let native = context.nativeTargets.first(where: { $0.id == identifier }) {
            let center = CGPoint(x: native.frame.midX, y: native.frame.midY)
            scopeWindow = context.capturedWindows.first { $0.frame.contains(center) }
            if scopeWindow == nil { nativeScopeFrame = native.frame.insetBy(dx: -24, dy: -24) }
        }
        if scrollOverflow || pendingScrollPoints.contains(where: { comparisonFrame.contains($0) }) {
            invalidate(reason: .scroll)
        }
        pendingScrollPoints.removeAll()
        scrollOverflow = false
    }

    func isCurrent(_ captureID: String) -> Bool {
        alive && !isDirty && context.captureID == captureID
    }

    /// Before initial publication and after provider awaits, never rely only on window bounds.
    func verify(_ context: VisualTurnContext, target: PointingTarget? = nil) async throws -> Bool {
        guard alive, self.context.captureID == context.captureID else { return false }
        prepareScope(for: target, context: context)
        if let target { self.target = target }
        try await poll()
        return isCurrent(context.captureID)
    }

    func accepted(_ target: PointingTarget) {
        prepareScope(for: target, context: context)
        guard isCurrent(target.captureID) else { return }
        self.target = target
        budget.pointed(at: clock())
        if monitorTask != nil { scheduleDeadline() }
        status(.pointed)
    }

    /// Voice completion does not reopen its terminal turn; only this short lease continues.
    func enableFollowUp() {
        followUpEnabled = true
        scheduleFollowUpIfNeeded()
    }

    func refreshIfNeeded(_ expected: VisualTurnContext) async throws -> VisualTurnContext? {
        guard alive, context.captureID == expected.captureID else { throw CancellationError() }
        if !scopeResolved { prepareScope(for: nil, context: expected) }
        try await poll()
        guard isDirty else { return nil }
        while alive {
            if let latest, clock() - stableSince >= 0.5 {
                guard budget.reserveRefresh(at: clock()) else {
                    stop(.exhausted); throw CancellationError()
                }
                let previousDisplay = context.displayID
                context = latest.context
                reference = latest.fingerprint
                referenceRevision = revision
                self.latest = nil
                // A new image has a new window namespace and may be on another display.
                target = nil
                // Preserve the model-selected window across refreshes, but never carry
                // its coordinates onto a different display or a replacement window.
                if let window = scopeWindow {
                    scopeWindow = context.capturedWindows.first {
                        $0.windowID == window.windowID && $0.ownerPID == window.ownerPID
                    }
                    if scopeWindow == nil { scopeResolved = false }
                }
                if previousDisplay != context.displayID {
                    scopeWindow = nil; nativeScopeFrame = nil; scopeResolved = false
                }
                pendingScrollPoints.removeAll()
                scrollOverflow = false
                if diagnosticEvents.count < 12 {
                    diagnosticEvents.append("refreshed revision=\(revision) count=\(budget.refreshCount)")
                }
                return context
            }
            try await waitForStability()
            try Task.checkCancellation()
            try await poll()
        }
        stop(.expired)
        throw CancellationError()
    }

    func poll() async throws {
        guard alive else {
            stop(allowed() ? .expired : .cancelled)
            throw CancellationError()
        }
        // Monitor, pre-publication checks and refresh share one ScreenCaptureKit request.
        let operation: Task<VisualTurnContext, Error>
        if let captureTask { operation = captureTask }
        else {
            operation = Task { try await capture() }
            captureTask = operation
        }
        let sample: VisualTurnContext
        do { sample = try await operation.value }
        catch {
            captureTask = nil
            // Cursor/focus can cross displays while ScreenCaptureKit is suspended.
            // Its torn-snapshot guard is a refresh signal, not permission to use the old image.
            if alive, (error as? URLError)?.code == .resourceUnavailable {
                latest = nil
                invalidate(reason: .captureInterrupted)
                return
            }
            throw error
        }
        captureTask = nil
        guard alive else { throw CancellationError() }
        // Several callers can await the same capture. Apply its result only once.
        guard lastAppliedSampleID != sample.captureID || lastAppliedScopeRevision != scopeRevision else { return }
        lastAppliedSampleID = sample.captureID
        lastAppliedScopeRevision = scopeRevision
        let fingerprint = try VisualSceneFingerprint(imageData: sample.imageData)
        let region = comparisonRegion
        let geometryChanged = geometryChanged(context, sample)
        let difference = reference.difference(from: fingerprint, region: region)
        let referenceChanged = geometryChanged || (scopeResolved && difference.changed)
        let previousChanged = latest.map {
            self.geometryChanged($0.context, sample)
                || (scopeResolved && $0.fingerprint.differs(from: fingerprint, region: region))
        } ?? referenceChanged
        if referenceChanged && !isDirty {
            invalidate(reason: geometryChanged ? .geometry : .pixels, changedPixels: difference.pixels)
        }
        if previousChanged { stableSince = clock() }
        latest = (sample, fingerprint)
    }

    private var comparisonRegion: CGRect {
        let frame = comparisonFrame
        return CGRect(x: (frame.minX - context.displayFrame.minX) / context.displayFrame.width,
                      y: (context.displayFrame.maxY - frame.maxY) / context.displayFrame.height,
                      width: frame.width / context.displayFrame.width,
                      height: frame.height / context.displayFrame.height)
    }

    private var comparisonFrame: CGRect {
        (scopeWindow?.frame ?? nativeScopeFrame ?? context.displayFrame).intersection(context.displayFrame)
    }

    private func geometryChanged(_ first: VisualTurnContext, _ second: VisualTurnContext) -> Bool {
        guard first.displayID == second.displayID, first.displayFrame == second.displayFrame else { return true }
        guard scopeResolved else { return false }
        func relevantWindows(_ sample: VisualTurnContext) -> [CapturedWindowEvidence] {
            guard let window = scopeWindow else {
                return sample.capturedWindows.filter { $0.frame.intersects(comparisonFrame) }
            }
            guard let index = sample.capturedWindows.firstIndex(where: { $0.windowID == window.windowID }) else { return [] }
            return sample.capturedWindows[...index].filter { $0.frame.intersects(comparisonFrame) }
        }
        let original = relevantWindows(first)
        let current = relevantWindows(second)
        guard original.count == current.count else { return true }
        return zip(original, current).contains {
            $0.windowID != $1.windowID || $0.ownerPID != $1.ownerPID || $0.frame != $1.frame
        }
    }

    private func scheduleFollowUpIfNeeded() {
        guard followUpEnabled, alive, isDirty, target != nil, followUpTask == nil else { return }
        followUpTask = Task { [weak self] in
            guard let self else { return }
            defer { self.followUpTask = nil }
            await self.refreshPointIfNeeded()
        }
    }

    private func scheduleDeadline() {
        deadlineTask?.cancel()
        let delay = max(0, budget.deadline - clock())
        deadlineTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            self?.stop(.expired)
        }
    }

    /// Shared production/test seam; does not generate voice or advance the user's step.
    func refreshPointIfNeeded() async {
        guard alive, isDirty, let requestedTarget = target else { return }
        let sourceApplication = context.capturedWindows.first { $0.id == requestedTarget.windowID }?.applicationName
        let description = requestedTarget.label + (sourceApplication.map { " (application: \($0))" } ?? "")
        do {
            guard let fresh = try await refreshIfNeeded(context) else { return }
            let candidate = try await locate(fresh, description)
            guard alive else { return }
            guard try await verify(fresh, target: candidate) else {
                // Preserve semantic intent for another bounded attempt, never old coordinates.
                target = requestedTarget
                return
            }
            guard let candidate else { stop(.noTarget); return }
            guard publish(candidate, fresh) else { stop(.noTarget); return }
            accepted(candidate)
        } catch {
            if !ended { stop(alive ? .unavailable : .expired) }
        }
    }
}
