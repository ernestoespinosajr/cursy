import AppKit

struct VisualTurnContext {
    let captureID: String
    let displayID: CGDirectDisplayID
    let displayFrame: CGRect
    let capturedAt: Date
    let imageData: Data
    let imageWidth: Int
    let imageHeight: Int
    var displayName = ""
    var windowContext: String = "Window identity unavailable. Ask which window if ambiguous."
    var nativeTargets: [NativePointingTarget] = []
    var windows: [ScreenWindowEvidence] = []
    var capturedWindows: [CapturedWindowEvidence] = []
    var spatialInput: SpatialContextPacket?
    var spatialInputNotice: String?
    var spatialDeliveryState: SpatialDeliveryState = .notRequested
    var spatialSessionID: ConversationSessionID?
    var spatialTurnID: ConversationTurnID?
    var spatialRevision = 0
    // Interpretation-only snapshots from earlier scenes of THIS held Talk turn.
    // Never participate in location(), native targets, or publication validation.
    var spatialHistory: [SpatialSceneEvidence] = []
    var omittedSpatialScenes = 0

    func location(for target: PointingTarget, currentFrame: CGRect, now: Date = .now) -> CGPoint? {
        guard validationFailure(for: target, currentFrame: currentFrame, now: now) == nil else { return nil }
        return ScreenCoordinateSpace.globalPoint(
            imagePoint: CGPoint(x: target.x * Double(imageWidth), y: target.y * Double(imageHeight)),
            imageSize: CGSize(width: imageWidth, height: imageHeight), displayFrame: displayFrame)
    }

    func validationFailure(for target: PointingTarget, currentFrame: CGRect, now: Date = .now) -> PointingRejection? {
        guard target.captureID == captureID else { return .captureMismatch }
        guard currentFrame == displayFrame else { return .displayChanged }
        guard now.timeIntervalSince(capturedAt) >= 0, now.timeIntervalSince(capturedAt) < 30 else { return .captureExpired }
        guard imageWidth > 0, imageHeight > 0, target.x.isFinite, target.y.isFinite,
              (0..<1).contains(target.x), (0..<1).contains(target.y) else { return .invalidCoordinates }
        guard !target.label.isEmpty, target.label.count <= 120 else { return .invalidLabel }
        return nil
    }

    /// Converts either public visual-window IDs or the Accessibility window IDs
    /// included for native controls into the single captured-window namespace
    /// used by local geometry validation.
    func canonicalVisualWindowID(for identifier: String) -> String? {
        let identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return nil }
        if capturedWindows.contains(where: { $0.id == identifier }) { return identifier }
        guard let accessibilityWindow = windows.first(where: { $0.id == identifier }) else { return nil }
        return ScreenWindowGrounding.uniqueCapturedWindow(
            ownerPID: accessibilityWindow.ownerPID,
            accessibilityFrame: accessibilityWindow.frame,
            capturedWindows: capturedWindows)?.id
    }
}

struct PointingTarget: Decodable {
    let captureID: String
    let x: Double
    let y: Double
    let label: String
    var nativeControlID: String? = nil
    var intent: String? = nil
    var windowID: String? = nil
    var annotationStyle: VisualAnnotationStyle? = nil
}

/// Provider coordinates refer to the exact image sent, never display points or a window crop.
/// Only this boundary converts them into the normalized internal overlay contract.
struct ImagePointingTarget: Decodable {
    let captureID: String
    let imageWidth: Int
    let imageHeight: Int
    let x: Double
    let y: Double
    let label: String
    let nativeControlID: String
    let intent: String
    let windowID: String

    func normalized(for context: VisualTurnContext) -> PointingTarget? {
        try? validated(for: context)
    }

