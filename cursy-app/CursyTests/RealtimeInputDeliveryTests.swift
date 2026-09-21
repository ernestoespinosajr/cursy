import Foundation
import Testing
@testable import Cursy

struct RealtimeInputDeliveryTests {
    @Test func earlySpeechIsFlushedInOrderBeforeLiveSpeech() throws {
        var input = RealtimeInputDelivery()
        #expect(try input.accept(Data([1, 2])).isEmpty)
        #expect(try input.accept(Data([3, 4])).isEmpty)
        #expect(input.markTransportReady() == Data([1, 2, 3, 4]))
        #expect(try input.accept(Data([5, 6])) == Data([5, 6]))
        #expect(input.totalBytes == 6)
        #expect(input.pending.isEmpty)
    }

    @Test func releaseBeforeConnectionPreservesAudioAndFinishesOnce() throws {
        var input = RealtimeInputDelivery()
        let utterance = Data(repeating: 7, count: RealtimePCMInbox.minimumBytes)
        #expect(try input.accept(utterance).isEmpty)
        #expect(input.release() == true)
        #expect(input.claimFinish() == false)
        #expect(try input.accept(Data([8, 9])).isEmpty)
        #expect(input.markTransportReady() == utterance)
        #expect(input.claimFinish() == true)
        #expect(input.claimFinish() == false)
        #expect(input.release() == false)
        #expect(input.markTransportReady().isEmpty)
        #expect(input.totalBytes == utterance.count)
    }

    @Test func connectionBeforeReleaseDoesNotCommitWhileRecording() throws {
        var input = RealtimeInputDelivery()
        #expect(input.markTransportReady().isEmpty)
        #expect(input.claimFinish() == false)
        #expect(try input.accept(Data([1, 2])) == Data([1, 2]))
        #expect(input.release() == true)
        #expect(input.claimFinish() == true)
        #expect(input.claimFinish() == false)
    }

    @Test func cancelDiscardsRAMAndRejectsLateReadinessAndSamples() throws {
        var input = RealtimeInputDelivery()
        _ = try input.accept(Data([1, 2]))
        input.cancel()
        #expect(input.pending.isEmpty)
        #expect(input.totalBytes == 0)
        #expect(input.markTransportReady().isEmpty)
        #expect(try input.accept(Data([3, 4])).isEmpty)
        #expect(input.release() == false)
        #expect(input.claimFinish() == false)
    }

    @Test func cancelAfterReleaseNeverFlushesOldSpeechIntoAnotherTurn() throws {
        var old = RealtimeInputDelivery()
        _ = try old.accept(Data([1, 2]))
        old.release()
        old.cancel()
        var next = RealtimeInputDelivery()
        _ = try next.accept(Data([3, 4]))
        #expect(old.markTransportReady().isEmpty)
        #expect(old.claimFinish() == false)
        #expect(next.markTransportReady() == Data([3, 4]))
    }

