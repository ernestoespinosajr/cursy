//
//  CursyCursorShape.swift
//  Cursy
//
//  Morphable rounded cursor geometry, movement-state reduction, and the native
//  glass rendering surface used by the screen overlay.
//

import SwiftUI

enum CursyCursorPresentationState: Equatable {
    case restingArrow
    case movingComet(CGFloat)
    case travelingComet
    case pointingArrow

    var morphProgress: CGFloat {
        switch self {
        case .restingArrow, .pointingArrow: return 0
        case .movingComet(let intensity): return min(max(intensity, 0), 1)
        case .travelingComet: return 1
        }
    }

    var isMovingShape: Bool { morphProgress > 0 }
}

enum CursyCursorMotionOverride {
    case none
    case traveling
    case pointing
}

struct CursyCursorMotionReducer {
    static let movementDistanceEpsilon: CGFloat = 0.15
    static let movementVelocityThreshold: CGFloat = 24
    static let idleDelay: TimeInterval = 0.16
    static let velocitySmoothingFactor: CGFloat = 0.28
    static let movementConfirmationWindow: TimeInterval = 0.10

    // Three stable deformation levels communicate speed without making the
    // shape chase noisy velocity samples on every 60 Hz tracking tick.
    static let slowMotionIntensity: CGFloat = 0.58
    static let mediumMotionIntensity: CGFloat = 0.78
    static let fastMotionIntensity: CGFloat = 1.0
    static let mediumVelocityThreshold: CGFloat = 260
    static let fastVelocityThreshold: CGFloat = 720

    private(set) var previousPosition: CGPoint?
    private(set) var previousTimestamp: TimeInterval?
    private(set) var lastMeaningfulMovementTimestamp: TimeInterval?
    private(set) var isMoving = false
    private(set) var movementAngleDegrees = -35.0
    private(set) var motionIntensity: CGFloat = 0
    private(set) var smoothedVelocity: CGFloat = 0
    private(set) var movementCandidateTimestamp: TimeInterval?

    var restingAngleDegrees: Double {
        Self.nearestEquivalentAngle(-35, relativeTo: movementAngleDegrees)
    }

    mutating func update(
        position: CGPoint,
        timestamp: TimeInterval,
        override: CursyCursorMotionOverride = .none
    ) -> CursyCursorPresentationState {
        switch override {
        case .traveling:
            isMoving = true
            motionIntensity = Self.fastMotionIntensity
            lastMeaningfulMovementTimestamp = timestamp
            return .travelingComet
        case .pointing:
            isMoving = false
            motionIntensity = 0
            return .pointingArrow
        case .none:
            break
        }

        guard let previousPosition, let previousTimestamp else {
            self.previousPosition = position
            self.previousTimestamp = timestamp
            return .restingArrow
        }

        let elapsed = max(timestamp - previousTimestamp, 1.0 / 240.0)
        let deltaX = position.x - previousPosition.x
        let deltaY = position.y - previousPosition.y
        let distance = hypot(deltaX, deltaY)
        let velocity = distance / elapsed
        let positionChanged = distance >= Self.movementDistanceEpsilon

        if positionChanged {
            // Keep the velocity anchor on the last distinct coordinate. Updating
            // it on every timer tick makes a slow one-pixel step look like that
            // pixel travelled in 16 ms, which falsely triggers the comet.
            self.previousPosition = position
            self.previousTimestamp = timestamp

            if smoothedVelocity == 0 {
                smoothedVelocity = velocity
            } else {
                smoothedVelocity += (velocity - smoothedVelocity) * Self.velocitySmoothingFactor
            }
        }

        let isMeaningfulMovement = positionChanged
            && velocity >= Self.movementVelocityThreshold

        if isMoving, positionChanged {
            let rawAngle = atan2(deltaY, deltaX) * (180.0 / .pi) + 90.0
            movementAngleDegrees = Self.nearestEquivalentAngle(
                rawAngle,
                relativeTo: movementAngleDegrees
            )
            motionIntensity = Self.intensity(
                for: smoothedVelocity,
                currentIntensity: motionIntensity
            )
            lastMeaningfulMovementTimestamp = timestamp
        } else if isMoving,
                  let lastMeaningfulMovementTimestamp,
                  timestamp - lastMeaningfulMovementTimestamp >= Self.idleDelay {
            isMoving = false
            motionIntensity = 0
            smoothedVelocity = 0
            movementCandidateTimestamp = nil
        } else if !isMoving, isMeaningfulMovement {
            if let movementCandidateTimestamp,
               timestamp - movementCandidateTimestamp <= Self.movementConfirmationWindow {
                isMoving = true
                self.movementCandidateTimestamp = nil
                lastMeaningfulMovementTimestamp = timestamp
                let rawAngle = atan2(deltaY, deltaX) * (180.0 / .pi) + 90.0
                movementAngleDegrees = Self.nearestEquivalentAngle(
                    rawAngle,
                    relativeTo: movementAngleDegrees
                )
                motionIntensity = Self.intensity(
                    for: smoothedVelocity,
                    currentIntensity: motionIntensity
                )
            } else {
                movementCandidateTimestamp = timestamp
            }
        } else if !isMoving, positionChanged {
            movementCandidateTimestamp = nil
            smoothedVelocity = velocity
        } else if !isMoving,
                  let movementCandidateTimestamp,
                  timestamp - movementCandidateTimestamp > Self.movementConfirmationWindow {
            self.movementCandidateTimestamp = nil
            smoothedVelocity = 0
        }

        return isMoving ? .movingComet(motionIntensity) : .restingArrow
    }

