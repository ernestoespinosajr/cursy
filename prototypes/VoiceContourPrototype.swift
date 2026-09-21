import AppKit
import SwiftUI

// Isolated visual prototype. No microphone, network or production cursor changes.
struct FluidVoiceContour: Shape {
    var amplitude: Double
    var time: Double
    var delay: Double = 0
    static let sampleCount = 96

    func point(at angle: Double) -> CGPoint {
        let phase = time - delay
        let energy = amplitude.isFinite ? min(max(amplitude, 0), 1) : 0
        // Independent phase speeds: the outline changes locally, not by rigid rotation.
        let wave = 0.48 * sin(3 * angle + 1.9 * phase)
            + 0.32 * sin(5 * angle - 2.6 * phase + 0.8)
            + 0.20 * sin(7 * angle + 1.1 * phase + 1.7)
        let radius = 0.41 * (1 + 0.24 * energy * wave)
        return CGPoint(x: 0.5 + radius * cos(angle), y: 0.5 + radius * sin(angle))
    }

    func path(in rect: CGRect) -> Path {
        let points = (0..<Self.sampleCount).map { index in
            let point = point(at: Double(index) * 2 * .pi / Double(Self.sampleCount))
            return CGPoint(x: rect.minX + point.x * rect.width,
                           y: rect.minY + point.y * rect.height)
        }
        var path = Path()
        path.move(to: points[0])
        // Periodic Catmull–Rom -> cubic Bézier, including the last/first tangent.
        for index in points.indices {
            let before = points[(index + points.count - 1) % points.count]
            let start = points[index]
            let end = points[(index + 1) % points.count]
            let after = points[(index + 2) % points.count]
            path.addCurve(to: end,
                control1: CGPoint(x: start.x + (end.x - before.x) / 6,
                                  y: start.y + (end.y - before.y) / 6),
                control2: CGPoint(x: end.x - (after.x - start.x) / 6,
                                  y: end.y - (after.y - start.y) / 6))
        }
        path.closeSubpath()
        return path
    }
}

private enum DemoSignal: String, CaseIterable, Identifiable {
    case sustained = "Voz sostenida"
    case phrase = "Frase con pausas"
    case silence = "Silencio"
    var id: String { rawValue }

    func level(at time: Double, strength: Double) -> Double {
        switch self {
        case .sustained: return strength
        case .silence: return 0
        case .phrase:
            let cycle = time.truncatingRemainder(dividingBy: 5)
            guard cycle < 3 else { return 0 }
            return strength * max(0, sin(cycle * .pi / 3))
                * (0.30 + 0.70 * pow(abs(sin(cycle * 7)), 2))
        }
    }
}

private struct DemoRing {
    let born: Double
    let energy: Double
}

private enum DemoPalette: String, CaseIterable, Identifiable {
    case blue = "Azul hielo", lavender = "Lavanda", mint = "Menta"
    case rose = "Rosa", champagne = "Champán", copper = "Cobre"
    case silver = "Plata", graphite = "Grafito"
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: Color(red: 0.30, green: 0.65, blue: 0.92)
        case .lavender: Color(red: 0.64, green: 0.51, blue: 0.84)
        case .mint: Color(red: 0.30, green: 0.72, blue: 0.60)
        case .rose: Color(red: 0.84, green: 0.47, blue: 0.62)
        case .champagne: Color(red: 0.76, green: 0.64, blue: 0.40)
        case .copper: Color(red: 0.76, green: 0.43, blue: 0.29)
        case .silver: Color(red: 0.62, green: 0.67, blue: 0.73)
        case .graphite: Color(red: 0.32, green: 0.37, blue: 0.44)
        }
    }
}

private enum DemoFinish: String, CaseIterable, Identifiable {
    case soft = "Suave", metallic = "Metálico"
    var id: String { rawValue }
}