    func validated(for context: VisualTurnContext) throws -> PointingTarget {
        guard captureID == context.captureID else { throw PointingRejection.captureMismatch }
        if !nativeControlID.isEmpty {
            return PointingTarget(captureID: captureID, x: 0, y: 0, label: label,
                nativeControlID: nativeControlID, intent: intent, windowID: windowID)
        }
        guard imageWidth == context.imageWidth, imageHeight == context.imageHeight,
              imageWidth > 0, imageHeight > 0 else { throw PointingRejection.imageDimensionsMismatch }
        guard x.isFinite, y.isFinite, x >= 0, x < Double(imageWidth), y >= 0, y < Double(imageHeight) else {
            throw PointingRejection.invalidCoordinates
        }
        guard let canonicalID = context.canonicalVisualWindowID(for: windowID) else { throw PointingRejection.unknownWindow }
        return PointingTarget(captureID: captureID,
            x: x / Double(imageWidth), y: y / Double(imageHeight), label: label,
            nativeControlID: "", intent: intent, windowID: canonicalID)
    }
}

enum VisualRequestMode: String, Decodable {
    case explain
    case locate
    case explainAndLocate = "explain_and_locate"
}

struct VisualGuidanceDecision: Decodable {
    enum Action: String, Decodable {
        case point
        case noPoint = "no_point"
    }

    enum Reason: String, Decodable {
        case targetVisible = "target_visible"
        case pointingNotRequested = "pointing_not_requested"
        case targetMissing = "target_missing"
        case ambiguous
        case unverified
    }

    let action: Action
    let reason: Reason
    let captureID: String
    let x: Double
    let y: Double
    let label: String
    let nativeControlID: String
    let intent: String
    let windowID: String
    let imageWidth: Int
    let imageHeight: Int
    let targetQuery: String
    let annotationStyle: VisualAnnotationStyle?
    let requestMode: VisualRequestMode?

    private enum CodingKeys: String, CodingKey {
        case action, reason, captureID, x, y, label, nativeControlID, intent, windowID, imageWidth, imageHeight, targetQuery, annotationStyle, requestMode
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        action = try values.decode(Action.self, forKey: .action)
        reason = try values.decode(Reason.self, forKey: .reason)
        captureID = try values.decode(String.self, forKey: .captureID)
        requestMode = try values.decodeIfPresent(VisualRequestMode.self, forKey: .requestMode)
        x = try values.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try values.decodeIfPresent(Double.self, forKey: .y) ?? 0
        label = try values.decodeIfPresent(String.self, forKey: .label) ?? ""
        nativeControlID = try values.decodeIfPresent(String.self, forKey: .nativeControlID) ?? ""
        intent = try values.decodeIfPresent(String.self, forKey: .intent) ?? "other"
        windowID = try values.decodeIfPresent(String.self, forKey: .windowID) ?? ""
        imageWidth = try values.decodeIfPresent(Int.self, forKey: .imageWidth) ?? 0
        imageHeight = try values.decodeIfPresent(Int.self, forKey: .imageHeight) ?? 0
        targetQuery = try values.decodeIfPresent(String.self, forKey: .targetQuery) ?? ""
        let style = try values.decodeIfPresent(String.self, forKey: .annotationStyle) ?? "automatic"
        if style == "automatic" { annotationStyle = nil }
        else if let decoded = VisualAnnotationStyle(rawValue: style) { annotationStyle = decoded }
        else { throw PointingRejection.malformedProviderResponse }
    }

