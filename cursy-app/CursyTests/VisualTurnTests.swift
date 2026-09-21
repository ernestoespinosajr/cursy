import AppKit
import Testing
@testable import Cursy

struct VisualTurnTests {
    @Test(arguments: ["pointing_not_requested", "target_missing", "ambiguous", "unverified"])
    func explanationDoesNotRequireLocationEvenWithATargetDescription(reason: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["requestMode": "explain",
            "action": "no_point", "reason": reason, "captureID": "capture",
            "targetQuery": "Explain the indicated content"])
        let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: data)
        guard case .conversation = try decision.route(for: context()) else {
            Issue.record("Explanation incorrectly sent to the control locator"); return
        }
    }

    @Test(arguments: ["locate", "explain_and_locate"])
    func explicitMarkingStillRequiresTheQualifiedLocator(mode: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["requestMode": mode,
            "action": "no_point", "reason": "pointing_not_requested", "captureID": "capture",
            "targetQuery": "Indicate the referenced element"])
        let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: data)
        guard case .localize = try decision.route(for: context()) else {
            Issue.record("Explicit marking bypassed validation"); return
        }
    }

    @Test func unknownRequestModeIsNotSilentlyAccepted() {
        let data = Data(#"{"requestMode":"anything","action":"no_point","reason":"ambiguous","captureID":"capture"}"#.utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(VisualGuidanceDecision.self, from: data) }
    }

    @Test(arguments: ["target_missing", "ambiguous", "unverified"])
    func negativeVisualDecisionsRequireSemanticReview(reason: String) throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "action": "no_point", "reason": reason, "captureID": "capture",
            "targetQuery": "Show the requested item in the named application"
        ])
        let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: data)
        guard case .localize(let request) = try decision.route(for: context()) else {
            Issue.record("Missing/ambiguous target bypassed semantic localization"); return
        }
        #expect(request.targetQuery == "Show the requested item in the named application")
        #expect(!request.question(transcript: nil).isEmpty)
    }

    @Test func genericRouteDoesNotDependOnGuessedCoordinatesOrWindow() throws {
        let data = Data(#"{"action":"point","reason":"target_visible","captureID":"capture","targetQuery":"Where is the requested application?","windowID":"wrong-window","x":-50,"y":999999}"#.utf8)
        let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: data)
        #expect(decision.pointingTarget(for: context()) == nil)
        guard case .localize = try decision.route(for: context()) else {
            Issue.record("Preliminary geometry prevented independent semantic resolution"); return
        }
    }

    @Test func conversationSkipsLocatorButNonemptyVisualQueryCannotBypassIt() throws {
        for query in ["", "Show the indicated setting"] {
            let data = try JSONSerialization.data(withJSONObject: ["action": "no_point",
                "reason": "pointing_not_requested", "captureID": "capture", "targetQuery": query])
            let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: data)
            switch try decision.route(for: context()) {
            case .conversation: #expect(query.isEmpty)
            case .localize: #expect(!query.isEmpty)
            case .native: Issue.record("Unexpected native route")
            }
        }
    }

    @Test(arguments: ["", " \n ", String(repeating: "x", count: 2001)])
    func semanticRequestRejectsEmptyOrOversizedQuery(query: String) {
        #expect(throws: PointingRejection.invalidTargetQuery) {
            try VisualLocalizationRequest(targetQuery: query)
        }
    }

    @Test func semanticRouteRejectsOldCaptureAndContradictoryDecision() throws {
        for (captureID, action, reason) in [("old", "no_point", "target_missing"),
                                            ("capture", "no_point", "target_visible"),
                                            ("capture", "point", "ambiguous")] {
            let data = try JSONSerialization.data(withJSONObject: ["action": action,
                "reason": reason, "captureID": captureID, "targetQuery": "Show the setting"])
            let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: data)
            #expect(throws: (any Error).self) { try decision.route(for: context()) }
        }
    }

    @Test func semanticQueryPreservesFollowUpAndBoundsOptionalCurrentTranscript() throws {
        let request = try VisualLocalizationRequest(targetQuery: "Show the previously requested file in the named app")
        #expect(request.question(transcript: nil).contains(request.targetQuery))
        #expect(request.question(transcript: "It is open now").contains("It is open now"))
        #expect(request.question(transcript: String(repeating: "z", count: 9000)).filter { $0 == "z" }.count == 8000)
    }

    @Test func validNativeDecisionRetainsFastPath() throws {
        let data = Data(#"{"action":"point","reason":"target_visible","captureID":"capture","nativeControlID":"fixture-close","intent":"close_window","label":"Close window"}"#.utf8)
        let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: data)
        guard case .native(let target) = try decision.route(for: context()) else {
            Issue.record("Native fast path lost"); return
        }
        #expect(target.nativeControlID == "fixture-close")
    }

    private func context() -> VisualTurnContext {
        VisualTurnContext(captureID: "capture", displayID: 1,
            displayFrame: CGRect(x: -1440, y: -200, width: 1440, height: 900),
            capturedAt: .now, imageData: Data(), imageWidth: 1280, imageHeight: 800)
    }

    @Test(arguments: [
        (1728, 1117, 1728, 1117),
        (2560, 1440, 1920, 1080),
        (3840, 2160, 1920, 1080),
        (1440, 2560, 1080, 1920),
        (1024, 768, 1024, 768),
    ])
    func screenCapturePreservesLegibleResolutionWithoutUpscaling(
        sourceWidth: Int, sourceHeight: Int, expectedWidth: Int, expectedHeight: Int
    ) {
        let size = ScreenCaptureImagePolicy.pixelSize(
            sourceWidth: sourceWidth, sourceHeight: sourceHeight)
        #expect(Int(size.width) == expectedWidth)
        #expect(Int(size.height) == expectedHeight)
    }

    @Test func normalizedCoordinatesUseDisplayPointsNotRetinaPixels() {
        let context = context()
        let target = PointingTarget(captureID: "capture", x: 0.25, y: 0.5, label: "Control")
        #expect(context.location(for: target, currentFrame: context.displayFrame) == CGPoint(x: -1080, y: 250))
    }

    @Test func invalidStaleAndDisconnectedTargetsAreRejected() {
        let context = context()
        for x in [Double.nan, .infinity, -0.01, 1.01] {
            #expect(context.location(for: PointingTarget(captureID: "capture", x: x, y: 0, label: "Control"), currentFrame: context.displayFrame) == nil)
        }
        let target = PointingTarget(captureID: "capture", x: 0, y: 0, label: "Control")
        #expect(context.location(for: target, currentFrame: .zero) == nil)
        #expect(context.location(for: target, currentFrame: context.displayFrame, now: context.capturedAt.addingTimeInterval(31)) == nil)
        #expect(context.location(for: PointingTarget(captureID: "old", x: 0, y: 0, label: "Control"), currentFrame: context.displayFrame) == nil)
        #expect((try? JSONDecoder().decode(PointingTarget.self, from: Data("{}".utf8))) == nil)
    }

    @Test(arguments: [
        CGRect(x: 0, y: 0, width: 1512, height: 982),
        CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        CGRect(x: 1512, y: -300, width: 2560, height: 1440),
        CGRect(x: 0, y: 982, width: 1920, height: 1080),
        CGRect(x: 0, y: -1080, width: 1920, height: 1080),
    ])
    func pointingUsesCapturedMonitorRegardlessOfRetinaResolution(frame: CGRect) {
        let context = VisualTurnContext(captureID: "monitor", displayID: 2, displayFrame: frame,
                                       capturedAt: .now, imageData: Data(), imageWidth: 1280, imageHeight: 720)
        let target = PointingTarget(captureID: "monitor", x: 0.25, y: 0.75, label: "Control")
        #expect(context.location(for: target, currentFrame: frame) ==
                CGPoint(x: frame.minX + frame.width * 0.25, y: frame.maxY - frame.height * 0.75))
        #expect(context.location(for: target, currentFrame: frame.offsetBy(dx: 100, dy: 0)) == nil)
    }

    @Test @MainActor func windowOperationsRequireVerifiedNativeControl() {
        let context = context()
        for intent in ["close_window", "minimize_window", "zoom_window", "dock_application"] {
            let target = PointingTarget(captureID: "capture", x: 0.98, y: 0.1,
                                       label: "Control", intent: intent)
            #expect(ElementLocationDetector.resolve(target, context: context, currentFrame: context.displayFrame) == nil)
        }
        let unknown = PointingTarget(captureID: "capture", x: 0, y: 0,
                                    label: "Cerrar", nativeControlID: "unknown-close", intent: "close_window")
        #expect(ElementLocationDetector.resolve(unknown, context: context, currentFrame: context.displayFrame) == nil)
        let other = PointingTarget(captureID: "capture", x: 0.25, y: 0.5, label: "Control", intent: "other")
        // Generic coordinates no longer bypass window identity/visibility checks.
        #expect(ElementLocationDetector.resolve(other, context: context, currentFrame: context.displayFrame) == nil)
        let missingIntent = PointingTarget(captureID: "capture", x: 0, y: 0, label: "Control")
        #expect(ElementLocationDetector.resolve(missingIntent, context: context, currentFrame: context.displayFrame) == nil)
    }

    @Test func visualGuidanceDecisionRequiresAnExplicitSafeOutcome() throws {
        var context = context()
        context.capturedWindows = [CapturedWindowEvidence(
            id: "window-1", windowID: 1, ownerPID: 7,
            applicationName: "Example", frame: context.displayFrame)]
        let pointJSON = #"{"action":"point","reason":"target_visible","captureID":"capture","imageWidth":1280,"imageHeight":800,"x":320,"y":400,"label":"Control","nativeControlID":"","intent":"other","windowID":"window-1"}"#
        let point = try JSONDecoder().decode(VisualGuidanceDecision.self, from: Data(pointJSON.utf8))
        #expect(point.pointingTarget(for: context)?.label == "Control")
        #expect(!point.isValidNoPoint(for: context))

        let noPointJSON = #"{"action":"no_point","reason":"ambiguous","captureID":"capture","x":0,"y":0,"label":"","nativeControlID":"","intent":"other","windowID":""}"#
        let noPoint = try JSONDecoder().decode(VisualGuidanceDecision.self, from: Data(noPointJSON.utf8))
        #expect(noPoint.pointingTarget(for: context) == nil)
        #expect(noPoint.isValidNoPoint(for: context))
    }

    @Test func visualGuidanceDecisionToleratesOmittedNonessentialFields() throws {
        let json = #"{"action":"no_point","reason":"pointing_not_requested","captureID":"capture"}"#
        let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: Data(json.utf8))
        #expect(decision.isValidNoPoint(for: context()))
    }

    @Test func visibleTargetCanonicalizesAccessibilityWindowIdentityBeforeValidation() throws {
        var context = context()
        let windowFrame = CGRect(x: -1300, y: -100, width: 900, height: 700)
        context.windows = [ScreenWindowEvidence(
            id: "3441-0", ownerPID: 3441,
            element: AXUIElementCreateSystemWide(), frame: windowFrame)]
        context.capturedWindows = [CapturedWindowEvidence(
            id: "visual-window-7520", windowID: 7520, ownerPID: 3441,
            applicationName: "Example", frame: windowFrame)]
        let json = #"{"action":"point","reason":"target_visible","captureID":"capture","imageWidth":1280,"imageHeight":800,"x":371.2,"y":496,"label":"Persona","nativeControlID":"","intent":"other","windowID":"3441-0"}"#
        let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: Data(json.utf8))
        let target = try #require(decision.pointingTarget(for: context))
        #expect(target.windowID == "visual-window-7520")
        #expect(target.x == 0.29)
        #expect(target.y == 0.62)
    }

    @Test func visualGuidanceDecisionRejectsMismatchedOrContradictoryCapture() throws {
        let context = context()
        let contradictoryJSON = #"{"action":"no_point","reason":"target_visible","captureID":"capture","x":0,"y":0,"label":"","nativeControlID":"","intent":"other","windowID":""}"#
        let contradictory = try JSONDecoder().decode(VisualGuidanceDecision.self, from: Data(contradictoryJSON.utf8))
        #expect(!contradictory.isValidNoPoint(for: context))

        let staleJSON = #"{"action":"point","reason":"target_visible","captureID":"old","x":0.25,"y":0.5,"label":"Control","nativeControlID":"","intent":"other","windowID":"window-1"}"#
        let stale = try JSONDecoder().decode(VisualGuidanceDecision.self, from: Data(staleJSON.utf8))
        #expect(stale.pointingTarget(for: context) == nil)
    }

    @Test @MainActor func visualContinuationStopsAfterTheValidatedPoint() {
        let spanish = OpenAIRealtimeVoiceClient.visualContinuationInstructions(for: .spanish)
        let english = OpenAIRealtimeVoiceClient.visualContinuationInstructions(for: .english)
        #expect(spanish.contains("Ahí está."))
        #expect(english.contains("There it is."))
        #expect(spanish.contains("entire response MUST be exactly"))
        #expect(spanish.contains("Do not explain, preview or summarize any later step"))
        #expect(!spanish.contains("VISIBLE TARGET FIRST"))
    }

    @Test @MainActor func captureDeadlineAndCancellationDoNotRequireMicrophoneOrScreen() async {
        do {
            _ = try await VisualCaptureRequest().run(timeout: .milliseconds(10)) {
                try await Task.sleep(for: .seconds(2))
                throw URLError(.unknown)
            }
            Issue.record("Expected deadline")
        } catch { #expect((error as? URLError)?.code == .timedOut) }
        let pending = Task { @MainActor in
            try await VisualCaptureRequest().run {
                try await Task.sleep(for: .seconds(2))
                throw URLError(.unknown)
            }
        }
        pending.cancel()
        do { _ = try await pending.value; Issue.record("Expected cancellation") }
        catch { #expect(error is CancellationError) }
    }
}
