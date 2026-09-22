import Foundation

/// Text-only plan data. Geometry is resolved from a new capture for each step.
nonisolated struct WalkthroughPlan: Codable, Equatable, Sendable {
    let goal: String
    let steps: [Step]

    struct Step: Codable, Equatable, Sendable {
        let instruction: String
        let successCriterion: String
        let requiresExplicitConfirmation: Bool
        let indications: [Indication]
    }

    struct Indication: Codable, Equatable, Sendable {
        enum Kind: String, Codable, Sendable { case cursor, circle, rectangle, arrow, label }
        enum Role: String, Codable, Sendable { case target, source, destination, route, explanation }
        let kind: Kind
        let role: Role
        let targetQuery: String
        let caption: String
    }

    enum ValidationError: Error { case invalidGoal, invalidSteps, invalidIndications, invalidText }

    func validate() throws {
        guard Self.validText(goal, limit: 2000) else { throw ValidationError.invalidGoal }
        guard (1...20).contains(steps.count) else { throw ValidationError.invalidSteps }
        for step in steps {
            guard Self.validText(step.instruction, limit: 600),
                  Self.validText(step.successCriterion, limit: 1000) else { throw ValidationError.invalidText }
            guard step.indications.count <= 3 else { throw ValidationError.invalidIndications }
            for indication in step.indications {
                guard Self.validText(indication.targetQuery, limit: 1000),
                      Self.validText(indication.caption, limit: 120) else { throw ValidationError.invalidText }
                if indication.role == .route, indication.kind != .arrow { throw ValidationError.invalidIndications }
            }
            // A route describes a relationship, not a fabricated fixed-length arrow.
            if step.indications.contains(where: { $0.role == .route }) {
                guard step.indications.contains(where: { $0.role == .source }),
                      step.indications.contains(where: { $0.role == .destination }) else {
                    throw ValidationError.invalidIndications
                }
            }
        }
    }

    static func validText(_ text: String, limit: Int) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.utf16.count <= limit
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 100_000 else { throw ValidationError.invalidText }
        let plan = try JSONDecoder().decode(Self.self, from: data)
        try plan.validate()
        return plan
    }
}

/// Every asynchronous result must still own this exact step revision.
nonisolated struct WalkthroughStepToken: Equatable, Hashable, Codable, Sendable {
    let guideID: UUID
    let conversationID: UUID
    let stepID: UUID
    let revision: Int
}

