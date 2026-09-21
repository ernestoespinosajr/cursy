import Foundation
import Testing
@testable import Cursy

struct ConversationSessionTests {
    @Test func asyncOwnershipIsRevokedByResetSupersessionAndTermination() throws {
        var session = ConversationSession()
        session.beginTurn()
        let old = try #require(session.activeContext)
        #expect(session.isActive(old))
        session.reset()
        session.beginTurn()
        let current = try #require(session.activeContext)
        #expect(!session.isActive(old))
        #expect(current.sessionID != old.sessionID)
        #expect(session.isActive(current))
        session.beginTurn()
        #expect(!session.isActive(current))
        let latest = try #require(session.activeContext)
        session.completeTurn(latest.turnID)
        #expect(!session.isActive(latest))
        #expect(session.activeContext == nil)
    }

    @Test(arguments: [ConversationTurnState.completed, .cancelled, .failed])
    func terminalTurnsRejectEveryMutation(state: ConversationTurnState) throws {
        var session = ConversationSession()
        let turn = session.beginTurn()
        let context = try #require(session.activeContext)
        switch state {
        case .completed: session.completeTurn(turn)
        case .cancelled: session.cancelTurn(turn)
        case .failed: session.failTurn(turn)
        default: Issue.record("Expected a terminal fixture")
        }
        let transcript = session.setTranscript("late", for: turn)
        let response = session.setResponse("late", for: turn)
        let delta = session.appendResponse("late", for: turn)
        let capture = session.attachCapture(captureID: "late", displayID: 1, for: turn)
        let transition = session.transition(to: .responding, for: turn)
        #expect(!transcript && !response && !delta && !capture && !transition)
        #expect(!session.isActive(context))
        #expect(session.requests.isEmpty && session.exchanges.isEmpty)
    }

    @Test func retainedTextIsBoundedAtTheCoreForEveryWriter() throws {
        var session = ConversationSession()
        session.setExplicitObjective(String(repeating: "a", count: 3000))
        let turn = session.beginTurn()
        session.setTranscript(String(repeating: "é", count: 9000), for: turn)
        session.setResponse(String(repeating: "b", count: 9000), for: turn)
        #expect(session.currentTurn?.response.count == ConversationSession.textLimit)
        session.setResponse("prefix", for: turn)
        session.appendResponse(String(repeating: "c", count: 9000), for: turn)
        session.appendResponse("must not grow", for: turn)
        #expect(session.currentTurn?.response.hasPrefix("prefix") == true)
        #expect(session.currentTurn?.response.count == ConversationSession.textLimit)
        #expect(session.requests.first?.transcript.count == ConversationSession.textLimit)
        #expect(session.objective?.count == ConversationSession.objectiveLimit)
        session.completeTurn(turn)
        let exchange = try #require(session.exchanges.first)
        #expect(exchange.userTranscript.count == ConversationSession.textLimit)
        #expect(exchange.assistantResponse.count == ConversationSession.textLimit)
    }

    @Test func blankTranscriptAndObjectiveDoNotInventContext() {
        var session = ConversationSession()
        let turn = session.beginTurn()
        session.setExplicitObjective("  \n ")
        session.setTranscript(" \n ", for: turn)
        session.setResponse("An answer without transcription", for: turn)
        session.completeTurn(turn)
        #expect(session.objective == nil)
        #expect(session.requests.isEmpty && session.exchanges.isEmpty)
    }

    @Test func newTurnInvalidatesAllOlderCallbacks() {
        var session = ConversationSession()
        let older = session.beginTurn()
        let current = session.beginTurn()
        #expect(session.lastCancelledTurnID == older)
        let transcriptAccepted = session.setTranscript("stale", for: older)
        let responseAccepted = session.appendResponse("stale", for: older)
        let captureAccepted = session.attachCapture(captureID: "stale", displayID: 1, for: older)
        let completionAccepted = session.completeTurn(older)
        let failureAccepted = session.failTurn(older)
        #expect(!transcriptAccepted && !responseAccepted && !captureAccepted)
        #expect(!completionAccepted && !failureAccepted)
        #expect(session.activeTurnID == current)
        #expect(session.currentTurn?.transcript == "")
    }

    @Test func completesExactlyOnceWithBoundCaptureAndAccumulatedResponse() {
        var session = ConversationSession()
        let turn = session.beginTurn()
        session.setTranscript("Close this window", for: turn)
        session.attachCapture(captureID: "capture-1", displayID: 42, for: turn)
        session.transition(to: .processing, for: turn)
        session.transition(to: .responding, for: turn)
        session.appendResponse("Use the ", for: turn)
        session.appendResponse("red button", for: turn)
        let completed = session.completeTurn(turn)
        let duplicate = session.completeTurn(turn)
        let late = session.appendResponse("late", for: turn)
        #expect(completed && !duplicate && !late)
        #expect(session.currentTurn?.state == .completed)
        #expect(session.activeTurnID == nil)
        #expect(session.exchanges.count == 1)
        #expect(session.exchanges.first?.assistantResponse == "Use the red button")
        #expect(session.exchanges.first?.capture?.displayID == 42)
    }

    @Test func historyIsBoundedAndIncompleteTurnsAreExcluded() {
        var session = ConversationSession()
        for index in 0..<12 {
            let turn = session.beginTurn()
            session.setTranscript("Question \(index)", for: turn)
            session.setResponse("Answer \(index)", for: turn)
            session.completeTurn(turn)
        }
        let incomplete = session.beginTurn()
        session.setResponse("No transcript", for: incomplete)
        session.completeTurn(incomplete)
        #expect(session.exchanges.count == 10)
        #expect(session.exchanges.first?.userTranscript == "Question 2")
        #expect(session.exchanges.last?.userTranscript == "Question 11")
    }

    @Test func cancellationAndFailureNeverEnterHistory() {
        var session = ConversationSession()
        let cancelled = session.beginTurn()
        session.setTranscript("Do not retain", for: cancelled)
        session.setResponse("Partial", for: cancelled)
        session.cancelTurn(cancelled)
        #expect(session.currentTurn?.state == .cancelled)
        let failed = session.beginTurn()
        session.failTurn(failed)
        let completionAccepted = session.completeTurn(failed)
        #expect(session.currentTurn?.state == .failed)
        #expect(!completionAccepted)
        #expect(session.exchanges.isEmpty)
    }

    @Test func transitionsNeverMoveBackwards() {
        var session = ConversationSession()
        let turn = session.beginTurn()
        session.transition(to: .responding, for: turn)
        let backwards = session.transition(to: .processing, for: turn)
        let bypass = session.transition(to: .completed, for: turn)
        #expect(!backwards && !bypass)
        #expect(session.currentTurn?.state == .responding)
    }

    @Test func objectiveIsExplicitAndResetInvalidatesIdentity() {
        var session = ConversationSession()
        let previousID = session.id
        let turn = session.beginTurn()
        session.setTranscript("Create a group", for: turn)
        #expect(session.objective == nil)
        session.setExplicitObjective(" Create a group ")
        #expect(session.objective == "Create a group")
        session.reset()
        let stale = session.setResponse("old result", for: turn)
        #expect(!stale)
        #expect(session.id != previousID)
        #expect(session.objective == nil)
        #expect(session.currentTurn == nil)
        #expect(session.exchanges.isEmpty)
    }
}