    mutating func reset(position: CGPoint, timestamp: TimeInterval) {
        previousPosition = position
        previousTimestamp = timestamp
        lastMeaningfulMovementTimestamp = nil
        isMoving = false
        movementAngleDegrees = -35
        motionIntensity = 0
        smoothedVelocity = 0
        movementCandidateTimestamp = nil
    }

    static func nearestEquivalentAngle(_ angle: Double, relativeTo reference: Double) -> Double {
        var delta = (angle - reference).truncatingRemainder(dividingBy: 360)
        if delta > 180 {
            delta -= 360
        } else if delta < -180 {
            delta += 360
        }
        return reference + delta
    }

    private static func intensity(
        for velocity: CGFloat,
        currentIntensity: CGFloat
    ) -> CGFloat {
        // Hysteresis around tier boundaries prevents a noisy velocity sample
        // from retargeting the morph on alternating display frames.
        if currentIntensity == fastMotionIntensity, velocity >= 640 {
            return fastMotionIntensity
        }
        if velocity >= fastVelocityThreshold {
            return fastMotionIntensity
        }
        if currentIntensity == mediumMotionIntensity, velocity >= 220 {
            return mediumMotionIntensity
        }
        if velocity >= mediumVelocityThreshold {
            return mediumMotionIntensity
        }
        return slowMotionIntensity
    }
}

struct CursyCursorShape: Shape {
    var morphProgress: CGFloat
    var voiceBlend: CGFloat = 0
    var voiceEnergy: CGFloat = 0
    var voiceWave: CGFloat = 0
    var voiceTime: Double = 0

