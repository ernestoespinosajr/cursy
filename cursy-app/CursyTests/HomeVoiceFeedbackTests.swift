import Foundation
import Testing
@testable import Cursy

struct HomeVoiceFeedbackTests {
    @Test(arguments: [CGFloat.nan, .infinity, -.infinity, -1, 0, 0.025])
    func silenceAndInvalidLevelsStayQuiet(_ input: CGFloat) {
        let feedback = HomeVoiceFeedback(activity: .listening, audioPowerLevel: input)
        #expect(feedback.level == 0)
        #expect(feedback.glowOpacity == 0.16)
        #expect(feedback.barScale(weight: 1, reduceMotion: false) == 0.15)
    }

    @Test func liveLevelIsBoundedAndProportional() {
        let quiet = HomeVoiceFeedback(activity: .listening, audioPowerLevel: 0.2)
        let loud = HomeVoiceFeedback(activity: .listening, audioPowerLevel: 0.8)
        let clipped = HomeVoiceFeedback(activity: .listening, audioPowerLevel: 3)
        #expect(quiet.level < loud.level)
        #expect(quiet.glowOpacity < loud.glowOpacity)
        #expect(clipped.level == 1)
        #expect(clipped.barScale(weight: 1, reduceMotion: false) == 1)
    }

    @Test(arguments: [HomeActivity.ready, .setupRequired, .connecting, .processing, .responding, .failed, .cancelled])
    func otherStatesIgnoreStaleAudio(_ activity: HomeActivity) {
        let feedback = HomeVoiceFeedback(activity: activity, audioPowerLevel: 1)
        #expect(!feedback.isListening)
        #expect(feedback.level == 0)
        #expect(feedback.glowOpacity == 0)
    }

    @Test func reducedMotionKeepsGeometryStatic() {
        let quiet = HomeVoiceFeedback(activity: .listening, audioPowerLevel: 0)
        let loud = HomeVoiceFeedback(activity: .listening, audioPowerLevel: 1)
        for weight in HomeVoiceFeedback.barWeights {
            #expect(quiet.barScale(weight: weight, reduceMotion: true)
                    == loud.barScale(weight: weight, reduceMotion: true))
        }
    }
}
