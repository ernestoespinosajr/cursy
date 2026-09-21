import AppKit
import CoreGraphics
import Testing
@testable import Cursy

struct HomeSpatialHintTests {
    @Test(arguments: [CGPoint.zero, CGPoint(x: -1800, y: 200), CGPoint(x: 400, y: -1200)])
    func hintReservesCameraAndUsesTheCurrentPanel(origin: CGPoint) throws {
        let screen = CGRect(origin: origin, size: CGSize(width: 1728, height: 1117))
        let camera = CGRect(x: screen.midX - 104, y: screen.maxY - 38, width: 208, height: 38)
        for presentation in [HomePresentation.compact, .expanded] {
            let frame = HomePanelLayout.frame(presentation: presentation, screenFrame: screen,
                visibleFrame: screen, safeTopInset: 38, notch: camera)
            let anchor = try #require(HomeSpatialHintAnchor.make(presentation: presentation,
                panelFrame: frame, displayFrame: screen, cameraFrame: camera))
            #expect(anchor.displayFrame == screen)
            #expect(anchor.slot.midX == camera.midX - screen.minX)
            #expect(anchor.slot.minY >= camera.height)
            if presentation == .compact {
                #expect(anchor.slot.minY == frame.height)
                #expect(anchor.gap == 10)
            } else {
                #expect(anchor.slot.minY == camera.height)
                #expect(anchor.gap == 7)
            }
        }
    }

    @Test func detachedNearBottomMovesHintAbovePanelInsteadOfCoveringItsFooter() throws {
        let screen = CGRect(x: -1200, y: 0, width: 1200, height: 900)
        let frame = CGRect(x: -1100, y: 12, width: 840, height: 540)
        let anchor = try #require(HomeSpatialHintAnchor.make(presentation: .detached,
            panelFrame: frame, displayFrame: screen, cameraFrame: nil))
        #expect(anchor.slot.maxY <= screen.maxY - frame.maxY)
        #expect(anchor.slot.minX >= 12)
        #expect(anchor.slot.maxX <= screen.width - 12)
        #expect(HomeSpatialHintAnchor.make(presentation: .hidden,
            panelFrame: frame, displayFrame: screen, cameraFrame: nil) == nil)
    }

    @Test func externalCompactPlacesHintBelowCapsuleAndAwayFromMenuBar() throws {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 30, width: 1440, height: 842)
        let frame = HomePanelLayout.frame(presentation: .compact, screenFrame: screen,
            visibleFrame: visible, safeTopInset: 0)
        let anchor = try #require(HomeSpatialHintAnchor.make(presentation: .compact,
            panelFrame: frame, displayFrame: screen, cameraFrame: nil))
        #expect(anchor.slot.minY == screen.maxY - frame.minY)
        #expect(anchor.slot.minY > screen.maxY - visible.maxY)
    }

    @Test func noInvitationDuringConnectionPreparationReleaseOrCancellation() {
        for status in [SpatialContextRecorder.Status.idle, .preparing, .released, .discarded] {
            #expect(HomeSpatialHint.text(status: status, listening: true, sceneCount: 0, spanish: true) == nil)
        }
        for status in [SpatialContextRecorder.Status.recording, .limited] {
            #expect(HomeSpatialHint.text(status: status, listening: false, sceneCount: 2, spanish: true) == nil)
            #expect(HomeSpatialHint.text(status: status, listening: true, sceneCount: 2, spanish: true) != nil)
        }
        #expect(HomeSpatialHint.text(status: .recording, listening: true, sceneCount: 0, spanish: false)
            == "Point while speaking · Esc cancels")
        #expect(HomeSpatialHint.duration == 0.4)
        #expect(HomeSpatialHint.reducedDuration == 0.15)
    }

    @Test @MainActor func approvedUIIconsAreAvailableSystemSymbols() {
        for symbol in ["control", "option", "mic", "cursorarrow", "cursorarrow.motionlines",
                       "sidebar.left", "gearshape", "checkmark.circle.fill"] {
            #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil)
        }
    }
}