    var animatableData: CGFloat {
        get { morphProgress }
        set { morphProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let progress = min(max(morphProgress, 0), 1)
        let arrow = Self.arrowGeometry
        let comet = Self.cometGeometry
        let membrane = Self.voiceCircleGeometry(energy: voiceEnergy, pressure: voiceWave)
        let blend = min(max(voiceBlend, 0), 1)

        if blend > 0 {
            let points = (0..<96).map { index -> CGPoint in
                let segmentIndex = index / 24
                let t = CGFloat(index % 24) / 24
                func sample(_ geometry: Geometry) -> CGPoint {
                    let segment = geometry.segments[segmentIndex]
                    let start = segmentIndex == 0 ? geometry.start : geometry.segments[segmentIndex - 1].end
                    let u = 1 - t
                    return CGPoint(
                        x: u*u*u*start.x + 3*u*u*t*segment.control1.x + 3*u*t*t*segment.control2.x + t*t*t*segment.end.x,
                        y: u*u*u*start.y + 3*u*u*t*segment.control1.y + 3*u*t*t*segment.control2.y + t*t*t*segment.end.y)
                }
                let a = sample(arrow), c = sample(comet)
                let angle = Double(index) * 2 * .pi / 96 - .pi / 2
                let wave = 0.48 * sin(3 * angle + 1.9 * voiceTime)
                    + 0.32 * sin(5 * angle - 2.6 * voiceTime + 0.8)
                    + 0.20 * sin(7 * angle + 1.1 * voiceTime + 1.7)
                let pressure = voiceWave.isFinite ? min(max(voiceWave, 0), 0.8) : 0
                let radius = 0.41 * (1 + 0.24 * Double(pressure) * wave)
                let target = CGPoint(x: 0.5 + radius * cos(angle), y: 0.5 + radius * sin(angle))
                let base = CGPoint(x: a.x + (c.x-a.x)*progress, y: a.y + (c.y-a.y)*progress)
                return CGPoint(x: rect.minX + (base.x + (target.x-base.x)*blend)*rect.width,
                               y: rect.minY + (base.y + (target.y-base.y)*blend)*rect.height)
            }
            var path = Path()
            path.move(to: points[0])
            for index in points.indices {
                let before = points[(index + 95) % 96], start = points[index]
                let end = points[(index + 1) % 96], after = points[(index + 2) % 96]
                path.addCurve(to: end,
                    control1: CGPoint(x: start.x + (end.x-before.x)/6, y: start.y + (end.y-before.y)/6),
                    control2: CGPoint(x: end.x - (after.x-start.x)/6, y: end.y - (after.y-start.y)/6))
            }
            path.closeSubpath()
            return path
        }

        func point(_ arrowPoint: CGPoint, _ cometPoint: CGPoint, _ membranePoint: CGPoint) -> CGPoint {
            let normalized = CGPoint(
                x: arrowPoint.x + (cometPoint.x - arrowPoint.x) * progress,
                y: arrowPoint.y + (cometPoint.y - arrowPoint.y) * progress
            )
            return CGPoint(
                x: rect.minX + (normalized.x + (membranePoint.x - normalized.x) * blend) * rect.width,
                y: rect.minY + (normalized.y + (membranePoint.y - normalized.y) * blend) * rect.height
            )
        }

        var path = Path()
        path.move(to: point(arrow.start, comet.start, membrane.start))

        for segmentIndex in arrow.segments.indices {
            let arrowSegment = arrow.segments[segmentIndex]
            let cometSegment = comet.segments[segmentIndex]
            let membraneSegment = membrane.segments[segmentIndex]
            path.addCurve(
                to: point(arrowSegment.end, cometSegment.end, membraneSegment.end),
                control1: point(arrowSegment.control1, cometSegment.control1, membraneSegment.control1),
                control2: point(arrowSegment.control2, cometSegment.control2, membraneSegment.control2)
            )
        }

        path.closeSubpath()
        return path
    }

    private struct Segment {
        let control1: CGPoint
        let control2: CGPoint
        let end: CGPoint
    }

    private struct Geometry {
        let start: CGPoint
        let segments: [Segment]
    }

    private static func voiceCircleGeometry(energy: CGFloat, pressure: CGFloat) -> Geometry {
        let radius: CGFloat = 0.48 + min(max(energy, 0), 1) * 0.02
        let handle = radius * 0.5522847498
        let deformation = min(max(pressure, 0), 1)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let angle = atan2(y, x)
            // Opposite points stay symmetric about the center. The second and
            // fourth harmonics produce visible lobes, not just an oval squeeze.
            let radialScale = 1 + deformation * (0.22 * cos(2 * angle) + 0.16 * cos(4 * angle))
            return CGPoint(x: 0.5 + x * radialScale, y: 0.5 + y * radialScale)
        }
        let top = point(0, -radius)
        // Four cubic arcs preserve the cursor topology while becoming circular.
        return Geometry(start: top, segments: [
            Segment(control1: point(handle, -radius), control2: point(radius, -handle), end: point(radius, 0)),
            Segment(control1: point(radius, handle), control2: point(handle, radius), end: point(0, radius)),
            Segment(control1: point(-handle, radius), control2: point(-radius, handle), end: point(-radius, 0)),
            Segment(control1: point(-radius, -handle), control2: point(-handle, -radius), end: top)
        ])
    }

