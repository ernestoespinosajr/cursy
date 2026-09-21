import Foundation
import CoreGraphics
import Testing
@testable import Cursy

@Suite("Home chat navigation and cursor appearance")
struct HomeWorkspaceTests {
    @Test func switchingPreservesTextButNeverActiveWorkOrCapture() throws {
        var library = HomeChatLibrary()
        var session = ConversationSession()
        let originalID = library.selectedID
        let turn = session.beginTurn()
        session.setTranscript("First chat", for: turn)
        session.attachCapture(captureID: "synthetic", displayID: 1, for: turn)
        session.setExplicitObjective("First objective")
        library.updateCurrent(session)
        let created = library.create()
        #expect(created)
        let secondID = library.selectedID
        var second = ConversationSession()
        let secondTurn = second.beginTurn()
        second.setTranscript("Second chat", for: secondTurn)
        library.updateCurrent(second)
        let restoredValue = library.select(originalID)
        var restored = try #require(restoredValue)
        #expect(restored.objective == "First objective")
        #expect(restored.requests.first?.transcript == "First chat")
        #expect(restored.requests.count == 1)
        #expect(restored.currentTurn?.capture == nil)
        #expect(restored.activeTurnID == nil)
        #expect(restored.id != session.id)
        let acceptedLateResponse = restored.appendResponse("late output", for: turn)
        #expect(!acceptedLateResponse)
        restored.beginTurn()
        let acceptedLateTranscript = restored.setTranscript("late transcript", for: turn)
        #expect(!acceptedLateTranscript)
        let otherValue = library.select(secondID)
        let other = try #require(otherValue)
        #expect(other.requests.first?.transcript == "Second chat")
        #expect(other.objective == nil)
    }

    @Test func repeatedUpdatesDoNotDuplicateChatsAndLimitNeverEvicts() {
        var library = HomeChatLibrary()
        let firstID = library.selectedID
        for _ in 0..<30 { library.updateCurrent(ConversationSession()) }
        #expect(library.records.count == 1)
        for _ in 1..<HomeChatLibrary.limit {
            let created = library.create()
            #expect(created)
            library.updateCurrent(ConversationSession())
        }
        let createdOverLimit = library.create()
        #expect(!createdOverLimit)
        #expect(library.records.count == HomeChatLibrary.limit)
        #expect(library.records.contains { $0.id == firstID })
        let current = library.selectedID
        let missing = library.select(UUID())
        #expect(missing == nil)
        #expect(library.selectedID == current)
    }

    @Test func appearanceHasStableFallbackAndLocalizedNames() {
        #expect(CursyCursorTint.resolve("unknown") == .mint)
        for tint in CursyCursorTint.allCases {
            #expect(CursyCursorTint.resolve(tint.rawValue) == tint)
            #expect(!tint.title(spanish: true).isEmpty)
            #expect(!tint.title(spanish: false).isEmpty)
        }
    }

    @Test func islandWaitsForItsOwnClickNotPreviousTurn() {
        let request = UUID()
        #expect(!HomeNotchInteraction.activationReady(request: request, completed: nil,
            hasCamera: true, voiceState: .listening, reduceMotion: false))
        #expect(!HomeNotchInteraction.activationReady(request: request, completed: UUID(),
            hasCamera: true, voiceState: .processing, reduceMotion: false))
        #expect(HomeNotchInteraction.activationReady(request: request, completed: request,
            hasCamera: true, voiceState: .listening, reduceMotion: false))
        #expect(HomeNotchInteraction.activationReady(request: request, completed: nil,
            hasCamera: false, voiceState: .listening, reduceMotion: false))
        #expect(HomeNotchInteraction.activationReady(request: request, completed: nil,
            hasCamera: true, voiceState: .listening, reduceMotion: true))
        #expect(HomeNotchInteraction.activationReady(request: request, completed: nil,
            hasCamera: true, voiceState: .responding, reduceMotion: false))
    }

    @Test func arrivalIsCurvedEvenDirectlyBelowCamera() {
        let start = CGPoint(x: 400, y: 600)
        let end = CGPoint(x: 400, y: 50)
        #expect(HomeNotchInteraction.arrivalPoint(from: start, to: end, progress: 0) == start)
        #expect(HomeNotchInteraction.arrivalPoint(from: start, to: end, progress: 1) == end)
        let first = HomeNotchInteraction.arrivalPoint(from: start, to: end, progress: 0.25)
        let second = HomeNotchInteraction.arrivalPoint(from: start, to: end, progress: 0.75)
        #expect(first.x < start.x)
        #expect(second.x > end.x)
        #expect(first.y > second.y)
        #expect(HomeNotchInteraction.arrivalDuration > HomeNotchInteraction.duration)
    }
}
