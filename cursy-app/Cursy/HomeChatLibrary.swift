import Foundation

/// Temporary UI conversations, separate from each session's bounded model context.
/// No disk, screenshots, credentials or audio. Durable storage belongs to tsk008.
struct HomeChatRecord: Identifiable {
    let id: UUID
    var session: ConversationSession
    var updatedAt: Date

    func title(spanish: Bool) -> String {
        let text = session.objective ?? session.requests.first?.transcript
        return text.map { String($0.prefix(54)) } ?? (spanish ? "Nueva conversación" : "New conversation")
    }
}

struct HomeChatLibrary {
    static let limit = 20
    private(set) var selectedID = UUID()
    private(set) var records: [HomeChatRecord] = []
    var canCreate: Bool { records.count < Self.limit }

    mutating func updateCurrent(_ session: ConversationSession) {
        let snapshot = session.resumableSnapshot()
        if let index = records.firstIndex(where: { $0.id == selectedID }) {
            records[index].session = snapshot
            records[index].updatedAt = Date()
        } else {
            records.append(HomeChatRecord(id: selectedID, session: snapshot, updatedAt: Date()))
        }
    }

    @discardableResult mutating func create() -> Bool {
        guard canCreate else { return false }
        selectedID = UUID()
        return true
    }

    mutating func select(_ id: UUID) -> ConversationSession? {
        guard id != selectedID, let record = records.first(where: { $0.id == id }) else { return nil }
        selectedID = id
        return record.session.resumableSnapshot()
    }
}
