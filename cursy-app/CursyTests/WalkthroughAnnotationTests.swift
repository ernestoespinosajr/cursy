import CoreGraphics
import Foundation
import Testing
@testable import Cursy

@MainActor
struct WalkthroughAnnotationTests {
    @Test(arguments: [CGPoint.zero, CGPoint(x: -1400, y: -500), CGPoint(x: 100, y: 900)])
    func dragGroupConnectsVerifiedEndpointsAndKeepsFullRegions(origin: CGPoint) throws {
        let frame = CGRect(origin: origin, size: CGSize(width: 1200, height: 900))
        let source = WalkthroughPlan.Indication(kind: .circle, role: .source, targetQuery: "File", caption: "Take this")
        let route = WalkthroughPlan.Indication(kind: .arrow, role: .route, targetQuery: "Source to destination", caption: "Drag")
        let destination = WalkthroughPlan.Indication(kind: .rectangle, role: .destination, targetQuery: "Folder", caption: "Drop here")
        let step = WalkthroughPlan.Step(instruction: "Move the file", successCriterion: "File is inside destination",
            requiresExplicitConfirmation: false, indications: [source, route, destination])
        let first = CGPoint(x: frame.minX + 100, y: frame.minY + 500)
        let last = CGPoint(x: frame.minX + 900, y: frame.minY + 300)
        let paragraph = CGRect(x: frame.minX + 600, y: frame.minY + 200, width: 500, height: 180)
        let resolved: [WalkthroughAnnotations.Resolved] = [
            .init(indication: source, point: first, region: CGRect(x: first.x - 30, y: first.y - 20, width: 60, height: 40)),
            .init(indication: destination, point: last, region: paragraph)
        ]
        let marks = WalkthroughAnnotations.make(step: step, resolved: resolved, displayFrame: frame)
        #expect(marks.count == 3)
        #expect(marks[1].routeStart == first)
        #expect(marks[1].point == last)
        #expect(marks[1].arrowTail == CGPoint(x: 100, y: 400))
        #expect(marks[2].region == paragraph)
        #expect(WalkthroughAnnotations.make(step: step, resolved: Array(resolved.prefix(1)), displayFrame: frame).isEmpty)
    }
}
