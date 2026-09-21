import Foundation
import CoreGraphics
import Testing
@testable import Cursy

struct ScreenWindowGroundingTests {
    @Test func windowFrameValidationAllowsRoundingButRejectsMovement() {
        let captured = CGRect(x: -1920, y: -200, width: 1200, height: 800)
        #expect(ScreenWindowGrounding.framesMatch(captured,
            CGRect(x: -1919.5, y: -200.5, width: 1200.5, height: 799.5)))
        #expect(!ScreenWindowGrounding.framesMatch(captured,
            CGRect(x: -1900, y: -200, width: 1200, height: 800)))
    }

    @Test func accessibilityAndCaptureWindowNamespacesCorrelateConservatively() {
        let captured = CapturedWindowEvidence(
            id: "visual-window-42", windowID: 42, ownerPID: 7,
            applicationName: "Example", frame: CGRect(x: 100, y: 100, width: 900, height: 700))
        let nearbyAccessibilityFrame = CGRect(x: 108, y: 94, width: 888, height: 712)
        #expect(ScreenWindowGrounding.uniqueCapturedWindow(
            ownerPID: 7, accessibilityFrame: nearbyAccessibilityFrame,
            capturedWindows: [captured])?.id == "visual-window-42")
        #expect(ScreenWindowGrounding.uniqueCapturedWindow(
            ownerPID: 8, accessibilityFrame: nearbyAccessibilityFrame,
            capturedWindows: [captured]) == nil)

        let duplicate = CapturedWindowEvidence(
            id: "visual-window-43", windowID: 43, ownerPID: 7,
            applicationName: "Example", frame: CGRect(x: 110, y: 90, width: 890, height: 710))
        #expect(ScreenWindowGrounding.uniqueCapturedWindow(
            ownerPID: 7, accessibilityFrame: nearbyAccessibilityFrame,
            capturedWindows: [captured, duplicate]) == nil)
    }

    @Test func modelCoordinatesMustRemainInsideTheVerifiedWindowAndDisplay() {
        let display = CGRect(x: 1728, y: 0, width: 2560, height: 1440)
        let window = CGRect(x: 1900, y: 120, width: 1200, height: 900)
        let accepted = CGPoint(x: 2200, y: 600)
        #expect(ScreenWindowGrounding.validatedModelPoint(
            windowFrame: window, estimatedPoint: accepted, displayFrame: display) == accepted)
        #expect(ScreenWindowGrounding.validatedModelPoint(
            windowFrame: window, estimatedPoint: CGPoint(x: 3500, y: 600), displayFrame: display) == nil)
        #expect(ScreenWindowGrounding.validatedModelPoint(
            windowFrame: window, estimatedPoint: CGPoint(x: CGFloat.nan, y: 600), displayFrame: display) == nil)
    }
}
