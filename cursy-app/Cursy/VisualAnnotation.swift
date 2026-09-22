import CoreGraphics
import Foundation
import SwiftUI

enum VisualAnnotationStyle: String, Codable, CaseIterable, Identifiable {
    case cursor, circle, arrow, rectangle, label
    var id: String { rawValue }

    /// Presentation belongs to the agent, never the retired visualAnnotationStyle preference.
    /// Older/automatic decisions and legacy fallback retain the safe cursor presentation.
    static func resolve(agentChoice: Self?) -> Self {
        agentChoice ?? .cursor
    }

    func title(spanish: Bool) -> String {
        switch self {
        case .cursor: return "Cursor"
        case .circle: return spanish ? "Círculo" : "Circle"
        case .arrow: return spanish ? "Flecha" : "Arrow"
        case .rectangle: return spanish ? "Rectángulo" : "Rectangle"
        case .label: return spanish ? "Etiqueta" : "Label"
        }
    }
}

/// Presentation only: constructed AFTER localization and freshness validation.
/// A region is supplied only when native geometry has been verified in full.
struct VisualAnnotation: Equatable {
    let id = UUID()
    let style: VisualAnnotationStyle
    let point: CGPoint
    let displayFrame: CGRect
    let label: String
    let region: CGRect?
    let routeStart: CGPoint?

    init?(style: VisualAnnotationStyle, point: CGPoint, displayFrame: CGRect, label: String,
          region: CGRect? = nil, routeStart: CGPoint? = nil) {
        let values = [point.x, point.y, displayFrame.minX, displayFrame.minY,
                      displayFrame.width, displayFrame.height]
        guard values.allSatisfy(\.isFinite), displayFrame.width >= 100,
              displayFrame.height >= 100, point.x >= displayFrame.minX,
              point.x < displayFrame.maxX, point.y > displayFrame.minY,
              point.y <= displayFrame.maxY, !label.isEmpty, label.count <= 120 else { return nil }
        if let region {
            guard [region.minX, region.minY, region.width, region.height].allSatisfy(\.isFinite),
                  region.width > 0, region.height > 0, displayFrame.contains(region),
                  region.contains(point) else { return nil }
        }
        if let routeStart {
            guard style == .arrow, routeStart.x.isFinite, routeStart.y.isFinite,
                  displayFrame.contains(routeStart), routeStart != point else { return nil }
        }
        // A point does not establish a paragraph's extent. Keep it a precise cue.
        self.style = (style == .rectangle || style == .circle) && region == nil ? .cursor : style
        self.point = point
        self.displayFrame = displayFrame
        self.label = label
        self.region = region
        self.routeStart = routeStart
    }

    var localPoint: CGPoint {
        ScreenCoordinateSpace.overlayPoint(globalPoint: point, displayFrame: displayFrame)
    }

    var arrowTail: CGPoint {
        if let routeStart {
            return ScreenCoordinateSpace.overlayPoint(globalPoint: routeStart, displayFrame: displayFrame)
        }
        let point = localPoint
        return CGPoint(x: point.x + (point.x > displayFrame.width / 2 ? -48 : 48),
                       y: point.y + (point.y > displayFrame.height / 2 ? -44 : 44))
    }

    var localRegion: CGRect? {
        region.map { CGRect(x: $0.minX - displayFrame.minX, y: displayFrame.maxY - $0.maxY,
                            width: $0.width, height: $0.height) }
    }

    var focusBounds: CGRect {
        let bounds = localRegion ?? CGRect(origin: localPoint, size: .zero)
        return bounds.insetBy(dx: -6, dy: -6)
            .intersection(CGRect(origin: .zero, size: displayFrame.size))
    }

    var usesEllipse: Bool {
        guard style == .circle else { return false }
        return CGRect(origin: .zero, size: displayFrame.size).contains(ellipseBounds)
    }

    var ellipseBounds: CGRect {
        let bounds = focusBounds
        return CGRect(x: bounds.midX - bounds.width / sqrt(2), y: bounds.midY - bounds.height / sqrt(2),
                      width: bounds.width * sqrt(2), height: bounds.height * sqrt(2))
    }

    func labelCenter(size: CGSize) -> CGPoint {
        let point = localPoint
        let bounds = usesEllipse ? ellipseBounds
            : (style == .rectangle || style == .circle ? focusBounds
                : localRegion ?? CGRect(origin: point, size: .zero))
        let gap: CGFloat = style == .label ? 12 : 18
        let preferredY = bounds.maxY + gap + size.height / 2
        let aboveY = bounds.minY - gap - size.height / 2
        return CGPoint(
            x: min(max(point.x, size.width / 2 + 6), displayFrame.width - size.width / 2 - 6),
            y: min(max(aboveY - size.height / 2 >= 6 ? aboveY : preferredY,
                       size.height / 2 + 6), displayFrame.height - size.height / 2 - 6))
    }
}
