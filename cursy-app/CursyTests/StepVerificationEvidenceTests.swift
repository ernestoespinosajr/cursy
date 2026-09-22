import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import Cursy

@MainActor
struct StepVerificationEvidenceTests {
    nonisolated static let whole = StepVerificationEvidence.Region(x: 0, y: 0, width: 1, height: 1)
    nonisolated static let target = StepVerificationEvidence.Region(x: 0.1, y: 0.1, width: 0.8, height: 0.3)

    static func decision(step: WalkthroughPlan.Step = WalkthroughTests.plan().steps[0],
                         source: StepVerificationEvidence.Source = .liveUI,
                         scope: String = "Workspace Alpha / Approved", resolved: Bool = true,
                         beforeSatisfied: Bool = false, currentSatisfied: Bool = true,
                         beforeState: String = "Empty", currentState: String = "Contains target",
                         contradictions: [String] = [], version: Int = 1,
                         region: StepVerificationEvidence.Region = whole,
                         currentRegion: StepVerificationEvidence.Region? = nil,
                         beforeWindow: String? = nil, currentWindow: String? = nil) -> StepVerificationDecision {
        .init(outcome: .confirmed, evidenceSummary: "The intended destination now contains the target.",
              evidence: .init(version: version, criterion: step.successCriterion,
                expectedTarget: "Destination contents", expectedScope: "Workspace Alpha / Approved",
                scopeResolved: resolved,
                before: .init(target: "Destination contents", scope: "Workspace Alpha / Approved",
                    source: .liveUI, state: beforeState, criterionSatisfied: beforeSatisfied,
                    windowID: beforeWindow, region: region),
                current: .init(target: "Destination contents", scope: scope, source: source,
                    state: currentState, criterionSatisfied: currentSatisfied,
                    windowID: currentWindow, region: currentRegion ?? region), contradictions: contradictions))
    }