    private static let arrowGeometry = Geometry(
        start: CGPoint(x: 0.50, y: 0.04),
        segments: [
            Segment(
                control1: CGPoint(x: 0.64, y: 0.04),
                control2: CGPoint(x: 0.70, y: 0.30),
                end: CGPoint(x: 0.93, y: 0.76)
            ),
            Segment(
                control1: CGPoint(x: 1.00, y: 0.91),
                control2: CGPoint(x: 0.79, y: 1.00),
                end: CGPoint(x: 0.50, y: 0.82)
            ),
            Segment(
                control1: CGPoint(x: 0.21, y: 1.00),
                control2: CGPoint(x: 0.00, y: 0.91),
                end: CGPoint(x: 0.07, y: 0.76)
            ),
            Segment(
                control1: CGPoint(x: 0.30, y: 0.30),
                control2: CGPoint(x: 0.36, y: 0.04),
                end: CGPoint(x: 0.50, y: 0.04)
            ),
        ]
    )

    // Directional speed droplet. Its front shares the arrow's rounded tip,
    // while the shoulders compress and the rear converges into a soft tail.
    // Matching the arrow's four-segment topology keeps every retarget smooth.
    private static let cometGeometry = Geometry(
        start: CGPoint(x: 0.50, y: 0.03),
        segments: [
            Segment(
                control1: CGPoint(x: 0.64, y: 0.03),
                control2: CGPoint(x: 0.82, y: 0.23),
                end: CGPoint(x: 0.80, y: 0.46)
            ),
            Segment(
                control1: CGPoint(x: 0.78, y: 0.67),
                control2: CGPoint(x: 0.61, y: 0.95),
                end: CGPoint(x: 0.50, y: 0.98)
            ),
            Segment(
                control1: CGPoint(x: 0.39, y: 0.95),
                control2: CGPoint(x: 0.22, y: 0.67),
                end: CGPoint(x: 0.20, y: 0.46)
            ),
            Segment(
                control1: CGPoint(x: 0.18, y: 0.23),
                control2: CGPoint(x: 0.36, y: 0.03),
                end: CGPoint(x: 0.50, y: 0.03)
            ),
        ]
    )
}

/// Explicit presentation values: glassEffect receives intermediate paths even
/// when its internal rendering does not interpolate a custom Shape.
struct CursyCursorPresentationSpring {
    private(set) var value: CGFloat = 0
    private(set) var velocity: CGFloat = 0

    func isSettled(at target: CGFloat) -> Bool {
        abs(value - target) < 0.0001 && abs(velocity) < 0.001
    }

    mutating func advance(toward target: CGFloat, elapsed: TimeInterval,
                          response: TimeInterval) {
        guard elapsed.isFinite, elapsed > 0 else { return }
        // Exact critically damped spring, preserving velocity on interruption.
        let interval = CGFloat(min(elapsed, 1.0 / 15.0))
        let frequency = CGFloat(2 * Double.pi / response)
        let displacement = value - target
        let coefficient = velocity + frequency * displacement
        let decay = exp(-frequency * interval)
        value = target + (displacement + coefficient * interval) * decay
        velocity = (velocity - frequency * coefficient * interval) * decay
        if isSettled(at: target) { snap(to: target) }
    }

    mutating func snap(to target: CGFloat) {
        value = target
        velocity = 0
    }
}

/// Detect changes in the smoothed amplitude envelope, not individual audio
/// oscillations. Sustained sound emits once; a new accent rearms after a dip.
struct CursyVoiceAccentDetector {
    private var peak: CGFloat = 0
    private var valley: CGFloat = 0
    private var armed = true
    private var lastEmission = -Double.infinity

    mutating func sample(_ level: CGFloat, at time: TimeInterval) -> Bool {
        let amplitude = level.isFinite ? min(max(level, 0), 1) : 0
        if amplitude < 0.02 {
            peak = 0
            valley = amplitude
            armed = true
            return false
        }
        if !armed, amplitude < peak * 0.65 {
            armed = true
            valley = amplitude
        }
        if armed {
            valley = min(valley, amplitude)
            if amplitude > 0.04, amplitude - valley >= 0.035,
               time - lastEmission >= 0.14 {
                armed = false
                peak = amplitude
                lastEmission = time
                return true
            }
        } else {
            peak = max(peak, amplitude)
        }
        return false
    }
}

