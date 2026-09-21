import Foundation
import CoreGraphics
import SwiftUI
import Testing
@testable import Cursy

@Suite("Home hover and camera silhouette")
struct HomeHoverPolicyTests {
    private func intent(_ presentation: HomePresentation = .expanded,
                        trigger: Bool = false, panel: Bool = false,
                        busy: Bool = false, dragging: Bool = false,
                        suppressed: Bool = false, voiceOver: Bool = false,
                        closing: Bool = false) -> HomeHoverIntent {
        HomeHoverPolicy.intent(presentation: presentation, inTrigger: trigger,
            inPanel: panel, busy: busy, dragging: dragging, suppressed: suppressed,
            voiceOver: voiceOver, closing: closing)
    }

    @Test func hiddenOpensOnlyAtCamera() {
        #expect(intent(.hidden, trigger: true) == .open)
        #expect(intent(.hidden) == .none)
        #expect(intent(.hidden, panel: true) == .none)
        #expect(intent(.hidden, trigger: true, dragging: true) == .none)
        #expect(intent(.hidden, trigger: true, suppressed: true) == .none)
    }

    @Test(arguments: [HomePresentation.compact, .expanded])
    func keepVisibleWhileUsed(presentation: HomePresentation) {
        #expect(intent(presentation) == .hide)
        #expect(intent(presentation, trigger: true) == (presentation == .compact ? .open : .none))
        #expect(intent(presentation, panel: true) == .none)
        #expect(intent(presentation, busy: true) == .none)
        #expect(intent(presentation, dragging: true) == .none)
        #expect(intent(presentation, voiceOver: true) == .none)
    }

    @Test func detachedNeverAutoHidesOrReattaches() {
        #expect(intent(.detached) == .none)
        #expect(intent(.detached, trigger: true) == .none)
    }

    @Test func autoCloseCanReverseButExplicitDismissalCannot() {
        #expect(intent(.hidden, panel: true, closing: true) == .open)
        #expect(intent(.hidden, panel: true, suppressed: true, closing: true) == .none)
        #expect(intent(.hidden, panel: true, dragging: true, closing: true) == .none)
    }

    @Test func exitGraceIsLongerThanEntryDwell() {
        #expect(HomeHoverPolicy.openDelay > 0)
        #expect(HomeHoverPolicy.hideDelay > HomeHoverPolicy.openDelay)
        #expect(HomeHoverPolicy.hideDelay < 1.5)
    }

    @Test func setupKeepsHomeVisibleWithoutBlockingExplicitClose() {
        for presentation in [HomePresentation.expanded, .compact] {
            #expect(HomeHoverPolicy.intent(presentation: presentation, inTrigger: false, inPanel: false,
                busy: false, dragging: false, suppressed: false, voiceOver: false, setupRequired: true) == .none)
        }
        #expect(HomeHoverPolicy.intent(presentation: .hidden, inTrigger: true, inPanel: false,
            busy: false, dragging: false, suppressed: true, voiceOver: false, setupRequired: true) == .none)
    }

    @Test func statusItemUsesOneHomeAndExpandsTheVoiceIsland() {
        #expect(HomePresentation.afterStatusItemClick(from: .hidden) == .expanded)
        #expect(HomePresentation.afterStatusItemClick(from: .compact) == .expanded)
        #expect(HomePresentation.afterStatusItemClick(from: .expanded) == .hidden)
        #expect(HomePresentation.afterStatusItemClick(from: .detached) == .hidden)
    }

    @Test func settingsSurfaceIncludesHelpAndRoutesSetupToPermissions() {
        #expect(HomeSidebarSection.settingsLanding(needsSetup: true) == .privacy)
        #expect(HomeSidebarSection.settingsLanding(needsSetup: false) == .general)
        #expect(HomeSidebarSection.allCases == [.chats, .general, .voice, .microphone, .shortcuts, .cursor, .privacy, .help])
        #expect(HomeSidebarSection.help.title(spanish: true) == "Ayuda")
        #expect(HomeSidebarSection.help.title(spanish: false) == "Help")
    }

    @Test(arguments: [CGFloat(320), 620])
    func cameraNeckHasOpenShoulders(width: CGFloat) {
        let bounds = CGRect(x: -80, y: 30, width: width, height: 84)
        let path = HomeSurfaceShape(notchWidth: 208).path(in: bounds)
        #expect(path.contains(CGPoint(x: bounds.midX, y: bounds.minY + 1)))
        #expect(!path.contains(CGPoint(x: bounds.minX + 28, y: bounds.minY + 1)))
        #expect(!path.contains(CGPoint(x: bounds.maxX - 28, y: bounds.minY + 1)))
        #expect(path.contains(CGPoint(x: bounds.minX + 28, y: bounds.minY + 30)))
        #expect(path.boundingRect == bounds)
    }

    @Test func noCameraUsesFloatingRoundedSurface() {
        let bounds = CGRect(x: 0, y: 0, width: 620, height: 430)
        let path = HomeSurfaceShape(notchWidth: 0).path(in: bounds)
        #expect(path.contains(CGPoint(x: 30, y: 1)))
        #expect(path.boundingRect == bounds)
    }
}
