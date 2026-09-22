import Foundation
import CoreGraphics
import ImageIO

/// Transient model claims, not trusted native attestations or executable coordinates.
nonisolated struct StepVerificationEvidence: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        case liveUI, document, quotation, historical, suggestion, preview, otherScope, unknown
    }

    struct Region: Codable, Equatable, Sendable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
        var isValid: Bool {
            [x, y, width, height].allSatisfy(\.isFinite)
                && x >= 0 && y >= 0 && width > 0 && height > 0
                && x + width <= 1 && y + height <= 1
        }
    }

    struct Observation: Codable, Equatable, Sendable {
        let target: String
        let scope: String
        let source: Source
        let state: String
        let criterionSatisfied: Bool
        let windowID: String?
        let region: Region
    }

    let version: Int
    let criterion: String
    let expectedTarget: String
    let expectedScope: String
    let scopeResolved: Bool
    let before: Observation
    let current: Observation
    let contradictions: [String]
}

extension StepVerificationDecision {
    /// Fail closed at both the transport and publication boundaries. Native geometry
    /// and pixels can veto a claim; they cannot establish its semantic truth.
    @MainActor
    func validated(step: WalkthroughPlan.Step, before: VisualTurnContext,
                   current: VisualTurnContext) -> Self {
        guard outcome == .confirmed else { return self }
        func uncertain(_ reason: String) -> Self {
            Self(outcome: .uncertain, evidenceSummary: reason)
        }
        guard !step.requiresExplicitConfirmation,
              let evidence, evidence.version == 1, evidence.scopeResolved,
              evidence.criterion == step.successCriterion,
              evidence.contradictions.isEmpty,
              WalkthroughPlan.validText(evidenceSummary, limit: 1000),
              [evidence.expectedScope, evidence.expectedTarget].allSatisfy({
                  WalkthroughPlan.validText($0, limit: 240)
              }) else { return uncertain("The completion claim lacks resolved, consistent evidence for this step.") }
        for observation in [evidence.before, evidence.current] {
            guard observation.source == .liveUI,
                  observation.scope == evidence.expectedScope,
                  observation.target == evidence.expectedTarget,
                  WalkthroughPlan.validText(observation.state, limit: 400),
                  observation.region.isValid else {
                return uncertain("The evidence does not belong to the intended live target and scope.")
            }
        }
        guard !evidence.before.criterionSatisfied, evidence.current.criterionSatisfied,
              evidence.before.state.trimmingCharacters(in: .whitespacesAndNewlines)
                != evidence.current.state.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return uncertain("The evidence does not establish a new completed state.")
        }
        guard Self.isGrounded(evidence.before, in: before), Self.isGrounded(evidence.current, in: current) else {
            return uncertain("The evidence region is not grounded in a visible captured window.")
        }
        guard let previousPixels = Self.fingerprint(evidence.before.region, in: before),
              let currentPixels = Self.fingerprint(evidence.current.region, in: current),
              currentPixels.differs(from: previousPixels) else {
            return uncertain("No meaningful pixel change was verified on the target surface itself.")
        }
        return self
    }

    @MainActor
    private static func isGrounded(_ observation: StepVerificationEvidence.Observation,
                                   in context: VisualTurnContext) -> Bool {
        // Image-only captures have no OS identity to attest. Do not invent one.
        if context.capturedWindows.isEmpty { return observation.windowID == nil }
        guard let window = context.capturedWindows.first(where: { $0.id == observation.windowID }) else { return false }
        let rect = observation.region.rect
        let frame = context.displayFrame
        let global = CGRect(x: frame.minX + rect.minX * frame.width,
                            y: frame.maxY - rect.maxY * frame.height,
                            width: rect.width * frame.width, height: rect.height * frame.height)
        return ScreenWindowGrounding.regionIsVisible(global,
            point: CGPoint(x: global.midX, y: global.midY), window: window,
            displayFrame: frame, currentWindows: context.capturedWindows)
    }

    @MainActor
    func windowRemainsVisible(from context: VisualTurnContext, in recheck: VisualTurnContext) -> Bool {
        guard outcome == .confirmed else { return true }
        guard context.displayID == recheck.displayID, context.displayFrame == recheck.displayFrame,
              let observation = evidence?.current, observation.region.isValid else { return false }
        if context.capturedWindows.isEmpty { return recheck.capturedWindows.isEmpty }
        guard let window = context.capturedWindows.first(where: { $0.id == observation.windowID }) else { return false }
        let rect = observation.region.rect
        let frame = context.displayFrame
        let global = CGRect(x: frame.minX + rect.minX * frame.width,
                            y: frame.maxY - rect.maxY * frame.height,
                            width: rect.width * frame.width, height: rect.height * frame.height)
        // Recheck OS identity, not the transient public IDs assigned to another capture.
        return ScreenWindowGrounding.regionIsVisible(global,
            point: CGPoint(x: global.midX, y: global.midY), window: window,
            displayFrame: recheck.displayFrame, currentWindows: recheck.capturedWindows)
    }

    @MainActor
    private static func fingerprint(_ region: StepVerificationEvidence.Region,
                                    in context: VisualTurnContext) -> VisualSceneFingerprint? {
        guard let source = CGImageSourceCreateWithData(context.imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width == context.imageWidth, image.height == context.imageHeight else { return nil }
        // CGImage cropping uses image pixels with a top-left origin, unlike Cocoa windows.
        let crop = CGRect(x: region.x * Double(image.width), y: region.y * Double(image.height),
                          width: region.width * Double(image.width), height: region.height * Double(image.height)).integral
        guard crop.width >= 2, crop.height >= 2, let target = image.cropping(to: crop) else { return nil }
        return try? VisualSceneFingerprint(image: target)
    }
}
