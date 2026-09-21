import Foundation
import CoreGraphics
import Testing
@testable import Cursy

nonisolated private final class SelectionTreeFixture: SelectionSearchBackend {
    struct Item {
        var parent: Int?
        var children: [Int] = []
        var role = "AXGroup"
        var secure = false
        var text: String?
        var bounds: CGRect? = CGRect(x: 100, y: 200, width: 120, height: 20)
    }
    var items: [Int: Item] = [0: Item(role: "AXWindow")]
    var canContinue = true
    var sampled: [Int] = []
    func add(_ node: Int, parent: Int = 0, role: String = "AXGroup", text: String? = nil) {
        items[node] = Item(parent: parent, role: role, text: text)
        items[parent]?.children.append(node)
    }
    func parent(of node: Int) -> Int? { items[node]?.parent }
    func children(of node: Int, offset: Int, limit: Int) -> [Int] {
        Array((items[node]?.children ?? []).dropFirst(offset).prefix(limit))
    }
    func role(of node: Int) -> String? { items[node]?.role }
    func isSecure(_ node: Int) -> Bool { items[node]?.secure == true }
    func selectedText(in node: Int, anchor: CGPoint?) -> (SelectedTextContext, CGRect)? {
        sampled.append(node)
        return SelectionEvidence.resolve(text: items[node]?.text, bounds: items[node]?.bounds, pointerAnchor: anchor)
    }
}

@Suite("Selection reader traversal and lifecycle")
struct SelectedTextSearchTests {
    @Test func fullWebRangeWinsOverIndividualFragment() {
        let tree = SelectionTreeFixture()
        tree.add(1, role: "AXWebArea", text: "Whole selected range")
        for node in 2...18 { tree.add(node, parent: node - 1) }
        tree.add(19, parent: 18, role: "AXStaticText", text: "fragment")
        var search = SelectionTreeSearch(backend: tree)
        #expect(search.read(window: 0, hit: 19, focused: nil, anchor: nil)?.0.text == "Whole selected range")
        #expect(tree.sampled.first == 1)
    }
    @Test func menuFocusDoesNotHideDeepDocumentOrLaterSiblings() {
        let tree = SelectionTreeFixture()
        tree.add(1, role: "AXMenu")
        for node in 2...80 { tree.add(node) }
        for node in 81...100 { tree.add(node, parent: node - 1) }
        tree.add(101, parent: 100, role: "AXWebArea", text: "Selected in document")
        var search = SelectionTreeSearch(backend: tree)
        #expect(search.read(window: 0, hit: 1, focused: 1, anchor: nil)?.0.text == "Selected in document")
    }
    @Test func confirmedWebTextWithoutBoundsUsesGestureButNotKeyboard() {
        let tree = SelectionTreeFixture()
        tree.add(1, role: "AXWebArea", text: "Exact text")
        tree.items[1]?.bounds = nil
        var keyboard = SelectionTreeSearch(backend: tree)
        #expect(keyboard.read(window: 0, hit: nil, focused: 1, anchor: nil) == nil)
        var mouse = SelectionTreeSearch(backend: tree)
        #expect(mouse.read(window: 0, hit: nil, focused: 1, anchor: CGPoint(x: 80, y: 90))?.1.midX == 80)
    }
    @Test func selectionOutsideOriginatingWindowIsNotRead() {
        let tree = SelectionTreeFixture()
        tree.items[2] = .init(role: "AXWindow")
        tree.add(3, parent: 2, role: "AXWebArea", text: "Other window")
        var search = SelectionTreeSearch(backend: tree)
        #expect(search.read(window: 0, hit: 3, focused: 3, anchor: .zero) == nil)
        #expect(!tree.sampled.contains(3))
    }
    @Test func protectedInputBlocksDocumentFallback() {
        let tree = SelectionTreeFixture()
        tree.add(1, role: "AXWebArea", text: "Stale range")
        tree.add(2, parent: 1, role: "AXTextField", text: "Protected")
        tree.items[2]?.secure = true
        var search = SelectionTreeSearch(backend: tree)
        #expect(search.read(window: 0, hit: 2, focused: 2, anchor: .zero) == nil)
        #expect(tree.sampled.isEmpty)
    }
    @Test func protectedSubtreesArePruned() {
        let tree = SelectionTreeFixture()
        tree.add(1, role: "AXTextField")
        tree.items[1]?.secure = true
        tree.add(2, parent: 1, role: "AXStaticText", text: "Protected")
        var search = SelectionTreeSearch(backend: tree)
        #expect(search.read(window: 0, hit: nil, focused: nil, anchor: nil) == nil)
        #expect(!tree.sampled.contains(2))
    }
    @Test func traversalHasFiniteNodeAndCycleLimits() {
        let tree = SelectionTreeFixture()
        for node in 1...600 { tree.add(node, role: "AXStaticText") }
        tree.items[10]?.children = [0]
        var search = SelectionTreeSearch(backend: tree)
        #expect(search.read(window: 0, hit: nil, focused: nil, anchor: nil) == nil)
        #expect(search.reachedLimit)
        #expect(search.visitedCount <= 512)
    }
    @Test func cancelledOrExpiredBackendDoesNotRead() {
        let tree = SelectionTreeFixture()
        tree.add(1, role: "AXWebArea", text: "Selected")
        tree.canContinue = false
        var search = SelectionTreeSearch(backend: tree)
        #expect(search.read(window: 0, hit: 1, focused: 1, anchor: .zero) == nil)
        #expect(tree.sampled.isEmpty)
    }
    @Test func warmupDoesNotRestartRemoteDebounce() {
        var warmup = SelectionAccessibilityWarmup()
        var requests = 0
        let enable = { requests += 1; return true }
        #expect(warmup.prepare(processID: 1, now: 10, isEnabled: { false }, isSettable: { true }, enable: enable) == 12.3)
        #expect(warmup.prepare(processID: 1, now: 11, isEnabled: { false }, isSettable: { true }, enable: enable) == 12.3)
        #expect(warmup.prepare(processID: 1, now: 13, isEnabled: { true }, isSettable: { true }, enable: enable) == 13)
        #expect(requests == 1)
        _ = warmup.prepare(processID: 2, now: 13, isEnabled: { false }, isSettable: { true }, enable: enable)
        #expect(requests == 2)
    }
    @Test func unsupportedOrFailedWarmupDoesNotClaimReadinessDelay() {
        var warmup = SelectionAccessibilityWarmup()
        var calls = 0
        #expect(warmup.prepare(processID: 1, now: 10, isEnabled: { false }, isSettable: { false }, enable: { calls += 1; return true }) == 10)
        #expect(calls == 0)
        #expect(warmup.prepare(processID: 2, now: 10, isEnabled: { false }, isSettable: { true }, enable: { false }) == 10)
    }
    @Test func menuNotificationsCoalesceButNewInputRevokesOldResult() throws {
        var lifecycle = SelectionReadLifecycle()
        let firstToken = lifecycle.begin()
        let first = try #require(firstToken)
        #expect(lifecycle.begin() == nil)
        #expect(lifecycle.generation == first)
        lifecycle.invalidate()
        let secondToken = lifecycle.begin()
        let second = try #require(secondToken)
        let staleFinished = lifecycle.finish(first)
        #expect(!staleFinished)
        #expect(lifecycle.isReading)
        let currentFinished = lifecycle.finish(second)
        #expect(currentFinished)
        #expect(!lifecycle.isReading)
    }
}
