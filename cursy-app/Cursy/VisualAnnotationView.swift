import AppKit
import SwiftUI

struct VisualAnnotationView: View {
    let annotation: VisualAnnotation
    let elapsed: Double
    let pointer: CGPoint
    @AppStorage(CursyCursorTint.preferenceKey) private var tintValue = CursyCursorTint.mint.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var tint: Color { CursyCursorTint.resolve(tintValue).color }
    private var labelSize: CGSize {
        let maximumWidth = min(300, annotation.displayFrame.width - 16)
        let bounds = (annotation.label as NSString).boundingRect(
            with: CGSize(width: maximumWidth - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)])
        return CGSize(width: min(maximumWidth, ceil(bounds.width) + 24), height: ceil(bounds.height) + 18)
    }

    var body: some View {
        let ink = VisualAnnotationMotion.inkProgress(elapsed, reducedMotion: reduceMotion)
        let reveal = VisualAnnotationMotion.captionProgress(elapsed, style: annotation.style, reducedMotion: reduceMotion)
        let path = AnnotationDrawing(annotation: annotation).path(progress: ink)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                if annotation.style == .rectangle || annotation.style == .circle, ink >= 1 {
                    context.fill(path, with: .color(tint.opacity(reduceTransparency ? 0 : 0.065)))
                }
                context.addFilter(.shadow(color: tint.opacity(reduceTransparency ? 0 : 0.35), radius: 5))
                context.stroke(path, with: .color(.black.opacity(0.75)),
                               style: StrokeStyle(lineWidth: contrast == .increased ? 5 : 3.8, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                if !reduceMotion, !reduceTransparency, contrast != .increased {
                    context.stroke(path, with: .radialGradient(Gradient(colors: [.white.opacity(0.85), .white.opacity(0.06)]),
                        center: pointer, startRadius: 0, endRadius: 150), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                }
            }
            .opacity(reduceMotion ? reveal : 1)
            if captionFits {
                caption
                    .opacity(reveal)
                    .offset(y: reduceMotion ? 0 : 6 * (1 - reveal))
                    .position(annotation.labelCenter(size: labelSize))
            }
        }
        .frame(width: annotation.displayFrame.width, height: annotation.displayFrame.height)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(annotation.label)
    }

    private var captionFits: Bool {
        let center = annotation.labelCenter(size: labelSize)
        let bounds = CGRect(x: center.x - labelSize.width / 2, y: center.y - labelSize.height / 2,
                            width: labelSize.width, height: labelSize.height)
        guard CGRect(origin: .zero, size: annotation.displayFrame.size).contains(bounds) else { return false }
        if let region = annotation.localRegion { return !bounds.intersects(region) }
        return !bounds.contains(annotation.localPoint)
    }

    private var caption: some View {
        let visible = annotation.style == .label
            ? VisualAnnotationMotion.visibleText(annotation.label, elapsed: elapsed, reducedMotion: reduceMotion)
            : annotation.label
        return ZStack(alignment: .topLeading) {
            Text(annotation.label).hidden()
            Text(visible)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: labelSize.width, height: labelSize.height, alignment: .topLeading)
        .background { captionSurface }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(contrast == .increased ? 0.7 : 0.14), lineWidth: 1))
        .shadow(color: .black.opacity(reduceTransparency ? 0 : 0.22), radius: 8, y: 3)
    }

    @ViewBuilder private var captionSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        if reduceTransparency || contrast == .increased {
            shape.fill(.black)
        } else if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.clear, in: shape)
                // Keep contrast independent of the glass compositor/backdrop.
                .overlay(shape.fill(.black.opacity(0.88)))
        } else {
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(.black.opacity(0.82)))
        }
    }
}
