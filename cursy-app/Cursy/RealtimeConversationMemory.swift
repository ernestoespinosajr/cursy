import Foundation

/// One committed audio item per PTT turn. Duplicate/foreign transcripts are ignored.
struct RealtimeTranscriptState {
    private(set) var itemID: String?
    private(set) var settled = false

    mutating func committed(_ id: String) {
        guard itemID == nil, !id.isEmpty else { return }
        itemID = id
    }

    mutating func settle(itemID: String) -> Bool {
        guard !settled, self.itemID == itemID else { return false }
        settled = true
        return true
    }

    mutating func expire() { settled = true }
}

extension ConversationSession {
    /// Text only; never replay old screenshots, coordinates, tool calls or AX metadata.
    var realtimeHistoryItems: [[String: Any]] {
        var items: [[String: Any]] = []
        func item(role: String, text: String) -> [String: Any] {
            ["type": "message", "role": role,
             "content": [["type": role == "assistant" ? "output_text" : "input_text", "text": text]]]
        }
        if let objective {
            items.append(item(role: "user", text: "My conversation objective is: " + objective))
        }
        if let selectedText { items.append(item(role: "user", text: selectedText.sourceMessage)) }
        for request in requests.suffix(Self.historyLimit) {
            items.append(item(role: "user", text: request.transcript))
            if let exchange = exchanges.first(where: { $0.turnID == request.turnID }) {
                items.append(item(role: "assistant", text: exchange.assistantResponse))
            }
        }
        return items
    }
}