struct VoiceContourPrototype: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var signal = DemoSignal.sustained
    @State private var strength = 0.8
    @State private var slowMotion = false
    @State private var reduceMotion = false
    @State private var glass = true
    @State private var darkBackground = false
    @State private var palette = DemoPalette.mint
    @State private var finish = DemoFinish.soft
    @State private var time = 0.0
    @State private var lastTick: Date?
    @State private var energy = 0.0
    @State private var rings: [DemoRing] = []
    @State private var nextRingTime = 0.0

    private var motionDisabled: Bool { reduceMotion || systemReduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Contorno de voz · prototipo aislado").font(.title2.bold())
            Text("Audio simulado. No usa micrófono ni modifica Cursy.").foregroundStyle(.secondary)
            Picker("Señal", selection: $signal) {
                ForEach(DemoSignal.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            HStack(spacing: 18) {
                Circle().fill(palette.color).frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Picker("Color", selection: $palette) {
                    ForEach(DemoPalette.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Acabado", selection: $finish) {
                    ForEach(DemoFinish.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
            }
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                HStack(spacing: 24) {
                    specimen(scale: 1, label: "Tamaño real · 16 pt")
                    specimen(scale: 4, label: "Ampliado · ×4")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(darkBackground ? Color.black.opacity(0.88) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onChange(of: timeline.date) { _, date in tick(date) }
            }
            HStack {
                Text("Intensidad")
                Slider(value: $strength, in: 0...1)
                Text(strength, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit().frame(width: 50)
            }
            HStack {
                Toggle("Cámara lenta ×¼", isOn: $slowMotion)
                Toggle("Reducir movimiento", isOn: $reduceMotion)
            }
            HStack {
                Toggle("Liquid Glass", isOn: $glass)
                Toggle("Fondo oscuro", isOn: $darkBackground)
            }
            Text("Comprueba el borde con voz sostenida. En silencio no nacen ondas y el núcleo recupera el círculo.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 650)
        .onDisappear { lastTick = nil }
    }

    private func specimen(scale: CGFloat, label: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Canvas { context, size in
                    guard !motionDisabled else { return }
                    for ring in rings {
                        let age = time - ring.born
                        let progress = min(max(age / 1.1, 0), 1)
                        let diameter = 21 + progress * 27
                        let rect = CGRect(x: size.width / 2 - diameter / 2,
                                          y: size.height / 2 - diameter / 2,
                                          width: diameter, height: diameter)
                        let contour = FluidVoiceContour(amplitude: ring.energy, time: time,
                                                        delay: age * 0.45)
                        var ringContext = context
                        ringContext.opacity = sin(progress * .pi) * 0.75
                        ringContext.stroke(contour.path(in: rect),
                            with: .linearGradient(Gradient(colors: surfaceColors),
                                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)), lineWidth: 0.8)
                    }
                }
                .frame(width: 60, height: 60)
                core.frame(width: 16, height: 16)
            }
            .scaleEffect(scale)
            .frame(width: 260, height: 245)
            Text(label).font(.caption).foregroundStyle(darkBackground ? .white : .black)
        }
    }

    @ViewBuilder private var core: some View {
        let contour = FluidVoiceContour(amplitude: motionDisabled ? 0 : energy, time: time)
        if #available(macOS 26, *), glass, !reduceTransparency {
            Color.clear.glassEffect(.clear.tint(palette.color.opacity(0.40)), in: contour)
                .overlay {
                    contour.fill(surfaceGradient)
                        .opacity(finish == .metallic ? 0.55 : 0.16)
                }
        } else {
            contour.fill(surfaceGradient)
        }
    }

    // Static light bands suggest polished metal without adding motion or another silhouette.
    private var surfaceColors: [Color] {
        if finish == .metallic {
            return [palette.color, palette.color.opacity(0.85),
                    Color(white: 0.96), palette.color, palette.color.opacity(0.65)]
        }
        return [palette.color.opacity(0.65), palette.color]
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(colors: surfaceColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func tick(_ date: Date) {
        let elapsed = min(max(lastTick.map { date.timeIntervalSince($0) } ?? 1.0 / 60, 0), 0.05)
            * (slowMotion ? 0.25 : 1)
        lastTick = date
        time += elapsed
        let target = signal.level(at: time, strength: strength)
        // A visual envelope only. This prototype never touches audio samples.
        let smoothingTime = target > energy ? 0.08 : 0.18
        energy += (target - energy) * (1 - exp(-elapsed / smoothingTime))
        rings.removeAll { time - $0.born >= 1.1 }
        if motionDisabled { rings.removeAll(); return }
        if target > 0.04, energy > 0.04, time >= nextRingTime, rings.count < 3 {
            rings.append(DemoRing(born: time, energy: max(energy, 0.3)))
            nextRingTime = time + 0.28 + 0.20 * (1 - energy)
        }
    }
}

#if VOICE_CONTOUR_DEMO
@main struct VoiceContourDemo {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 590),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Cursy · Prototipo de ondas (sin micrófono)"
        window.contentView = NSHostingView(rootView: VoiceContourPrototype())
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
#endif

#if DEBUG
#Preview("Prototipo polar · sin audio real") { VoiceContourPrototype() }
#endif
