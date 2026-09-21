//
//  CursyTests.swift
//  CursyTests
//
//  Created by thorfinn on 3/2/26.
//

import Testing
@testable import Cursy

struct CursyTests {

    @Test func voiceDeformationIsVisibleAndRingsKeepTheirShape() {
        #expect(CursyVoiceMotion.pressure(for: 0.02) == 0)
        #expect(CursyVoiceMotion.pressure(for: .nan) == 0)
        #expect(CursyVoiceMotion.pressure(for: 1) == 0.8)
        let rect = CGRect(x: 0, y: 0, width: 16, height: 16)
        let loud = CursyCursorShape(morphProgress: 0, voiceBlend: 1, voiceWave: 1).path(in: rect)
        let later = CursyCursorShape(morphProgress: 0, voiceBlend: 1, voiceWave: 1, voiceTime: 0.4).path(in: rect)
        #expect(loud != later)
        #expect(rect.contains(loud.boundingRect))
        let wave = CursyVoicePulse(startedAt: 0, strength: 0.08, isListening: true)
        #expect(wave.deformation >= 0.3 && wave.deformation <= 0.8)
    }

    @Test func voiceAccentsFollowEnvelopeInsteadOfAPeriodicTimer() {
        var detector = CursyVoiceAccentDetector()
        #expect(!detector.sample(0, at: 0))
        #expect(detector.sample(0.4, at: 0.2))
        #expect(!detector.sample(0.4, at: 1.0))
        #expect(!detector.sample(0.4, at: 2.0))
        #expect(!detector.sample(0.1, at: 2.1))
        #expect(detector.sample(0.5, at: 2.3))
        #expect(!detector.sample(.nan, at: 2.4))
    }

    @Test func voicePressureDeformsContourWithinFixedFrame() {
        let rect = CGRect(x: 0, y: 0, width: 16, height: 16)
        let resting = CursyCursorShape(morphProgress: 0, voiceBlend: 1).path(in: rect)
        let speaking = CursyCursorShape(morphProgress: 0, voiceBlend: 1,
                                       voiceWave: 0.8).path(in: rect)
        #expect(resting != speaking)
        #expect(rect.contains(speaking.boundingRect))
        let silentLater = CursyCursorShape(morphProgress: 0, voiceBlend: 1, voiceTime: 2).path(in: rect)
        #expect(resting == silentLater)
    }

    @Test func pcmInboxRetainsFinalSamplesAndRejectsLateCallbacks() {
        let inbox = RealtimePCMInbox()
        #expect(inbox.append(Data(repeating: 1, count: 4_080))) // 85 ms
        let first = inbox.drain()
        #expect(first.count < RealtimePCMInbox.minimumBytes)
        #expect(inbox.append(Data(repeating: 2, count: 720)))
        let final = inbox.drain(closing: true)
        #expect(first.count + final.count == RealtimePCMInbox.minimumBytes)
        #expect(!inbox.append(Data(repeating: 3, count: 960)))
        #expect(inbox.drain().isEmpty)
    }

    @Test func voiceCircleIsRoundDistinctFromCometAndRespondsToVoice() {
        let rect = CGRect(x: 0, y: 0, width: 16, height: 16)
        let comet = CursyCursorShape(morphProgress: 1).path(in: rect)
        let quiet = CursyCursorShape(morphProgress: 0, voiceBlend: 1).path(in: rect)
        let speaking = CursyCursorShape(morphProgress: 0, voiceBlend: 1,
                                       voiceEnergy: 0.8, voiceWave: 0.7).path(in: rect)
        #expect(quiet != comet)
        #expect(abs(quiet.boundingRect.width - quiet.boundingRect.height) < 0.001)
        #expect(speaking != quiet)
        #expect(speaking.boundingRect.width.isFinite)
    }

