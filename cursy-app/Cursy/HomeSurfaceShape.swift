import SwiftUI
import CoreGraphics

/// One opaque silhouette overlaps the physical housing from the screen edge;
/// conversation controls start below the camera and concave shoulders.
struct HomeSurfaceShape: Shape {
    var notchWidth: CGFloat
    var notchHeight: CGFloat = 0
    static let neckHeight: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        guard notchWidth > 0, rect.width > notchWidth + 80, rect.height > 60 else {
            return Path(roundedRect: rect, cornerRadius: 22)
        }
        let top = rect.minY
        let shoulder = top + notchHeight + Self.neckHeight
        let leftNeck = rect.midX - notchWidth / 2 - 20
        let rightNeck = rect.midX + notchWidth / 2 + 20
        let radius: CGFloat = 22
        var path = Path()
        path.move(to: CGPoint(x: leftNeck, y: top))
        path.addLine(to: CGPoint(x: rightNeck, y: top))
        path.addLine(to: CGPoint(x: rightNeck, y: top + notchHeight))
        path.addQuadCurve(to: CGPoint(x: rightNeck + 14, y: shoulder),
                          control: CGPoint(x: rightNeck, y: shoulder))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: shoulder + radius),
                          control: CGPoint(x: rect.maxX, y: shoulder))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: shoulder + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: shoulder),
                          control: CGPoint(x: rect.minX, y: shoulder))
        path.addLine(to: CGPoint(x: leftNeck - 14, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: leftNeck, y: top + notchHeight),
                          control: CGPoint(x: leftNeck, y: shoulder))
        path.closeSubpath()
        return path
    }
}

struct HomeIslandShape: Shape {
    func path(in rect: CGRect) -> Path {
        let shoulder: CGFloat = 12
        let radius: CGFloat = 18
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder),
                          control: CGPoint(x: rect.maxX - shoulder, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder - radius, y: rect.maxY),
                          control: CGPoint(x: rect.maxX - shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + shoulder + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - radius),
                          control: CGPoint(x: rect.minX + shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                          control: CGPoint(x: rect.minX + shoulder, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
