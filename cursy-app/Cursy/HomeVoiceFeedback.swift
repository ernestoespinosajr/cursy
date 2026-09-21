import SwiftUI

/// Presentation only: consumes the existing meter, never owns a microphone.
struct HomeVoiceFeedback {
    let isListening: Bool
    let level: CGFloat

    init(activity: HomeActivity, audioPowerLevel: CGFloat) {
        isListening = activity == .listening
        // Match the accepted cursor's noise floor; the meter already has gain.
        level = isListening && audioPowerLevel.isFinite
            ? min(max((audioPowerLevel - 0.025) / 0.975, 0), 1) : 0
    }

    // A volume silhouette, not frequency analysis or a simulated recording.
    static let barWeights: [CGFloat] = [0.35, 0.7, 1, 0.7, 0.35]

    func barScale(weight: CGFloat, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 0.25 + 0.65 * weight : 0.15 + 0.85 * weight * level
    }

    var glowOpacity: Double { isListening ? 0.16 + 0.34 * Double(level) : 0 }
}

struct HomeVoiceWaveform: View {
    let feedback: HomeVoiceFeedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HomeVoiceFeedback.barWeights.indices, id: \.self) { index in
                Capsule()
                    .fill(.primary)
                    .frame(width: 3, height: 20)
                    .scaleEffect(x: 1, y: feedback.barScale(
                        weight: HomeVoiceFeedback.barWeights[index], reduceMotion: reduceMotion))
            }
        }
        .frame(width: 23, height: 20)
        .opacity(0.45 + 0.4 * Double(feedback.level))
        .animation(.timingCurve(0.23, 1, 0.32, 1, duration: DS.Animation.fast), value: feedback.level)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct HomeVoiceGlow: View {
    let feedback: HomeVoiceFeedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                glow(.mint, width: geometry.size.width * 0.65)
                    .offset(x: -geometry.size.width * 0.23)
                glow(.blue, width: geometry.size.width * 0.65)
                glow(.purple.opacity(0.65), width: geometry.size.width * 0.55)
                    .offset(x: geometry.size.width * 0.28)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .scaleEffect(x: 1, y: reduceMotion ? 1 : 0.8 + 0.2 * feedback.level, anchor: .bottom)
            .mask(LinearGradient(colors: [.clear, .black.opacity(0.25), .black],
                                 startPoint: .top, endPoint: .bottom))
        }
        .opacity(feedback.glowOpacity)
        .animation(.timingCurve(0.23, 1, 0.32, 1, duration: DS.Animation.fast), value: feedback.level)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glow(_ color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(EllipticalGradient(colors: [color, color.opacity(0.45), .clear],
                                    center: .bottom, endRadiusFraction: 0.5))
            .frame(width: width, height: 80)
    }
}
