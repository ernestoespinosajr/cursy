import SwiftUI
import CoreGraphics

/// Reveal the surface, not a scaled screenshot of the text. The origin remains
/// on the top edge, immediately below the camera housing on a notched display.
struct HomeReveal: ViewModifier {
    let progress: CGFloat
    let sourceWidth: CGFloat
    var sourceHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .mask(HomeRevealMask(progress: reduceMotion ? 1 : progress,
                                 sourceWidth: sourceWidth, sourceHeight: sourceHeight))
            .opacity(reduceMotion || sourceWidth == 0 ? Double(progress) : 1)
            .allowsHitTesting(progress == 1)
    }
}

struct HomeRevealMask: Shape {
    var progress: CGFloat
    var sourceWidth: CGFloat
    var sourceHeight: CGFloat = 0
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let bounds = Self.bounds(in: rect, progress: progress, sourceWidth: sourceWidth, sourceHeight: sourceHeight)
        return Path(bounds)
    }

    static func bounds(in rect: CGRect, progress: CGFloat, sourceWidth: CGFloat, sourceHeight: CGFloat = 0) -> CGRect {
        let amount = progress.isFinite ? min(max(progress, 0), 1) : 0
        let start = sourceWidth.isFinite ? min(max(sourceWidth, 0), rect.width) : 0
        let width = start + (rect.width - start) * amount
        let initialHeight = sourceHeight.isFinite ? min(max(sourceHeight, 0), rect.height) : 0
        return CGRect(x: rect.midX - width / 2, y: rect.minY,
                      width: width, height: initialHeight + (rect.height - initialHeight) * amount)
    }
}
