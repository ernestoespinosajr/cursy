import Foundation
import CoreGraphics

/// Shared presentation coordinates only; no audio ownership or target authority.
struct HomeNotchAnchor: Equatable {
    let displayFrame: CGRect
    let cameraFrame: CGRect

    var hiddenCursorPoint: CGPoint {
        CGPoint(x: cameraFrame.midX, y: displayFrame.maxY + 24)
    }
    var activationPoint: CGPoint {
        CGPoint(x: cameraFrame.midX, y: cameraFrame.minY - 12)
    }
}

enum HomeNotchInteraction {
    static let duration: TimeInterval = 0.25
    static let arrivalDuration: TimeInterval = 0.8
    static let clickDuration: TimeInterval = 0.14

    static func activationReady(request: UUID?, completed: UUID?, hasCamera: Bool,
                                voiceState: CompanionVoiceState, reduceMotion: Bool) -> Bool {
        if !hasCamera || reduceMotion || voiceState == .responding { return true }
        guard let request else { return false }
        return completed == request
    }

    /// A lateral S-curve remains visible even when starting directly below camera.
    static func arrivalPoint(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        let amount = min(max(progress.isFinite ? progress : 0, 0), 1)
        let distance = hypot(end.x - start.x, end.y - start.y)
        let bend = min(140, max(30, distance * 0.20))
        let direction: CGFloat = start.x <= end.x ? -1 : 1
        let first = CGPoint(x: start.x + direction * bend, y: start.y + (end.y - start.y) * 0.35)
        let second = CGPoint(x: end.x - direction * bend, y: end.y + (start.y - end.y) * 0.20)
        let remainder = 1 - amount
        return CGPoint(x: remainder * remainder * remainder * start.x + 3 * remainder * remainder * amount * first.x + 3 * remainder * amount * amount * second.x + amount * amount * amount * end.x,
                       y: remainder * remainder * remainder * start.y + 3 * remainder * remainder * amount * first.y + 3 * remainder * amount * amount * second.y + amount * amount * amount * end.y)
    }

    static func shouldDock(voiceState: CompanionVoiceState, hasValidatedTarget: Bool) -> Bool {
        switch voiceState {
        case .connecting, .listening: return true
        case .processing: return !hasValidatedTarget
        case .idle, .responding: return false
        }
    }

    static func shouldShowIsland(voiceState: CompanionVoiceState, presentation: HomePresentation,
                                dismissedDuringTurn: Bool) -> Bool {
        voiceState != .idle && presentation == .hidden && !dismissedDuringTurn
    }
}