    @Test func voicePulseLifetimeIsBounded() {
        let pulse = CursyVoicePulse(startedAt: 10, strength: 0.5, isListening: true)
        #expect(pulse.progress(at: 9) == 0)
        #expect(pulse.progress(at: 10.55) > 0.49)
        #expect(pulse.progress(at: 10.55) < 0.51)
        #expect(pulse.progress(at: 12) == 1)
    }

    @Test func voiceMorphProducesIntermediateFramesAndSettles() {
        var spring = CursyCursorPresentationSpring()
        var previousValue = spring.value
        for _ in 0..<60 {
            spring.advance(toward: 0.65, elapsed: 1.0 / 60.0, response: 0.45)
            #expect(spring.value >= previousValue)
            #expect(spring.value <= 0.65)
            previousValue = spring.value
        }
        #expect(spring.isSettled(at: 0.65))
        spring.advance(toward: 0, elapsed: 1.0 / 60.0, response: 0.45)
        #expect(spring.value > 0 && spring.value < 0.65)
        for _ in 0..<60 {
            spring.advance(toward: 0, elapsed: 1.0 / 60.0, response: 0.45)
        }
        #expect(spring.isSettled(at: 0))
    }

    @Test func voiceMorphRetargetsWithoutResettingPresentation() {
        var spring = CursyCursorPresentationSpring()
        for _ in 0..<8 {
            spring.advance(toward: 0.75, elapsed: 1.0 / 60.0, response: 0.45)
        }
        let beforeInterruption = spring.value
        spring.advance(toward: 0.65, elapsed: 1.0 / 60.0, response: 0.45)
        #expect(abs(spring.value - beforeInterruption) < 0.1)
        #expect(spring.value > 0 && spring.value < 0.65)
        spring.snap(to: 0)
        #expect(spring.isSettled(at: 0))
    }

    @Test func firstPermissionRequestUsesSystemPromptOnly() async throws {
        let presentationDestination = WindowPositionManager.permissionRequestPresentationDestination(
            hasPermissionNow: false,
            hasAttemptedSystemPrompt: false
        )

        #expect(presentationDestination == .systemPrompt)
    }

    @Test func repeatedPermissionRequestOpensSystemSettings() async throws {
        let presentationDestination = WindowPositionManager.permissionRequestPresentationDestination(
            hasPermissionNow: false,
            hasAttemptedSystemPrompt: true
        )

        #expect(presentationDestination == .systemSettings)
    }

    @Test func knownGrantedScreenRecordingPermissionSkipsTheGate() async throws {
        let shouldTreatPermissionAsGranted = WindowPositionManager.shouldTreatScreenRecordingPermissionAsGrantedForSessionLaunch(
            hasScreenRecordingPermissionNow: false,
            hasPreviouslyConfirmedScreenRecordingPermission: true
        )

        #expect(shouldTreatPermissionAsGranted)
    }

    @Test func spanishLanguageForcesSpanishRealtimeResponses() {
        #expect(CursyLanguage.spanish.realtimeInstructions.contains("Always understand and answer"))
        #expect(CursyLanguage.spanish.realtimeInstructions.contains("Spanish"))
        #expect(CursyLanguage.spanish.localeIdentifier == "es-419")
    }

    @Test func englishLanguageForcesEnglishRealtimeResponses() {
        #expect(CursyLanguage.english.realtimeInstructions.contains("American English"))
        #expect(CursyLanguage.english.localeIdentifier == "en-US")
    }

    @Test func cursorBecomesDirectionalCometDuringMovementAndArrowAfterIdleDelay() {
        var reducer = CursyCursorMotionReducer()

        #expect(reducer.update(position: .zero, timestamp: 0) == .restingArrow)
        #expect(reducer.update(position: CGPoint(x: 10, y: 0), timestamp: 0.016) == .restingArrow)
        #expect(reducer.update(position: CGPoint(x: 20, y: 0), timestamp: 0.032).isMovingShape)
        #expect(reducer.update(position: CGPoint(x: 20, y: 0), timestamp: 0.08).isMovingShape)
        #expect(reducer.update(position: CGPoint(x: 20, y: 0), timestamp: 0.20) == .restingArrow)
    }

