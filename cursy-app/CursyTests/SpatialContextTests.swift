import AppKit
import Testing
@testable import Cursy

@MainActor
struct SpatialContextTests {
    private func scene(shade: CGFloat = 0.2, display: UInt32 = 1,
                       frame: CGRect = CGRect(x: 0, y: 0, width: 1000, height: 800),
                       ownerPID: pid_t = 100) throws -> VisualTurnContext {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 320,
            pixelsHigh: 200, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor(white: shade, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 320, height: 200).fill()
        NSGraphicsContext.restoreGraphicsState()
        return VisualTurnContext(captureID: UUID().uuidString, displayID: display,
            displayFrame: frame, capturedAt: .now,
            imageData: try #require(bitmap.representation(using: .png, properties: [:])),
            imageWidth: 320, imageHeight: 200,
            capturedWindows: [CapturedWindowEvidence(id: "test-window", windowID: 10,
                ownerPID: ownerPID, applicationName: "Fixture", frame: frame)])
    }

    private func owner() -> ConversationTurnContext {
        ConversationTurnContext(sessionID: ConversationSessionID(), turnID: ConversationTurnID())
    }

    @Test func historicalCheckpointExcludesSamplesAfterCaptureStarted() async throws {
        var time = 0.0
        let image = try scene()
        let owner = owner()
        var calls = 0
        var pending: CheckedContinuation<VisualTurnContext, Never>?
        let recorder = SpatialContextRecorder(clock: { time }, capture: {
            calls += 1
            if calls == 1 { return image }
            return await withCheckedContinuation { pending = $0 }
        }, pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner); await recorder.drainCapture()
        time = 0.25; recorder.sample()
        time = 1.0; recorder.sample()
        while pending == nil { await Task.yield() }
        time = 1.3; recorder.sample()
        pending?.resume(returning: image)
        await recorder.drainCapture()
        recorder.invalidate(); recorder.release()
        let result = recorder.attach(to: image, owner: owner)
        let evidence = try #require(result.spatialHistory.first)
        #expect(evidence.observedMilliseconds == 1000)
        #expect(evidence.packet.points.last?[2] == 1000)
        #expect(result.spatialInput == nil)
        #expect(result.spatialHistory.count == 1)
        // Passing a previously attached context cannot resurrect consumed history.
        #expect(recorder.attach(to: result, owner: owner).spatialHistory.isEmpty)
    }

