import Foundation
import Testing
@testable import Cursy

struct VisualGuidanceOutcomeTests {
    @Test func combinedRequestAllowsExplanationOnlyAfterPublication() throws {
        let text = try VisualGuidanceOutcome.published.toolOutput(language: .spanish, requestMode: .explainAndLocate)
        let result = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        #expect(result["request_mode"] as? String == "explain_and_locate")
        #expect(result["spoken_reply"] == nil)
        #expect(result["pointed"] as? Bool == true)
        let rejected = try VisualGuidanceOutcome.rejected(.invalidCoordinates)
            .toolOutput(language: .spanish, requestMode: .explainAndLocate)
        #expect(rejected.contains("failed validation"))
    }
    private func output(_ outcome: VisualGuidanceOutcome) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(outcome.toolOutput(language: .spanish).utf8)) as? [String: Any])
    }

    @Test(arguments: [PointingRejection.providerNoTarget, .invalidCoordinates, .sceneChanged,
                      .providerFailure, .malformedProviderResponse, .staleTurn, .invalidNativeTarget])
    func rejectionReasonSurvivesTheVoiceBoundary(reason: PointingRejection) throws {
        let outcome = VisualGuidanceOutcome.rejected(reason)
        let result = try output(outcome)
        #expect(result["pointed"] as? Bool == false)
        #expect(result["reason"] as? String == reason.rawValue)
        #expect(result["spoken_reply"] == nil)
        #expect(outcome.suppressesContinuation == (reason == .staleTurn))
    }

    @Test func missingGestureAndProviderNoTargetAreDistinctFromInvalidCoordinates() throws {
        let missing = try output(.rejected(.providerNoTarget, spatial: .promptBudgetExceeded))
        #expect(missing["reason"] as? String == "providerNoTarget")
        #expect(missing["spatial_evidence"] as? String == "promptBudgetExceeded")
        #expect((missing["instruction"] as? String)?.contains("pointer evidence was unavailable") == true)
        let delivered = try output(.rejected(.providerNoTarget, spatial: .attached))
        #expect((delivered["instruction"] as? String)?.contains("not invalid coordinates") == true)
        #expect((delivered["instruction"] as? String)?.contains("pointer evidence was unavailable") == false)
        let geometry = try output(.rejected(.invalidCoordinates, spatial: .attached))
        #expect((geometry["instruction"] as? String)?.contains("failed validation") == true)
    }

    @Test func onlyPublicationAllowsTheExactConfirmation() throws {
        let result = try output(.published)
        #expect(result["pointed"] as? Bool == true)
        #expect(result["spoken_reply"] as? String == "Ahí está.")
        #expect(VisualGuidanceOutcome.published.isPublished)
        #expect(!VisualGuidanceOutcome.published.suppressesContinuation)
    }

    @MainActor @Test func explanatoryContinuationIsSeparateFromPointingFailure() {
        let instructions = OpenAIRealtimeVoiceClient.visualContinuationInstructions(for: .spanish)
        #expect(instructions.contains("reason is pointing_not_requested, answer the actual question"))
        #expect(instructions.contains("comparison does not require highlighting"))
        #expect(instructions.contains("Otherwise, if pointed is false"))
        #expect(instructions.contains("current image and any valid spatial evidence"))
    }
}
