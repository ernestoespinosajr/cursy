import Foundation
import CoreGraphics
import Testing
@testable import Cursy

nonisolated private final class SelectionMenuFixture: SelectionMenuBackend {
    struct Item {
        var role: String
        var rect: CGRect
        var parent: Int?
        var children: [Int] = []
        var secure = false
    }
    var nodes: [Int: Item] = [:]
    var canContinue = true
    var probes = 0
    var hitNode = 2
    func hit(at point: CGPoint) -> Int? {
        probes += 1
        return nodes[1]?.rect.contains(point) == true ? hitNode : nil
    }
    func parent(of node: Int) -> Int? { nodes[node]?.parent }
    func children(of node: Int, offset: Int, limit: Int) -> [Int] {
        Array((nodes[node]?.children ?? []).dropFirst(offset).prefix(limit))
    }
    func role(of node: Int) -> String? { nodes[node]?.role }
    func bounds(of node: Int) -> CGRect? { nodes[node]?.rect }
    func isSecure(_ node: Int) -> Bool { nodes[node]?.secure == true }

    init(menu: CGRect, singleAction: Bool = false) {
        nodes[0] = Item(role: "AXWebArea", rect: CGRect(x: 0, y: 0, width: 1600, height: 900))
        nodes[1] = Item(role: "AXGroup", rect: menu, parent: 0, children: singleAction ? [2] : [2, 3])
        nodes[2] = Item(role: "AXButton", rect: menu.insetBy(dx: 12, dy: 4), parent: 1)
        if !singleAction { nodes[3] = Item(role: "AXButton", rect: menu.insetBy(dx: 12, dy: 4), parent: 1) }
    }
}

@Suite("Selection menu detection across accessible layouts")
struct SelectionMenuSearchTests {
    private let window = CGRect(x: 0, y: 0, width: 1600, height: 900)

    // Regression geometry from the user's Claude capture; names are fixtures only.
    @Test func claudeOffsetMenuIsFoundBetweenOldProbeColumns() throws {
        let selection = CGRect(x: 34, y: 250, width: 1525, height: 100)
        let menu = CGRect(x: 72, y: 366, width: 450, height: 46)
        let backend = SelectionMenuFixture(menu: menu)
        var detector = SelectionMenuSearch(backend: backend)
        let obstacles = detector.read(selection: selection, window: window)
        #expect(obstacles == [menu])
        let result = try #require(SelectionPopoverLayout.frame(selection: selection,
            size: CGSize(width: 160, height: 32), visible: window, obstacles: obstacles))
        #expect(result.midX == menu.midX && result.minY == menu.maxY + 12)
        #expect(!result.intersects(selection) && !result.intersects(menu))
    }
    @Test func outlookSingleActionKeepsItsWholeContainer() throws {
        let selection = CGRect(x: 22, y: 200, width: 574, height: 30)
        let menu = CGRect(x: 340, y: 234, width: 148, height: 42)
        let backend = SelectionMenuFixture(menu: menu, singleAction: true)
        var detector = SelectionMenuSearch(backend: backend)
        let obstacles = detector.read(selection: selection, window: window)
        #expect(obstacles == [menu])
        for width in [160.0, 370.0] {
            let result = try #require(SelectionPopoverLayout.frame(selection: selection,
                size: CGSize(width: width, height: 46), visible: window, obstacles: obstacles))
            #expect(result.minY == menu.maxY + 12 && !result.intersects(menu))
        }
    }
    @Test func singleActionInsideWrappersNeedsNoToolbarRole() {
        let menu = CGRect(x: 240, y: 250, width: 150, height: 36)
        let backend = SelectionMenuFixture(menu: menu, singleAction: true)
        backend.nodes[2]?.role = "AXUnknown"
        backend.nodes[2]?.children = [4]
        backend.nodes[4] = .init(role: "AXGroup", rect: menu.insetBy(dx: 10, dy: 2), parent: 2, children: [5])
        backend.nodes[5] = .init(role: "AXButton", rect: menu.insetBy(dx: 12, dy: 3), parent: 4)
        backend.hitNode = 1
        var detector = SelectionMenuSearch(backend: backend)
        #expect(detector.read(selection: CGRect(x: 100, y: 180, width: 500, height: 50), window: window) == [menu])
    }
    @Test func staticTextAndProtectedControlsAreNotMenus() {
        let menu = CGRect(x: 150, y: 250, width: 200, height: 30)
        let backend = SelectionMenuFixture(menu: menu, singleAction: true)
        backend.nodes[2]?.role = "AXStaticText"
        var textDetector = SelectionMenuSearch(backend: backend)
        #expect(textDetector.read(selection: CGRect(x: 100, y: 180, width: 500, height: 50), window: window).isEmpty)
        backend.nodes[2]?.role = "AXButton"
        backend.nodes[2]?.secure = true
        var secureDetector = SelectionMenuSearch(backend: backend)
        #expect(secureDetector.read(selection: CGRect(x: 100, y: 180, width: 500, height: 50), window: window).isEmpty)
    }
    @Test func denseStripCoversOffsetSingleActionSizes() {
        let selection = CGRect(x: 34, y: 200, width: 1500, height: 70)
        let probes = SelectionMenuSearch<SelectionMenuFixture>.probePoints(selection: selection, window: window)
        for x in stride(from: 0.0, through: 1520, by: 53) {
            for offset in stride(from: -24.0, through: 88, by: 13) {
                let menu = CGRect(x: x, y: selection.maxY + offset, width: 60, height: 18)
                #expect(probes.contains(where: { menu.contains($0) }))
            }
        }
    }
    @Test func cancellationAndMalformedSpansStopBeforeIPC() {
        let backend = SelectionMenuFixture(menu: CGRect(x: 200, y: 250, width: 150, height: 36))
        backend.canContinue = false
        var detector = SelectionMenuSearch(backend: backend)
        #expect(detector.read(selection: CGRect(x: 100, y: 180, width: 500, height: 50), window: window).isEmpty)
        #expect(backend.probes == 0)
        #expect(SelectionMenuSearch<SelectionMenuFixture>.probePoints(selection: .infinite, window: window).isEmpty)
    }
    @Test func negativeDisplayOriginPreservesMenuAnchoring() {
        let display = window.offsetBy(dx: -1600, dy: -200)
        let selection = CGRect(x: -1500, y: 100, width: 1000, height: 70)
        let menu = CGRect(x: -1450, y: 180, width: 210, height: 30)
        let backend = SelectionMenuFixture(menu: menu, singleAction: true)
        backend.nodes[0]?.rect = display
        var detector = SelectionMenuSearch(backend: backend)
        #expect(detector.read(selection: selection, window: display) == [menu])
    }
}