    @Test func connectionBufferIsBoundedWithoutTruncatingAcceptedSpeech() throws {
        var input = RealtimeInputDelivery()
        let maximum = Data(repeating: 1, count: RealtimeInputDelivery.connectionBufferLimit)
        _ = try input.accept(maximum)
        #expect(throws: RealtimeInputDelivery.DeliveryError.connectionBufferFull) {
            _ = try input.accept(Data([2]))
        }
        #expect(input.totalBytes == maximum.count)
        #expect(input.markTransportReady() == maximum)
    }

    @Test func totalBudgetSurvivesTransportReadinessAndInputDeviceChanges() throws {
        var input = RealtimeInputDelivery()
        // Rebuilding the AVAudioEngine changes its inbox, never this turn budget.
        _ = try input.accept(Data(repeating: 1, count: RealtimeInputDelivery.connectionBufferLimit))
        _ = input.markTransportReady()
        let rest = RealtimeInputDelivery.recordingLimit - input.totalBytes
        #expect(try input.accept(Data(repeating: 2, count: rest)).count == rest)
        #expect(throws: RealtimeInputDelivery.DeliveryError.recordingLimitReached) {
            _ = try input.accept(Data([3]))
        }
        #expect(input.totalBytes == RealtimeInputDelivery.recordingLimit)
    }

    @Test func mailboxDrainAtReleaseRetainsExactlyAcceptedSamples() throws {
        let inbox = RealtimePCMInbox()
        var input = RealtimeInputDelivery()
        #expect(inbox.append(Data(repeating: 1, count: 2_400)))
        _ = try input.accept(inbox.drain())
        #expect(inbox.append(Data(repeating: 2, count: 2_400)))
        _ = try input.accept(inbox.drain(closing: true))
        input.release()
        #expect(!inbox.append(Data([3, 4])))
        #expect(inbox.drain().isEmpty)
        let flushed = input.markTransportReady()
        #expect(flushed.count == RealtimePCMInbox.minimumBytes)
        #expect(flushed.prefix(2_400) == Data(repeating: 1, count: 2_400))
        #expect(flushed.suffix(2_400) == Data(repeating: 2, count: 2_400))
    }

    @Test func shortTapRetainsItsRealLengthForMinimumDurationCheck() throws {
        var input = RealtimeInputDelivery()
        _ = try input.accept(Data(repeating: 0, count: RealtimePCMInbox.minimumBytes - 2))
        input.release()
        #expect(input.totalBytes < RealtimePCMInbox.minimumBytes)
        input.cancel()
        #expect(input.markTransportReady().isEmpty)
    }

    @Test func networkFailureAfterCaptureNeverSwitchesToAnotherRecorder() {
        #expect(!OpenAIRealtimeVoiceError.connectionStartFailed.permitsLegacyFallback)
        #expect(!OpenAIRealtimeVoiceError.connectionBufferFull.permitsLegacyFallback)
        #expect(!OpenAIRealtimeVoiceError.microphoneStartFailed.permitsLegacyFallback)
    }

    @Test func latencyMeasuresCaptureAndReleaseSeparatelyWithoutWallClock() throws {
        var trace = RealtimeLatencyTrace(now: 10)
        let firstPCM = trace.mark(.firstPCM, now: 10.125)
        let pcm = try #require(firstPCM)
        #expect(pcm.sinceStartMS == 125)
        #expect(pcm.sinceReleaseMS == nil)
        _ = trace.mark(.released, now: 12)
        let firstAudio = trace.mark(.firstAudioReceived, now: 12.5)
        let audio = try #require(firstAudio)
        #expect(audio.sinceStartMS == 2_500)
        #expect(audio.sinceReleaseMS == 500)
        #expect(trace.mark(.firstAudioReceived, now: 12.75) == nil)
        #expect(trace.mark(.firstPCM, now: 13) == nil) // Route recovery does not reset first PCM.
    }

    @Test func newTraceDoesNotInheritReleaseOrFirstAudioFromPreviousTurn() throws {
        var old = RealtimeLatencyTrace(now: 0)
        _ = old.mark(.released, now: 1)
        _ = old.mark(.firstAudioReceived, now: 2)
        var next = RealtimeLatencyTrace(now: 3)
        #expect(old.id != next.id)
        let firstPCM = next.mark(.firstPCM, now: 3.25)
        let pcm = try #require(firstPCM)
        #expect(pcm.sinceStartMS == 250)
        #expect(pcm.sinceReleaseMS == nil)
    }

    @Test func cleanupDoesNotReportACompletedOrFailedTurnAsCancelled() {
        for terminal in [RealtimeLatencyTrace.Phase.completed, .failed, .discarded] {
            var trace = RealtimeLatencyTrace(now: 0)
            #expect(trace.mark(terminal, now: 1) != nil)
            #expect(trace.mark(.cancelled, now: 2) == nil)
            #expect(trace.mark(.firstAudioReceived, now: 3) == nil)
        }
    }
}