nonisolated struct WalkthroughSession: Equatable, Sendable {
    enum Status: String, Codable, Sendable { case draft, active, paused, completed, cancelled, blocked }
    enum Confirmation: Equatable, Codable, Sendable {
        case user
        case visual(observationID: UUID, evidence: String)
    }

    struct Step: Equatable, Codable, Identifiable, Sendable {
        let id: UUID
        let content: WalkthroughPlan.Step
        fileprivate(set) var confirmation: Confirmation?
    }

    let id: UUID
    let conversationID: UUID
    let goal: String
    private(set) var revision: Int
    private(set) var status: Status
    private(set) var steps: [Step]
    private(set) var blockedReason: String?
    private(set) var verificationUsage: [UUID: Int] = [:]

    mutating func recordVerificationUsage(_ usage: [UUID: Int]) throws {
        guard StepVerificationPolicy.validUsage(usage),
              verificationUsage.allSatisfy({ usage[$0.key, default: 0] >= $0.value }) else {
            throw WalkthroughPlan.ValidationError.invalidSteps
        }
        // Usage is accounting, not a new step revision; in-flight tokens stay unchanged.
        verificationUsage = usage
    }

    init(plan: WalkthroughPlan, conversationID: UUID) throws {
        try plan.validate()
        id = UUID()
        self.conversationID = conversationID
        goal = plan.goal
        revision = 0
        status = .draft
        steps = plan.steps.map { Step(id: UUID(), content: $0) }
    }

    var completedCount: Int { steps.prefix(while: { $0.confirmation != nil }).count }
    var currentStep: Step? { steps.first(where: { $0.confirmation == nil }) }
    var token: WalkthroughStepToken? {
        guard status == .active, let currentStep else { return nil }
        return WalkthroughStepToken(guideID: id, conversationID: conversationID,
                                    stepID: currentStep.id, revision: revision)
    }
    var isTerminal: Bool { status == .completed || status == .cancelled }

    @discardableResult mutating func activate() -> Bool {
        guard [.draft, .paused, .blocked].contains(status), currentStep != nil else { return false }
        revision += 1
        status = .active
        blockedReason = nil
        return true
    }

    mutating func pause() {
        guard status == .active else { return }
        revision += 1
        status = .paused
    }

    mutating func cancel() {
        guard !isTerminal else { return }
        revision += 1
        status = .cancelled
    }

    mutating func block(_ reason: String, for expected: WalkthroughStepToken) {
        guard token == expected else { return }
        revision += 1
        status = .blocked
        blockedReason = String(reason.prefix(600))
    }

    /// Synchronous transaction: duplicate or late confirmations cannot advance twice.
    @discardableResult mutating func confirm(_ expected: WalkthroughStepToken,
                                            by confirmation: Confirmation) -> Bool {
        guard token == expected, let index = steps.firstIndex(where: { $0.confirmation == nil }) else { return false }
        if case .visual(_, let evidence) = confirmation {
            guard !steps[index].content.requiresExplicitConfirmation,
                  WalkthroughPlan.validText(evidence, limit: 1000) else { return false }
        }
        steps[index].confirmation = confirmation
        revision += 1
        if currentStep == nil { status = .completed }
        return true
    }

    /// User-requested correction replaces only unfinished steps, never confirmed history or goal.
    mutating func reviseRemaining(_ replacements: [WalkthroughPlan.Step]) throws {
        guard !isTerminal else { throw WalkthroughPlan.ValidationError.invalidSteps }
        let completed = Array(steps.prefix(completedCount))
        let plan = WalkthroughPlan(goal: goal, steps: completed.map(\.content) + replacements)
        guard !replacements.isEmpty else { throw WalkthroughPlan.ValidationError.invalidSteps }
        try plan.validate()
        steps = completed + replacements.map { Step(id: UUID(), content: $0) }
        revision += 1
        status = .paused
        blockedReason = nil
    }

    /// A checkpoint intentionally cannot carry images, coordinates, timers, or consent.
    struct Checkpoint: Codable, Sendable {
        let version: Int
        let id: UUID
        let conversationID: UUID
        let goal: String
        let revision: Int
        let status: Status
        let steps: [Step]
        var verificationUsage: [UUID: Int]? = nil
    }

    var checkpoint: Checkpoint {
        Checkpoint(version: 1, id: id, conversationID: conversationID, goal: goal,
                   revision: revision, status: status, steps: steps, verificationUsage: verificationUsage)
    }

    init(checkpoint: Checkpoint) throws {
        guard checkpoint.version == 1, (0...1_000_000_000).contains(checkpoint.revision),
              StepVerificationPolicy.validUsage(checkpoint.verificationUsage ?? [:]),
              Set(checkpoint.steps.map(\.id)).count == checkpoint.steps.count else {
            throw WalkthroughPlan.ValidationError.invalidSteps
        }
        try WalkthroughPlan(goal: checkpoint.goal, steps: checkpoint.steps.map(\.content)).validate()
        var encounteredPending = false
        for step in checkpoint.steps {
            if step.confirmation == nil { encounteredPending = true }
            else if encounteredPending { throw WalkthroughPlan.ValidationError.invalidSteps }
            if case .visual(_, let evidence) = step.confirmation {
                guard !step.content.requiresExplicitConfirmation,
                      WalkthroughPlan.validText(evidence, limit: 1000) else {
                    throw WalkthroughPlan.ValidationError.invalidSteps
                }
            }
        }
        guard (checkpoint.status == .completed) == !encounteredPending else {
            throw WalkthroughPlan.ValidationError.invalidSteps
        }
        id = checkpoint.id
        conversationID = checkpoint.conversationID
        goal = checkpoint.goal
        revision = checkpoint.revision + 1
        status = [.completed, .cancelled].contains(checkpoint.status) ? checkpoint.status : .paused
        steps = checkpoint.steps
        verificationUsage = checkpoint.verificationUsage ?? [:]
    }
}
