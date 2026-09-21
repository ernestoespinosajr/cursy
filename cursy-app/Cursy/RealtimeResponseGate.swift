import Foundation

/// Correlates output to the exact response requested by this client, not a turn-wide flag.
struct RealtimeResponseGate {
    enum Purpose { case visualDecision, spokenReply }
    private var token: String?
    private var purpose: Purpose?
    private var responseID: String?

    mutating func prepare(_ purpose: Purpose) -> [String: String] {
        let token = UUID().uuidString
        self.token = token
        self.purpose = purpose
        responseID = nil
        return ["cursy_response": token]
    }

    @discardableResult
    mutating func register(_ response: [String: Any]) -> Bool {
        guard let expected = token,
              let metadata = response["metadata"] as? [String: Any],
              metadata["cursy_response"] as? String == expected,
              let identifier = response["id"] as? String, !identifier.isEmpty,
              responseID == nil || responseID == identifier else { return false }
        responseID = identifier
        return true
    }

    func isCurrent(_ identifier: String?) -> Bool {
        guard let identifier, let responseID else { return false }
        return identifier == responseID
    }

    func allowsSpeech(_ identifier: String?) -> Bool {
        purpose == .spokenReply && isCurrent(identifier)
    }
}
