import Foundation

/// Main-actor-owned value state. No device/network work: ordering is testable offline.
struct RealtimeInputDelivery {
    enum DeliveryError: Error { case connectionBufferFull, recordingLimitReached }
    static let connectionBufferLimit = 24_000 * 2 * 20
    static let recordingLimit = 24_000 * 2 * 120
    private(set) var totalBytes = 0
    private(set) var pending = Data()
    private(set) var transportReady = false
    private(set) var released = false
    private var finishClaimed = false
    private var cancelled = false

    mutating func accept(_ data: Data) throws -> Data {
        guard !cancelled, !released, !data.isEmpty else { return Data() }
        guard data.count <= Self.recordingLimit - totalBytes else {
            throw DeliveryError.recordingLimitReached
        }
        if !transportReady {
            guard data.count <= Self.connectionBufferLimit - pending.count else {
                throw DeliveryError.connectionBufferFull
            }
            pending.append(data)
        }
        totalBytes += data.count
        return transportReady ? data : Data()
    }

    /// Flushed once, ahead of all subsequently accepted samples.
    mutating func markTransportReady() -> Data {
        guard !cancelled, !transportReady else { return Data() }
        transportReady = true
        let buffered = pending
        pending = Data()
        return buffered
    }

    @discardableResult
    mutating func release() -> Bool {
        guard !cancelled, !released else { return false }
        released = true
        return true
    }

    mutating func claimFinish() -> Bool {
        guard !cancelled, released, transportReady, !finishClaimed else { return false }
        finishClaimed = true
        return true
    }

    mutating func cancel() {
        cancelled = true
        pending = Data()
        totalBytes = 0
    }
}

/// First occurrence of each phase, using a monotonic clock. Contains no user content.
struct RealtimeLatencyTrace {
    enum Phase: String {
        case captureRequested, firstPCM, brokerReady, transportReady, released
        case visualCaptureStarted, visualCaptureReady, inputCommitted, visualContextSent
        case visualDecisionRequested, visualDecisionReady, localizationStarted, localizationFinished
        case spokenResponseRequested, firstAudioReceived, playbackScheduled, completed, failed, cancelled, discarded
    }
    struct Measurement {
        let phase: Phase
        let sinceStartMS: Double
        let sinceReleaseMS: Double?
    }
    let id = UUID()
    private let startedAt: TimeInterval
    private var releaseTime: TimeInterval?
    private var recorded = Set<Phase>()
    private var terminal = false

    init(now: TimeInterval = ProcessInfo.processInfo.systemUptime) { startedAt = now }

    mutating func mark(_ phase: Phase, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Measurement? {
        guard !terminal, recorded.insert(phase).inserted else { return nil }
        switch phase {
        case .completed, .failed, .cancelled, .discarded: terminal = true
        default: break
        }
        if phase == .released { releaseTime = now }
        return Measurement(phase: phase, sinceStartMS: (now - startedAt) * 1_000,
                           sinceReleaseMS: releaseTime.map { (now - $0) * 1_000 })
    }
}
