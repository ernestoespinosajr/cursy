import Foundation
import Testing
@testable import Cursy

struct WalkthroughStoreTests {
    func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cursy-guide-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    @Test func noOptInCreatesNoFileAndSavedGuideRestoresPaused() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("guides")
        let store = WalkthroughStore(directory: directory)
        var guide = try WalkthroughSession(plan: WalkthroughTests.plan(), conversationID: UUID())
        guide.activate()
        do { try await store.save(guide.checkpoint, consent: false); Issue.record("Saved without consent") }
        catch WalkthroughStore.StoreError.consentRequired { }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        try await store.save(guide.checkpoint, consent: true)
        let loaded = try await store.loadAll()
        #expect(loaded.count == 1)
        let restored = try WalkthroughSession(checkpoint: #require(loaded.first))
        #expect(restored.status == .paused)
        #expect(restored.token == nil)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(guide.id.uuidString + ".json").path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test func staleWritesAndDeletedGuideCannotResurrect() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WalkthroughStore(directory: directory)
        var guide = try WalkthroughSession(plan: WalkthroughTests.plan(), conversationID: UUID())
        let stale = guide.checkpoint
        guide.activate()
        try await store.save(guide.checkpoint, consent: true)
        do { try await store.save(stale, consent: true); Issue.record("Stale write accepted") }
        catch WalkthroughStore.StoreError.staleWrite { }
        try await store.delete(guide.id)
        do { try await store.save(guide.checkpoint, consent: true); Issue.record("Deleted guide resurrected") }
        catch WalkthroughStore.StoreError.staleWrite { }
        #expect(try await store.loadAll().isEmpty)
    }

    @Test func hundredSerializedSaveRestartsPreserveConfirmedSteps() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var guide = try WalkthroughSession(plan: WalkthroughTests.plan(), conversationID: UUID())
        guide.activate()
        guide.confirm(try #require(guide.token), by: .user)
        for _ in 0..<100 {
            let writer = WalkthroughStore(directory: directory)
            try await writer.save(guide.checkpoint, consent: true)
            let reopened = WalkthroughStore(directory: directory)
            let saved = try await reopened.loadAll()
            guide = try WalkthroughSession(checkpoint: #require(saved.first))
            #expect(guide.completedCount == 1)
            #expect(guide.status == .paused)
        }
    }

    @Test func corruptFileIsNotSilentlyOverwritten() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WalkthroughStore(directory: directory)
        let guide = try WalkthroughSession(plan: WalkthroughTests.plan(), conversationID: UUID())
        let path = directory.appendingPathComponent(guide.id.uuidString + ".json")
        let corrupt = Data("{truncated".utf8)
        try corrupt.write(to: path)
        await #expect(throws: Error.self) { try await store.loadAll() }
        await #expect(throws: Error.self) { try await store.save(guide.checkpoint, consent: true) }
        #expect(try Data(contentsOf: path) == corrupt)
    }

    @Test func restartingPreservesQuotaWithoutRestoringConsent() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WalkthroughStore(directory: directory)
        var guide = try WalkthroughSession(plan: WalkthroughTests.plan(), conversationID: UUID())
        guide.activate()
        let token = try #require(guide.token)
        let stale = guide.checkpoint
        try guide.recordVerificationUsage([token.stepID: 10])
        #expect(guide.token == token)
        try await store.save(guide.checkpoint, consent: true)
        do { try await store.save(stale, consent: true); Issue.record("Same-revision write replenished quota") }
        catch WalkthroughStore.StoreError.staleWrite { }
        let loaded = try await WalkthroughStore(directory: directory).loadAll()
        var restored = try WalkthroughSession(checkpoint: #require(loaded.first))
        #expect(restored.status == .paused)
        restored.activate()
        var policy = StepVerificationPolicy(token: try #require(restored.token), usage: restored.verificationUsage)
        #expect(policy.leaseDeadline == nil)
        #expect(policy.inFlight == nil)
        let renewed = policy.startLease(at: 0, consent: true)
        #expect(!renewed)
        #expect(policy.remoteCount == 10)
    }

    @Test func checkpointRejectsInvalidQuotaAndReadsLegacyAbsentQuota() throws {
        let guide = try WalkthroughSession(plan: WalkthroughTests.plan(), conversationID: UUID())
        var checkpoint = guide.checkpoint
        for invalid in [-1, 0, 11, Int.max] {
            checkpoint.verificationUsage = [UUID(): invalid]
            #expect(throws: Error.self) { try WalkthroughSession(checkpoint: checkpoint) }
        }
        checkpoint.verificationUsage = Dictionary(uniqueKeysWithValues: (0..<4).map { _ in (UUID(), 10) })
        #expect(throws: Error.self) { try WalkthroughSession(checkpoint: checkpoint) }
        checkpoint.verificationUsage = nil
        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(WalkthroughSession.Checkpoint.self, from: data)
        #expect(try WalkthroughSession(checkpoint: decoded).verificationUsage.isEmpty)
    }
}
