import Foundation
import Testing
@testable import Cursy

struct RealtimeConversationMemoryTests {
    @Test func consecutiveTurnsReplayTheOriginalRequestAndCompletedAnswerInOrder() throws {
        var session = ConversationSession()
        let first = session.beginTurn()
        session.setTranscript("Find the export option in the editor", for: first)
        session.setResponse("There it is.", for: first)
        session.completeTurn(first)
        session.beginTurn()
        let snapshot = session.realtimeHistoryItems
        #expect(snapshot.map { $0["role"] as? String } == ["user", "assistant"])
        let content = try #require(snapshot.first?["content"] as? [[String: String]])
        #expect(content.first?["text"] == "Find the export option in the editor")
        session.reset()
        #expect(session.realtimeHistoryItems.isEmpty)
        #expect(snapshot.count == 2) // In-flight context is a value, not mutable session storage.
    }

    @Test func historyEvictsOldRequestsAndTheirRepliesTogether() throws {
        var session = ConversationSession()
        let first = session.beginTurn()
        session.setTranscript("OLD_REQUEST_SENTINEL", for: first)
        session.setResponse("OLD_REPLY_SENTINEL", for: first)
        session.completeTurn(first)
        for index in 0..<ConversationSession.historyLimit {
            let turn = session.beginTurn()
            session.setTranscript("New request \(index)", for: turn)
            session.cancelTurn(turn)
        }
        let json = String(decoding: try JSONSerialization.data(withJSONObject: session.realtimeHistoryItems), as: UTF8.self)
        #expect(session.realtimeHistoryItems.count == ConversationSession.historyLimit)
        #expect(!json.contains("OLD_REQUEST_SENTINEL") && !json.contains("OLD_REPLY_SENTINEL"))
    }

    @Test func interruptedAnswerKeepsOriginalRequestWithoutInventingAnAnswer() throws {
        var session = ConversationSession()
        let first = session.beginTurn()
        session.setTranscript("Muéstrame WhatsApp y la conversación con Ernesto Hijo", for: first)
        session.appendResponse("Abre", for: first)
        let second = session.beginTurn()
        session.setTranscript("Ya tengo WhatsApp abierto", for: second)
        let items = session.realtimeHistoryItems
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0["role"] as? String == "user" })
        let json = String(decoding: try JSONSerialization.data(withJSONObject: items), as: UTF8.self)
        #expect(json.contains("Ernesto Hijo"))
        #expect(json.contains("Ya tengo WhatsApp abierto"))
        #expect(!json.contains("Abre"))
        session.reset()
        #expect(session.requests.isEmpty)
        #expect(session.realtimeHistoryItems.isEmpty)
    }

    @Test func requestsAreBoundedAndStaleUpdatesCannotChangeThem() {
        var session = ConversationSession()
        let stale = session.beginTurn()
        for index in 0..<12 {
            let turn = session.beginTurn()
            session.setTranscript("Request \(index)", for: turn)
            session.setTranscript("Updated \(index)", for: turn)
        }
        let accepted = session.setTranscript("stale", for: stale)
        #expect(!accepted)
        #expect(session.requests.count == 10)
        #expect(session.requests.first?.transcript == "Updated 2")
        #expect(session.realtimeHistoryItems.count == 10)
    }

    @Test func transcriptMustMatchCommitAndSettleOnlyOnce() {
        var state = RealtimeTranscriptState()
        let beforeCommit = state.settle(itemID: "old")
        #expect(!beforeCommit)
        state.committed("current")
        state.committed("foreign")
        let foreign = state.settle(itemID: "foreign")
        let current = state.settle(itemID: "current")
        let duplicate = state.settle(itemID: "current")
        #expect(!foreign)
        #expect(current)
        #expect(!duplicate)
    }

    @Test func timeoutAndResetRejectLateTranscript() {
        var state = RealtimeTranscriptState()
        state.committed("old")
        state.expire()
        let expired = state.settle(itemID: "old")
        #expect(!expired)
        state = RealtimeTranscriptState()
        let reset = state.settle(itemID: "old")
        #expect(!reset)
    }

    @Test func replayContainsOnlyConversationTextAndResetClearsIt() throws {
        var session = ConversationSession()
        session.setExplicitObjective("Encontrar una conversación")
        let turn = session.beginTurn()
        session.setTranscript("Abrir WhatsApp", for: turn)
        session.setResponse("Usa el Dock", for: turn)
        session.attachCapture(captureID: "private-capture-id", displayID: 7, for: turn)
        session.completeTurn(turn)
        let items = session.realtimeHistoryItems
        #expect(items.count == 3)
        #expect(items[1]["role"] as? String == "user")
        #expect(items[2]["role"] as? String == "assistant")
        let data = try JSONSerialization.data(withJSONObject: items)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("private-capture-id"))
        #expect(!json.contains("input_image"))
        session.reset()
        #expect(session.realtimeHistoryItems.isEmpty)
    }
}
