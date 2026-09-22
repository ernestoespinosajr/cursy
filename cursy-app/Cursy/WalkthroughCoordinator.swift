import Combine
import Foundation

/// Owns guide work independently of conversation audio. Dependencies share the app's
/// capture slot and validated locator; this coordinator never performs user input.
@MainActor
final class WalkthroughCoordinator: ObservableObject {
    struct Dependencies {
        var plan: (String) async throws -> WalkthroughPlan
        var capture: () async throws -> VisualTurnContext
        var locate: (WalkthroughPlan.Step, VisualTurnContext, () async throws -> (() -> Void)) async throws -> [VisualAnnotation]
        var verify: (WalkthroughPlan.Step, VisualTurnContext, VisualTurnContext) async throws -> StepVerificationDecision
        var allowed: (UUID) -> Bool
        var publish: ([VisualAnnotation]) -> Void
        var clock: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
        var sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    }

    enum Notice: Equatable {
        case preparing, ready, locating, following, paused, unavailable, uncertain
        case nextStep, completed, cancelled, limit, blocked(String)
    }

    @Published private(set) var guide: WalkthroughSession? {
        didSet { persistCurrentIfEnabled() }
    }
    @Published private(set) var savedGuides: [WalkthroughSession.Checkpoint] = []
    @Published private(set) var persistenceFailed = false
    @Published private(set) var notice: Notice = .ready
    @Published private(set) var isPreparing = false
    @Published private(set) var isFollowing = false
    private(set) var verificationPolicy: StepVerificationPolicy?
    private let dependencies: Dependencies
    private let store: WalkthroughStore?
    private var savedIDs: Set<UUID> = []
    private var deletedSavedIDs: Set<UUID> = []
    private var operationID = UUID()
    private var operationTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var lastSceneEvent: TimeInterval = -.infinity

    init(dependencies: Dependencies, store: WalkthroughStore? = nil) {
        self.dependencies = dependencies
        self.store = store
    }

    var currentIsSaved: Bool { guide.map { savedIDs.contains($0.id) } ?? false }

    func loadSavedGuides() async {
        guard let store else { return }
        do {
            let loaded = try await store.loadAll()
            savedGuides = loaded.filter { !deletedSavedIDs.contains($0.id) }
            savedIDs = Set(savedGuides.map(\.id))
            persistenceFailed = false
        } catch { persistenceFailed = true }
    }

    func saveCurrentGuide() async {
        guard let store, let checkpoint = guide?.checkpoint, !deletedSavedIDs.contains(checkpoint.id) else { return }
        do {
            try await store.save(checkpoint, consent: true)
            guard !deletedSavedIDs.contains(checkpoint.id) else { return }
            savedIDs.insert(checkpoint.id)
            persistCurrentIfEnabled()
            await loadSavedGuides()
        } catch { persistenceFailed = true }
    }

    func deleteSavedGuide(_ id: UUID) async {
        guard let store else { return }
        if guide?.id == id { cancel() }
        deletedSavedIDs.insert(id)
        savedIDs.remove(id)
        do {
            try await store.delete(id)
            savedGuides.removeAll { $0.id == id }
            persistenceFailed = false
        } catch { persistenceFailed = true }
    }

    private func persistCurrentIfEnabled() {
        guard let store, let checkpoint = guide?.checkpoint, savedIDs.contains(checkpoint.id),
              !deletedSavedIDs.contains(checkpoint.id) else { return }
        Task { [weak self] in
            do {
                try await store.save(checkpoint, consent: true)
                await self?.loadSavedGuides()
            } catch WalkthroughStore.StoreError.staleWrite {
                // A later revision or deletion already won; never retry an obsolete save.
            } catch { self?.persistenceFailed = true }
        }
    }

