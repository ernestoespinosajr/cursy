import AppKit
import Testing
@testable import Cursy

@Suite("Custom push-to-talk shortcuts")
struct HomeKeyboardShortcutTests {
    @Test func rejectsReservedAndUnmodifiedKeys() {
        #expect(HomeKeyboardShortcut.make(keyCode: 12, flags: .command, characters: "q") == nil)
        #expect(HomeKeyboardShortcut.make(keyCode: 49, flags: .command, characters: " ") == nil)
        #expect(HomeKeyboardShortcut.make(keyCode: 40, flags: [], characters: "k") == nil)
        #expect(HomeKeyboardShortcut.make(keyCode: 53, flags: .control, characters: "") == nil)
    }
    @Test func heldKeyAndModifierReleaseCannotLeaveRecordingStuck() throws {
        let shortcut = try #require(HomeKeyboardShortcut.make(keyCode: 40, flags: [.control, .shift], characters: "k"))
        #expect(shortcut.transition(type: .keyDown, keyCode: 40, flags: [.control, .shift], pressed: false) == .pressed)
        #expect(shortcut.transition(type: .keyDown, keyCode: 40, flags: [.control, .shift], pressed: true) == .none)
        #expect(shortcut.transition(type: .flagsChanged, keyCode: 59, flags: .shift, pressed: true) == .released)
        #expect(shortcut.transition(type: .keyUp, keyCode: 40, flags: [.control, .shift], pressed: true) == .released)
        #expect(shortcut.transition(type: .keyDown, keyCode: 40, flags: [.control, .shift, .command], pressed: false) == .none)
    }
}