    @Test(arguments: [false, true])
    func previousVerifiedSceneSurvivesScrollOrMonitorCrossing(crossMonitor: Bool) async throws {
        var time = 0.0
        let first = try scene()
        let second = try scene(shade: 0.7, display: crossMonitor ? 2 : 1,
            frame: CGRect(x: crossMonitor ? -1000 : 0, y: 0, width: 1000, height: 800))
        var current = first
        var pointer = CGPoint(x: 250, y: 600)
        let owner = owner()
        let recorder = SpatialContextRecorder(clock: { time }, capture: { current },
            pointer: { pointer }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        time = 0.25; recorder.sample()
        time = 1.05; recorder.sample()
        await recorder.drainCapture() // verified checkpoint in the first scene
        time = 1.1
        current = second
        if crossMonitor { pointer.x -= 1000; recorder.sample() }
        else { recorder.invalidate() }
        #expect(recorder.trail.isEmpty && recorder.retainedSceneCount == 1)
        time = 1.7; recorder.sample()
        await recorder.drainCapture()
        time = 1.8; recorder.sample(); recorder.release()
        let result = recorder.attach(to: second, owner: owner)
        let historical = try #require(result.spatialHistory.first)
        #expect(historical.packet.displayID == 1)
        #expect(historical.imageData == first.imageData)
        #expect(historical.packet.points.allSatisfy { $0[2] <= 1050 })
        #expect(result.spatialInput?.displayID == second.displayID)
        #expect(result.spatialInput?.points.allSatisfy { $0[2] >= 1800 } == true)
        #expect(recorder.retainedSceneCount == 0)
        #expect(recorder.attach(to: second, owner: owner).spatialHistory.isEmpty)
        let event = OpenAIRealtimeVoiceClient.visualInputMessage(context: result)
        let item = try #require(event["item"] as? [String: Any])
        let parts = try #require(item["content"] as? [[String: Any]])
        #expect(parts.filter { $0["type"] as? String == "input_image" }.count == 4)
        let texts = parts.compactMap { $0["text"] as? String }
        #expect(texts.first?.contains("1 historical scenes") == true)
        #expect(texts[1].contains("HISTORICAL"))
        #expect(texts[2].contains("CURRENT screen snapshot"))
        let fresh = second.invalidatingSpatialInput(from: result)
        #expect(fresh.spatialHistory.isEmpty && fresh.spatialInput == nil)
        // A historical snapshot is never a valid publication capture.
        let reference = try #require(historical.referenceContext(sessionID: owner.sessionID,
            turnID: owner.turnID, beforeRevision: result.spatialRevision))
        let target = PointingTarget(captureID: reference.captureID, x: 0.25, y: 0.25, label: "fixture")
        #expect(reference.validationFailure(for: target, currentFrame: .zero) == .captureExpired)
        #expect(result.validationFailure(for: target, currentFrame: result.displayFrame) == .captureMismatch)
        let observation = try VisualObservation(context: result, capture: { second },
            allowed: { true }, clearPoint: {}, status: { _ in },
            locate: { _, _ in nil }, publish: { _, _ in false })
        defer { observation.stop() }
        #expect(observation.context.spatialHistory.isEmpty)
        #expect(observation.context.captureID == result.captureID)
    }

    @Test func historyIsBoundedAndUnverifiedGestureTailsAreOmitted() async throws {
        var time = 0.0
        var current = try scene()
        let owner = owner()
        let recorder = SpatialContextRecorder(clock: { time }, capture: { current },
            pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        // The first short gesture has no matching post-gesture snapshot.
        time = 0.1; recorder.sample(); recorder.invalidate()
        for index in 0..<4 {
            current = try scene(shade: CGFloat(index + 1) / 10)
            time += 0.6; recorder.sample(); await recorder.drainCapture()
            time += 0.25; recorder.sample()
            time += 1.05; recorder.sample(); await recorder.drainCapture()
            time += 0.1; recorder.invalidate()
        }
        time += 0.6; recorder.sample(); await recorder.drainCapture()
        time += 0.25; recorder.sample(); recorder.release()
        let result = recorder.attach(to: current, owner: owner)
        #expect(result.spatialHistory.count == 2)
        #expect(result.omittedSpatialScenes == 3) // first unverified + two evicted
        #expect(result.spatialHistory.map { $0.packet.sceneRevision } == [3, 4])
        let prepared = SpatialHistoryTransport.prepare(context: result, currentImageBytes: 0)
        #expect(prepared.included == 2 && prepared.omitted == 3)
        #expect(prepared.imageBytes <= SpatialSceneEvidence.imageBudget)
        let full = SpatialHistoryTransport.prepare(context: result,
            currentImageBytes: SpatialSceneEvidence.imageBudget)
        #expect(full.included == 0 && full.omitted == 5 && full.content.isEmpty)
        var wrongOwner = result
        wrongOwner.spatialTurnID = ConversationTurnID()
        #expect(SpatialHistoryTransport.prepare(context: wrongOwner, currentImageBytes: 0).included == 0)
        wrongOwner = result
        wrongOwner.spatialSessionID = ConversationSessionID()
        #expect(SpatialHistoryTransport.prepare(context: wrongOwner, currentImageBytes: 0).included == 0)
    }

    @Test(arguments: ["cancel", "permission", "expiry", "newTurn"])
    func historicalImagesArePurgedAtLifecycleBoundaries(boundary: String) async throws {
        var time = 0.0
        var allowed = true
        let scene = try scene()
        let owner = owner()
        let recorder = SpatialContextRecorder(clock: { time }, capture: { scene },
            pointer: { CGPoint(x: 250, y: 600) }, allowed: { allowed }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner); await recorder.drainCapture()
        time = 0.25; recorder.sample()
        time = 1.05; recorder.sample(); await recorder.drainCapture()
        recorder.invalidate()
        #expect(recorder.retainedSceneCount == 1)
        switch boundary {
        case "permission": allowed = false; recorder.sample()
        case "expiry": time = 31; recorder.sample()
        case "newTurn": recorder.begin(owner: self.owner()); await recorder.drainCapture()
        default: recorder.cancel()
        }
        #expect(recorder.retainedSceneCount == 0)
        recorder.release()
        #expect(recorder.attach(to: scene, owner: owner).spatialHistory.isEmpty)
    }

    @Test(arguments: [CGPoint.zero, CGPoint(x: -1800, y: 0), CGPoint(x: 1400, y: 120),
                      CGPoint(x: 200, y: 900), CGPoint(x: -300, y: -900)])
    func normalizedMappingRoundTripsOnEveryDisplay(origin: CGPoint) throws {
        let frame = CGRect(origin: origin, size: CGSize(width: 1000, height: 800))
        let point = CGPoint(x: origin.x + 250, y: origin.y + 600)
        var path = SpatialPath(startedAt: 10)
        path.append(globalPoint: point, displayFrame: frame, at: 10.25)
        let sample = try #require(path.samples.first)
        #expect(sample.x == 0.25 && sample.y == 0.25 && sample.milliseconds == 250)
        for raster in [CGSize(width: 1000, height: 800), CGSize(width: 2000, height: 1600)] {
            #expect(ScreenCoordinateSpace.globalPoint(imagePoint: CGPoint(x: sample.x * raster.width,
                y: sample.y * raster.height), imageSize: raster, displayFrame: frame) == point)
        }
    }

    @Test func boundedSimplificationRetainsEndpointsAndRejectsInvalidSamples() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        var path = SpatialPath(startedAt: 0)
        for index in 0..<25_000 {
            path.append(globalPoint: CGPoint(x: index % 998 + 1, y: index % 798 + 1),
                        displayFrame: frame, at: Double(index) / 1_000)
        }
        #expect(path.samples.count <= 512)
        let exported = SpatialPath.simplified(path.samples, limit: 128)
        #expect(exported.count <= 128)
        #expect(exported.first == path.samples.first && exported.last == path.samples.last)
        let previous = path.samples
        path.append(globalPoint: CGPoint(x: CGFloat.nan, y: 1), displayFrame: frame, at: 26)
        path.append(globalPoint: CGPoint(x: -20, y: 1), displayFrame: frame, at: 26)
        path.append(globalPoint: CGPoint(x: 100, y: 100), displayFrame: frame, at: 31)
        path.append(globalPoint: CGPoint(x: 100, y: 100), displayFrame: frame, at: -1)
        #expect(path.samples == previous)
    }

    @Test func singleCurrentScenePacketIsTurnOwnedAndConsumedOnce() async throws {
        let baseline = try scene()
        let fresh = try scene()
        let owner = owner()
        var time = 0.0
        var calls = 0
        let recorder = SpatialContextRecorder(clock: { time }, capture: { calls += 1; return baseline },
            pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        time = 0.25
        recorder.sample()
        recorder.release()
        #expect(recorder.trail.isEmpty)
        let attached = recorder.attach(to: fresh, owner: owner)
        let packet = try #require(attached.spatialInput)
        #expect(packet.captureID == fresh.captureID && packet.captureID != baseline.captureID)
        #expect(packet.turnID == owner.turnID.rawValue.uuidString)
        #expect(packet.points.first == [0.25, 0.25, 250])
        #expect(attached.spatialDeliveryState == .attached)
        #expect(attached.spatialTurnID == owner.turnID)
        #expect(attached.modelContext.contains("normalized_top_left"))
        #expect(attached.modelContext.contains("NOT a verified target"))
        let event = OpenAIRealtimeVoiceClient.visualInputMessage(context: attached)
        let item = try #require(event["item"] as? [String: Any])
        let content = try #require(item["content"] as? [[String: String]])
        #expect(content.count == 4)
        #expect(content[0]["text"]?.contains(fresh.captureID) == true)
        #expect(content[0]["text"]?.contains("normalized_top_left") == true)
        #expect(content[1]["image_url"] == "data:image/jpeg;base64,\(fresh.imageData.base64EncodedString())")
        #expect(content[2]["text"]?.contains("SAME snapshot") == true)
        #expect(content[3]["type"] == "input_image")
        let reference = try #require(SpatialReferenceImage.make(for: attached))
        let bitmap = try #require(NSBitmapImageRep(data: reference))
        #expect(bitmap.pixelsWide == 320 && bitmap.pixelsHigh == 200)
        // A hollow endpoint centered at (80, 50) must not be flipped to (80, 150).
        let marked = try #require(bitmap.colorAt(x: 84, y: 50)?.usingColorSpace(.deviceRGB))
        let opposite = try #require(bitmap.colorAt(x: 84, y: 150)?.usingColorSpace(.deviceRGB))
        #expect(marked.redComponent > marked.greenComponent + 0.3)
        #expect(abs(opposite.redComponent - opposite.greenComponent) < 0.1)
        var mismatched = attached
        mismatched.spatialTurnID = ConversationTurnID()
        #expect(SpatialReferenceImage.make(for: mismatched) == nil)
        mismatched = attached
        mismatched.spatialRevision += 1
        #expect(SpatialReferenceImage.make(for: mismatched) == nil)
        #expect(SpatialReferenceImage.make(for: fresh.invalidatingSpatialInput(from: attached)) == nil)
        let refreshed = OpenAIRealtimeVoiceClient.visualInputMessage(context: attached, refreshed: true)
        let refreshedItem = try #require(refreshed["item"] as? [String: Any])
        #expect((refreshedItem["content"] as? [[String: String]])?.count == 2)
        #expect(recorder.attach(to: fresh, owner: owner).spatialInput == nil)
        #expect(calls == 1)
    }

    @Test(arguments: [UInt32(1), UInt32(2)])
    func referenceRejectsInvalidPathsAndPreservesCleanImage(display: UInt32) throws {
        var context = try scene(display: display, frame: CGRect(x: -1000, y: 200, width: 1000, height: 800))
        let owner = owner()
        context.spatialSessionID = owner.sessionID
        context.spatialTurnID = owner.turnID
        context.spatialDeliveryState = .attached
        let original = context.imageData
        for points in [[[0.2, 0.3, 0.0], [0.4, 0.5, 100.0]], [], [[Double.nan, 0, 0]],
                       [[1.0, 0.2, 0]], [[0.2, 0.3]], [[0.2, 0.3, 30000]],
                       [[0.2, 0.3, 200], [0.3, 0.4, 100]]] {
            context.spatialInput = SpatialContextPacket(sessionID: owner.sessionID.rawValue.uuidString,
                turnID: owner.turnID.rawValue.uuidString, captureID: context.captureID,
                displayID: display, sceneRevision: 0, imageWidth: 320, imageHeight: 200, points: points)
            let valid = points.count == 2 && points.first?.last == 0
            #expect((SpatialReferenceImage.make(for: context) != nil) == valid)
            #expect(context.imageData == original)
        }
    }

    @Test(arguments: ["pixels", "display", "geometry", "owner", "corrupt"])
    func changedEvidenceCannotCarryTheOldPath(change: String) async throws {
        let initial = try scene()
        var fresh = try scene(shade: change == "pixels" ? 0.8 : 0.2,
            display: change == "display" ? 2 : 1,
            frame: CGRect(x: change == "geometry" ? 20 : 0, y: 0, width: 1000, height: 800),
            ownerPID: change == "owner" ? 200 : 100)
        if change == "corrupt" {
            fresh = VisualTurnContext(captureID: "bad", displayID: 1, displayFrame: initial.displayFrame,
                capturedAt: .now, imageData: Data(), imageWidth: 320, imageHeight: 200,
                capturedWindows: initial.capturedWindows)
        }
        let owner = owner()
        let recorder = SpatialContextRecorder(capture: { initial }, pointer: { CGPoint(x: 250, y: 600) },
            allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        recorder.release()
        let result = recorder.attach(to: fresh, owner: owner)
        #expect(result.spatialInput == nil)
        #expect(result.spatialInputNotice != nil)
        let expected: SpatialDeliveryState = change == "pixels" ? .regionChanged
            : change == "corrupt" ? .imageUnreadable : .geometryChanged
        #expect(result.spatialDeliveryState == expected)
    }

    @Test func scrollDropsPathAndWaitsForStableBaseline() async throws {
        let initial = try scene()
        var time = 0.0
        var calls = 0
        let owner = owner()
        let recorder = SpatialContextRecorder(clock: { time }, capture: { calls += 1; return initial },
            pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        #expect(!recorder.trail.isEmpty)
        recorder.invalidate()
        #expect(recorder.trail.isEmpty)
        time = 0.1
        recorder.sample()
        await recorder.drainCapture()
        #expect(calls == 1)
        time = 0.6
        recorder.sample()
        await recorder.drainCapture()
        recorder.sample()
        recorder.release()
        let packet = try #require(recorder.attach(to: initial, owner: owner).spatialInput)
        #expect(packet.sceneRevision == 1)
        #expect(packet.points.allSatisfy { $0[2] >= 600 })
    }

    @Test func crossingDisplaysDoesNotJoinPaths() async throws {
        var time = 0.0
        let first = try scene()
        let second = try scene(display: 2, frame: CGRect(x: -1000, y: 0, width: 1000, height: 800))
        var current = first
        var pointer = CGPoint(x: 250, y: 600)
        let owner = owner()
        let recorder = SpatialContextRecorder(clock: { time }, capture: { current }, pointer: { pointer },
            allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        pointer = CGPoint(x: -750, y: 600)
        current = second
        recorder.sample()
        #expect(recorder.trail.isEmpty)
        time = 0.6
        recorder.sample()
        await recorder.drainCapture()
        recorder.sample()
        recorder.release()
        let packet = try #require(recorder.attach(to: second, owner: owner).spatialInput)
        #expect(packet.displayID == 2)
        #expect(packet.points.first == [0.25, 0.25, 600])
    }

    @Test func permissionAndIdleNeverCapture() async {
        var calls = 0
        let recorder = SpatialContextRecorder(capture: { calls += 1; throw CancellationError() },
            allowed: { false }, installEventSources: false)
        recorder.sample()
        recorder.begin(owner: owner())
        await recorder.drainCapture()
        #expect(calls == 0 && recorder.owner == nil)
        recorder.cancel()
    }

    @Test func resetOrNewTurnCannotAcceptLateCapture() async throws {
        let initial = try scene()
        let oldOwner = owner()
        let newOwner = owner()
        let recorder = SpatialContextRecorder(capture: {
            try? await Task.sleep(for: .milliseconds(10)) // Simulates non-cooperative API.
            return initial
        }, pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: oldOwner)
        await Task.yield()
        recorder.cancel()
        recorder.begin(owner: newOwner)
        await recorder.drainCapture()
        #expect(recorder.trail.isEmpty)
        #expect(recorder.owner == newOwner)
        #expect(recorder.attach(to: initial, owner: oldOwner).spatialInput == nil)
    }

    @Test func limitPurgesEvidenceWithoutCallingAudio() async throws {
        var time = 0.0
        let initial = try scene()
        let owner = owner()
        let recorder = SpatialContextRecorder(clock: { time }, capture: { initial },
            pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        var cancelledInput = false
        recorder.onCancelInput = { cancelledInput = true }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        time = 30
        recorder.sample()
        recorder.release()
        #expect(recorder.status == .limited && recorder.trail.isEmpty)
        #expect(!cancelledInput)
        #expect(recorder.attach(to: initial, owner: owner).spatialDeliveryState == .expired)
    }

    @Test func revokedPermissionPurgesEvidence() async throws {
        let initial = try scene()
        var permitted = true
        let owner = owner()
        let recorder = SpatialContextRecorder(capture: { initial }, pointer: { CGPoint(x: 250, y: 600) },
            allowed: { permitted }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        permitted = false
        recorder.sample()
        #expect(recorder.owner == nil && recorder.trail.isEmpty)
        #expect(recorder.attach(to: initial, owner: owner).spatialInput == nil)
    }

    @Test func payloadIsBoundedAndFreshCaptureHasNoPath() throws {
        let original = try scene()
        let packet = SpatialContextPacket(sessionID: UUID().uuidString, turnID: UUID().uuidString,
            captureID: original.captureID, displayID: 1, sceneRevision: 5, imageWidth: 320, imageHeight: 200,
            points: (0..<128).map { [0.1234, 0.9999, Double($0 * 200)] })
        #expect(try JSONEncoder().encode(packet).count < 8_192)
        #expect(packet.modelText != nil)
        let resized = packet.forRaster(width: 768, height: 480)
        #expect(resized.points == packet.points && resized.captureID == packet.captureID)
        #expect(resized.imageWidth == 768 && resized.imageHeight == 480)
        #expect(!original.modelContext.contains("Spatial input for"))
        var attached = original
        attached.spatialInput = packet
        let bounded = attached.modelContext(maximumCharacters: original.windowContext.count + 150)
        #expect(bounded.contains("Spatial path omitted"))
        #expect(!bounded.contains("normalized_top_left"))
        #expect(bounded.count <= original.windowContext.count + 150)
    }

    @Test func periodicSceneChangeClearsOnlyThisRevision() async throws {
        var time = 0.0
        var current = try scene()
        let owner = owner()
        var calls = 0
        let recorder = SpatialContextRecorder(clock: { time }, capture: { calls += 1; return current },
            pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        #expect(!recorder.trail.isEmpty)
        time = 0.9
        recorder.sample()
        await recorder.drainCapture()
        #expect(calls == 1)
        time = 1
        current = try scene(shade: 0.8)
        recorder.sample()
        await recorder.drainCapture()
        #expect(calls == 2 && recorder.trail.isEmpty)
        time = 1.2
        recorder.sample()
        recorder.release()
        let packet = try #require(recorder.attach(to: current, owner: owner).spatialInput)
        #expect(packet.sceneRevision == 1)
        #expect(packet.points.allSatisfy { $0[2] >= 1200 })
    }

    @Test func oneCaptureSlotSurvivesNonCooperativeCancellation() async throws {
        let initial = try scene()
        let slot = VisualCaptureSlot()
        var pending: CheckedContinuation<VisualTurnContext, Never>?
        let first = Task { @MainActor in
            try await slot.run {
                await withCheckedContinuation { pending = $0 }
            }
        }
        // Only synthetic continuations; no ScreenCaptureKit or permission access.
        while pending == nil { await Task.yield() }
        first.cancel()
        var secondEntered = false
        do {
            _ = try await slot.run { secondEntered = true; return initial }
            Issue.record("Concurrent capture must fail closed")
        } catch { #expect((error as? URLError)?.code == .resourceUnavailable) }
        #expect(!secondEntered)
        pending?.resume(returning: initial)
        _ = try await first.value
        #expect(try await slot.run { initial }.captureID == initial.captureID)
    }

    @Test func releaseDuringCaptureNeverStartsRecordingAgain() async throws {
        let initial = try scene()
        let owner = owner()
        var pending: CheckedContinuation<VisualTurnContext, Never>?
        let recorder = SpatialContextRecorder(capture: {
            await withCheckedContinuation { pending = $0 }
        }, pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        while pending == nil { await Task.yield() }
        recorder.release()
        pending?.resume(returning: initial)
        await recorder.drainCapture()
        #expect(recorder.status == .released && recorder.trail.isEmpty)
        #expect(recorder.attach(to: initial, owner: owner).spatialInput == nil)
    }

    @Test func failedScenePollDropsThePreviousEvidence() async throws {
        let initial = try scene()
        var time = 0.0
        let owner = owner()
        var fail = false
        let recorder = SpatialContextRecorder(clock: { time }, capture: {
            if fail { throw URLError(.timedOut) }
            return initial
        }, pointer: { CGPoint(x: 250, y: 600) }, allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        fail = true
        time = 1
        recorder.sample()
        await recorder.drainCapture()
        #expect(recorder.trail.isEmpty && recorder.status == .preparing)
        recorder.release()
        #expect(recorder.attach(to: initial, owner: owner).spatialDeliveryState == .captureFailed)
    }

    @Test func attachmentGuardsDoNotConsumeAnotherOwnersEvidence() async throws {
        let initial = try scene()
        let owner = owner()
        let recorder = SpatialContextRecorder(capture: { initial }, pointer: { CGPoint(x: 250, y: 600) },
            allowed: { true }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        #expect(recorder.attach(to: initial, owner: owner).spatialDeliveryState == .stillRecording)
        recorder.release()
        #expect(recorder.attach(to: initial, owner: self.owner()).spatialDeliveryState == .ownerMismatch)
        #expect(recorder.attach(to: initial, owner: owner).spatialDeliveryState == .attached)
        #expect(recorder.attach(to: initial, owner: owner).spatialDeliveryState == .alreadyConsumed)
    }

    @Test func finalPermissionRevocationIsExplicit() async throws {
        let initial = try scene()
        let owner = owner()
        var allowed = true
        let recorder = SpatialContextRecorder(capture: { initial }, pointer: { CGPoint(x: 250, y: 600) },
            allowed: { allowed }, installEventSources: false)
        defer { recorder.cancel() }
        recorder.begin(owner: owner)
        await recorder.drainCapture()
        recorder.sample()
        recorder.release()
        allowed = false
        let result = recorder.attach(to: initial, owner: owner)
        #expect(result.spatialInput == nil)
        #expect(result.spatialDeliveryState == .permissionRevoked)
    }

    @Test func packetBudgetUsesUTF16AndNeverPretendsToDeliverAnOmittedPath() throws {
        var context = try scene()
        context.windowContext = String(repeating: "🧭", count: 100)
        context.spatialInput = SpatialContextPacket(sessionID: "fixture", turnID: "fixture",
            captureID: context.captureID, displayID: context.displayID, sceneRevision: 0,
            imageWidth: context.imageWidth, imageHeight: context.imageHeight, points: [[0.2, 0.3, 100]])
        let full = context.preparedModelContext()
        #expect(full.state == .attached && full.sampleCount == 1)
        let bounded = context.preparedModelContext(maximumCharacters: full.text.count)
        #expect(bounded.state == .promptBudgetExceeded && bounded.sampleCount == 0)
        #expect(!bounded.text.contains("normalized_top_left"))
        #expect(bounded.text.utf16.count <= full.text.count)
        #expect(context.preparedModelContext(maximumCharacters: full.text.utf16.count).state == .attached)
        context.spatialInput = SpatialContextPacket(sessionID: "fixture", turnID: "fixture",
            captureID: context.captureID, displayID: 1, sceneRevision: 0, imageWidth: 320,
            imageHeight: 200, points: Array(repeating: [0.1234, 0.5678, 12345], count: 3000))
        let oversized = context.preparedModelContext()
        #expect(oversized.state == .packetTooLarge && oversized.sampleCount == 0)
        #expect(oversized.text.contains("unavailable"))
    }

    @Test func refreshedSceneCarriesOnlyTheLossReasonNotOldPoints() throws {
        var previous = try scene()
        previous.spatialDeliveryState = .attached
        previous.spatialTurnID = owner().turnID
        previous.spatialInput = SpatialContextPacket(sessionID: "fixture", turnID: "fixture",
            captureID: previous.captureID, displayID: 1, sceneRevision: 0,
            imageWidth: 320, imageHeight: 200, points: [[0.2, 0.3, 100]])
        let fresh = try scene(display: 2).invalidatingSpatialInput(from: previous)
        #expect(fresh.spatialInput == nil && fresh.spatialDeliveryState == .sceneRefreshed)
        #expect(fresh.spatialTurnID == previous.spatialTurnID)
        #expect(!fresh.modelContext.contains("normalized_top_left"))
        let events = OpenAIRealtimeVoiceClient.visualRefreshEvents(context: fresh, callID: "fixture")
        let item = try #require(events[1]["item"] as? [String: Any])
        let content = try #require(item["content"] as? [[String: Any]])
        #expect((content[0]["text"] as? String)?.contains("earlier pointer path is obsolete") == true)
    }
}
