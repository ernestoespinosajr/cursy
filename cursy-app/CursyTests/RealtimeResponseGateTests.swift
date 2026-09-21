import Testing
@testable import Cursy

struct RealtimeResponseGateTests {
    @Test func decisionRefreshAndLateEventsNeverEnterAudioOrHistory() {
        var gate = RealtimeResponseGate()
        let first = gate.prepare(.visualDecision)
        let registered = gate.register(["id": "decision-1", "metadata": first])
        #expect(registered)
        #expect(!gate.allowsSpeech("decision-1"))
        let refresh = gate.prepare(.visualDecision)
        let refreshed = gate.register(["id": "decision-2", "metadata": refresh])
        #expect(refreshed)
        #expect(!gate.allowsSpeech("decision-2"))
        let final = gate.prepare(.spokenReply)
        #expect(!gate.allowsSpeech("decision-1"))
        #expect(!gate.allowsSpeech("decision-2"))
        let accepted = gate.register(["id": "final", "metadata": final])
        #expect(accepted)
        #expect(gate.allowsSpeech("final"))
        let late = gate.register(["id": "decision-1", "metadata": first])
        #expect(!late)
        #expect(!gate.allowsSpeech("decision-1"))
        #expect(gate.allowsSpeech("final"))
    }

    @Test func unknownMissingAndCancelledResponsesFailClosed() {
        var gate = RealtimeResponseGate()
        let metadata = gate.prepare(.spokenReply)
        let missingMetadata = gate.register(["id": "unknown"])
        #expect(!missingMetadata)
        #expect(!gate.allowsSpeech(nil))
        #expect(!gate.allowsSpeech("unknown"))
        let registered = gate.register(["id": "voice", "metadata": metadata])
        #expect(registered)
        #expect(gate.allowsSpeech("voice")) // Voice-only and terminal limitations use the same gate.
        gate = RealtimeResponseGate()
        let afterCancel = gate.register(["id": "voice", "metadata": metadata])
        #expect(!afterCancel)
        #expect(!gate.allowsSpeech("voice"))
    }
}
