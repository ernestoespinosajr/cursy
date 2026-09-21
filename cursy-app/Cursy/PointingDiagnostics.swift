import AppKit
import os

enum PointingRejection: String, Error {
    case captureMismatch, displayChanged, captureExpired, invalidCoordinates, invalidLabel
    case imageDimensionsMismatch, unknownWindow, malformedProviderResponse
    case providerNoTarget, providerFailure, refinementIntentMismatch, refinementWindowMismatch
    case staleTurn, windowMissing, windowOwnerChanged, windowMoved
    case pointOutsideWindow, pointOutsideDisplay, noWindowAtPoint, occludedByWindow
    case genericPointOverDock, sceneChanged
    case invalidTargetQuery, invalidNativeTarget
}

/// Publication and semantic failure are not the same as coordinate rejection.
enum VisualGuidanceOutcome: Equatable {
    case published
    case rejected(PointingRejection, spatial: SpatialDeliveryState = .notRequested)

    var isPublished: Bool { self == .published }
    var suppressesContinuation: Bool {
        if case .rejected(.staleTurn, _) = self { return true }
        return false
    }

    func toolOutput(language: CursyLanguage, requestMode: VisualRequestMode? = nil) throws -> String {
        var output: [String: Any] = ["decision": "point", "pointed": isPublished,
                                   "request_mode": (requestMode ?? .locate).rawValue]
        switch self {
        case .published:
            output["spoken_reply"] = language == .spanish ? "Ahí está." : "There it is."
            output["instruction"] = "Say exactly spoken_reply and nothing else. End the turn immediately. Do not explain later steps."
            if requestMode == .explainAndLocate {
                output["instruction"] = "The location was published. Briefly answer the user's requested explanation about that same element using the supplied image. Do not preview later steps or invent details."
                output.removeValue(forKey: "spoken_reply")
            }
        case .rejected(let reason, let spatial):
            output["reason"] = reason.rawValue
            output["spatial_evidence"] = spatial.rawValue
            switch reason {
            case .providerNoTarget:
                output["instruction"] = spatial.isUnavailable
                    ? "The locator returned no target and the pointer evidence was unavailable. Do not claim invalid coordinates or that the target is absent. If the request depends on this/here, explain that the gesture could not be linked to the current image and ask the user to point again while speaking. Otherwise ask one concise target clarification."
                    : "The locator returned no target, not invalid coordinates. Do not claim the target is absent or a highlight was made. Say you could not identify the intended target and ask one concise clarification; do not provide unverified spatial directions."
            case .sceneChanged, .displayChanged, .captureExpired, .windowMoved, .windowMissing, .windowOwnerChanged, .occludedByWindow:
                output["instruction"] = "The scene or target evidence changed. Briefly explain that the current location could not be confirmed. Ask the user to point again if the request depends on their gesture; do not reuse old coordinates."
            case .providerFailure, .malformedProviderResponse:
                output["instruction"] = "Visual analysis failed technically. Say briefly that analysis could not be completed and invite a retry. Do not claim the target is absent or ask the user to describe it as if ambiguity were established."
            case .staleTurn:
                output["instruction"] = "This turn is obsolete. Do not speak or publish a location."
            default:
                output["instruction"] = "The proposed location failed validation. Say briefly it could not be highlighted safely. Do not claim the target is missing and do not give directions to an unverified location."
            }
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]), as: UTF8.self)
    }
}

enum PointingDiagnostics {
    private static let logger = Logger(subsystem: "com.hellocursy.Cursy", category: "PointingValidation")

    static func providerCandidate(_ target: ImagePointingTarget, context: VisualTurnContext) {
        let correlation = UUID(uuidString: context.captureID)?.uuidString ?? "fixture"
        logger.notice("Provider candidate capture=\(correlation, privacy: .public) declaredImage=\(target.imageWidth)x\(target.imageHeight) sentImage=\(context.imageWidth)x\(context.imageHeight) pixel=(\(target.x),\(target.y))")
    }