    func revise(request: String) {
        guard let current = guide, !current.isTerminal else { return }
        pause()
        isPreparing = true
        notice = .preparing
        let operation = operationID
        let completed = current.steps.prefix(current.completedCount).map { $0.content.instruction }.joined(separator: "\n")
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let plan = try await dependencies.plan("Keep this goal: \(current.goal)\nAlready completed, do not repeat:\n\(completed)\nUser correction:\n\(request)")
                guard owns(operation), guide?.id == current.id else { return }
                try guide?.reviseRemaining(plan.steps)
                isPreparing = false
                notice = .paused
            } catch {
                guard owns(operation) else { return }
                isPreparing = false
                notice = .unavailable
            }
        }
    }

    func prepare(request: String, conversationID: UUID) {
        stopWork()
        guide?.cancel()
        guide = nil
        verificationPolicy = nil
        isPreparing = true
        notice = .preparing
        let operation = operationID
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let plan = try await dependencies.plan(request)
                guard owns(operation) else { return }
                guide = try WalkthroughSession(plan: plan, conversationID: conversationID)
                isPreparing = false
                notice = .ready
            } catch {
                guard owns(operation) else { return }
                isPreparing = false
                notice = .unavailable
            }
        }
    }

    func start() {
        guard guide?.activate() == true else { return }
        notice = .locating
        presentCurrentStep()
    }

    /// Explicit per-lease choice, not inferred from global screen-sharing consent.
    func enableFollowing() {
        guard let token = guide?.token, dependencies.allowed(token.conversationID) else { return }
        if verificationPolicy == nil {
            verificationPolicy = StepVerificationPolicy(token: token, usage: guide?.verificationUsage ?? [:])
        }
        if verificationPolicy?.token != token { _ = verificationPolicy?.move(to: token) }
        guard verificationPolicy?.startLease(at: dependencies.clock(), consent: true) == true else {
            notice = .limit
            return
        }
        isFollowing = true
        notice = .following
        scheduleLeaseDeadline()
        presentCurrentStep()
    }

    func pause() {
        stopWork()
        guide?.pause()
        notice = guide?.status == .completed ? .completed : guide?.status == .cancelled ? .cancelled : .paused
    }

    func cancel() {
        stopWork()
        guide?.cancel()
        notice = .cancelled
    }

    func confirmCurrentStep() {
        guard let token = guide?.token else { return }
        advance(token, confirmation: .user)
    }

    func sceneChanged() {
        guard guide?.status == .active else { return }
        lastSceneEvent = dependencies.clock()
        verificationPolicy?.invalidateScene()
        dependencies.publish([])
    }

    func restore(_ checkpoint: WalkthroughSession.Checkpoint) throws {
        let restored = try WalkthroughSession(checkpoint: checkpoint)
        stopWork()
        guide = restored
        verificationPolicy = nil
        notice = restored.status == .completed ? .completed : restored.status == .cancelled ? .cancelled : .paused
    }

    private func advance(_ token: WalkthroughStepToken, confirmation: WalkthroughSession.Confirmation) {
        guard guide?.confirm(token, by: confirmation) == true else { return }
        dependencies.publish([])
        if guide?.status == .completed {
            stopWork()
            notice = .completed
        } else {
            if let next = guide?.token { _ = verificationPolicy?.move(to: next) }
            notice = .nextStep
            presentCurrentStep()
        }
    }

    private func stopWork() {
        operationID = UUID()
        operationTask?.cancel(); operationTask = nil
        deadlineTask?.cancel(); deadlineTask = nil
        verificationPolicy?.stop(.paused)
        isFollowing = false
        isPreparing = false
        dependencies.publish([])
    }

    private func owns(_ operation: UUID, token: WalkthroughStepToken? = nil) -> Bool {
        !Task.isCancelled && operationID == operation && (token == nil || guide?.token == token)
    }

    private func canObserve(_ token: WalkthroughStepToken) -> Bool {
        guide?.token == token && dependencies.allowed(token.conversationID)
    }

    /// A stale continuation must never pause its replacement. The current owner,
    /// however, must revoke following immediately when observation is no longer allowed.
    private func continueObservation(_ operation: UUID, token: WalkthroughStepToken) -> Bool {
        guard owns(operation, token: token) else { return false }
        guard canObserve(token) else { pause(); return false }
        return true
    }

    private func reserveGuidanceRequest(for token: WalkthroughStepToken) async throws -> (() -> Void) {
        while true {
            try Task.checkCancellation()
            guard canObserve(token) else { throw CancellationError() }
            // Manual localization follows an explicit user action. Automatic follow-up
            // localization shares the verification lease's remote quota and interval.
            guard isFollowing else { return {} }
            let now = dependencies.clock()
            switch verificationPolicy?.reserveAnalysis(observationID: UUID(), capturedAt: now, at: now, consent: true) {
            case .allowed(let reservation):
                try await recordReservedUsage(for: token)
                try Task.checkCancellation()
                guard canObserve(token) else { throw CancellationError() }
                return { [weak self] in
                    guard let self else { return }
                    _ = self.verificationPolicy?.accept(reservation, at: self.dependencies.clock(), consent: self.canObserve(token))
                }
            case .wait:
                try await dependencies.sleep(.seconds(1))
            case .stopped, .none: throw CancellationError()
            }
        }
    }

    private func recordReservedUsage(for token: WalkthroughStepToken) async throws {
        guard guide?.token == token, let usage = verificationPolicy?.stepCounts else { throw CancellationError() }
        try guide?.recordVerificationUsage(usage)
        // Saved guides commit the debit before dispatch, so reopening cannot replenish
        // the budget. Temporary guides still never create a file. No lease is persisted.
        if let store, let checkpoint = guide?.checkpoint, savedIDs.contains(checkpoint.id) {
            try await store.save(checkpoint, consent: true)
        }
    }

    private func scheduleLeaseDeadline() {
        deadlineTask?.cancel()
        guard let deadline = verificationPolicy?.leaseDeadline else { return }
        deadlineTask = Task { [weak self] in
            guard let self else { return }
            do { try await dependencies.sleep(.seconds(max(0, deadline - dependencies.clock()))) }
            catch { return }
            guard !Task.isCancelled, isFollowing, verificationPolicy?.leaseDeadline == deadline else { return }
            pause()
            notice = .limit
        }
    }

    private func presentCurrentStep() {
        let previousOperation = operationTask
        previousOperation?.cancel()
        operationID = UUID()
        guard let token = guide?.token, let step = guide?.currentStep?.content else { return }
        let operation = operationID
        operationTask = Task { [weak self] in
            guard let self else { return }
            await previousOperation?.value
            guard owns(operation, token: token) else { return }
            guard canObserve(token) else {
                notice = .ready // Manual instructions remain available without screen access.
                return
            }
            do {
                let sceneAtStart = lastSceneEvent
                if isFollowing { try await dependencies.sleep(.seconds(1)) }
                guard continueObservation(operation, token: token) else { return }
                let before = try await dependencies.capture()
                guard continueObservation(operation, token: token) else { return }
                let marks = try await dependencies.locate(step, before, { try await self.reserveGuidanceRequest(for: token) })
                guard continueObservation(operation, token: token) else { return }
                if !marks.isEmpty {
                    try await dependencies.sleep(.seconds(1))
                    guard continueObservation(operation, token: token) else { return }
                    let fresh = try await dependencies.capture()
                    guard continueObservation(operation, token: token) else { return }
                    if sceneAtStart == lastSceneEvent, fresh.displayID == before.displayID,
                       fresh.displayFrame == before.displayFrame,
                       try !VisualSceneFingerprint(imageData: fresh.imageData).differs(from: VisualSceneFingerprint(imageData: before.imageData)) {
                        dependencies.publish(marks)
                    }
                }
                if isFollowing {
                    try await observe(step: step, token: token, before: before, operation: operation)
                } else if notice != .nextStep { notice = .ready }
            } catch {
                guard owns(operation, token: token) else { return }
                let reachedLimit = verificationPolicy?.stopped == .stepLimit || verificationPolicy?.stopped == .guideLimit
                pause()
                notice = reachedLimit ? .limit : .unavailable
            }
        }
    }

    private func observe(step: WalkthroughPlan.Step, token: WalkthroughStepToken,
                         before: VisualTurnContext, operation: UUID) async throws {
        let baseline = try VisualSceneFingerprint(imageData: before.imageData)
        var previous = baseline
        var lastAnalyzed: VisualSceneFingerprint?
        while owns(operation, token: token), isFollowing {
            try await dependencies.sleep(.seconds(1))
            guard continueObservation(operation, token: token) else { return }
            let now = dependencies.clock()
            guard verificationPolicy?.isAllowed(at: now, consent: true) == true else {
                pause(); notice = .limit; return
            }
            guard now - lastSceneEvent >= 0.5,
                  verificationPolicy?.reserveCapture(at: now, consent: true) == true else { continue }
            let eventRevision = lastSceneEvent
            let capturedAt = dependencies.clock()
            let current = try await dependencies.capture()
            guard continueObservation(operation, token: token) else { return }
            let fingerprint = try VisualSceneFingerprint(imageData: current.imageData)
            let stable = !fingerprint.differs(from: previous)
            previous = fingerprint
            if !stable {
                dependencies.publish([])
                verificationPolicy?.invalidateScene()
                continue
            }
            guard eventRevision == lastSceneEvent, fingerprint.differs(from: baseline),
                  lastAnalyzed.map({ fingerprint.differs(from: $0) }) ?? true else { continue }
            let reservation = verificationPolicy?.reserveAnalysis(observationID: UUID(), capturedAt: capturedAt,
                at: dependencies.clock(), consent: true)
            guard case .allowed(let request) = reservation else {
                if case .stopped = reservation { pause(); notice = .limit; return }
                continue
            }
            try await recordReservedUsage(for: token)
            guard continueObservation(operation, token: token) else { return }
            let reportedDecision = try await dependencies.verify(step, before, current)
            let decision = reportedDecision.validated(step: step, before: before, current: current)
            guard continueObservation(operation, token: token) else { return }
            // Recheck actual pixels after the provider wait, not only OS event hints.
            try await dependencies.sleep(.seconds(1))
            guard continueObservation(operation, token: token) else { return }
            let recheck = try await dependencies.capture()
            guard continueObservation(operation, token: token) else { return }
            let latest = try VisualSceneFingerprint(imageData: recheck.imageData)
            if recheck.displayID != current.displayID || recheck.displayFrame != current.displayFrame
                || latest.differs(from: fingerprint) { verificationPolicy?.invalidateScene() }
            guard verificationPolicy?.accept(request, at: dependencies.clock(), consent: true) == true else { continue }
            lastAnalyzed = fingerprint
            switch decision.outcome {
            case .confirmed:
                if step.requiresExplicitConfirmation || !decision.windowRemainsVisible(from: current, in: recheck) {
                    pause(); notice = .uncertain; return
                }
                advance(token, confirmation: .visual(observationID: request.observationID, evidence: decision.evidenceSummary))
                return
            case .pending:
                if verificationPolicy?.remoteCount == 30 || verificationPolicy?.stepCounts[token.stepID] == 10 {
                    pause(); notice = .limit; return
                }
                let sceneBeforeLocalization = lastSceneEvent
                let marks = try await dependencies.locate(step, recheck, { try await self.reserveGuidanceRequest(for: token) })
                guard continueObservation(operation, token: token) else { return }
                if !marks.isEmpty {
                    try await dependencies.sleep(.seconds(1))
                    guard continueObservation(operation, token: token) else { return }
                    let fresh = try await dependencies.capture()
                    guard continueObservation(operation, token: token) else { return }
                    if sceneBeforeLocalization == lastSceneEvent, fresh.displayID == recheck.displayID,
                       fresh.displayFrame == recheck.displayFrame,
                       try !VisualSceneFingerprint(imageData: fresh.imageData).differs(from: latest) {
                        dependencies.publish(marks)
                    }
                }
                notice = .following
            case .uncertain: pause(); notice = .uncertain; return
            case .blocked:
                guide?.block(decision.evidenceSummary, for: token)
                stopWork()
                notice = .blocked(decision.evidenceSummary)
                return
            }
        }
    }
}