    /// Realtime supplies semantic intent, not an irrevocable window/coordinate choice.
    func route(for context: VisualTurnContext) throws -> VisualGuidanceRoute {
        guard captureID == context.captureID else { throw PointingRejection.captureMismatch }
        guard (action == .point && reason == .targetVisible) || isValidNoPoint(for: context) else {
            throw PointingRejection.malformedProviderResponse
        }
        let query = targetQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count <= VisualLocalizationRequest.maximumQueryLength else {
            throw PointingRejection.invalidTargetQuery
        }
        // Understanding supplied content does not require publishing a location.
        // Keep the legacy route for older tool payloads, but never let an incidental
        // target description turn an explicit explanation into a UI-localization job.
        if requestMode == .explain { return .conversation }
        if requestMode == nil, action == .noPoint, reason == .pointingNotRequested, query.isEmpty { return .conversation }
        if action == .point, let target = pointingTarget(for: context),
           !nativeControlID.isEmpty,
           NativeTargetPolicy.isValid(intent: intent, controlID: nativeControlID) {
            return .native(target)
        }
        return .localize(try VisualLocalizationRequest(targetQuery: query, annotationStyle: annotationStyle))
    }

    func pointingTarget(for context: VisualTurnContext) -> PointingTarget? {
        guard action == .point, reason == .targetVisible,
              captureID == context.captureID else { return nil }

        var target = ImagePointingTarget(captureID: captureID,
            imageWidth: imageWidth, imageHeight: imageHeight, x: x, y: y, label: label,
            nativeControlID: nativeControlID, intent: intent, windowID: windowID).normalized(for: context)
        target?.annotationStyle = annotationStyle
        return target
    }

    func isValidNoPoint(for context: VisualTurnContext) -> Bool {
        guard action == .noPoint, captureID == context.captureID else { return false }
        return reason != .targetVisible
    }
}

enum VisualGuidanceRoute {
    case native(PointingTarget)
    case localize(VisualLocalizationRequest)
    case conversation
}

struct VisualLocalizationRequest {
    static let maximumQueryLength = 2000
    let targetQuery: String
    let annotationStyle: VisualAnnotationStyle?

    init(targetQuery: String, annotationStyle: VisualAnnotationStyle? = nil) throws {
        let query = targetQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count <= Self.maximumQueryLength else {
            throw PointingRejection.invalidTargetQuery
        }
        self.targetQuery = query
        self.annotationStyle = annotationStyle
    }

    func question(transcript: String?) -> String {
        // The tool query is derived from current audio and resolves follow-up references.
        // Optional text must come from this same turn, never lastTranscript or replay.
        var question = "Current spoken request, restated with conversational references resolved: \(targetQuery)"
        if let transcript = transcript?.trimmingCharacters(in: .whitespacesAndNewlines), !transcript.isEmpty {
            question += "\nCurrent-turn transcription (may contain speech-recognition errors): \(transcript.prefix(8000))"
        }
        return question
    }
}

/// Serializes the underlying operation even when a deadline caller has already
/// returned. A cancelled Apple capture can still be in flight until its await ends.
@MainActor
final class VisualCaptureSlot {
    private var occupied = false

    func run(_ operation: () async throws -> VisualTurnContext) async throws -> VisualTurnContext {
        try Task.checkCancellation()
        guard !occupied else { throw URLError(.resourceUnavailable) }
        occupied = true
        defer { occupied = false }
        return try await operation()
    }
}

/// Owns a deadline independently of ScreenCaptureKit's cancellation behavior.
@MainActor
final class VisualCaptureRequest {
    private var continuation: CheckedContinuation<VisualTurnContext, Error>?
    private var operation: Task<Void, Never>?
    private var deadline: Task<Void, Never>?

    func run(timeout: Duration = .seconds(3),
             capture: @escaping @MainActor () async throws -> VisualTurnContext = {
                 try await CompanionScreenCaptureUtility.captureCursorScreen()
             }) async throws -> VisualTurnContext {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                operation = Task {
                    do { self.finish(.success(try await capture())) }
                    catch { self.finish(.failure(error)) }
                }
                deadline = Task {
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self.finish(.failure(URLError(.timedOut)))
                }
                if Task.isCancelled { finish(.failure(CancellationError())) }
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    private func finish(_ result: Result<VisualTurnContext, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        operation?.cancel(); operation = nil
        deadline?.cancel(); deadline = nil
        continuation.resume(with: result)
    }
}