    @Test func cursorCometDeformationIncreasesWithSpeed() {
        var slowReducer = CursyCursorMotionReducer()
        var fastReducer = CursyCursorMotionReducer()

        _ = slowReducer.update(position: .zero, timestamp: 0)
        _ = fastReducer.update(position: .zero, timestamp: 0)

        _ = slowReducer.update(position: CGPoint(x: 1, y: 0), timestamp: 0.016)
        _ = fastReducer.update(position: CGPoint(x: 20, y: 0), timestamp: 0.016)
        let slow = slowReducer.update(position: CGPoint(x: 2, y: 0), timestamp: 0.032)
        let fast = fastReducer.update(position: CGPoint(x: 40, y: 0), timestamp: 0.032)

        #expect(fast.morphProgress > slow.morphProgress)
    }

    @Test func cursorCometTracksMovementDirection() {
        var reducer = CursyCursorMotionReducer()

        _ = reducer.update(position: .zero, timestamp: 0)
        _ = reducer.update(position: CGPoint(x: 10, y: 0), timestamp: 0.016)
        _ = reducer.update(position: CGPoint(x: 20, y: 0), timestamp: 0.032)

        #expect(abs(reducer.movementAngleDegrees - 90) < 0.001)
    }

    @Test func cursorStaysArrowDuringSlowQuantizedMovement() {
        var reducer = CursyCursorMotionReducer()

        _ = reducer.update(position: .zero, timestamp: 0)
        #expect(
            reducer.update(position: CGPoint(x: 0.5, y: 0), timestamp: 0.08)
                == .restingArrow
        )
        #expect(
            reducer.update(position: CGPoint(x: 0.5, y: 0), timestamp: 0.16)
                == .restingArrow
        )
        #expect(
            reducer.update(position: CGPoint(x: 1.0, y: 0), timestamp: 0.24)
                == .restingArrow
        )
    }

    @Test func cursorCometRemainsStableWhenMovementSlowsAfterActivation() {
        var reducer = CursyCursorMotionReducer()

        _ = reducer.update(position: .zero, timestamp: 0)
        _ = reducer.update(position: CGPoint(x: 10, y: 0), timestamp: 0.016)
        #expect(
            reducer.update(position: CGPoint(x: 20, y: 0), timestamp: 0.032)
                .isMovingShape
        )
        #expect(
            reducer.update(position: CGPoint(x: 20.5, y: 0), timestamp: 0.112)
                .isMovingShape
        )
        #expect(
            reducer.update(position: CGPoint(x: 21, y: 0), timestamp: 0.192)
                .isMovingShape
        )
    }

    @Test func cursorHeadingUsesShortestPathAcrossAngleWrap() {
        let unwrapped = CursyCursorMotionReducer.nearestEquivalentAngle(
            -89,
            relativeTo: 269
        )

        #expect(abs(unwrapped - 271) < 0.001)
    }

    @Test func cursorIgnoresSubpixelPointerJitter() {
        var reducer = CursyCursorMotionReducer()

        _ = reducer.update(position: .zero, timestamp: 0)
        let presentation = reducer.update(
            position: CGPoint(x: 0.2, y: 0.2),
            timestamp: 0.016
        )

        #expect(presentation == .restingArrow)
    }

    @Test func navigationOverridesPointerMotionState() {
        var reducer = CursyCursorMotionReducer()

        #expect(
            reducer.update(position: .zero, timestamp: 0, override: .traveling)
                == .travelingComet
        )
        #expect(
            reducer.update(position: .zero, timestamp: 0.1, override: .pointing)
                == .pointingArrow
        )
    }

    @Test func speedDropletGeometryIsLongerThanItIsWide() {
        let boundingRect = CursyCursorShape(morphProgress: 1)
            .path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
            .boundingRect

        #expect(boundingRect.height > boundingRect.width)
    }

}
