import Foundation
import CoreGraphics
import SwiftUI
import Testing
@testable import Cursy

@Suite("Voice island and cursor docking")
struct HomeNotchInteractionTests {
    @Test(arguments: [false, true])
    func voiceOwnsDockingUntilResponseOrValidatedTarget(hasTarget: Bool) {
        #expect(HomeNotchInteraction.shouldDock(voiceState: .connecting, hasValidatedTarget: hasTarget))
        #expect(HomeNotchInteraction.shouldDock(voiceState: .listening, hasValidatedTarget: hasTarget))
        #expect(HomeNotchInteraction.shouldDock(voiceState: .processing, hasValidatedTarget: hasTarget) == !hasTarget)
        #expect(!HomeNotchInteraction.shouldDock(voiceState: .responding, hasValidatedTarget: hasTarget))
        #expect(!HomeNotchInteraction.shouldDock(voiceState: .idle, hasValidatedTarget: hasTarget))
    }

    @Test func automaticallyShowsWithoutOverridingUserPresentation() {
        for state in [CompanionVoiceState.connecting, .listening, .processing, .responding] {
            #expect(HomeNotchInteraction.shouldShowIsland(voiceState: state, presentation: .hidden, dismissedDuringTurn: false))
            #expect(!HomeNotchInteraction.shouldShowIsland(voiceState: state, presentation: .hidden, dismissedDuringTurn: true))
            for presentation in [HomePresentation.compact, .expanded, .detached] {
                #expect(!HomeNotchInteraction.shouldShowIsland(voiceState: state, presentation: presentation, dismissedDuringTurn: false))
            }
        }
        #expect(!HomeNotchInteraction.shouldShowIsland(voiceState: .idle, presentation: .hidden, dismissedDuringTurn: false))
    }

    @Test(arguments: [CGFloat(0), -1800])
    func cameraIsCoveredAndControlsHaveLateralSpace(origin: CGFloat) {
        let screen = CGRect(x: origin, y: -200, width: 1728, height: 1117)
        let camera = CGRect(x: screen.midX - 104, y: screen.maxY - 38, width: 208, height: 38)
        let frame = HomePanelLayout.frame(presentation: .compact, screenFrame: screen,
            visibleFrame: screen.insetBy(dx: 0, dy: 38), safeTopInset: 38, notch: camera)
        #expect(frame.maxY == screen.maxY)
        #expect(frame.contains(camera))
        #expect(frame.height == 52)
        #expect((frame.width - camera.width) / 2 >= 120)
        let anchor = HomeNotchAnchor(displayFrame: screen, cameraFrame: camera)
        #expect(anchor.hiddenCursorPoint.x == camera.midX)
        #expect(anchor.hiddenCursorPoint.y > screen.maxY)
        let local = ScreenCoordinateSpace.overlayPoint(globalPoint: anchor.hiddenCursorPoint, displayFrame: screen)
        #expect(local.y == -24)
    }

    @Test func revealNeverCutsIntoPhysicalCamera() {
        let canvas = CGRect(x: 0, y: 0, width: 460, height: 52)
        for progress in [CGFloat(0), 0.2, 0.5, 1] {
            let mask = HomeRevealMask.bounds(in: canvas, progress: progress, sourceWidth: 208, sourceHeight: 38)
            #expect(mask.contains(CGRect(x: 126, y: 0, width: 208, height: 38)))
        }
    }

    @Test func expandedNeckCoversCameraAndLeavesMenuBarSidesClear() {
        let bounds = CGRect(x: 0, y: 0, width: 620, height: 482)
        let path = HomeSurfaceShape(notchWidth: 208, notchHeight: 38).path(in: bounds)
        for depth in [CGFloat(1), 30, 38, 45, 52, 75] {
            #expect(path.contains(CGPoint(x: bounds.midX - 103, y: depth)))
            #expect(path.contains(CGPoint(x: bounds.midX + 103, y: depth)))
        }
        #expect(!path.contains(CGPoint(x: 40, y: 20)))
        #expect(path.contains(CGPoint(x: 40, y: 75)))
    }

    @Test func compactHoverExpandsWithoutRequiringAClick() {
        #expect(HomeHoverPolicy.intent(presentation: .compact, inTrigger: true, inPanel: true,
            busy: true, dragging: false, suppressed: false, voiceOver: false) == .open)
        #expect(HomeHoverPolicy.intent(presentation: .compact, inTrigger: true, inPanel: true,
            busy: true, dragging: true, suppressed: false, voiceOver: false) == .none)
    }
}