    // Explicit pixels: the target occupies the top half, distracting content the bottom.
    // These are contract tests with authored observations, not model-perception tests.
    static func scene(target: CGFloat, elsewhere: CGFloat = 0.2) throws -> VisualTurnContext {
        let pixels = [UInt8](repeating: UInt8(target * 255), count: 100 * 40)
            + [UInt8](repeating: UInt8(elsewhere * 255), count: 100 * 40)
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(width: 100, height: 80, bitsPerComponent: 8,
            bitsPerPixel: 8, bytesPerRow: 100, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let bitmap = NSBitmapImageRep(cgImage: image)
        return .init(captureID: UUID().uuidString, displayID: 1,
            displayFrame: CGRect(x: -1000, y: 300, width: 1000, height: 800), capturedAt: .now,
            imageData: try #require(bitmap.representation(using: .png, properties: [:])), imageWidth: 100, imageHeight: 80)
    }

    private func outcome(_ decision: StepVerificationDecision, before: VisualTurnContext,
                         current: VisualTurnContext) -> StepVerificationDecision.Outcome {
        decision.validated(step: WalkthroughTests.plan().steps[0], before: before, current: current).outcome
    }

    @Test func matchingLiveEvidenceWithActualTargetChangeCanConfirm() throws {
        let before = try Self.scene(target: 0.1)
        let current = try Self.scene(target: 0.9)
        #expect(outcome(Self.decision(region: Self.target), before: before, current: current) == .confirmed)
        let decision = Self.decision(region: Self.target)
        #expect(try StepVerificationDecision.decode(JSONEncoder().encode(decision)) == decision)
    }

    @Test func bareConfirmedCannotAdvance() throws {
        let legacy = try StepVerificationDecision.decode(Data(#"{"outcome":"confirmed","evidenceSummary":"Done"}"#.utf8))
        #expect(outcome(legacy, before: try Self.scene(target: 0.1), current: try Self.scene(target: 0.9)) == .uncertain)
    }

    @Test(arguments: [StepVerificationEvidence.Source.document, .quotation, .historical, .suggestion, .preview, .otherScope, .unknown])
    func nonAuthoritativeSourcesCannotConfirm(source: StepVerificationEvidence.Source) throws {
        #expect(outcome(Self.decision(source: source), before: try Self.scene(target: 0.1),
                        current: try Self.scene(target: 0.9)) == .uncertain)
    }

    @Test func wrongWorkspaceAndDocumentExamplesAreNotResultEvidence() throws {
        let before = try Self.scene(target: 0.1)
        let current = try Self.scene(target: 0.1, elsewhere: 0.9)
        // Regression categories from family-1-case-4 and family-3-case-8.
        #expect(outcome(Self.decision(scope: "Workspace Beta / Approved"), before: before, current: current) == .uncertain)
        #expect(outcome(Self.decision(source: .document), before: before, current: current) == .uncertain)
        // Even if the model mislabels the source as liveUI, unchanged primary pixels veto it.
        #expect(outcome(Self.decision(region: Self.target), before: before, current: current) == .uncertain)
        #expect(try VisualSceneFingerprint(imageData: current.imageData)
            .differs(from: VisualSceneFingerprint(imageData: before.imageData)))
    }

    @Test func ambiguousContradictoryOrNonTransitionalEvidenceCannotConfirm() throws {
        let before = try Self.scene(target: 0.1)
        let current = try Self.scene(target: 0.9)
        let decisions = [Self.decision(resolved: false), Self.decision(beforeSatisfied: true),
                         Self.decision(currentSatisfied: false), Self.decision(currentState: "Empty"),
                         Self.decision(contradictions: ["Primary destination still empty"]),
                         Self.decision(version: 2), Self.decision(currentState: String(repeating: "x", count: 401)),
                         Self.decision(beforeState: " ")]
        for decision in decisions { #expect(outcome(decision, before: before, current: current) == .uncertain) }
        let wrongStep = WalkthroughTests.plan().steps[1]
        #expect(Self.decision().validated(step: wrongStep, before: before, current: current).outcome == .uncertain)
        let sensitive = WalkthroughTests.plan(sensitive: true).steps[0]
        #expect(Self.decision(step: sensitive).validated(step: sensitive, before: before, current: current).outcome == .uncertain)
    }

    @Test func malformedOrUndecodableImageRegionsFailClosed() throws {
        let before = try Self.scene(target: 0.1)
        let current = try Self.scene(target: 0.9)
        for region in [StepVerificationEvidence.Region(x: .nan, y: 0, width: 1, height: 1),
                       .init(x: 0, y: 0, width: .infinity, height: 1),
                       .init(x: -0.1, y: 0, width: 1, height: 1),
                       .init(x: 0, y: 0, width: 0, height: 1),
                       .init(x: 0.9, y: 0, width: 0.2, height: 1),
                       .init(x: 0, y: 0, width: 0.001, height: 0.001)] {
            #expect(outcome(Self.decision(region: region), before: before, current: current) == .uncertain)
        }
        let broken = VisualTurnContext(captureID: "invalid", displayID: 1, displayFrame: current.displayFrame,
            capturedAt: .now, imageData: Data(), imageWidth: 100, imageHeight: 80)
        #expect(outcome(Self.decision(), before: before, current: broken) == .uncertain)
    }

    @Test func windowIdentityVisibilityAndCocoaCoordinateConversionAreChecked() throws {
        var before = try Self.scene(target: 0.1)
        var current = try Self.scene(target: 0.9)
        let window = CapturedWindowEvidence(id: "primary", windowID: 21, ownerPID: 41,
            applicationName: "Synthetic", frame: before.displayFrame)
        before.capturedWindows = [window]
        current.capturedWindows = [window]
        let valid = Self.decision(region: Self.target, beforeWindow: "primary", currentWindow: "primary")
        #expect(outcome(valid, before: before, current: current) == .confirmed)
        #expect(outcome(Self.decision(), before: before, current: current) == .uncertain)
        #expect(outcome(Self.decision(beforeWindow: "primary", currentWindow: "invented"), before: before, current: current) == .uncertain)
        // Top-left target maps to Cocoa y=780...1020 on this negative-origin display.
        current.capturedWindows.insert(.init(id: "cover", windowID: 22, ownerPID: 42,
            applicationName: "Other", frame: CGRect(x: -900, y: 800, width: 100, height: 100)), at: 0)
        #expect(outcome(valid, before: before, current: current) == .uncertain)
        // A window covering only the lower half must not occlude the top-left crop.
        current.capturedWindows[0] = .init(id: "lower", windowID: 23, ownerPID: 42,
            applicationName: "Other", frame: CGRect(x: -900, y: 300, width: 100, height: 100))
        #expect(outcome(valid, before: before, current: current) == .confirmed)
        current.capturedWindows = [.init(id: "small", windowID: 24, ownerPID: 42,
            applicationName: "Other", frame: CGRect(x: -1000, y: 300, width: 100, height: 100))]
        #expect(outcome(Self.decision(beforeWindow: "primary", currentWindow: "small"), before: before, current: current) == .uncertain)
    }

    @Test func nativeWindowChangeDoesNotAutomaticallyInvalidateSameSemanticScope() throws {
        var before = try Self.scene(target: 0.1)
        var current = try Self.scene(target: 0.9)
        before.capturedWindows = [.init(id: "before", windowID: 1, ownerPID: 40,
            applicationName: "Synthetic", frame: before.displayFrame)]
        current.capturedWindows = [.init(id: "after", windowID: 2, ownerPID: 40,
            applicationName: "Synthetic", frame: current.displayFrame)]
        #expect(outcome(Self.decision(region: Self.target, beforeWindow: "before", currentWindow: "after"),
                        before: before, current: current) == .confirmed)
    }

    @Test func nativeWindowRecheckUsesOSIdentityNotPublicLabelOrPixelsAlone() throws {
        var current = try Self.scene(target: 0.9)
        current.capturedWindows = [.init(id: "current", windowID: 7, ownerPID: 40,
            applicationName: "Synthetic", frame: current.displayFrame)]
        let decision = Self.decision(region: Self.target, currentWindow: "current")
        var recheck = current
        recheck.capturedWindows = [.init(id: "renumbered", windowID: 7, ownerPID: 40,
            applicationName: "Synthetic", frame: current.displayFrame)]
        #expect(decision.windowRemainsVisible(from: current, in: recheck))
        recheck.capturedWindows = [.init(id: "current", windowID: 8, ownerPID: 41,
            applicationName: "Other", frame: current.displayFrame)]
        #expect(!decision.windowRemainsVisible(from: current, in: recheck))
    }

    @Test func resizedOrMovedSurfaceRequiresItsOwnContentChange() throws {
        let moved = StepVerificationEvidence.Region(x: 0.2, y: 0.15, width: 0.5, height: 0.2)
        let decision = Self.decision(region: Self.target, currentRegion: moved)
        let before = try Self.scene(target: 0.1)
        #expect(outcome(decision, before: before, current: try Self.scene(target: 0.9)) == .confirmed)
        #expect(outcome(decision, before: before, current: try Self.scene(target: 0.1, elsewhere: 0.9)) == .uncertain)
    }
}
