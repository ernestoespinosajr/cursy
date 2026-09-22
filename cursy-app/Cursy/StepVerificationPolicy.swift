import Foundation

/// Client-owned correlation. Models supply an outcome and evidence, never IDs or permissions.
nonisolated struct StepVerificationRequest: Equatable, Sendable {
    let id: UUID
    let token: WalkthroughStepToken
    let observationID: UUID
    let sceneRevision: Int
    let capturedAt: TimeInterval
}

nonisolated struct StepVerificationDecision: Codable, Equatable, Sendable {
    enum Outcome: String, Codable, Sendable { case pending, confirmed, uncertain, blocked }
    let outcome: Outcome
    let evidenceSummary: String
    let evidence: StepVerificationEvidence?

    init(outcome: Outcome, evidenceSummary: String, evidence: StepVerificationEvidence? = nil) {
        self.outcome = outcome
        self.evidenceSummary = evidenceSummary
        self.evidence = evidence
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 8000 else { throw WalkthroughPlan.ValidationError.invalidText }
        let decision = try JSONDecoder().decode(Self.self, from: data)
        guard WalkthroughPlan.validText(decision.evidenceSummary, limit: 1000) else {
            throw WalkthroughPlan.ValidationError.invalidText
        }
        return decision
    }
}

/// One five-minute consent lease; renewing never replenishes guide/step remote quotas.
nonisolated struct StepVerificationPolicy: Sendable {
    enum StopReason: Equatable, Sendable { case paused, expired, stepLimit, guideLimit, consentRevoked, unavailable }
    enum Reservation: Equatable, Sendable {
        case allowed(StepVerificationRequest)
        case wait
        case stopped(StopReason)
    }

    private(set) var token: WalkthroughStepToken
    private(set) var leaseDeadline: TimeInterval?
    private(set) var stopped: StopReason? = .paused
    private(set) var sceneRevision = 0
    private(set) var remoteCount = 0
    private(set) var stepCounts: [UUID: Int] = [:]
    private(set) var inFlight: StepVerificationRequest?
    private var lastCaptureAt: TimeInterval?
    private var lastAnalysisAt: TimeInterval?

    init(token: WalkthroughStepToken, usage: [UUID: Int] = [:]) {
        self.token = token
        // The checkpoint decoder validates these counts. Fail closed for any other caller.
        if Self.validUsage(usage) {
            stepCounts = usage
            remoteCount = usage.values.reduce(0, +)
        } else { remoteCount = 30 }
    }

    static func validUsage(_ usage: [UUID: Int]) -> Bool {
        usage.count <= 30 && usage.values.allSatisfy { (1...10).contains($0) }
            && usage.values.reduce(0, +) <= 30
    }

    mutating func startLease(at now: TimeInterval, consent: Bool) -> Bool {
        guard now.isFinite, consent, remoteCount < 30, stepCounts[token.stepID, default: 0] < 10 else { return false }
        sceneRevision += 1
        leaseDeadline = now + 300
        stopped = nil
        inFlight = nil
        return true
    }

    mutating func stop(_ reason: StopReason) {
        stopped = reason
        leaseDeadline = nil
        sceneRevision += 1
        inFlight = nil
    }

    mutating func move(to next: WalkthroughStepToken) -> Bool {
        guard next.guideID == token.guideID, next.conversationID == token.conversationID,
              next.revision > token.revision else { return false }
        token = next
        sceneRevision += 1
        inFlight = nil
        return true
    }

    mutating func invalidateScene() {
        sceneRevision += 1
        // Keep single-flight ownership until completion, but its revision cannot publish.
    }

    mutating func isAllowed(at now: TimeInterval, consent: Bool) -> Bool {
        guard stopped == nil else { return false }
        guard consent else { stop(.consentRevoked); return false }
        guard now.isFinite, let deadline = leaseDeadline, now < deadline else { stop(.expired); return false }
        return true
    }

    mutating func reserveCapture(at now: TimeInterval, consent: Bool) -> Bool {
        guard isAllowed(at: now, consent: consent), inFlight == nil,
              lastCaptureAt.map({ now - $0 >= 1 }) ?? true else { return false }
        lastCaptureAt = now
        return true
    }

    mutating func reserveAnalysis(observationID: UUID, capturedAt: TimeInterval,
                                  at now: TimeInterval, consent: Bool) -> Reservation {
        guard isAllowed(at: now, consent: consent) else { return .stopped(stopped ?? .paused) }
        guard remoteCount < 30 else { stop(.guideLimit); return .stopped(.guideLimit) }
        guard stepCounts[token.stepID, default: 0] < 10 else { stop(.stepLimit); return .stopped(.stepLimit) }
        guard inFlight == nil, capturedAt.isFinite, capturedAt <= now, now - capturedAt <= 5,
              lastAnalysisAt.map({ now - $0 >= 3 }) ?? true else { return .wait }
        let request = StepVerificationRequest(id: UUID(), token: token, observationID: observationID,
                                              sceneRevision: sceneRevision, capturedAt: capturedAt)
        inFlight = request
        lastAnalysisAt = now
        remoteCount += 1
        stepCounts[token.stepID, default: 0] += 1
        return .allowed(request)
    }

    /// The actual model evaluation remains a separate quality gate. This gate only
    /// proves freshness, consent, current ownership and exactly-once publication.
    mutating func accept(_ request: StepVerificationRequest, at now: TimeInterval, consent: Bool) -> Bool {
        guard isAllowed(at: now, consent: consent), inFlight == request else { return false }
        inFlight = nil
        return request.token == token && request.sceneRevision == sceneRevision
            && now >= request.capturedAt && now - request.capturedAt <= 10
    }

    mutating func failed(_ request: StepVerificationRequest) {
        guard inFlight == request else { return }
        inFlight = nil
        stop(.unavailable)
    }
}
