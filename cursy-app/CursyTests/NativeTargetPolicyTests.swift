import Testing
@testable import Cursy

struct NativeTargetPolicyTests {
    @Test func dockRequiresItsOwnVerifiedID() {
        #expect(NativeTargetPolicy.isValid(intent: "dock_application", controlID: "dock-1-2-dockapp"))
        #expect(!NativeTargetPolicy.isValid(intent: "dock_application", controlID: nil))
        #expect(!NativeTargetPolicy.isValid(intent: "dock_application", controlID: "1-0-close"))
        #expect(!NativeTargetPolicy.isValid(intent: "other", controlID: "dock-1-2-dockapp"))
    }

    @Test func windowControlsAndGenericTargetsRemainDistinct() {
        #expect(NativeTargetPolicy.isValid(intent: "close_window", controlID: "1-0-close"))
        #expect(!NativeTargetPolicy.isValid(intent: "close_window", controlID: "dock-1-2-dockapp"))
        #expect(NativeTargetPolicy.isValid(intent: "other", controlID: ""))
        #expect(!NativeTargetPolicy.isValid(intent: "open_app", controlID: ""))
    }
}
