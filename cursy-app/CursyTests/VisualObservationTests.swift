import AppKit
import Testing
@testable import Cursy

@MainActor
struct VisualObservationTests {
    private func scene(_ shade: CGFloat, display: UInt32 = 1, origin: CGPoint = .zero,
                       windowFrame: CGRect? = nil, rightShade: CGFloat? = nil) throws -> VisualTurnContext {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 320,
            pixelsHigh: 200, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor(white: shade, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 320, height: 200).fill()
        if let rightShade {
            NSColor(white: rightShade, alpha: 1).setFill()
            NSRect(x: 160, y: 0, width: 160, height: 200).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let frame = CGRect(origin: origin, size: CGSize(width: 1000, height: 800))
        return VisualTurnContext(captureID: UUID().uuidString, displayID: display,
            displayFrame: frame, capturedAt: .now, imageData: data, imageWidth: 320, imageHeight: 200,
            capturedWindows: [CapturedWindowEvidence(id: "visual-window-10", windowID: 10,
                ownerPID: 101, applicationName: "Fixture", frame: windowFrame ?? frame)])
    }

    private func target(_ context: VisualTurnContext, x: Double = 0.4) -> PointingTarget {
        PointingTarget(captureID: context.captureID, x: x, y: 0.5, label: "Requested element",
            nativeControlID: "", intent: "other", windowID: "visual-window-10")
    }

    private func splitScene(left: CGFloat = 0.2, right: CGFloat = 0.2,
                            otherFrame: CGRect = CGRect(x: 500, y: 0, width: 500, height: 800)) throws -> VisualTurnContext {
        var context = try scene(left, windowFrame: CGRect(x: 0, y: 0, width: 500, height: 800), rightShade: right)
        // The other app is first/frontmost, but the model requests the left window.
        context.capturedWindows.insert(CapturedWindowEvidence(id: "visual-window-20", windowID: 20,
            ownerPID: 202, applicationName: "Other fixture", frame: otherFrame), at: 0)
        return context
    }

    @Test func unrelatedAnimationAndWindowMovementDoNotSpendRetries() async throws {
        let initial = try splitScene()
        let observation = try VisualObservation(context: initial, capture: {
            try splitScene(right: 0.9, otherFrame: CGRect(x: 600, y: 0, width: 400, height: 700))
        }, allowed: { true },
            clearPoint: {}, status: { _ in }, locate: { _, _ in nil }, publish: { _, _ in false })
        try await observation.poll() // Before the model has chosen a target.
        #expect(!observation.isDirty)
        observation.prepareScope(for: target(initial), context: initial)
        // A fresh raster identity ensures the relevant-region check really executes.
        let current = try await observation.verify(initial, target: target(initial))
        #expect(current)
        #expect(try await observation.refreshIfNeeded(initial) == nil)
        #expect(observation.budget.refreshCount == 0)
    }

    @Test func scopedScrollAndScopedContentChangesStillInvalidate() async throws {
        let initial = try splitScene()
        let updated = try splitScene(left: 0.8)
        let observation = try VisualObservation(context: initial, capture: { updated }, allowed: { true },
            clearPoint: {}, status: { _ in }, locate: { _, _ in nil }, publish: { _, _ in false })
        observation.recordScroll(at: CGPoint(x: 750, y: 300))
        observation.prepareScope(for: target(initial), context: initial)
        #expect(!observation.isDirty) // Scroll belonged to the other app.
        #expect(try await !observation.verify(initial, target: target(initial)))
        #expect(observation.isDirty)
    }

    @Test func alreadySampledImageIsRecheckedWhenModelChoosesScope() async throws {
        let initial = try splitScene()
        let updated = try splitScene(left: 0.8)
        let observation = try VisualObservation(context: initial, capture: { updated }, allowed: { true },
            clearPoint: {}, status: { _ in }, locate: { _, _ in nil }, publish: { _, _ in false })
        try await observation.poll()
        #expect(!observation.isDirty)
        // Same capture ID (coalesced request), different scope: don't skip validation.
        #expect(try await !observation.verify(initial, target: target(initial)))
        #expect(observation.isDirty)
    }

    @Test func queuedScrollInRequestedWindowInvalidatesBeforePublication() throws {
        let initial = try splitScene()
        let observation = try VisualObservation(context: initial, capture: { initial }, allowed: { true },
            clearPoint: {}, status: { _ in }, locate: { _, _ in nil }, publish: { _, _ in false })
        observation.recordScroll(at: CGPoint(x: 250, y: 300))
        observation.prepareScope(for: target(initial), context: initial)
        #expect(observation.isDirty)
        #expect(!observation.isPointCurrent)
    }

    @Test func scopePersistsAfterRefreshDespiteChangingOtherWindow() async throws {
        let initial = try splitScene()
        var sample = try splitScene(left: 0.8)
        var now = 0.0
        let observation = try VisualObservation(context: initial, clock: { now }, capture: { sample },
            waitForStability: { now += 0.5 }, allowed: { true }, clearPoint: {}, status: { _ in },
            locate: { _, _ in nil }, publish: { _, _ in false })
        observation.prepareScope(for: target(initial), context: initial)
        let fresh = try #require(try await observation.refreshIfNeeded(initial))
        sample = try splitScene(left: 0.8, right: 0.9)
        #expect(try await observation.refreshIfNeeded(fresh) == nil)
        #expect(observation.budget.refreshCount == 1)
    }

    @Test(arguments: [true, false])
    func relevantOcclusionOrMissingWindowIsNotIgnored(missing: Bool) async throws {
        let initial = try splitScene()
        var sample = try splitScene(otherFrame: CGRect(x: 250, y: 0, width: 500, height: 800))
        if missing { sample.capturedWindows.removeAll { $0.windowID == 10 } }
        let observation = try VisualObservation(context: initial, capture: { sample }, allowed: { true },
            clearPoint: {}, status: { _ in }, locate: { _, _ in nil }, publish: { _, _ in false })
        #expect(try await !observation.verify(initial, target: target(initial)))
    }

    @Test func budgetsNeverExtendAndRefreshIsBounded() {
        var budget = VisualObservationBudget(startedAt: 0)
        let first = budget.reserveRefresh(at: 1)
        let second = budget.reserveRefresh(at: 2)
        let third = budget.reserveRefresh(at: 3)
        #expect(first && second && !third)
        budget.pointed(at: 4)
        budget.pointed(at: 7)
        #expect(budget.deadline == 9)
        #expect(!budget.isAlive(at: 9))
        var late = VisualObservationBudget(startedAt: 0)
        late.pointed(at: 29)
        #expect(late.deadline == 30)
    }

    @Test func pixelDifferenceHasNoiseToleranceAndRegionIsolation() {
        let initial = [UInt8](repeating: 80, count: 320 * 200)
        var pixels = initial
        pixels[0] = 90
        #expect(!VisualSceneFingerprint(pixels: pixels).differs(from: .init(pixels: initial)))
        for row in 0..<80 { for column in 240..<300 { pixels[row * 320 + column] = 200 } }
        let changed = VisualSceneFingerprint(pixels: pixels)
        #expect(changed.differs(from: .init(pixels: initial)))
        #expect(!changed.differs(from: .init(pixels: initial), region: CGRect(x: 0, y: 0, width: 0.5, height: 1)))
    }

    @Test func stableSceneDoesNotConsumeARefresh() async throws {
        let initial = try scene(0.2)
        var captures = 0
        let observation = try VisualObservation(context: initial, clock: { 0 }, capture: {
            captures += 1; return initial
        }, allowed: { true }, clearPoint: {}, status: { _ in }, locate: { _, _ in
            Issue.record("Unexpected provider call"); return nil
        }, publish: { _, _ in false })
        #expect(try await observation.refreshIfNeeded(initial) == nil)
        #expect(observation.isCurrent(initial.captureID))
        #expect(captures == 1)
        #expect(observation.budget.refreshCount == 0)
    }

    @Test(arguments: [CGPoint.zero, CGPoint(x: -1000, y: 200), CGPoint(x: 1728, y: -300)])
    func scrollRelocatesThroughRealGeometryAndPublication(origin: CGPoint) async throws {
        let initial = try scene(0.2, origin: origin)
        let updated = try scene(0.8, origin: origin)
        var now = 0.0
        var clearCount = 0
        var published: CGPoint?
        var requests = 0
        let observation = try VisualObservation(context: initial, clock: { now }, capture: { updated },
            waitForStability: { now += 0.5 }, allowed: { true }, clearPoint: { clearCount += 1 },
            status: { _ in }, locate: { context, label in
                requests += 1
                #expect(label == "Requested element (application: Fixture)")
                return target(context, x: 0.6)
            }, publish: { candidate, context in
                published = try? ScreenWindowGrounding.resolve(target: candidate, context: context,
                    currentFrame: context.displayFrame, currentWindows: context.capturedWindows)
                return published != nil
            })
        observation.accepted(target(initial))
        observation.invalidate()
        #expect(!observation.isPointCurrent)
        await observation.refreshPointIfNeeded()
        #expect(requests == 1)
        #expect(clearCount >= 1)
        #expect(published == CGPoint(x: origin.x + 600, y: origin.y + 400))
        #expect(observation.isPointCurrent)
        #expect(observation.budget.refreshCount == 1)
    }

    @Test func changedFrameOrMonitorInvalidatesIdenticalPixels() async throws {
        let initial = try scene(0.2)
        let moved = try scene(0.2, display: 2, origin: CGPoint(x: -1000, y: 0))
        let observation = try VisualObservation(context: initial, capture: { moved },
            allowed: { true }, clearPoint: {}, status: { _ in }, locate: { _, _ in nil }, publish: { _, _ in false })
        #expect(try await !observation.verify(initial, target: target(initial)))
        #expect(observation.isDirty)
    }

    @Test(arguments: [false, true])
    func noPublicationWhenProviderReturnsMissingOrLeaseCancelled(cancel: Bool) async throws {
        let initial = try scene(0.2)
        let updated = try scene(0.8)
        var now = 0.0
        var permitted = true
        var publications = 0
        let observation = try VisualObservation(context: initial, clock: { now }, capture: { updated },
            waitForStability: { now += 0.5 }, allowed: { permitted }, clearPoint: {}, status: { _ in },
            locate: { context, _ in
                if cancel { permitted = false; return target(context) }
                return nil
            }, publish: { _, _ in publications += 1; return true })
        observation.accepted(target(initial))
        observation.invalidate()
        await observation.refreshPointIfNeeded()
        #expect(publications == 0)
        #expect(!observation.isPointCurrent)
    }

    @Test func lateCaptureCannotResurrectStoppedLease() async throws {
        let initial = try scene(0.2)
        var observation: VisualObservation!
        var clears = 0
        observation = try VisualObservation(context: initial, capture: {
            observation.stop(); return initial
        }, allowed: { true }, clearPoint: { clears += 1 }, status: { _ in },
            locate: { _, _ in nil }, publish: { _, _ in Issue.record("Unexpected point"); return true })
        do { try await observation.poll(); Issue.record("Expected cancellation") }
        catch is CancellationError {}
        #expect(observation.ended)
        #expect(observation.context.imageData.isEmpty)
        #expect(clears == 1)
    }

    @Test func sceneChangesDuringProviderCallBlockPublication() async throws {
        let initial = try scene(0.2)
        let updated = try scene(0.6)
        let changedAgain = try scene(0.9)
        var current = updated
        var now = 0.0
        let observation = try VisualObservation(context: initial, clock: { now }, capture: { current },
            waitForStability: { now += 0.5 }, allowed: { true }, clearPoint: {}, status: { _ in },
            locate: { context, _ in current = changedAgain; return target(context) },
            publish: { _, _ in Issue.record("Stale point published"); return true })
        observation.accepted(target(initial))
        observation.invalidate()
        await observation.refreshPointIfNeeded()
        #expect(observation.isDirty)
        #expect(!observation.isPointCurrent)
    }

    @Test func genericPipelineAwaitsFreshnessBeforeGeometryAndPublish() async throws {
        let initial = try scene(0.2)
        let candidate = target(initial)
        let result = await GenericPointingPipeline.run(context: initial,
            isCurrent: { true }, locate: { candidate }, verifyFreshness: { _ in false },
            resolve: { _ in Issue.record("Obsolete geometry used"); return .zero },
            publish: { _, _ in Issue.record("Obsolete target published") })
        guard case .failure(.sceneChanged) = result else { Issue.record("Expected sceneChanged"); return }
    }

    @Test func threeChangedScenesExhaustTheSameRequestBudget() async throws {
        let initial = try scene(0.2)
        var sample = try scene(0.6)
        var now = 0.0
        let observation = try VisualObservation(context: initial, clock: { now }, capture: { sample },
            waitForStability: { now += 0.5 }, allowed: { true }, clearPoint: {}, status: { _ in },
            locate: { _, _ in nil }, publish: { _, _ in false })
        let first = try #require(try await observation.refreshIfNeeded(initial))
        #expect(!observation.isCurrent(initial.captureID))
        sample = try scene(0.8)
        let second = try #require(try await observation.refreshIfNeeded(first))
        sample = try scene(0.1)
        do { _ = try await observation.refreshIfNeeded(second); Issue.record("Budget exceeded") }
        catch is CancellationError {}
        #expect(observation.budget.refreshCount == 2)
        #expect(observation.ended)
    }

    @Test func continuousMovementStopsAtDeadlineWithoutProviderCall() async throws {
        let dark = try scene(0.1)
        let light = try scene(0.9)
        var now = 0.0
        var captures = 0
        let observation = try VisualObservation(context: dark, clock: { now }, capture: {
            captures += 1
            return captures.isMultiple(of: 2) ? dark : light
        }, waitForStability: { now += 1 }, allowed: { true }, clearPoint: {}, status: { _ in },
            locate: { _, _ in Issue.record("Unstable image sent to provider"); return nil },
            publish: { _, _ in false })
        observation.invalidate()
        do { _ = try await observation.refreshIfNeeded(dark); Issue.record("Unstable capture accepted") }
        catch is CancellationError {}
        #expect(now >= 30)
        #expect(observation.budget.refreshCount == 0)
    }

    @Test func completedVoiceTurnCanObserveButNewTurnRevokesIt() async throws {
        let initial = try scene(0.2)
        var session = ConversationSession()
        let turnID = session.beginTurn()
        var captures = 0
        let observation = try VisualObservation(context: initial, capture: { captures += 1; return initial },
            allowed: { session.currentTurn?.id == turnID }, clearPoint: {}, status: { _ in },
            locate: { _, _ in nil }, publish: { _, _ in false })
        session.setTranscript("Find a setting", for: turnID)
        session.setResponse("There it is", for: turnID)
        session.completeTurn(turnID)
        #expect(!session.isActive(turnID))
        #expect(try await observation.verify(initial))
        session.beginTurn()
        do { try await observation.poll(); Issue.record("Superseded capture started") }
        catch is CancellationError {}
        #expect(captures == 1)
        #expect(session.exchanges.count == 1)
    }

    @Test func revokedPermissionNeverStartsCapture() async throws {
        let initial = try scene(0.2)
        let observation = try VisualObservation(context: initial, capture: {
            Issue.record("Capture after revocation"); return initial
        }, allowed: { false }, clearPoint: {}, status: { _ in }, locate: { _, _ in nil }, publish: { _, _ in false })
        #expect(!observation.isCurrent(initial.captureID))
        do { try await observation.poll(); Issue.record("Expected cancellation") }
        catch is CancellationError {}
    }

    @Test func refreshProtocolReturnsOneToolResultThenImageThenRequiredDecision() throws {
        let context = try scene(0.2)
        let events = OpenAIRealtimeVoiceClient.visualRefreshEvents(context: context, callID: "test-call")
        #expect(events.count == 3)
        let result = try #require(events[0]["item"] as? [String: Any])
        #expect(result["type"] as? String == "function_call_output")
        #expect(result["call_id"] as? String == "test-call")
        let output = try #require(result["output"] as? String)
        let decision = try #require(try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
        #expect(decision["pointed"] as? Bool == false)
        #expect(decision["reason"] as? String == "scene_changed")
        let message = try #require(events[1]["item"] as? [String: Any])
        let content = try #require(message["content"] as? [[String: Any]])
        #expect((content[0]["text"] as? String)?.contains(context.captureID) == true)
        #expect(content[1]["type"] as? String == "input_image")
        #expect(events[2]["type"] as? String == "response.create")
        let response = try #require(events[2]["response"] as? [String: Any])
        #expect(response["tool_choice"] as? String == "required")
        #expect(response["output_modalities"] as? [String] == ["text"])
        #expect(events.allSatisfy { $0["type"] as? String != "input_audio_buffer.commit" })
    }

    @Test func tornCaptureDuringMonitorCrossingRetriesWithoutReusingOldImage() async throws {
        let initial = try scene(0.2)
        let secondDisplay = try scene(0.2, display: 2, origin: CGPoint(x: -1000, y: 0))
        var now = 0.0
        var attempts = 0
        let observation = try VisualObservation(context: initial, clock: { now }, capture: {
            attempts += 1
            if attempts == 1 { throw URLError(.resourceUnavailable) }
            return secondDisplay
        }, waitForStability: { now += 0.5 }, allowed: { true }, clearPoint: {}, status: { _ in },
            locate: { _, _ in nil }, publish: { _, _ in false })
        let fresh = try #require(try await observation.refreshIfNeeded(initial))
        #expect(fresh.displayID == 2)
        #expect(fresh.captureID != initial.captureID)
        #expect(attempts >= 2)
        #expect(!observation.ended)
    }

    @Test func fingerprintPreservesTopLeftRasterOrientation() throws {
        var pixels = [UInt8](repeating: 0, count: 320 * 200)
        for index in 0..<(320 * 100) { pixels[index] = 240 }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(width: 320, height: 200, bitsPerComponent: 8,
            bitsPerPixel: 8, bytesPerRow: 320, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        let fingerprint = try VisualSceneFingerprint(imageData: data)
        #expect(fingerprint.pixels[100] > 200)
        #expect(fingerprint.pixels[320 * 150] < 20)
    }
}
