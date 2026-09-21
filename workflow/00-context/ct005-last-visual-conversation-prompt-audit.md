# Last visual conversation prompt audit

Date: 2026-09-18
Status: superseded in part by the user's provider-vision decision on 2026-09-18
Related: tsk002, tsk003

> Superseding decision: the local Apple Vision OCR/hybrid resolver proposed in
> this audit was useful diagnostic work but is not the desired product
> architecture. The original codebase localized visible elements by asking its
> model provider to interpret the screenshot and return coordinates. Current
> Cursy restores that boundary with OpenAI as the active provider: the model
> interprets screen content, while native code validates capture, display,
> window identity, freshness and geometry. No local OCR or lexical target
> resolver remains. Future providers such as Claude must implement the same
> provider-neutral visual-location contract.

## Request summary

Analyze the effective prompts and runtime decisions from the most recent Cursy
conversation after the user reported that a requested named list item was visibly
present but Cursy answered verbally instead of pointing with the cursor.

## Evidence inspected

- Current Realtime system instructions, mandatory `resolve_visual_guidance` tool
  schema and post-tool continuation in `OpenAIRealtimeVoiceClient.swift`.
- Shared general screen policy, local OCR grounding, captured-window metadata,
  pointing validation and in-memory conversation replay.
- tsk002 and tsk003 execution records and current project logbook/dependencies.
- Content-free unified logs from the newest app process between 19:16 and 19:17.
- The user-provided screenshot. A local Apple Vision read-only check recognized
  the requested visible list label at confidence 1.0; the image was not persisted.

The app deliberately does not log transcript text, OCR strings, screenshots,
tool arguments or response prose. Therefore the exact spoken utterances and exact
image sent during that prior turn cannot be reconstructed after the fact. This is
a privacy constraint, not evidence that conversation continuity was absent.

## Verified facts

- The last process began with no replay history, accepted one visual point on
  display 1, then replayed two, three and four text history items in later turns.
  The conversation was not reset between those turns.
- Later captures were made on display 2 and each contained four captured windows
  plus 39-42 locally grounded OCR observations. The visual input was neither absent
  nor empty.
- The mandatory tool was called. One later turn returned `pointing_not_requested`;
  the final two returned `target_missing`. There was no local pointing-validation
  rejection for those final two turns because the model never proposed a point.
- The supplied screenshot visibly contains the requested named list item. Apple
  Vision recognizes the label in that screenshot, so `target_missing` is wrong for
  the demonstrated state. The screenshot remains a QA regression example, not an
  application-specific product rule.
- The prompt already says visible-target-first, point instead of verbal spatial
  directions, use exact OCR evidence, and use `no_point` only when a safe target is
  unavailable. Prompt wording alone did not enforce the intended semantic choice.
- `visualContinuationInstructions` contains the literal text
  `(voiceInstructions(for: language))` rather than Swift interpolation
  `\(voiceInstructions(for: language))`. The continuation therefore loses the base
  language, screen and cursor-first rules after the tool result.
- History replay is text-only and bounded. It correctly excludes old screenshots,
  coordinates, tool calls and accessibility metadata; each new turn receives a
  fresh capture.

## Inferences

- The primary failure is now semantic target resolution, not missing capture,
  optional tool use or empty OCR. The model is allowed to declare `target_missing`
  even when supplied evidence contradicts that result, and the client accepts that
  declaration without a deterministic local challenge.
- Prompt repetition and conservative validation wording may bias the model toward
  `no_point`, but current telemetry cannot prove which instruction caused the
  choice. The reason enum is too coarse to distinguish "not in image" from
  "visible but no matching evidence/window ID selected".
- Repeated replay lines with the same item count likely represent interrupted or
  restarted push-to-talk attempts. They do not by themselves prove duplicate
  history insertion.

## Reusable code and affected areas

- Reuse `ConversationSession.realtimeHistoryItems` for conversational intent and
  `VisualTurnContext` for fresh per-turn evidence.
- Reuse `ScreenTextGrounding`, captured-window IDs and `ElementLocationDetector`
  for deterministic verification; do not introduce application-specific matching.
- Affected areas: `OpenAIRealtimeVoiceClient.swift`, `VisualTurnContext.swift`,
  visual decision diagnostics, prompt-contract tests and a behavioral fixture set
  spanning list items, buttons, files, tabs and settings.

## Viable approaches

1. Minimal prompt repair: fix continuation interpolation, reduce duplicated rules
   and add more `no_point` reasons. Low risk, but still trusts the same model to
   contradict visible structured evidence.
2. Recommended hybrid resolver: have the model identify the requested semantic
   target/query, then resolve candidate OCR/window evidence locally. For a locate,
   show, indicate or find request, challenge `target_missing` when a unique visible
   candidate exists and only permit `no_point` after deterministic resolution
   fails. Keep the model for language understanding and local code for geometry.
3. Full visual-agent trace/evaluation layer: persist opt-in redacted fixtures and
   replay many model decisions. Best observability, but unnecessary before fixing
   the current contract and would broaden privacy/rollout scope.

## Complexity and risks

- Technical: 5/10 — change the decision contract without weakening safety.
- Integration: 5/10 — Realtime tool flow, OCR/window grounding and continuation.
- Testing: 6/10 — behavioral fixtures plus live multi-monitor acceptance.
- Rollout: 2/10 — native client only if the provider contract remains unchanged.
- Overall: 5/10.

Risks: false semantic matches, pointing at quoted text in another window, stale
geometry between capture and point, multilingual/name normalization, and logging
sensitive screen content. Preserve exact-window/topmost/freshness validation and
keep runtime telemetry content-free.

## Recommendation

Route as `$cce-quick-feature`, implemented as a refinement of active tsk002 rather
than a parallel application-specific ticket. CCE owner: `cce-ai-engineer` for the
model/tool decision contract. Companion skills: `write-swift` for the native
resolver and tests, and `openai-docs` for current Realtime structured-output rules.
Available tool categories: repository/source inspection, unified local logs,
Apple Vision diagnostics, Swift tests/type-checking and official OpenAI docs.

Ready-to-run next prompt:

`$cce-quick-feature Usa ct005 para reforzar la fase pendiente de tsk002 con un
resolver híbrido general: corrige la interpolación del prompt de continuación,
evita aceptar target_missing cuando una solicitud de señalamiento tiene un único
candidato visible verificable y añade fixtures generales sin reglas de WhatsApp.`
