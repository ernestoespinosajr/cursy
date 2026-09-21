import Foundation
import CoreGraphics
import Testing
@testable import Cursy

@Suite("Selected text scope and placement")
struct SelectedTextContextTests {
    @Test func misplacedRangeUsesCurrentDragForPlacementOnly() {
        let window = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let staleRange = CGRect(x: 150, y: 600, width: 400, height: 40)
        let forward = SelectionPlacementEvidence.frame(reported: staleRange,
            start: CGPoint(x: 150, y: 450), end: CGPoint(x: 400, y: 400), window: window)
        let backward = SelectionPlacementEvidence.frame(reported: staleRange,
            start: CGPoint(x: 400, y: 400), end: CGPoint(x: 150, y: 450), window: window)
        #expect(forward == backward)
        #expect(forward.maxY == 464 && forward.minY == 386)
        #expect(!forward.intersects(staleRange))
    }
    @Test func genuineRangeGeometryIsPreservedAndForeignGestureIgnored() {
        let window = CGRect(x: -1000, y: -200, width: 1000, height: 800)
        let range = CGRect(x: -900, y: 200, width: 400, height: 60)
        #expect(SelectionPlacementEvidence.frame(reported: range,
            start: CGPoint(x: -890, y: 250), end: CGPoint(x: -510, y: 210), window: window) == range)
        #expect(SelectionPlacementEvidence.frame(reported: range,
            start: .zero, end: CGPoint(x: 400, y: 400), window: window) == range)
        #expect(SelectionPlacementEvidence.frame(reported: range, start: nil, end: nil, window: window) == range)
    }
    @Test func pointerFallbackAvoidsEntireMultilineDrag() {
        let end = CGPoint(x: 360, y: 100)
        let window = CGRect(x: 0, y: 0, width: 900, height: 700)
        let frame = SelectionPlacementEvidence.frame(reported: CGRect(x: 358, y: 98, width: 4, height: 4),
            start: CGPoint(x: 140, y: 190), end: end, window: window)
        #expect(frame.maxY == 204 && frame.minY == 86)
    }
    @Test func offsetMenuOverlappingFirstLineAnchorsTheWholeStack() throws {
        let selection = CGRect(x: 160, y: 100, width: 430, height: 65)
        let menu = CGRect(x: 5, y: 160, width: 365, height: 30)
        let result = try #require(SelectionPopoverLayout.frame(selection: selection,
            size: CGSize(width: 160, height: 32), visible: CGRect(x: 0, y: 0, width: 1000, height: 800), obstacles: [menu]))
        #expect(result.minY == menu.maxY + 12)
        #expect(result.midX == menu.midX)
        #expect(!result.intersects(selection) && !result.intersects(menu))
    }
    @Test func editorAndOfferBothClearMenusAtDisplayEdge() throws {
        let visible = CGRect(x: -1000, y: 0, width: 1000, height: 600)
        let selection = CGRect(x: -920, y: 480, width: 400, height: 60)
        let menu = CGRect(x: -980, y: 550, width: 390, height: 35)
        for size in [CGSize(width: 160, height: 32), CGSize(width: 370, height: 46)] {
            let result = try #require(SelectionPopoverLayout.frame(selection: selection, size: size, visible: visible, obstacles: [menu]))
            #expect(result.maxY == selection.minY - 12)
            #expect(visible.contains(result) && !result.intersects(menu) && !result.intersects(selection))
        }
    }
    @Test func unrelatedOrMalformedToolbarCannotDisplaceOffer() throws {
        let selection = CGRect(x: 150, y: 100, width: 300, height: 60)
        let menu = CGRect(x: 0, y: 720, width: 900, height: 50)
        #expect(!SelectionPlacementEvidence.isNearbyMenu(menu, selection: selection))
        #expect(!SelectionPlacementEvidence.isNearbyMenu(.infinite, selection: selection))
        let result = try #require(SelectionPopoverLayout.frame(selection: selection,
            size: CGSize(width: 160, height: 32), visible: CGRect(x: 0, y: 0, width: 1000, height: 800), obstacles: [menu]))
        #expect(result.minY == selection.maxY + 12 && result.midX == selection.midX)
    }
    @Test func accessibleTreeAlreadyEnabledIsNotChanged() {
        var calls = 0
        #expect(!SelectionAccessibilitySupport.activateIfNeeded(isEnabled: { true },
            isSettable: { calls += 1; return true }, enable: { calls += 1; return true }))
        #expect(calls == 0)
    }
    @Test func unsupportedAccessibilityInterfaceIsNotWritten() {
        var calls = 0
        #expect(!SelectionAccessibilitySupport.activateIfNeeded(isEnabled: { false },
            isSettable: { false }, enable: { calls += 1; return true }))
        #expect(calls == 0)
    }
    @Test func supportedAccessibilityInterfaceIsRequestedOnce() {
        var enabled = false
        var calls = 0
        for expected in [true, false] {
            let result = SelectionAccessibilitySupport.activateIfNeeded(isEnabled: { enabled },
                isSettable: { true }, enable: { calls += 1; enabled = true; return true })
            #expect(result == expected)
        }
        #expect(calls == 1)
    }
    @Test func rejectedAccessibilityRequestIsNotReportedAsEnabled() {
        #expect(!SelectionAccessibilitySupport.activateIfNeeded(isEnabled: { false },
            isSettable: { true }, enable: { false }))
    }
    @Test func delayedNotificationRetainsOnlyRecentGestureInSameApp() {
        let anchor = SelectionGestureAnchor(point: CGPoint(x: 40, y: 80), processID: 123, timestamp: 10)
        #expect(anchor.resolve(processID: 123, now: 10.4) == anchor.point)
        #expect(anchor.resolve(processID: 456, now: 10.4) == nil)
        #expect(anchor.resolve(processID: nil, now: 10.4) == nil)
        #expect(anchor.resolve(processID: 123, now: 11.1) == nil)
        #expect(anchor.resolve(processID: 123, now: 9) == nil)
    }
    @Test func geometryIsPreferredToMouseAnchor() throws {
        let bounds = CGRect(x: -900, y: 240, width: 500, height: 80)
        let evidence = try #require(SelectionEvidence.resolve(text: "Exact selection", bounds: bounds,
            pointerAnchor: CGPoint(x: -600, y: 260)))
        #expect(evidence.0.text == "Exact selection")
        #expect(evidence.1 == bounds)
    }
    @Test func confirmedTextCanUsePointerWithoutPretendingItIsAnExtent() throws {
        let evidence = try #require(SelectionEvidence.resolve(text: "A selected web fragment", bounds: nil,
            pointerAnchor: CGPoint(x: 400, y: 300)))
        #expect(evidence.1.midX == 400 && evidence.1.midY == 300)
        #expect(evidence.1.width == 4)
        #expect(SelectionEvidence.resolve(text: nil, bounds: nil, pointerAnchor: .zero) == nil)
        #expect(SelectionEvidence.resolve(text: "", bounds: nil, pointerAnchor: .zero) == nil)
    }
    @Test func keyboardDoesNotGuessMissingBounds() {
        #expect(SelectionEvidence.resolve(text: "Selected", bounds: nil, pointerAnchor: nil) == nil)
        #expect(SelectionEvidence.resolve(text: "Selected", bounds: .zero, pointerAnchor: nil) == nil)
    }
    @Test func rejectsMalformedGeometryAndOversizeText() {
        #expect(!SelectionEvidence.validBounds(.infinite))
        #expect(!SelectionEvidence.validBounds(.null))
        #expect(!SelectionEvidence.validBounds(CGRect(x: CGFloat.nan, y: 0, width: 10, height: 20)))
        #expect(SelectionEvidence.resolve(text: String(repeating: "a", count: 6001), bounds: nil, pointerAnchor: .zero) == nil)
    }
    @Test func exactTextWithoutSilentTruncation() {
        let text = "  Una idea.\nOtro párrafo 👩🏽‍💻  "
        #expect(SelectedTextContext(text: text)?.text == text)
        #expect(SelectedTextContext(text: "  \n") == nil)
        #expect(SelectedTextContext(text: String(repeating: "a", count: 6001)) == nil)
        #expect(SelectedTextContext(text: String(repeating: "👩🏽‍💻", count: 2000)) == nil)
    }
    @Test func selectionStartsIsolatedAndRestoresOnlyItsOwnHistory() throws {
        var session = ConversationSession()
        let oldTurn = session.beginTurn()
        session.setTranscript("Unrelated private chat", for: oldTurn)
        session.setResponse("Old answer", for: oldTurn)
        session.completeTurn(oldTurn)
        let oldID = session.id
        session.useSelection(try #require(SelectedTextContext(text: "Exact fragment")))
        #expect(session.id != oldID)
        #expect(session.requests.isEmpty && session.exchanges.isEmpty && session.objective == nil)
        #expect(session.realtimeHistoryItems.count == 1)
        let turn = session.beginTurn()
        session.setTranscript("Explain this", for: turn)
        let resumed = session.resumableSnapshot()
        #expect(resumed.selectedText?.text == "Exact fragment")
        #expect(resumed.activeTurnID == nil)
        #expect(resumed.requests.count == 1)
        session.reset()
        #expect(session.selectedText == nil)
        #expect(!session.isActive(turn))
    }
    @Test func chatSwitchKeepsSelectionScopeSeparate() throws {
        var library = HomeChatLibrary()
        var selected = ConversationSession()
        selected.useSelection(try #require(SelectedTextContext(text: "Selected only")))
        library.updateCurrent(selected)
        let selectedID = library.selectedID
        let created = library.create()
        #expect(created)
        library.updateCurrent(ConversationSession())
        #expect(library.records.last?.session.selectedText == nil)
        let restored = library.select(selectedID)
        #expect(restored?.selectedText?.text == "Selected only")
    }
    @Test func stacksAboveMenusAndFallsBelowWhenNecessary() throws {
        let screen = CGRect(x: -1200, y: -300, width: 1200, height: 900)
        let selection = CGRect(x: -1000, y: 100, width: 300, height: 60)
        let menu = CGRect(x: -1050, y: 170, width: 400, height: 45)
        let frame = try #require(SelectionPopoverLayout.frame(selection: selection, size: CGSize(width: 370, height: 46), visible: screen, obstacles: [menu]))
        #expect(frame.minY == menu.maxY + 12)
        #expect(!frame.intersects(menu) && !frame.intersects(selection))
        let highSelection = CGRect(x: -1000, y: 480, width: 300, height: 45)
        let highMenu = CGRect(x: -1050, y: 535, width: 400, height: 50)
        let below = try #require(SelectionPopoverLayout.frame(selection: highSelection, size: CGSize(width: 370, height: 46), visible: screen, obstacles: [highMenu]))
        #expect(below.maxY == highSelection.minY - 12)
    }
    @Test func rejectsCrowdedAndOffscreenPlacement() {
        let screen = CGRect(x: 0, y: 0, width: 300, height: 200)
        #expect(SelectionPopoverLayout.frame(selection: screen, size: CGSize(width: 200, height: 46), visible: screen, obstacles: []) == nil)
        #expect(SelectionPopoverLayout.frame(selection: screen.offsetBy(dx: 400, dy: 0), size: CGSize(width: 200, height: 46), visible: screen, obstacles: []) == nil)
    }
}
