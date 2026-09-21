import AppKit
import SwiftUI
import Testing
@testable import Cursy

struct VisualAnnotationTests {
    @Test(arguments: VisualAnnotationStyle.allCases)
    func presentationUsesAgentChoice(style: VisualAnnotationStyle) {
        #expect(VisualAnnotationStyle.resolve(agentChoice: style) == style)
    }

    @Test func missingAgentChoiceUsesCursor() {
        #expect(VisualAnnotationStyle.resolve(agentChoice: nil) == .cursor)
    }

    @Test(arguments: VisualAnnotationStyle.allCases)
    func explicitStyleSurvivesNativeAndGenericRouting(style: VisualAnnotationStyle) throws {
        let context = VisualTurnContext(captureID: "capture", displayID: 1,
            displayFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), capturedAt: .now,
            imageData: Data(), imageWidth: 1440, imageHeight: 900)
        for native in [false, true] {
            let data = try JSONSerialization.data(withJSONObject: [
                "action": "point", "reason": "target_visible", "captureID": "capture",
                "targetQuery": "Show the requested control", "annotationStyle": style.rawValue,
                "nativeControlID": native ? "fixture-close" : "",
                "intent": native ? "close_window" : "other", "label": "Control"
            ])
            let decision = try JSONDecoder().decode(VisualGuidanceDecision.self, from: data)
            switch try decision.route(for: context) {
            case .native(let target):
                #expect(native)
                #expect(target.annotationStyle == style)
            case .localize(let request):
                #expect(!native)
                #expect(request.annotationStyle == style)
                #expect(request.targetQuery == "Show the requested control")
            case .conversation: Issue.record("Visual request lost")
            }
        }
    }

    @Test func styleDecodingDefaultsAndRejectsUnknownValues() throws {
        for style in [nil, "automatic", "unsupported"] as [String?] {
            var payload = ["action": "no_point", "reason": "target_missing", "captureID": "capture"]
            payload["annotationStyle"] = style
            let data = try JSONSerialization.data(withJSONObject: payload)
            if style == "unsupported" {
                #expect(throws: (any Error).self) { try JSONDecoder().decode(VisualGuidanceDecision.self, from: data) }
            } else {
                #expect(try JSONDecoder().decode(VisualGuidanceDecision.self, from: data).annotationStyle == nil)
            }
        }
    }

    @Test(arguments: [CGRect(x: 0, y: 0, width: 1440, height: 900),
                      CGRect(x: -1920, y: -300, width: 1920, height: 1080),
                      CGRect(x: 200, y: 900, width: 1280, height: 720)])
    func displayMappingAndEdgeLabels(frame: CGRect) throws {
        for local in [CGPoint(x: 0, y: 0), CGPoint(x: frame.width - 1, y: frame.height - 1),
                      CGPoint(x: frame.width / 2, y: frame.height / 2)] {
            let point = CGPoint(x: frame.minX + local.x, y: frame.maxY - local.y)
            let annotation = try #require(VisualAnnotation(style: .arrow, point: point, displayFrame: frame, label: "Target"))
            #expect(annotation.localPoint == local)
            let size = CGSize(width: 240, height: 54)
            let center = annotation.labelCenter(size: size)
            #expect(center.x - size.width / 2 >= 0)
            #expect(center.x + size.width / 2 <= frame.width)
            #expect(center.y - size.height / 2 >= 0)
            #expect(center.y + size.height / 2 <= frame.height)
            #expect(CGRect(origin: .zero, size: frame.size).contains(annotation.arrowTail))
        }
    }

    @Test func malformedPresentationIsRejected() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        for point in [CGPoint(x: CGFloat.infinity, y: 10), CGPoint(x: -1, y: 10), CGPoint(x: 10, y: 801)] {
            #expect(VisualAnnotation(style: .circle, point: point, displayFrame: frame, label: "Target") == nil)
        }
        #expect(VisualAnnotation(style: .circle, point: CGPoint(x: 20, y: 20), displayFrame: frame, label: "") == nil)
    }

    @Test func adaptiveBoundsNeverInventExtentFromPoint() throws {
        let display = CGRect(x: -1200, y: 100, width: 1200, height: 800)
        let region = CGRect(x: -1000, y: 500, width: 700, height: 90)
        let point = CGPoint(x: -700, y: 530)
        let annotation = try #require(VisualAnnotation(style: .rectangle, point: point,
            displayFrame: display, label: "Paragraph", region: region))
        #expect(annotation.localRegion == CGRect(x: 200, y: 310, width: 700, height: 90))
        #expect(annotation.focusBounds.contains(try #require(annotation.localRegion)))
        #expect(VisualAnnotation(style: .rectangle, point: point, displayFrame: display, label: "Unknown extent")?.style == .cursor)
        #expect(VisualAnnotation(style: .circle, point: point, displayFrame: display, label: "Unknown extent")?.style == .cursor)
        #expect(VisualAnnotation(style: .rectangle, point: point, displayFrame: display,
            label: "Invalid", region: CGRect(x: -1300, y: 500, width: 700, height: 90)) == nil)
    }

    @Test func ellipseContainsCornersAndFallsBackAtDisplayEdge() throws {
        let display = CGRect(x: 0, y: 0, width: 900, height: 700)
        for region in [CGRect(x: 200, y: 200, width: 160, height: 40), CGRect(x: 0, y: 200, width: 160, height: 40)] {
            let annotation = try #require(VisualAnnotation(style: .circle, point: CGPoint(x: region.midX, y: region.midY),
                displayFrame: display, label: "Control", region: region))
            #expect(annotation.usesEllipse == (region.minX > 0))
            if annotation.usesEllipse {
                let local = try #require(annotation.localRegion)
                let oval = annotation.ellipseBounds
                let normalizedCorner = pow((local.minX - oval.midX) / (oval.width / 2), 2)
                    + pow((local.minY - oval.midY) / (oval.height / 2), 2)
                #expect(normalizedCorner <= 1)
            }
        }
    }

    @Test func fullRegionOcclusionRejectsEvenWithVisibleCenter() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let window = CapturedWindowEvidence(id: "window", windowID: 1, ownerPID: 1, applicationName: "", frame: display)
        let region = CGRect(x: 100, y: 100, width: 500, height: 80)
        let point = CGPoint(x: 350, y: 140)
        let occluder = CapturedWindowEvidence(id: "other", windowID: 2, ownerPID: 2, applicationName: "",
            frame: CGRect(x: 100, y: 100, width: 40, height: 80))
        #expect(ScreenWindowGrounding.regionIsVisible(region, point: point, window: window,
            displayFrame: display, currentWindows: [window]))
        #expect(!ScreenWindowGrounding.regionIsVisible(region, point: point, window: window,
            displayFrame: display, currentWindows: [occluder, window]))
        #expect(!ScreenWindowGrounding.regionIsVisible(region, point: point, window: window,
            displayFrame: display, currentWindows: []))
    }

    @Test func drawingTipAndInkShareProgress() throws {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        for style in [VisualAnnotationStyle.circle, .rectangle, .arrow] {
            let annotation = try #require(VisualAnnotation(style: style, point: CGPoint(x: 400, y: 400),
                displayFrame: display, label: "Control", region: CGRect(x: 300, y: 350, width: 200, height: 100)))
            let drawing = AnnotationDrawing(annotation: annotation)
            for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let elapsed = VisualAnnotationMotion.drawingStart + fraction * VisualAnnotationMotion.draw
                #expect(abs(VisualAnnotationMotion.inkProgress(elapsed, reducedMotion: false) - fraction) < 0.0001)
                if style == .rectangle {
                    let expected: CGFloat = annotation.focusBounds.minX + annotation.focusBounds.width * fraction
                    #expect(abs(drawing.tip(progress: fraction).x - expected) < 0.0001)
                } else {
                    #expect(drawing.tip(progress: fraction) == drawing.tracedPoints(progress: fraction).last)
                }
            }
        }
        #expect(VisualAnnotationMotion.draw == 1)
        #expect(VisualAnnotationMotion.inkProgress(0, reducedMotion: true) == 1)
    }

    @Test func typingUsesWholeGraphemesAndFinishesWithinOneSecond() {
        let text = "¡Bien! 👩🏽‍💻 Revisa aquí."
        #expect(VisualAnnotationMotion.visibleText(text, elapsed: 0, reducedMotion: false).isEmpty)
        #expect(VisualAnnotationMotion.visibleText(text, elapsed: 4, reducedMotion: false) == text)
        #expect(VisualAnnotationMotion.visibleText(text, elapsed: 0, reducedMotion: true) == text)
        let partial = VisualAnnotationMotion.visibleText(text, elapsed: 0.5, reducedMotion: false)
        #expect(text.hasPrefix(partial))
        #expect(VisualAnnotationMotion.typingDuration(String(repeating: "a", count: 120)) == 1)
    }

    @Test func labelHasNoArtistGeometryAndPrefersAboveTarget() throws {
        let annotation = try #require(VisualAnnotation(style: .label, point: CGPoint(x: 400, y: 400),
            displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800), label: "Context",
            region: CGRect(x: 300, y: 350, width: 200, height: 100)))
        #expect(AnnotationDrawing(annotation: annotation).path(progress: 1).isEmpty)
        let size = CGSize(width: 220, height: 34)
        let expectedBottom: CGFloat = 338
        #expect(abs(annotation.labelCenter(size: size).y + size.height / 2 - expectedBottom) < 0.0001)
    }
}