    static func record(_ reason: PointingRejection, context: VisualTurnContext,
                       target: PointingTarget? = nil, actualWindow: CGWindowID? = nil,
                       expectedWindowOverride: CGWindowID? = nil) {
        // Only an app-created UUID, fixed reason code and numbers; never model labels/IDs/text.
        let correlation = UUID(uuidString: context.captureID)?.uuidString ?? "fixture"
        let expected = context.capturedWindows.first { $0.id == target?.windowID }
        let expectedWindow = expectedWindowOverride ?? expected?.windowID
        logger.notice("Point rejected capture=\(correlation, privacy: .public) reason=\(reason.rawValue, privacy: .public) display=\(context.displayID) expectedWindow=\(expectedWindow ?? 0) actualWindow=\(actualWindow ?? 0)")
        if let target {
            logger.notice("Point candidate capture=\(correlation, privacy: .public) image=\(context.imageWidth)x\(context.imageHeight) normalized=(\(target.x),\(target.y)) displayFrame=(\(context.displayFrame.minX),\(context.displayFrame.minY),\(context.displayFrame.width),\(context.displayFrame.height)) age=\(Date().timeIntervalSince(context.capturedAt))")
            if let expected, let point = context.location(for: target, currentFrame: context.displayFrame) {
                logger.notice("Point geometry capture=\(correlation, privacy: .public) global=(\(point.x),\(point.y)) windowFrame=(\(expected.frame.minX),\(expected.frame.minY),\(expected.frame.width),\(expected.frame.height))")
            }
        }
    }
}

/// The production async seam. External model, OS validation and publication are
/// supplied by the coordinator; tests exercise the same ordering and guards.
enum GenericPointingPipeline {
    @MainActor static func run(context: VisualTurnContext,
        isCurrent: () -> Bool,
        locate: () async throws -> PointingTarget?,
        verifyFreshness: (PointingTarget) async throws -> Bool = { _ in true },
        resolve: (PointingTarget) throws -> CGPoint,
        publish: (PointingTarget, CGPoint) -> Void
    ) async -> Result<CGPoint, PointingRejection> {
        var candidate: PointingTarget?
        do {
            guard !Task.isCancelled, isCurrent() else { throw PointingRejection.staleTurn }
            let refined = try await locate()
            guard !Task.isCancelled, isCurrent() else { throw PointingRejection.staleTurn }
            guard let refined else { throw PointingRejection.providerNoTarget }
            candidate = refined
            guard NativeTargetPolicy.isValid(intent: refined.intent ?? "", controlID: refined.nativeControlID) else {
                throw PointingRejection.refinementIntentMismatch
            }
            if refined.nativeControlID?.isEmpty != false {
                guard context.canonicalVisualWindowID(for: refined.windowID ?? "") != nil else {
                    throw PointingRejection.unknownWindow
                }
            } else if !context.nativeTargets.contains(where: { $0.id == refined.nativeControlID }) {
                throw PointingRejection.invalidNativeTarget
            }
            if let failure = context.validationFailure(for: refined, currentFrame: context.displayFrame) { throw failure }
            // The qualified locator owns semantic window selection. Validate its result,
            // not agreement with the weaker preliminary guess that caused ct011.
            guard try await verifyFreshness(refined) else { throw PointingRejection.sceneChanged }
            guard !Task.isCancelled, isCurrent() else { throw PointingRejection.staleTurn }
            let point = try resolve(refined)
            guard !Task.isCancelled, isCurrent() else { throw PointingRejection.staleTurn }
            publish(refined, point)
            return .success(point)
        } catch {
            let reason: PointingRejection = (Task.isCancelled || !isCurrent()) ? .staleTurn
                : (error as? PointingRejection ?? .providerFailure)
            PointingDiagnostics.record(reason, context: context, target: candidate)
            return .failure(reason)
        }
    }
}