enum CursyVoiceMotion {
    static let mint = Color(red: 0.30, green: 0.72, blue: 0.60)
    // Visual-only sensitivity; never modify the microphone samples or gain.
    static func pressure(for level: CGFloat) -> CGFloat {
        guard level.isFinite, level > 0.04 else { return 0 }
        return 0.8 * min(sqrt((min(level, 1) - 0.04) / 0.50), 1)
    }
}

struct CursyGlassCursorView: View {
    let presentationState: CursyCursorPresentationState
    let voiceState: CompanionVoiceState
    let audioPowerLevel: CGFloat
    var isVisible: Bool = true
    var tint: CursyCursorTint? = nil
    @AppStorage(CursyCursorTint.preferenceKey) private var storedTint = CursyCursorTint.mint.rawValue
    private var accentColor: Color { (tint ?? .resolve(storedTint)).color }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var morphSpring = CursyCursorPresentationSpring()
    @State private var activitySpring = CursyCursorPresentationSpring()
    @State private var voiceSpring = CursyCursorPresentationSpring()
    @State private var waveSpring = CursyCursorPresentationSpring()
    @State private var targetVoice: CGFloat = 0
    @State private var targetWave: CGFloat = 0
    @State private var targetMorph: CGFloat = 0
    @State private var targetActivity: CGFloat = 0
    @State private var lastFrameTime: TimeInterval?
    @State private var response: TimeInterval = 0.30
    @State private var pulses: [CursyVoicePulse] = []
    @State private var listeningTint = CursyCursorPresentationSpring()
    @State private var accentDetector = CursyVoiceAccentDetector()
    @State private var contourTime = 0.0

    private var clockPaused: Bool {
        !isVisible || reduceMotion || (!needsContinuousFrames
            && pulses.isEmpty
            && listeningTint.isSettled(at: voiceState == .listening ? 1 : 0)
            && morphSpring.isSettled(at: targetMorph)
            && voiceSpring.isSettled(at: targetVoice)
            && waveSpring.isSettled(at: targetWave)
            && activitySpring.isSettled(at: targetActivity))
    }

    private var needsContinuousFrames: Bool {
        voiceState == .connecting || voiceState == .processing || (voiceState == .listening && audioPowerLevel > 0.025)
    }

