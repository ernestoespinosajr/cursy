import Foundation
import CoreGraphics
import SwiftUI

/// Presentation-only placement in the existing click-through overlay. Never
/// extends Home's input region or places text in the physical camera rectangle.
struct HomeSpatialHintAnchor: Equatable {
    let displayFrame: CGRect
    let slot: CGRect // Overlay coordinates, top-left origin.
    let gap: CGFloat

    static func make(presentation: HomePresentation, panelFrame: CGRect,
                     displayFrame: CGRect, cameraFrame: CGRect?) -> Self? {
        guard presentation != .hidden else { return nil }
        let expandedCamera = presentation == .expanded ? cameraFrame : nil
        var top = displayFrame.maxY - (expandedCamera?.minY ?? panelFrame.minY)
        if expandedCamera == nil, top + 64 > displayFrame.height {
            let abovePanel = displayFrame.maxY - panelFrame.maxY - 64
            if abovePanel >= (cameraFrame?.height ?? 0) { top = abovePanel }
        }
        let width = min(580, max(1, displayFrame.width - 24))
        let center = expandedCamera?.midX ?? panelFrame.midX
        let left = min(max(12, center - displayFrame.minX - width / 2),
                       max(12, displayFrame.width - width - 12))
        return Self(displayFrame: displayFrame,
                    slot: CGRect(x: left, y: min(max(0, top), max(0, displayFrame.height - 64)),
                                 width: width, height: 64),
                    gap: expandedCamera == nil ? 10 : 7)
    }
}

enum HomeSpatialHint {
    static let duration: TimeInterval = 0.4
    static let reducedDuration: TimeInterval = 0.15

    static func text(status: SpatialContextRecorder.Status, listening: Bool,
                     sceneCount: Int, spanish: Bool) -> String? {
        guard listening else { return nil }
        switch status {
        case .recording:
            if sceneCount > 0 {
                return spanish ? "\(sceneCount) escenas anteriores · Sigue señalando · Esc cancela"
                    : "\(sceneCount) earlier scenes · Keep pointing · Esc cancels"
            }
            return spanish ? "Señala mientras hablas · Esc cancela" : "Point while speaking · Esc cancels"
        case .limited:
            return spanish ? "Límite de gesto alcanzado · La voz continúa" : "Gesture limit reached · Voice continues"
        default: return nil
        }
    }
}

struct HomeSpatialHintCard: View {
    let text: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Label(text, systemImage: "cursorarrow.motionlines")
            .font(.system(size: 11, weight: .medium))
            .lineLimit(2).multilineTextAlignment(.center)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(.black.opacity(reduceTransparency || contrast == .increased ? 1 : 0.9),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

/// Keeps the outgoing content mounted so the same 400ms path works in reverse.
/// State changes retarget SwiftUI's current presentation; no delayed callbacks.
struct HomeSpatialHintNotification: View {
    let text: String?
    let anchor: HomeSpatialHintAnchor?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var retainedText = ""
    @State private var retainedAnchor: HomeSpatialHintAnchor?
    @State private var visible = false

    var body: some View {
        let slot = retainedAnchor?.slot ?? .zero
        HomeSpatialHintCard(text: retainedText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, retainedAnchor?.gap ?? 10)
            .offset(y: reduceMotion || visible ? 0 : -slot.height)
            .opacity(visible ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: HomeSpatialHint.reducedDuration)
                : .timingCurve(0.25, 0.1, 0.25, 1, duration: HomeSpatialHint.duration), value: visible)
            .frame(width: slot.width, height: slot.height, alignment: .top)
            .clipped()
            .position(x: slot.midX, y: slot.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(!visible)
            .onAppear { update() }
            .onChange(of: text) { update() }
            .onChange(of: anchor) { update() }
    }

    private func update() {
        if let text { retainedText = text }
        if let anchor { retainedAnchor = anchor }
        visible = text != nil && anchor != nil
    }
}
