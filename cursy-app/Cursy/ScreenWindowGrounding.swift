import Foundation
import CoreGraphics

struct CapturedWindowEvidence: Sendable {
    let id: String
    let windowID: CGWindowID
    let ownerPID: pid_t
    let applicationName: String
    let frame: CGRect
}

/// Correlates Accessibility and captured-window identity without interpreting
/// screen content. OpenAI remains responsible for understanding the image and
/// selecting the target coordinates.
enum ScreenWindowGrounding {
    /// Current windows are supplied in front-to-back order, from one OS snapshot.
    /// Same evaluator used by production and synthetic multi-window integration tests.
    static func resolve(target: PointingTarget, context: VisualTurnContext, currentFrame: CGRect,
                        currentWindows: [CapturedWindowEvidence], now: Date = .now) throws -> CGPoint {
        if let failure = context.validationFailure(for: target, currentFrame: currentFrame, now: now) { throw failure }
        guard let window = context.capturedWindows.first(where: { $0.id == target.windowID }) else { throw PointingRejection.unknownWindow }
        guard let current = currentWindows.first(where: { $0.windowID == window.windowID }) else { throw PointingRejection.windowMissing }
        guard current.ownerPID == window.ownerPID else { throw PointingRejection.windowOwnerChanged }
        guard framesMatch(current.frame, window.frame) else { throw PointingRejection.windowMoved }
        guard let point = context.location(for: target, currentFrame: currentFrame, now: now) else { throw PointingRejection.invalidCoordinates }
        guard context.displayFrame.contains(point) else { throw PointingRejection.pointOutsideDisplay }
        guard window.frame.contains(point) else { throw PointingRejection.pointOutsideWindow }
        guard let topmost = currentWindows.first(where: { $0.frame.contains(point) }) else { throw PointingRejection.noWindowAtPoint }
        guard topmost.windowID == window.windowID else {
            PointingDiagnostics.record(.occludedByWindow, context: context, target: target, actualWindow: topmost.windowID)
            throw PointingRejection.occludedByWindow
        }
        guard !context.nativeTargets.contains(where: { $0.id.hasSuffix("-dockapp") && $0.frame.contains(point) }) else {
            throw PointingRejection.genericPointOverDock
        }
        return point
    }

    static func framesMatch(_ first: CGRect, _ second: CGRect, tolerance: CGFloat = 1) -> Bool {
        abs(first.minX - second.minX) <= tolerance
            && abs(first.minY - second.minY) <= tolerance
            && abs(first.width - second.width) <= tolerance
            && abs(first.height - second.height) <= tolerance
    }

    static func uniqueCapturedWindow(ownerPID: pid_t, accessibilityFrame: CGRect,
                                     capturedWindows: [CapturedWindowEvidence]) -> CapturedWindowEvidence? {
        let matches = capturedWindows.filter {
            $0.ownerPID == ownerPID
                && framesMatch($0.frame, accessibilityFrame, tolerance: 24)
        }
        guard matches.count == 1 else { return nil }
        return matches[0]
    }

    static func validatedModelPoint(windowFrame: CGRect, estimatedPoint: CGPoint,
                                    displayFrame: CGRect) -> CGPoint? {
        guard estimatedPoint.x.isFinite, estimatedPoint.y.isFinite,
              windowFrame.contains(estimatedPoint),
              displayFrame.contains(estimatedPoint) else { return nil }
        return estimatedPoint
    }
}
