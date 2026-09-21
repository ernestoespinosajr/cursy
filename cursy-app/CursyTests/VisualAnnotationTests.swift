import AppKit
import Testing
@testable import Cursy

struct VisualAnnotationTests {
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
}
