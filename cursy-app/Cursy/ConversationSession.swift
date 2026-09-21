import Foundation

struct ConversationSessionID: Hashable, Sendable {
    let rawValue: UUID
    init() { rawValue = UUID() }
}

struct ConversationTurnID: Hashable, Sendable {
    let rawValue: UUID
    init() { rawValue = UUID() }
}

/// Immutable ownership captured before async work; reset or a new turn revokes it.
struct ConversationTurnContext: Equatable, Sendable {
    let sessionID: ConversationSessionID
    let turnID: ConversationTurnID
}

enum ConversationTurnState: Sendable {
    case capturing, processing, responding, completed, cancelled, failed

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed: return true
        case .capturing, .processing, .responding: return false
        }
    }
}

struct ConversationCaptureReference: Equatable, Sendable {
    let captureID: String
    let displayID: UInt32
}

struct ConversationTurn: Sendable {
    let id: ConversationTurnID
    fileprivate(set) var state: ConversationTurnState = .capturing
    fileprivate(set) var transcript = ""
    fileprivate(set) var response = ""
    fileprivate(set) var capture: ConversationCaptureReference?
}

struct ConversationExchange: Sendable {
    let turnID: ConversationTurnID
    let userTranscript: String
    let assistantResponse: String
    let capture: ConversationCaptureReference?
}

struct ConversationRequest: Sendable {
    let turnID: ConversationTurnID
    let transcript: String
}

/// In-memory, provider-neutral conversation state. The owning coordinator serializes mutations.
/// Images, native accessibility objects, credentials and audio never enter session history.
struct ConversationSession: Sendable {
    static let historyLimit = 10
    static let textLimit = 8000
    static let objectiveLimit = 2000
    private(set) var id = ConversationSessionID()
    private(set) var objective: String?
    private(set) var currentTurn: ConversationTurn?
    private(set) var exchanges: [ConversationExchange] = []
    // A user's request remains relevant even when they interrupt the spoken answer.
    private(set) var requests: [ConversationRequest] = []
    private(set) var lastCancelledTurnID: ConversationTurnID?

    var activeTurnID: ConversationTurnID? {
        guard let currentTurn, !currentTurn.state.isTerminal else { return nil }
        return currentTurn.id
    }

    var activeContext: ConversationTurnContext? {
        activeTurnID.map { ConversationTurnContext(sessionID: id, turnID: $0) }
    }

    func isActive(_ context: ConversationTurnContext) -> Bool {
        context.sessionID == id && isActive(context.turnID)
    }

    // Objective must originate in an explicit user choice, never a model inference.
    mutating func setExplicitObjective(_ objective: String?) {
        let trimmed = objective?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.objective = trimmed?.isEmpty == false ? trimmed.map { String($0.prefix(Self.objectiveLimit)) } : nil
    }

    @discardableResult
    mutating func beginTurn() -> ConversationTurnID {
        if let activeTurnID { cancelTurn(activeTurnID) }
        let turnID = ConversationTurnID()
        currentTurn = ConversationTurn(id: turnID)
        return turnID
    }

    func isActive(_ turnID: ConversationTurnID) -> Bool {
        activeTurnID == turnID
    }

    @discardableResult
    mutating func transition(to state: ConversationTurnState, for turnID: ConversationTurnID) -> Bool {
        guard isActive(turnID), let currentState = currentTurn?.state else { return false }
        switch (currentState, state) {
        case (.capturing, .processing), (.capturing, .responding), (.processing, .responding):
            currentTurn?.state = state
            return true
        default:
            // Terminal transitions have dedicated methods to keep history consistent.
            return currentState == state
        }
    }

    @discardableResult
    mutating func setTranscript(_ transcript: String, for turnID: ConversationTurnID) -> Bool {
        guard isActive(turnID) else { return false }
        let bounded = String(transcript.prefix(Self.textLimit))
        currentTurn?.transcript = bounded
        requests.removeAll { $0.turnID == turnID }
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            requests.append(ConversationRequest(turnID: turnID, transcript: trimmed))
            if requests.count > Self.historyLimit { requests.removeFirst(requests.count - Self.historyLimit) }
        }
        return true
    }

    @discardableResult
    mutating func setResponse(_ response: String, for turnID: ConversationTurnID) -> Bool {
        guard isActive(turnID) else { return false }
        currentTurn?.response = String(response.prefix(Self.textLimit))
        return true
    }

    @discardableResult
    mutating func appendResponse(_ delta: String, for turnID: ConversationTurnID) -> Bool {
        guard isActive(turnID) else { return false }
        let remaining = Self.textLimit - (currentTurn?.response.count ?? 0)
        currentTurn?.response += delta.prefix(max(0, remaining))
        return true
    }

    @discardableResult
    mutating func attachCapture(captureID: String, displayID: UInt32, for turnID: ConversationTurnID) -> Bool {
        guard isActive(turnID), !captureID.isEmpty else { return false }
        currentTurn?.capture = ConversationCaptureReference(captureID: captureID, displayID: displayID)
        return true
    }

    @discardableResult
    mutating func completeTurn(_ turnID: ConversationTurnID) -> Bool {
        guard isActive(turnID), let turn = currentTurn else { return false }
        currentTurn?.state = .completed
        // Do not fabricate a transcript when a transport did not supply one.
        if !turn.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !turn.response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            exchanges.append(ConversationExchange(turnID: turnID, userTranscript: turn.transcript,
                assistantResponse: turn.response, capture: turn.capture))
            if exchanges.count > Self.historyLimit { exchanges.removeFirst(exchanges.count - Self.historyLimit) }
        }
        return true
    }

    @discardableResult
    mutating func cancelTurn(_ turnID: ConversationTurnID) -> Bool {
        guard isActive(turnID) else { return false }
        currentTurn?.state = .cancelled
        lastCancelledTurnID = turnID
        return true
    }

    @discardableResult
    mutating func failTurn(_ turnID: ConversationTurnID) -> Bool {
        guard isActive(turnID) else { return false }
        currentTurn?.state = .failed
        return true
    }

    mutating func reset() {
        self = ConversationSession()
    }

    /// Reopening must never resurrect active work or old screen authority.
    func resumableSnapshot() -> Self {
        var snapshot = self
        snapshot.id = ConversationSessionID()
        if let activeTurnID = snapshot.activeTurnID { snapshot.cancelTurn(activeTurnID) }
        snapshot.currentTurn?.capture = nil
        snapshot.exchanges = exchanges.map {
            ConversationExchange(turnID: $0.turnID, userTranscript: $0.userTranscript,
                                 assistantResponse: $0.assistantResponse, capture: nil)
        }
        return snapshot
    }
}
