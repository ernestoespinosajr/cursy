import AppKit
import Testing
@testable import Cursy

@MainActor
struct PointingPipelineTests {
    @Test(arguments: ["requested app", "file", "setting", "tab", "list item"])
    func missingDecisionCanResolveAnExposedBackgroundTarget(subject: String) async throws {
        let frame = CGRect(x: -1000, y: 1117, width: 1000, height: 800)
        let context = context(frame: frame)
        let arguments = try JSONSerialization.data(withJSONObject: [
            "action": "no_point", "reason": "target_missing", "captureID": context.captureID,
            "targetQuery": "Show the \(subject)", "windowID": "visual-window-10"
        ])
        let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: arguments)
        guard case .localize(let request) = try decision.route(for: context) else {
            Issue.record("Must route missing request to vision"); return
        }
        var calls = 0
        var publications = 0
        let result = await GenericPointingPipeline.run(context: context, isCurrent: { true }, locate: {
            calls += 1
            #expect(request.targetQuery.contains(subject))
            // Exposed point belongs to background, unlike the initial foreground guess.
            return try ElementLocationDetector.decodeLocation(
                response(x: 100, y: 440, window: "visual-window-20"), context: context)
        }, verifyFreshness: { resolved in
            #expect(resolved.windowID == "visual-window-20")
            return true
        }, resolve: { resolved in
            try ScreenWindowGrounding.resolve(target: resolved, context: context,
                currentFrame: frame, currentWindows: context.capturedWindows)
        }, publish: { resolved, point in
            #expect(resolved.windowID == "visual-window-20")
            #expect(point.x == frame.minX + 100)
            publications += 1
        })
        _ = try result.get()
        #expect(calls == 1)
        #expect(publications == 1)
    }

    @Test func resolvedBackgroundTargetStillRejectsOccludedPixels() async throws {
        let context = context(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        let result = await GenericPointingPipeline.run(context: context, isCurrent: { true }, locate: {
            try ElementLocationDetector.decodeLocation(response(window: "visual-window-20"), context: context)
        }, resolve: { resolved in
            try ScreenWindowGrounding.resolve(target: resolved, context: context,
                currentFrame: context.displayFrame, currentWindows: context.capturedWindows)
        }, publish: { _, _ in Issue.record("Occluded point published") })
        guard case .failure(.occludedByWindow) = result else { Issue.record("Expected occlusion rejection"); return }
    }

    @Test(arguments: [true, false])
    func semanticReviewSupportsNativeResultOnlyWithCapturedIdentity(knownID: Bool) async throws {
        var context = context(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        context.nativeTargets = [NativePointingTarget(id: "fixture-dockapp", element: AXUIElementCreateSystemWide(),
            frame: CGRect(x: 50, y: 50, width: 50, height: 50))]
        let result = await GenericPointingPipeline.run(context: context, isCurrent: { true }, locate: {
            PointingTarget(captureID: context.captureID, x: 0, y: 0, label: "Application",
                nativeControlID: knownID ? "fixture-dockapp" : "unknown-dockapp", intent: "dock_application")
        }, resolve: { _ in
            #expect(knownID)
            // Production performs a live AX revalidation here; fixture never queries another app.
            return CGPoint(x: 75, y: 75)
        }, publish: { _, _ in #expect(knownID) })
        if knownID { _ = try result.get() }
        else if case .failure(.invalidNativeTarget) = result {} else { Issue.record("Unbound native result accepted") }
    }

    private func context(frame: CGRect, captureID: String = "fixture") -> VisualTurnContext {
        let window = CapturedWindowEvidence(id: "visual-window-10", windowID: 10, ownerPID: 101,
            applicationName: "Fixture", frame: CGRect(x: frame.minX + 200, y: frame.minY + 100, width: 500, height: 500))
        let background = CapturedWindowEvidence(id: "visual-window-20", windowID: 20, ownerPID: 202,
            applicationName: "Background", frame: frame)
        return VisualTurnContext(captureID: captureID, displayID: 2, displayFrame: frame,
            capturedAt: .now, imageData: Data(), imageWidth: 1000, imageHeight: 800,
            capturedWindows: [window, background])
    }

    private func response(x: Double = 400, y: Double = 440,
                          window: String = "visual-window-10", intent: String = "other") -> String {
        """
        {"target":{"x":\(x),"y":\(y),"label":"Visible control","intent":"\(intent)","nativeControlID":"","windowID":"\(window)"}}
        """
    }

    @Test(arguments: [
        CGRect(x: 0, y: 0, width: 1000, height: 800),
        CGRect(x: 1728, y: -200, width: 1000, height: 800),
        CGRect(x: -1000, y: 1117, width: 1000, height: 800)
    ])
    func decodedProviderPointTraversesWindowValidationAndOverlay(frame: CGRect) async throws {
        let context = context(frame: frame)
        var events: [String] = []
        var overlay: CGPoint?
        let result = await GenericPointingPipeline.run(context: context,
            isCurrent: { true }, locate: {
                events.append("provider")
                // This is the production decoder, not a pre-normalized point fixture.
                return try ElementLocationDetector.decodeLocation(response(), context: context)
            }, resolve: { target in
                events.append("validation")
                return try ScreenWindowGrounding.resolve(target: target, context: context,
                    currentFrame: frame, currentWindows: context.capturedWindows)
            }, publish: { _, point in
                events.append("publication")
                overlay = ScreenCoordinateSpace.overlayPoint(globalPoint: point, displayFrame: frame)
            })
        _ = try result.get()
        events.append("continuation")
        #expect(events == ["provider", "validation", "publication", "continuation"])
        let published = try #require(overlay)
        #expect(abs(published.x - 400) < 0.00001)
        #expect(abs(published.y - 440) < 0.00001)
    }

    @Test(arguments: [PointingRejection.providerNoTarget, .malformedProviderResponse,
                      .imageDimensionsMismatch, .invalidCoordinates, .unknownWindow,
                      .refinementIntentMismatch, .windowMissing,
                      .windowOwnerChanged, .windowMoved, .pointOutsideWindow, .occludedByWindow,
                      .captureExpired, .displayChanged, .staleTurn, .providerFailure])
    func failedPipelineDoesNotPublishAndReportsExactCause(expected: PointingRejection) async throws {
        let frame = CGRect(x: 1728, y: -200, width: 1000, height: 800)
        let context = context(frame: frame)
        var current = true
        var publications = 0
        let result = await GenericPointingPipeline.run(context: context,
            isCurrent: { current }, locate: {
                switch expected {
                case .providerNoTarget: return try ElementLocationDetector.decodeLocation(#"{"target":null}"#, context: context)
                case .malformedProviderResponse: return try ElementLocationDetector.decodeLocation("{}", context: context)
                case .imageDimensionsMismatch:
                    return try ImagePointingTarget(captureID: context.captureID,
                        imageWidth: 500, imageHeight: context.imageHeight, x: 400, y: 440,
                        label: "Visible control", nativeControlID: "", intent: "other",
                        windowID: "visual-window-10").validated(for: context)
                case .invalidCoordinates: return try ElementLocationDetector.decodeLocation(response(x: 1000), context: context)
                case .unknownWindow: return try ElementLocationDetector.decodeLocation(response(window: "unknown"), context: context)
                case .refinementIntentMismatch: return try ElementLocationDetector.decodeLocation(response(intent: "close_window"), context: context)
                case .pointOutsideWindow: return try ElementLocationDetector.decodeLocation(response(x: 950), context: context)
                case .providerFailure: throw URLError(.timedOut)
                case .staleTurn: current = false // Sharing revoked or a replacement turn arrived during await.
                default: break
                }
                return try ElementLocationDetector.decodeLocation(response(), context: context)
            }, resolve: { target in
                var windows = context.capturedWindows
                let originalWindow = windows[0]
                switch expected {
                case .windowMissing: windows.removeFirst()
                case .windowOwnerChanged:
                    windows[0] = CapturedWindowEvidence(id: originalWindow.id, windowID: originalWindow.windowID,
                        ownerPID: 999, applicationName: "", frame: originalWindow.frame)
                case .windowMoved:
                    windows[0] = CapturedWindowEvidence(id: originalWindow.id, windowID: originalWindow.windowID,
                        ownerPID: originalWindow.ownerPID, applicationName: "", frame: originalWindow.frame.offsetBy(dx: 30, dy: 0))
                case .occludedByWindow:
                    windows.insert(CapturedWindowEvidence(id: "visual-window-30", windowID: 30, ownerPID: 303,
                        applicationName: "Cover", frame: CGRect(x: frame.minX + 350, y: frame.minY + 300, width: 100, height: 100)), at: 0)
                default: break
                }
                return try ScreenWindowGrounding.resolve(target: target, context: context,
                    currentFrame: expected == .displayChanged ? frame.offsetBy(dx: 1, dy: 0) : frame,
                    currentWindows: windows,
                    now: expected == .captureExpired ? context.capturedAt.addingTimeInterval(31) : .now)
            }, publish: { _, _ in publications += 1 })
        guard case .failure(let reason) = result else { Issue.record("Unsafe target was accepted"); return }
        #expect(reason == expected)
        #expect(publications == 0)
    }

    @Test func staleTurnNeverCallsProvider() async throws {
        let context = context(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        let result = await GenericPointingPipeline.run(context: context,
            isCurrent: { false }, locate: { Issue.record("Provider must not run"); return nil },
            resolve: { _ in Issue.record("Resolver must not run"); return .zero },
            publish: { _, _ in Issue.record("Publication must not run") })
        guard case .failure(.staleTurn) = result else { Issue.record("Expected stale turn"); return }
    }

    @Test func localizationUsesCallerCaptureAndRasterDespiteHostileEchoedMetadata() throws {
        let context = context(frame: CGRect(x: -1000, y: 1117, width: 1000, height: 800),
                              captureID: "caller-owned-capture")
        let providerResponse = """
        {"target":{"captureID":"different-capture","imageWidth":1,"imageHeight":1,
        "x":400,"y":440,"label":"Visible control","intent":"other",
        "nativeControlID":"","windowID":"visual-window-10"}}
        """
        let target = try #require(try ElementLocationDetector.decodeLocation(providerResponse, context: context))
        #expect(target.captureID == context.captureID)
        #expect(abs(target.x - 0.4) < 0.00001)
        #expect(abs(target.y - 0.55) < 0.00001)
        let point = try ScreenWindowGrounding.resolve(target: target, context: context,
            currentFrame: context.displayFrame, currentWindows: context.capturedWindows)
        let overlay = ScreenCoordinateSpace.overlayPoint(globalPoint: point, displayFrame: context.displayFrame)
        #expect(abs(overlay.x - 400) < 0.00001)
        #expect(abs(overlay.y - 440) < 0.00001)

        let replacement = self.context(frame: context.displayFrame, captureID: "replacement-capture")
        #expect(replacement.validationFailure(for: target, currentFrame: replacement.displayFrame) == .captureMismatch)
    }

    @Test(arguments: [false, true])
    func awaitedLocalizationCannotPublishAfterCaptureReplacementOrCancellation(cancelTask: Bool) async throws {
        let context = context(frame: CGRect(x: 0, y: 0, width: 1000, height: 800), captureID: "old-capture")
        let requestStarted = AsyncStream<Void>.makeStream()
        var reply: CheckedContinuation<String, Never>?
        var currentCaptureID = context.captureID
        var resolutions = 0
        var publications = 0
        let operation = Task {
            await GenericPointingPipeline.run(context: context,
                isCurrent: { currentCaptureID == context.captureID }, locate: {
                    let providerResponse: String = await withCheckedContinuation { continuation in
                        reply = continuation
                        requestStarted.continuation.yield(())
                        requestStarted.continuation.finish()
                    }
                    return try ElementLocationDetector.decodeLocation(providerResponse, context: context)
                }, resolve: { target in
                    resolutions += 1
                    return try ScreenWindowGrounding.resolve(target: target, context: context,
                        currentFrame: context.displayFrame, currentWindows: context.capturedWindows)
                }, publish: { _, _ in publications += 1 })
        }
        for await _ in requestStarted.stream { break }
        if cancelTask {
            operation.cancel()
        } else {
            currentCaptureID = "replacement-capture"
        }
        reply?.resume(returning: response())
        let result = await operation.value
        guard case .failure(.staleTurn) = result else { Issue.record("Expected stale turn"); return }
        #expect(resolutions == 0)
        #expect(publications == 0)
    }
}
