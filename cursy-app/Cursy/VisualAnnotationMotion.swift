import CoreGraphics
import Foundation
import SwiftUI

/// One monotonic clock drives both the ink and the companion tip. No model state.
enum VisualAnnotationMotion {
    static let playbackRate = 1.6
    static let approach = 0.7 / playbackRate
    static let press = 0.18 / playbackRate
    static let draw = 1.6 / playbackRate
    static let release = 0.18 / playbackRate
    static let departure = 0.65 / playbackRate
    static let caption = 0.45 / playbackRate
    static let drawingStart = approach + press
    static let drawingEnd = drawingStart + draw
    static let total = drawingEnd + release + departure

    static func progress(_ elapsed: Double, start: Double, duration: Double) -> Double {
        min(1, max(0, (elapsed - start) / duration))
    }

    static func curve(from: CGPoint, to: CGPoint, progress: Double) -> CGPoint {
        let eased = progress * progress * (3 - 2 * progress)
        let control = CGPoint(x: (from.x + to.x) / 2,
                              y: min(from.y, to.y) - min(60, hypot(to.x - from.x, to.y - from.y) * 0.18))
        let remaining = 1 - eased
        return CGPoint(x: remaining * remaining * from.x + 2 * remaining * eased * control.x + eased * eased * to.x,
                       y: remaining * remaining * from.y + 2 * remaining * eased * control.y + eased * eased * to.y)
    }

    static func typingDuration(_ text: String) -> Double { min(1, max(0.3, Double(text.count) * 0.024)) }

    static func visibleText(_ text: String, elapsed: Double, reducedMotion: Bool) -> String {
        if reducedMotion { return text }
        let fraction = progress(elapsed, start: caption, duration: typingDuration(text))
        return String(text.prefix(Int(ceil(Double(text.count) * fraction))))
    }

    static func inkProgress(_ elapsed: Double, reducedMotion: Bool) -> Double {
        reducedMotion ? 1 : progress(elapsed, start: drawingStart, duration: draw)
    }

    static func captionProgress(_ elapsed: Double, style: VisualAnnotationStyle, reducedMotion: Bool) -> Double {
        progress(elapsed, start: reducedMotion || style == .label ? 0 : drawingEnd,
                 duration: reducedMotion ? 0.15 : caption)
    }

    /// Same center-to-tip offset as Cursy's 16pt, -35° resting-arrow geometry.
    static let tipOffset = CGPoint(x: -4.22, y: -6.03)
    static func cursorCenter(tip: CGPoint) -> CGPoint {
        CGPoint(x: tip.x - tipOffset.x, y: tip.y - tipOffset.y)
    }
}

struct AnnotationDrawing {
    let annotation: VisualAnnotation

    // Polyline arc-length sampling keeps arrow/ellipse ink and tip exactly paired.
    var trace: [CGPoint] {
        if annotation.usesEllipse {
            let bounds = annotation.ellipseBounds
            return (0...160).map { index in
                let angle = Double.pi + Double(index) / 160 * 2 * Double.pi
                return CGPoint(x: bounds.midX + bounds.width / 2 * cos(angle),
                               y: bounds.midY + bounds.height / 2 * sin(angle))
            }
        }
        guard annotation.style == .arrow else { return [] }
        let start = annotation.arrowTail
        let end = annotation.localPoint
        let angle = atan2(start.y - end.y, start.x - end.x)
        let first = CGPoint(x: end.x + 11 * cos(angle - 0.5), y: end.y + 11 * sin(angle - 0.5))
        let second = CGPoint(x: end.x + 11 * cos(angle + 0.5), y: end.y + 11 * sin(angle + 0.5))
        return [start, end, first, end, second]
    }

    func tracedPoints(progress: Double) -> [CGPoint] {
        let points = trace
        guard let first = points.first else { return [] }
        let lengths = zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        var remaining = lengths.reduce(0, +) * min(1, max(0, progress))
        var result = [first]
        for index in lengths.indices {
            let start = points[index], end = points[index + 1]
            let fraction = lengths[index] > 0 ? min(1, remaining / lengths[index]) : 1
            result.append(CGPoint(x: start.x + (end.x - start.x) * fraction,
                                  y: start.y + (end.y - start.y) * fraction))
            remaining -= lengths[index]
            if remaining <= 0 { break }
        }
        return result
    }

    func tip(progress: Double) -> CGPoint {
        if let last = tracedPoints(progress: progress).last { return last }
        let bounds = annotation.focusBounds
        return CGPoint(x: bounds.minX + bounds.width * progress,
                       y: bounds.minY + bounds.height * progress)
    }

    func path(progress: Double) -> Path {
        guard annotation.style != .label, annotation.style != .cursor, progress > 0 else { return Path() }
        let points = tracedPoints(progress: progress)
        if let first = points.first {
            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            return path
        }
        let bounds = annotation.focusBounds
        let growing = CGRect(x: bounds.minX, y: bounds.minY,
                             width: bounds.width * progress, height: bounds.height * progress)
        return Path(roundedRect: growing, cornerRadius: min(9, growing.width / 2, growing.height / 2))
    }
}
