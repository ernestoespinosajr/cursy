import SwiftUI

/// The pointer trail tracks directly; only the separate notch hint animates.
/// Clean screenshots exclude this overlay; the model receives bound evidence.
struct SpatialTrailView: View {
    @ObservedObject var recorder: SpatialContextRecorder
    let screenFrame: CGRect
    let spanish: Bool
    let isListening: Bool
    let hintAnchor: HomeSpatialHintAnchor?
    @AppStorage("showListeningHint") private var showListeningHint = true

    var body: some View {
        ZStack(alignment: .top) {
            if recorder.displayFrame == screenFrame, !recorder.trail.isEmpty {
                Canvas { context, size in
                    var path = Path()
                    for (index, sample) in recorder.trail.enumerated() {
                        let point = CGPoint(x: sample.x * size.width, y: sample.y * size.height)
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    context.stroke(path, with: .color(CursyVoiceMotion.mint.opacity(0.8)),
                                   style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    if let last = recorder.trail.last {
                        let dot = CGRect(x: last.x * size.width - 4, y: last.y * size.height - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: dot), with: .color(CursyVoiceMotion.mint))
                    }
                }
                .transaction { $0.animation = nil }
            }
            HomeSpatialHintNotification(text: HomeSpatialHint.text(status: recorder.status,
                listening: isListening && showListeningHint, sceneCount: recorder.retainedSceneCount, spanish: spanish),
                anchor: hintAnchor?.displayFrame == screenFrame ? hintAnchor : nil)
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