    var body: some View {
        // The lens stays outside TimelineView. The clock only supplies targets;
        // it never owns/recreates the rendered surface on voice-mode changes.
        CursyCursorSurface(morphProgress: morphSpring.value,
                           activity: activitySpring.value,
                           voiceBlend: voiceSpring.value,
                           voiceWave: waveSpring.value,
                           voiceTime: contourTime,
                           listeningTint: listeningTint.value,
                           accentColor: accentColor,
                           reduceTransparency: reduceTransparency)
            .background {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                        paused: clockPaused)) { context in
                    Canvas { context, size in
                        let now = ProcessInfo.processInfo.systemUptime
                        for pulse in pulses {
                            let progress = pulse.progress(at: now)
                            let radius = (21 + progress * 27) / 2
                            let rect = CGRect(x: size.width / 2 - radius, y: size.height / 2 - radius,
                                              width: radius * 2, height: radius * 2)
                            let color = accentColor
                            let ring = CursyCursorShape(morphProgress: 0, voiceBlend: 1,
                                voiceEnergy: 0, voiceWave: pulse.deformation,
                                voiceTime: contourTime - (now - pulse.startedAt) * 0.45)
                            var ringContext = context
                            ringContext.opacity = Double(sin(progress * .pi)) * 0.75 * Double(voiceSpring.value)
                            ringContext.stroke(ring.path(in: rect),
                                with: .linearGradient(Gradient(colors: [color.opacity(0.65), color]),
                                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)), lineWidth: 0.8)
                        }
                    }
                        .frame(width: 80, height: 80)
                        .onChange(of: context.date) { _, date in
                            advanceFrame(at: date)
                        }
                }
            }
            .onAppear { updateSurface() }
            .onChange(of: voiceState) { _, _ in
                accentDetector = CursyVoiceAccentDetector()
                updateSurface(response: 0.45)
            }
            .onChange(of: audioPowerLevel) { _, _ in
                guard voiceState == .listening else { return }
                updateSurface()
            }
            .onChange(of: presentationState) { _, _ in
                guard voiceState == .idle || voiceState == .responding else { return }
                updateSurface()
            }
            .onChange(of: reduceMotion) { _, _ in pulses.removeAll(); updateSurface(animated: false) }
            .onChange(of: isVisible) { _, _ in lastFrameTime = nil; pulses.removeAll() }
            .accessibilityHidden(true)
    }

    private func advanceFrame(at date: Date) {
        guard !reduceMotion else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = lastFrameTime.map { now - $0 } ?? 1.0 / 60.0
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            contourTime += min(max(elapsed, 0), 0.05)
            if needsContinuousFrames { updateSurface(at: date, response: response) }
            morphSpring.advance(toward: targetMorph, elapsed: elapsed, response: response)
            activitySpring.advance(toward: targetActivity, elapsed: elapsed,
                response: voiceState == .listening
                    ? (targetActivity > activitySpring.value ? 0.10 : 0.24) : response)
            voiceSpring.advance(toward: targetVoice, elapsed: elapsed, response: 0.4)
            waveSpring.advance(toward: targetWave, elapsed: elapsed,
                response: targetWave > waveSpring.value ? 0.16 : 0.30)
            listeningTint.advance(toward: voiceState == .listening ? 1 : 0,
                                  elapsed: elapsed, response: 0.30)
            pulses.removeAll { $0.progress(at: now) >= 1 }
            let isListening = voiceState == .listening
            let voiceAccent = isListening && voiceSpring.value > 0.7
                && accentDetector.sample(activitySpring.value, at: now)
            if voiceAccent, targetActivity > 0.04, pulses.count < 3 {
                pulses.append(CursyVoicePulse(startedAt: now,
                    strength: activitySpring.value, isListening: true))
            }
            lastFrameTime = clockPaused ? nil : now
        }
    }

    private func updateSurface(at date: Date = .now, response: Double = 0.30,
                               animated: Bool = true) {
        let breath = CGFloat((sin(date.timeIntervalSinceReferenceDate * .pi) + 1) / 2)
        // Meter already includes microphone gain. Do not amplify it again.
        let level = audioPowerLevel.isFinite
            ? min(max((audioPowerLevel - 0.025) / 0.975, 0), 1) : 0
        let morph: CGFloat
        let activity: CGFloat
        let voice: CGFloat
        let wave: CGFloat
        switch voiceState {
        case .connecting:
            morph = 0
            voice = 1
            activity = 0.05 + breath * 0.12
            wave = 0
        case .listening:
            morph = 0
            voice = 1
            activity = level
            wave = CursyVoiceMotion.pressure(for: level)
        case .processing:
            morph = 0
            voice = 1
            activity = 0.18 + breath * 0.24
            wave = 0
        case .idle, .responding:
            morph = presentationState.morphProgress
            activity = 0
            voice = 0
            wave = 0
        }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.response = response
            targetMorph = reduceMotion ? 0 : morph
            targetVoice = voice
            targetWave = reduceMotion ? 0 : wave
            targetActivity = reduceMotion ? (voiceState == .processing ? 0.4 : 0) : activity
            if !animated || reduceMotion {
                morphSpring.snap(to: targetMorph)
                activitySpring.snap(to: targetActivity)
                voiceSpring.snap(to: targetVoice)
                waveSpring.snap(to: targetWave)
                listeningTint.snap(to: voiceState == .listening ? 1 : 0)
                lastFrameTime = nil
            }
        }
    }
}

// Interactive, microphone-free prototype for validating native glass in Xcode.
#if DEBUG
private struct CursyVoiceCirclePreview: View {
    @State private var mode = CompanionVoiceState.listening
    @State private var simulateVoice = true
    @State private var level = 0.35

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Cursor") { mode = .idle }
                Button("Preparando") { mode = .connecting }
                Button("Escucha") { mode = .listening }
                Button("Pensando") { mode = .processing }
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !simulateVoice)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let simulatedLevel = max(0, sin(time * 2.3)) * (0.2 + 0.6 * abs(sin(time * 5)))
                CursyGlassCursorView(presentationState: .restingArrow, voiceState: mode,
                    audioPowerLevel: CGFloat(simulateVoice ? simulatedLevel : level))
                    .frame(width: 300, height: 150)
            }
            Toggle("Simular voz (sin micrófono ni red)", isOn: $simulateVoice)
            Slider(value: $level, in: 0...1) { Text("Nivel manual") }
                .disabled(simulateVoice)
        }
        .padding(24)
        .frame(width: 460)
    }
}

