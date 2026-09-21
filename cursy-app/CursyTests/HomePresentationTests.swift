import Foundation
import CoreGraphics
import Testing
@testable import Cursy

@Suite("Home presentation and session projection")
struct HomePresentationTests {
    @Test func currentResponseAppearsOnceAfterCompletion() {
        var session = ConversationSession()
        let turn = session.beginTurn()
        session.setTranscript("Explain this diagram", for: turn)
        session.setResponse("These are the components.", for: turn)
        #expect(HomeExchange.visible(in: session).count == 1)
        session.completeTurn(turn)
        let visible = HomeExchange.visible(in: session)
        #expect(visible.count == 1)
        #expect(visible.first?.id == turn)
        #expect(visible.first?.response == "These are the components.")
    }

    @Test func partialTurnAndResetReflectSourceImmediately() {
        var session = ConversationSession()
        let turn = session.beginTurn()
        #expect(HomeExchange.visible(in: session).isEmpty)
        session.setTranscript("This one", for: turn)
        #expect(HomeExchange.visible(in: session).first?.request == "This one")
        session.reset()
        #expect(HomeExchange.visible(in: session).isEmpty)
        let acceptedLateResponse = session.appendResponse("Late response", for: turn)
        #expect(!acceptedLateResponse)
        #expect(HomeExchange.visible(in: session).isEmpty)
    }

    @Test func historyRemainsBoundedByExistingSession() {
        var session = ConversationSession()
        for index in 0..<20 {
            let turn = session.beginTurn()
            session.setTranscript("Question \(index)", for: turn)
            session.setResponse("Response \(index)", for: turn)
            session.completeTurn(turn)
        }
        #expect(HomeExchange.visible(in: session).count == ConversationSession.historyLimit)
        #expect(HomeExchange.visible(in: session).last?.request == "Question 19")
    }

    @Test func terminalStatesDoNotShowStaleThinking() {
        var session = ConversationSession()
        let first = session.beginTurn()
        session.failTurn(first)
        #expect(HomeActivity.resolve(session: session, voiceState: .processing, permissionsReady: true) == .failed)
        let next = session.beginTurn()
        #expect(HomeActivity.resolve(session: session, voiceState: .connecting, permissionsReady: true) == .connecting)
        session.cancelTurn(next)
        #expect(HomeActivity.resolve(session: session, voiceState: .responding, permissionsReady: true) == .cancelled)
        session.reset()
        #expect(HomeActivity.resolve(session: session, voiceState: .idle, permissionsReady: true) == .ready)
    }

    @Test func setupHasPriorityAndLiveStatesArePreserved() {
        let session = ConversationSession()
        #expect(HomeActivity.resolve(session: session, voiceState: .idle, permissionsReady: false) == .setupRequired)
        #expect(HomeActivity.resolve(session: session, voiceState: .listening, permissionsReady: true) == .listening)
        #expect(HomeActivity.resolve(session: session, voiceState: .processing, permissionsReady: true) == .processing)
        #expect(HomeActivity.resolve(session: session, voiceState: .responding, permissionsReady: true) == .responding)
    }

    @Test(arguments: [HomePresentation.compact, .expanded, .detached])
    func respectsNotchAndVisibleBounds(presentation: HomePresentation) {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let visible = CGRect(x: 0, y: 80, width: 1728, height: 1000)
        let frame = HomePanelLayout.frame(presentation: presentation, screenFrame: screen,
            visibleFrame: visible, safeTopInset: 38)
        #expect(visible.contains(frame))
        #expect(frame.maxY <= screen.maxY - 38)
        #expect(frame.midX == visible.midX)
    }

    @Test(arguments: [HomePresentation.compact, .expanded, .detached])
    func externalNegativeOriginAndSmallDisplay(presentation: HomePresentation) {
        let screen = CGRect(x: -900, y: -500, width: 500, height: 380)
        let visible = CGRect(x: -900, y: -480, width: 500, height: 340)
        let frame = HomePanelLayout.frame(presentation: presentation, screenFrame: screen,
            visibleFrame: visible, safeTopInset: 0)
        #expect(visible.contains(frame))
        #expect(frame.width > 0 && frame.height > 0)
    }

    @Test func removedDisplayClampsDetachedWindow() {
        let oldFrame = CGRect(x: -1500, y: 1800, width: 620, height: 490)
        let remaining = CGRect(x: 0, y: 80, width: 1200, height: 700)
        let clamped = HomePanelLayout.clamped(oldFrame, to: remaining)
        #expect(remaining.contains(clamped))
        #expect(clamped.size == oldFrame.size)
        let tiny = CGRect(x: 10, y: 10, width: 400, height: 250)
        #expect(tiny.contains(HomePanelLayout.clamped(oldFrame, to: tiny)))
    }

    @Test(arguments: [CGFloat(0), -1800])
    func attachesToRealNotchWithoutGap(origin: CGFloat) throws {
        let screen = CGRect(x: origin, y: -200, width: 1728, height: 1117)
        let visible = CGRect(x: origin, y: -120, width: 1728, height: 999)
        let notch = try #require(HomePanelLayout.notch(screenFrame: screen, safeTopInset: 38,
            leftArea: CGRect(x: origin, y: 879, width: 760, height: 38),
            rightArea: CGRect(x: origin + 968, y: 879, width: 760, height: 38)))
        #expect(notch.width == 208)
        for presentation in [HomePresentation.compact, .expanded] {
            let frame = HomePanelLayout.frame(presentation: presentation, screenFrame: screen,
                visibleFrame: visible, safeTopInset: 38, notch: notch)
            #expect(frame.maxY == screen.maxY)
            #expect(frame.midX == notch.midX)
            #expect(screen.contains(frame))
            #expect(frame.contains(notch))
        }
        let detached = HomePanelLayout.frame(presentation: .detached, screenFrame: screen,
            visibleFrame: visible, safeTopInset: 38, notch: notch)
        #expect(detached.maxY < notch.minY)
    }

    @Test func noCameraHousingKeepsFloatingFallback() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        #expect(HomePanelLayout.notch(screenFrame: screen, safeTopInset: 0,
            leftArea: nil, rightArea: nil) == nil)
        #expect(HomePanelLayout.notch(screenFrame: screen, safeTopInset: 38,
            leftArea: .zero, rightArea: .zero) == nil)
        let visible = CGRect(x: 0, y: 80, width: 1920, height: 976)
        let frame = HomePanelLayout.frame(presentation: .expanded, screenFrame: screen,
            visibleFrame: visible, safeTopInset: 0)
        #expect(frame.maxY == visible.maxY - 12)
    }

    @Test(arguments: [CGFloat(-1), 0, 0.25, 0.75, 1, 2, .nan, .infinity])
    func revealStaysTopAnchoredAndBounded(progress: CGFloat) {
        let canvas = CGRect(x: 0, y: 0, width: 620, height: 506)
        let mask = HomeRevealMask.bounds(in: canvas, progress: progress, sourceWidth: 208)
        #expect(mask.minY == canvas.minY)
        #expect(mask.midX == canvas.midX)
        #expect(mask.width >= 208 && mask.width <= canvas.width)
        #expect(mask.height >= 0 && mask.height <= canvas.height)
        if progress == 1 { #expect(mask == canvas) }
    }
}
