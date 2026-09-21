import Testing
@testable import Cursy

struct ScreenContextPolicyTests {
    @Test func sharedGuidanceIsNotSpecificToAnApplicationOrChat() {
        // Prompt-contract regression check, not a claim of model-behavior coverage.
        let instructions = ScreenContextPolicy.instructions.lowercased()
        #expect(!instructions.contains("whatsapp"))
        #expect(!instructions.contains("requested chat"))
        #expect(!instructions.contains("conversation name"))
        #expect(instructions.contains("for every application and task"))
        #expect(instructions.contains("verbal spatial directions are not a successful substitute for the cursor"))
        #expect(instructions.contains("point first"))
    }

    @Test func focusedWindowSurvivesEnumerationLimit() {
        let windows = ScreenContextPolicy.focusedFirst([1, 2, 3, 4, 5], focused: 5, matches: ==)
        #expect(Array(windows.prefix(4)) == [5, 1, 2, 3])
        #expect(windows.filter { $0 == 5 }.count == 1)
    }

    @Test func focusedWindowMissingFromEnumerationIsIncluded() {
        #expect(ScreenContextPolicy.focusedFirst([1, 2], focused: 7, matches: ==) == [7, 1, 2])
        #expect(ScreenContextPolicy.focusedFirst([1, 2], focused: nil, matches: ==) == [1, 2])
    }
}
