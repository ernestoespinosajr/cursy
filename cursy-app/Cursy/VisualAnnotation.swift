import CoreGraphics
import Foundation
import SwiftUI

enum VisualAnnotationStyle: String, Codable, CaseIterable, Identifiable {
    case cursor, circle, arrow, rectangle, label
    var id: String { rawValue }

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
/// Focus marks are fixed-size, never an invented bounding box for an element.
struct VisualAnnotation: Equatable {
    let style: VisualAnnotationStyle
    let point: CGPoint
    let displayFrame: CGRect
    let label: String

    init?(style: VisualAnnotationStyle, point: CGPoint, displayFrame: CGRect, label: String) {
        let values = [point.x, point.y, displayFrame.minX, displayFrame.minY,
                      displayFrame.width, displayFrame.height]
        guard values.allSatisfy(\.isFinite), displayFrame.width >= 100,
              displayFrame.height >= 100, point.x >= displayFrame.minX,
              point.x < displayFrame.maxX, point.y > displayFrame.minY,
              point.y <= displayFrame.maxY, !label.isEmpty, label.count <= 120 else { return nil }
        self.style = style
        self.point = point
        self.displayFrame = displayFrame
        self.label = label
    }

    var localPoint: CGPoint {
        ScreenCoordinateSpace.overlayPoint(globalPoint: point, displayFrame: displayFrame)
    }

    var arrowTail: CGPoint {
        let point = localPoint
        return CGPoint(x: point.x + (point.x > displayFrame.width / 2 ? -48 : 48),
                       y: point.y + (point.y > displayFrame.height / 2 ? -44 : 44))
    }

    func labelCenter(size: CGSize) -> CGPoint {
        let point = localPoint
        let preferredY = point.y + 42 + size.height / 2
        let aboveY = point.y - 42 - size.height / 2
        return CGPoint(
            x: min(max(point.x, size.width / 2 + 6), displayFrame.width - size.width / 2 - 6),
            y: min(max(preferredY + size.height / 2 + 6 <= displayFrame.height ? preferredY : aboveY,
                       size.height / 2 + 6), displayFrame.height - size.height / 2 - 6))
    }
}

struct VisualAnnotationView: View {
    let annotation: VisualAnnotation
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var labelSize: CGSize {
        let maximumWidth = min(240, annotation.displayFrame.width - 16)
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let bounds = (annotation.label as NSString).boundingRect(
            with: CGSize(width: maximumWidth - 16, height: 38),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font])
        return CGSize(width: min(maximumWidth, ceil(bounds.width) + 16),
                      height: min(54, ceil(bounds.height) + 16))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                let point = annotation.localPoint
                var path = Path()
                switch annotation.style {
                case .circle:
                    path.addEllipse(in: CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50))
                case .rectangle:
                    path.addRoundedRect(in: CGRect(x: point.x - 36, y: point.y - 23, width: 72, height: 46),
                                        cornerSize: CGSize(width: 8, height: 8))
                case .arrow:
                    let tail = annotation.arrowTail
                    let angle = atan2(tail.y - point.y, tail.x - point.x)
                    path.move(to: tail)
                    path.addLine(to: point)
                    for offset in [-0.5, 0.5] {
                        path.move(to: CGPoint(x: point.x + 12 * cos(angle + offset),
                                             y: point.y + 12 * sin(angle + offset)))
                        path.addLine(to: point)
                    }
                case .label:
                    path.addEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
                case .cursor: break
                }
                // Dual stroke stays readable on both light and dark application content.
                context.stroke(path, with: .color(.black.opacity(0.85)),
                               style: StrokeStyle(lineWidth: contrast == .increased ? 6 : 5, lineCap: .round))
                context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            Text(annotation.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(8)
                .frame(width: labelSize.width, height: labelSize.height)
                .background {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor))
                    } else {
                        RoundedRectangle(cornerRadius: 10).fill(.regularMaterial)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.35), lineWidth: 1))
                .position(annotation.labelCenter(size: labelSize))
        }
        .frame(width: annotation.displayFrame.width, height: annotation.displayFrame.height)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(annotation.label)
    }
}
