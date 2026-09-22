import AppKit
import Testing
@testable import Cursy

@MainActor
struct WalkthroughCoordinatorTests {
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 {
            if condition() { return }
            await Task.yield()
        }
        #expect(condition())
    }

    private func scene(_ shade: CGFloat) throws -> VisualTurnContext {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32,
            pixelsHigh: 20, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSColor(white: shade, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 32, height: 20).fill()
        NSGraphicsContext.restoreGraphicsState()
        return VisualTurnContext(captureID: UUID().uuidString, displayID: 1,
            displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800), capturedAt: .now,
            imageData: try #require(bitmap.representation(using: .png, properties: [:])), imageWidth: 32, imageHeight: 20)
    }

    @Test func threeManualFlowsKeepGoalAndNeverCaptureWithoutSharing() async throws {
        for goal in ["Change a setting", "Organize a file", "Fill a form"] {
            var captureCalls = 0
            let coordinator = WalkthroughCoordinator(dependencies: .init(
                plan: { request in .init(goal: request, steps: WalkthroughTests.plan().steps) },
                capture: { captureCalls += 1; throw CancellationError() },
                locate: { _, _, _ in [] }, verify: { _, _, _ in throw CancellationError() },
                allowed: { _ in false }, publish: { _ in }))
            coordinator.prepare(request: goal, conversationID: UUID())
            try await waitUntil { !coordinator.isPreparing }
            coordinator.start()
            for _ in 0..<3 { coordinator.confirmCurrentStep() }
            #expect(coordinator.guide?.status == .completed)
            #expect(coordinator.guide?.goal == goal)
            #expect(coordinator.notice == .completed)
            #expect(captureCalls == 0)
        }
    }

    @Test func delayedPlanCannotReopenCancelledGuide() async throws {
        var continuation: CheckedContinuation<WalkthroughPlan, Error>?
        let coordinator = WalkthroughCoordinator(dependencies: .init(
            plan: { _ in try await withCheckedThrowingContinuation { continuation = $0 } },
            capture: { throw CancellationError() }, locate: { _, _, _ in [] },
            verify: { _, _, _ in throw CancellationError() }, allowed: { _ in false }, publish: { _ in }))
        coordinator.prepare(request: "Help", conversationID: UUID())
        try await waitUntil { continuation != nil }
        coordinator.cancel()
        continuation?.resume(returning: WalkthroughTests.plan())
        for _ in 0..<10 { await Task.yield() }
        #expect(coordinator.guide == nil)
        #expect(coordinator.notice == .cancelled)
        #expect(!coordinator.isPreparing)
    }

    @Test(arguments: [StepVerificationDecision.Outcome.confirmed, .uncertain, .pending, .blocked], [false, true])
    func modelDecisionIsAppliedOnlyAfterFreshStableRecheck(outcome: StepVerificationDecision.Outcome, structured: Bool) async throws {
        let before = try scene(0.1)
        let after = try scene(0.9)
        var clock = 0.0
        var captures = 0
        var verifications = 0
        let coordinator = WalkthroughCoordinator(dependencies: .init(
            plan: { _ in WalkthroughTests.plan(count: 1) },
            capture: { captures += 1; return captures <= 2 ? before : after },
            locate: { _, _, _ in [] }, verify: { _, _, _ in
                verifications += 1
                return StepVerificationDecision(outcome: outcome, evidenceSummary: "Synthetic visual result",
                    evidence: structured ? StepVerificationEvidenceTests.decision().evidence : nil)
            }, allowed: { _ in true }, publish: { _ in }, clock: { clock }, sleep: { duration in
                if duration >= .seconds(100) { try await Task.sleep(for: .seconds(60)) }
                else { clock += 1; await Task.yield(); try Task.checkCancellation() }
            }))
        coordinator.prepare(request: "Guide", conversationID: UUID())
        try await waitUntil { !coordinator.isPreparing }
        coordinator.start()
        try await waitUntil { captures == 1 }
        coordinator.enableFollowing()
        try await waitUntil { verifications > 0 && captures >= 5 }
        for _ in 0..<10 { await Task.yield() }
        if outcome == .confirmed && structured {
            #expect(coordinator.guide?.status == .completed)
            #expect(coordinator.guide?.completedCount == 1)
        } else {
            #expect(coordinator.guide?.completedCount == 0)
        }
        #expect(verifications == 1)
        coordinator.pause()
    }

    @Test func cancelledObservationCannotPauseReplacementGuide() async throws {
        let image = try scene(0.1)
        var continuation: CheckedContinuation<Void, Never>?
        var resumed = false
        var shortSleeps = 0
        var allowed = true
        let coordinator = WalkthroughCoordinator(dependencies: .init(
            plan: { request in .init(goal: request, steps: WalkthroughTests.plan().steps) },
            capture: { image }, locate: { _, _, _ in [] },
            verify: { _, _, _ in throw CancellationError() }, allowed: { _ in allowed },
            publish: { _ in }, sleep: { duration in
                if duration >= .seconds(100) { try await Task.sleep(for: .seconds(60)); return }
                shortSleeps += 1
                if shortSleeps == 2 {
                    // Model an OS callback that returns successfully even after cancellation.
                    await withCheckedContinuation { continuation = $0 }
                    resumed = true
                }
            }))
        coordinator.prepare(request: "Old guide", conversationID: UUID())
        try await waitUntil { !coordinator.isPreparing }
        coordinator.start()
        coordinator.enableFollowing()
        try await waitUntil { continuation != nil }
        allowed = false
        coordinator.prepare(request: "New guide", conversationID: UUID())
        try await waitUntil { !coordinator.isPreparing }
        coordinator.start()
        continuation?.resume()
        try await waitUntil { resumed }
        for _ in 0..<10 { await Task.yield() }
        #expect(coordinator.guide?.goal == "New guide")
        #expect(coordinator.guide?.status == .active)
        coordinator.cancel()
    }

    @Test(arguments: ["delay", "capture", "locate", "verify"])
    func revokedObservationPausesCurrentOwner(boundary: String) async throws {
        let before = try scene(0.1)
        let after = try scene(0.9)
        var allowed = true
        var clock = 0.0
        var captures = 0
        var verifications = 0
        var continuation: CheckedContinuation<Void, Never>?
        var resumed = false
        func revokeAtBoundary(_ current: String) async {
            guard boundary == current else { return }
            await withCheckedContinuation { continuation = $0 }
            resumed = true
        }
        let coordinator = WalkthroughCoordinator(dependencies: .init(
            plan: { _ in WalkthroughTests.plan(count: 1) },
            capture: {
                captures += 1
                await revokeAtBoundary("capture")
                return captures == 1 ? before : after
            }, locate: { _, _, _ in
                await revokeAtBoundary("locate")
                return []
            }, verify: { _, _, _ in
                verifications += 1
                await revokeAtBoundary("verify")
                return .init(outcome: .confirmed, evidenceSummary: "Synthetic completed result")
            }, allowed: { _ in allowed }, publish: { marks in #expect(marks.isEmpty) },
            clock: { clock }, sleep: { duration in
                if duration >= .seconds(100) { try await Task.sleep(for: .seconds(60)); return }
                await revokeAtBoundary("delay")
                clock += 1
                await Task.yield()
                try Task.checkCancellation()
            }))
        coordinator.prepare(request: "Guide", conversationID: UUID())
        try await waitUntil { !coordinator.isPreparing }
        coordinator.start()
        coordinator.enableFollowing()
        try await waitUntil { continuation != nil }
        let capturesAtRevocation = captures
        allowed = false
        continuation?.resume()
        try await waitUntil { resumed && !coordinator.isFollowing }
        #expect(coordinator.guide?.status == .paused)
        #expect(coordinator.guide?.completedCount == 0)
        #expect(captures == capturesAtRevocation)
        #expect(verifications == (boundary == "verify" ? 1 : 0))
        coordinator.cancel()
    }
}
