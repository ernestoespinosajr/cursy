import Foundation
import Testing
@testable import Cursy

private func expectTrue(_ result: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(result, sourceLocation: sourceLocation)
}

struct WalkthroughTests {
    static func plan(count: Int = 3, sensitive: Bool = false) -> WalkthroughPlan {
        WalkthroughPlan(goal: "Organize a project", steps: (0..<count).map { index in
            WalkthroughPlan.Step(instruction: "Complete step \(index)",
                successCriterion: "The result of step \(index) is visible",
                requiresExplicitConfirmation: sensitive,
                indications: [.init(kind: .cursor, role: .target, targetQuery: "Current target", caption: "Here")])
        })
    }

    @Test func manualProgressIsAtomicAndNeverReusesTokens() throws {
        var guide = try WalkthroughSession(plan: Self.plan(), conversationID: UUID())
        #expect(guide.token == nil)
        expectTrue(guide.activate())
        let first = try #require(guide.token)
        expectTrue(guide.confirm(first, by: .user))
        expectTrue(!guide.confirm(first, by: .user))
        #expect(guide.completedCount == 1)
        let second = try #require(guide.token)
        guide.pause()
        expectTrue(!guide.confirm(second, by: .user))
        expectTrue(guide.activate())
        expectTrue(!guide.confirm(second, by: .user))
        expectTrue(guide.confirm(try #require(guide.token), by: .user))
        expectTrue(guide.confirm(try #require(guide.token), by: .user))
        #expect(guide.status == .completed)
        #expect(guide.currentStep == nil)
        expectTrue(!guide.activate())
    }

    @Test func correctionPreservesCompletedStepsAndGoal() throws {
        var guide = try WalkthroughSession(plan: Self.plan(), conversationID: UUID())
        guide.activate()
        guide.confirm(try #require(guide.token), by: .user)
        let completed = guide.steps[0]
        let stale = try #require(guide.token)
        try guide.reviseRemaining(Self.plan(count: 1).steps)
        #expect(guide.status == .paused)
        #expect(guide.steps[0] == completed)
        #expect(guide.goal == "Organize a project")
        #expect(guide.steps.count == 2)
        guide.activate()
        expectTrue(!guide.confirm(stale, by: .user))
    }

    @Test func visualConfirmationCannotApproveSensitiveStep() throws {
        var guide = try WalkthroughSession(plan: Self.plan(sensitive: true), conversationID: UUID())
        guide.activate()
        let token = try #require(guide.token)
        expectTrue(!guide.confirm(token, by: .visual(observationID: UUID(), evidence: "Looks done")))
        expectTrue(guide.confirm(token, by: .user))
    }

    @Test func crossConversationAndCancelledResultsAreRejected() throws {
        var first = try WalkthroughSession(plan: Self.plan(), conversationID: UUID())
        var second = try WalkthroughSession(plan: Self.plan(), conversationID: UUID())
        first.activate(); second.activate()
        let token = try #require(first.token)
        expectTrue(!second.confirm(token, by: .user))
        first.cancel()
        expectTrue(!first.confirm(token, by: .user))
        expectTrue(!first.activate())
    }

    @Test func checkpointsRestorePausedWithoutVisualAuthority() throws {
        var guide = try WalkthroughSession(plan: Self.plan(), conversationID: UUID())
        guide.activate()
        guide.confirm(try #require(guide.token), by: .user)
        for _ in 0..<100 {
            let data = try JSONEncoder().encode(guide.checkpoint)
            let text = String(decoding: data, as: UTF8.self)
            #expect(!text.contains("capturedAt"))
            #expect(!text.contains("imageData"))
            #expect(!text.contains("leaseDeadline"))
            let checkpoint = try JSONDecoder().decode(WalkthroughSession.Checkpoint.self, from: data)
            let restored = try WalkthroughSession(checkpoint: checkpoint)
            #expect(restored.status == .paused)
            #expect(restored.token == nil)
            #expect(restored.steps == guide.steps)
            guide = restored
            guide.activate()
        }
    }

    @Test func malformedFutureOrTruncatedCheckpointFails() throws {
        let guide = try WalkthroughSession(plan: Self.plan(), conversationID: UUID())
        let current = guide.checkpoint
        let future = WalkthroughSession.Checkpoint(version: 2, id: current.id,
            conversationID: current.conversationID, goal: current.goal, revision: 0,
            status: .draft, steps: current.steps)
        #expect(throws: Error.self) { try WalkthroughSession(checkpoint: future) }
        let data = try JSONEncoder().encode(current)
        #expect(throws: Error.self) {
            try JSONDecoder().decode(WalkthroughSession.Checkpoint.self, from: data.prefix(data.count / 2))
        }
    }

    @Test(arguments: [0, 21]) func invalidStepCountsRejected(count: Int) {
        #expect(throws: Error.self) { try Self.plan(count: count).validate() }
    }

    @Test func routeRequiresBothEndsAndPlanIsBounded() throws {
        let route = WalkthroughPlan.Indication(kind: .arrow, role: .route, targetQuery: "Move between ends", caption: "Drag")
        let source = WalkthroughPlan.Indication(kind: .circle, role: .source, targetQuery: "Source", caption: "Pick up")
        let destination = WalkthroughPlan.Indication(kind: .rectangle, role: .destination, targetQuery: "Destination", caption: "Drop")
        func make(_ indications: [WalkthroughPlan.Indication]) -> WalkthroughPlan {
            WalkthroughPlan(goal: "Move a file", steps: [.init(instruction: "Move", successCriterion: "File visible at destination",
                requiresExplicitConfirmation: false, indications: indications)])
        }
        #expect(throws: Error.self) { try make([route]).validate() }
        #expect(throws: Error.self) { try make([source, route, destination, route]).validate() }
        try make([source, route, destination]).validate()
        let encoded = try JSONEncoder().encode(make([source, route, destination]))
        #expect(try WalkthroughPlan.decode(encoded) == make([source, route, destination]))
        #expect(throws: Error.self) { try WalkthroughPlan.decode(Data(repeating: 32, count: 100_001)) }
    }

    @Test func blockNeedsCurrentRevisionAndExplicitResume() throws {
        var guide = try WalkthroughSession(plan: Self.plan(), conversationID: UUID())
        guide.activate()
        let token = try #require(guide.token)
        guide.block("Can't find the destination", for: token)
        #expect(guide.status == .blocked)
        expectTrue(!guide.confirm(token, by: .user))
        guide.activate()
        guide.block("Stale", for: token)
        #expect(guide.status == .active)
        #expect(guide.blockedReason == nil)
    }
}

struct StepVerificationPolicyTests {
    func token(stepID: UUID = UUID(), revision: Int = 1) -> WalkthroughStepToken {
        WalkthroughStepToken(guideID: UUID(), conversationID: UUID(), stepID: stepID, revision: revision)
    }

    func reserve(_ policy: inout StepVerificationPolicy, at now: Double) throws -> StepVerificationRequest {
        guard case .allowed(let request) = policy.reserveAnalysis(observationID: UUID(), capturedAt: now, at: now, consent: true)
        else { throw WalkthroughPlan.ValidationError.invalidSteps }
        return request
    }

    @Test func explicitConsentAndLeaseExpiry() throws {
        var policy = StepVerificationPolicy(token: token())
        expectTrue(!policy.reserveCapture(at: 0, consent: true))
        expectTrue(!policy.startLease(at: 0, consent: false))
        expectTrue(policy.startLease(at: 0, consent: true))
        expectTrue(policy.reserveCapture(at: 0, consent: true))
        expectTrue(!policy.reserveCapture(at: 0.9, consent: true))
        expectTrue(policy.reserveCapture(at: 1, consent: true))
        expectTrue(!policy.isAllowed(at: 300, consent: true))
        #expect(policy.stopped == .expired)
    }

    @Test func singleFlightThrottleAndExactlyOnceAcceptance() throws {
        var policy = StepVerificationPolicy(token: token())
        policy.startLease(at: 0, consent: true)
        let request = try reserve(&policy, at: 0)
        expectTrue(!policy.reserveCapture(at: 1, consent: true))
        #expect(policy.reserveAnalysis(observationID: UUID(), capturedAt: 1, at: 1, consent: true) == .wait)
        expectTrue(policy.accept(request, at: 1, consent: true))
        expectTrue(!policy.accept(request, at: 1, consent: true))
        #expect(policy.reserveAnalysis(observationID: UUID(), capturedAt: 2, at: 2, consent: true) == .wait)
        _ = try reserve(&policy, at: 3)
        #expect(policy.remoteCount == 2)
    }

    @Test func stepQuotaSurvivesPauseAndConsentRenewal() throws {
        var policy = StepVerificationPolicy(token: token())
        policy.startLease(at: 0, consent: true)
        for index in 0..<10 {
            let now = Double(index * 3)
            let request = try reserve(&policy, at: now)
            expectTrue(policy.accept(request, at: now + 0.1, consent: true))
        }
        #expect(policy.reserveAnalysis(observationID: UUID(), capturedAt: 30, at: 30, consent: true) == .stopped(.stepLimit))
        expectTrue(!policy.startLease(at: 31, consent: true))
        #expect(policy.remoteCount == 10)
    }

    @Test func guideQuotaSurvivesStepChanges() throws {
        let first = token()
        var policy = StepVerificationPolicy(token: first)
        policy.startLease(at: 0, consent: true)
        for index in 0..<30 {
            if index > 0, index % 10 == 0 {
                expectTrue(policy.move(to: .init(guideID: first.guideID, conversationID: first.conversationID,
                    stepID: UUID(), revision: index + 1)))
            }
            let now = Double(index * 3)
            let request = try reserve(&policy, at: now)
            expectTrue(policy.accept(request, at: now + 0.1, consent: true))
        }
        #expect(policy.reserveAnalysis(observationID: UUID(), capturedAt: 90, at: 90, consent: true) == .stopped(.guideLimit))
        expectTrue(!policy.startLease(at: 91, consent: true))
    }

    // Ownership/freshness negatives, NOT sixty image-perception evaluation cases.
    @Test(arguments: 0..<60) func rejectsStaleOrUnauthorizedEvidence(caseNumber: Int) throws {
        let current = token()
        var policy = StepVerificationPolicy(token: current)
        policy.startLease(at: 0, consent: true)
        let request = try reserve(&policy, at: 0)
        switch caseNumber % 6 {
        case 0: policy.invalidateScene()
        case 1: policy.stop(.paused)
        case 2: _ = policy.move(to: .init(guideID: current.guideID, conversationID: current.conversationID,
            stepID: UUID(), revision: 2))
        case 3: policy.failed(request)
        default: break
        }
        expectTrue(!policy.accept(request, at: caseNumber % 6 == 4 ? 11 : 1, consent: caseNumber % 6 != 5))
    }

    @Test func malformedAndUncertainDecisionNeverConfirmGuide() throws {
        #expect(throws: Error.self) { try StepVerificationDecision.decode(Data("{\"outcome\":\"confirmed\",\"evidenceSummary\":\"\"}".utf8)) }
        #expect(throws: Error.self) { try StepVerificationDecision.decode(Data("{\"outcome\":\"success\",\"evidenceSummary\":\"x\"}".utf8)) }
        let decision = try StepVerificationDecision.decode(Data("{\"outcome\":\"uncertain\",\"evidenceSummary\":\"No visible receipt\"}".utf8))
        #expect(decision.outcome == .uncertain)
    }
}