#Preview("Círculo y pulsos de voz — prueba interactiva") { CursyVoiceCirclePreview() }
#endif

struct CursyVoicePulse {
    let startedAt: TimeInterval
    let strength: CGFloat
    let isListening: Bool

    var deformation: CGFloat {
        isListening ? max(0.3, CursyVoiceMotion.pressure(for: strength)) : 0
    }

    func progress(at time: TimeInterval) -> CGFloat {
        CGFloat(min(max((time - startedAt) / 1.1, 0), 1))
    }
}

private struct CursyCursorSurface: View {
    var morphProgress: CGFloat
    var activity: CGFloat
    var voiceBlend: CGFloat
    var voiceWave: CGFloat
    var voiceTime: Double
    var listeningTint: CGFloat
    var accentColor: Color
    let reduceTransparency: Bool

    private let cursorSize: CGFloat = 16
    private let nativeGlassOpticalScale: CGFloat = 0.32

    private var pearlGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.50, green: 0.88, blue: 1),
                                .white,
                                Color(red: 0.82, green: 0.78, blue: 1),
                                .white.opacity(0.8)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func voiceHighlights(shape: CursyCursorShape) -> some View {
        shape.fill(accentColor.opacity(0.32 + listeningTint * 0.20))
            .overlay(shape.stroke(pearlGradient, lineWidth: 1.1).opacity(activity))
    }

    var body: some View {
        glassCursor(morphProgress: morphProgress)
            .frame(width: cursorSize, height: cursorSize)
            .rotationEffect(.degrees(-35))
            .scaleEffect(1 + activity * 0.08)
            // The presentation clock supplies actual frame values. Do not
            // interpolate its glass outline or rotation a second time.
            .transaction { $0.animation = nil }
    }

    @ViewBuilder
    private func glassCursor(morphProgress: CGFloat) -> some View {
        let shape = CursyCursorShape(morphProgress: morphProgress, voiceBlend: voiceBlend,
                                     voiceEnergy: activity, voiceWave: voiceWave, voiceTime: voiceTime)

        if reduceTransparency {
            opaqueCursor(shape: shape)
        } else if #available(macOS 26.0, *) {
            nativeLiquidGlassCursor(shape: shape)
        } else {
            compatibleGlassCursor(shape: shape)
        }
    }

    private func opaqueCursor(shape: CursyCursorShape) -> some View {
        shape
            .fill(accentColor)
            .overlay(voiceHighlights(shape: shape))
            .overlay(shape.stroke(.white.opacity(0.72), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
            .shadow(color: accentColor.opacity(0.6), radius: 6, y: 1)
    }

    @available(macOS 26.0, *)
    private func nativeLiquidGlassCursor(shape: CursyCursorShape) -> some View {
        Color.clear
            // Color the lens itself. A separate fill/stroke follows the small
            // layout path, not the glass's optical extent, creating an inset
            // second cursor that becomes especially visible during a morph.
            .glassEffect(.clear.tint(
                accentColor.opacity(0.65 + listeningTint * 0.20)
            ), in: shape)
            // Liquid Glass samples beyond its layout bounds and therefore reads
            // optically much larger than a conventional 16-point cursor. Scale
            // the complete optical result, rather than shrinking only the path,
            // so the lensing, border, and morph remain registered.
            .scaleEffect(nativeGlassOpticalScale)
            .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.75)
            .shadow(color: accentColor.opacity(0.65), radius: 6, y: 1)
    }

    private func compatibleGlassCursor(shape: CursyCursorShape) -> some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(voiceHighlights(shape: shape))
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.62), .white.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
            )
            .shadow(color: .black.opacity(0.20), radius: 2, y: 1)
            .shadow(color: accentColor.opacity(0.6), radius: 6, y: 1)
    }
}
