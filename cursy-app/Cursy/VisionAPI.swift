import Foundation

/// Provider-neutral app contract. Provider credentials and adapters live in the Worker.
final class VisionAPI {
    enum Purpose: String { case conversation, localization }
    static let supportedModels = ["gpt-4.1", "gpt-4.1-mini"]
    static let localizationModel = "gpt-6-astra"
    var model: String
    let purpose: Purpose
    private let apiURL: URL
    private let tokenProvider: () -> String?
    private let session: URLSession

    init(proxyURL: String, model: String = "gpt-4.1", purpose: Purpose = .conversation,
         tokenProvider: @escaping () -> String? = { RealtimeVoiceConfiguration.internalAPIToken() },
         session: URLSession? = nil) {
        self.apiURL = URL(string: proxyURL)!
        self.model = model
        self.purpose = purpose
        self.tokenProvider = tokenProvider
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        self.session = session ?? URLSession(configuration: configuration)
    }

    private func request(images: [(data: Data, label: String)], systemPrompt: String,
                         history: [(userPlaceholder: String, assistantResponse: String)],
                         userPrompt: String, stream: Bool) throws -> URLRequest {
        guard let token = tokenProvider(), !token.isEmpty else { throw URLError(.userAuthenticationRequired) }
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encodedImages = images.map { image -> [String: String] in
            let isPNG = image.data.starts(with: [0x89, 0x50, 0x4e, 0x47])
            return ["data": image.data.base64EncodedString(), "mimeType": isPNG ? "image/png" : "image/jpeg", "label": image.label]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "purpose": purpose.rawValue, "stream": stream,
            "instructions": systemPrompt, "prompt": userPrompt,
            "images": encodedImages,
            "history": history.suffix(10).map { ["user": $0.userPlaceholder, "assistant": $0.assistantResponse] }
        ])
        return request
    }

    func analyzeImageStreaming(images: [(data: Data, label: String)], systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String, onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> (text: String, duration: TimeInterval) {
        let start = Date()
        let request = try request(images: images, systemPrompt: systemPrompt, history: conversationHistory,
                                  userPrompt: userPrompt, stream: true)
        let (bytes, response) = try await session.bytes(for: request)
        try Self.validate(response)
        var text = ""
        var completed = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: "),
                  let data = String(line.dropFirst(6)).data(using: .utf8),
                  let event = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            switch event["type"] as? String {
            case "delta":
                guard let delta = event["text"] as? String else { throw URLError(.cannotParseResponse) }
                text += delta
                await onTextChunk(text)
            case "done": completed = true
            case "error": throw URLError(.cannotLoadFromNetwork)
            default: throw URLError(.cannotParseResponse)
            }
            if completed { break }
        }
        guard completed, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return (text, Date().timeIntervalSince(start))
    }

    func analyzeImage(images: [(data: Data, label: String)], systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String
    ) async throws -> (text: String, duration: TimeInterval) {
        let start = Date()
        let request = try request(images: images, systemPrompt: systemPrompt, history: conversationHistory,
                                  userPrompt: userPrompt, stream: false)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = result["text"] as? String, !text.isEmpty else { throw URLError(.cannotParseResponse) }
        return (text, Date().timeIntervalSince(start))
    }

    private static func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(response.statusCode) else {
            throw NSError(domain: "CursyVision", code: response.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Vision service rejected the request (HTTP \(response.statusCode))."])
        }
    }
}
