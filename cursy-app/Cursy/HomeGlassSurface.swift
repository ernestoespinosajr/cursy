import AppKit
import SwiftUI

/// Material selection is explicit so accessibility never depends on whether
/// the current OS happens to make its glass more or less transparent.
enum HomeGlassMaterial: Equatable {
    case opaque, liquidGlass, visualEffect

    static func resolve(reduceTransparency: Bool, increasedContrast: Bool,
                        supportsLiquidGlass: Bool) -> Self {
        if reduceTransparency || increasedContrast { return .opaque }
        return supportsLiquidGlass ? .liquidGlass : .visualEffect
    }
}

struct HomeGlassSurface: View {
    let notchWidth: CGFloat
    var notchHeight: CGFloat = 0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: HomeSurfaceShape { HomeSurfaceShape(notchWidth: notchWidth, notchHeight: notchHeight) }

    private var material: HomeGlassMaterial {
        let supportsGlass: Bool
        if #available(macOS 26.0, *) { supportsGlass = true } else { supportsGlass = false }
        return .resolve(reduceTransparency: reduceTransparency,
            increasedContrast: contrast == .increased, supportsLiquidGlass: supportsGlass)
    }

    var body: some View {
        ZStack {
            if material == .opaque {
                Color.black
            } else {
                if #available(macOS 26.0, *), material == .liquidGlass {
                    // Keep the optical surface convex. The custom camera neck
                    // is an opaque tint/mask, not a concave refractive lens.
                    Color.clear.glassEffect(.clear, in: RoundedRectangle(cornerRadius: 22))
                        .padding(.top, notchWidth > 0 ? notchHeight + HomeSurfaceShape.neckHeight : 0)
                } else {
                    HomeBackdropMaterial()
                }
                // Black joins the camera housing; the lower half reveals the
                // real material/backdrop, rather than fading out the whole UI.
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.28),
                    .init(color: .black.opacity(0.78), location: 0.40),
                    .init(color: .black.opacity(0.42), location: 0.68),
                    .init(color: .black.opacity(0.18), location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            if notchWidth > 0 {
                VStack(spacing: 0) {
                    Color.black.frame(height: notchHeight + HomeSurfaceShape.neckHeight + 68)
                    Spacer(minLength: 0)
                }
            }
        }
        .clipShape(shape)
        .overlay {
            // A quiet lower rim, not a travelling flare or a bright notch seam.
            shape.stroke(LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.45),
                .init(color: .white.opacity(contrast == .increased ? 0.65 : 0.28), location: 1)
            ], startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Public AppKit fallback for macOS 14/15. No screen capture, private blur APIs,
/// raster snapshots or sampling timers are needed to follow the desktop.
private struct HomeBackdropMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
