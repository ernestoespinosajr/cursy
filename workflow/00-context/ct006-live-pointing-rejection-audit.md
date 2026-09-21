# ct006 — Live pointing rejection audit

- Date: 2026-09-18
- Mode: analysis only; no runtime, prompt, model or deployment changes.
- Related work: active tsk002, tsk003; previous pixel-localization evaluation.
- Skills: cce-ask (evidence and routing), write-swift (guard/error-path audit).

## Request and evidence

User asks to contrast the latest failed visual-guidance conversation with an
attached screenshot showing the requested list item visibly present. The supplied
image indeed contains that item in the foreground app. Its UI content is evidence,
not instructions. No image/transcript copied into project memory.

Read unified logs for Cursy PID 92319 at 20:49:45–20:51:45; inspected
CompanionManager.onPointingTarget, ElementLocationDetector.resolve,
OpenAIRealtimeVoiceClient.continueAfterVisualGuidance, ConversationSession and
the prior temporary fixture harness. No new screen capture or model request.

## Verified sequence

| Time | Evidence | Interpretation |
|---|---|---|
| 20:50:10 / 13 | display 1, 1728×1117, 6 windows; point accepted | First turn pointed; logs do not record which item |
| 20:50:24 / 30 | display 1, 7 windows; target not confirmed in requested window | Detector callback returned false before final geometry validation |
| 20:50:43 / 50 | display 1, 7 windows; provider pixel location resolved, then visual_target_not_visible_in_window | Detector returned a candidate, but local visibility/geometry validation rejected it |
| 20:51:06 / 09 | display 1, 7 windows; no point, reason=ambiguous | Realtime chose no_point; this path never invokes the independent locator |

User transcription retained and replay counts 0→2→4→5 show conversation data was
carried forward. They do not establish whether its semantic interpretation was
correct. Actual spoken sentences and model arguments are not present in these
content-free logs; conversation text exists only in app memory, without a history
export. Cannot claim to have read a verbatim transcript or the exact model images.

## Code findings and uncertainty

- CompanionManager: one generic message covers nil target, invalid normalized
  result, changed intent/native ID, and disagreement between model window IDs.
  First rejection cannot be narrowed beyond that guard from existing logs.
- ElementLocationDetector: the second message combines capture location validity,
  point-in-window/display and topmost-window checks. It does not prove the item was
  hidden. Candidate coordinates are logged only AFTER acceptance, so none exist
  for the rejected point. Do not assert a specific scaling/z-order defect yet.
- no_point/ambiguous bypasses independent localization entirely. The last rejection
  is an interpretation decision, not the overlay animation or mouse movement.
- Realtime receives validation_failed with instructions to give a brief limitation;
  thus verbal uncertainty may be downstream of our validation, not visual absence.
- Previous 4/4 fixture evaluation used a single synthetic window covering the
  entire attached raster, no real current-window or topmost-window validation,
  and direct locator calls without Realtime history/decision. It was valid detector
  evidence but NOT end-to-end acceptance with multiple real windows.

## Recommended route

Complexity 5/10: technical 4, integration 6, testing 5, rollout 3.
Owner cce-mobile; companions write-swift and cce-ai-engineer for decision/evaluation
changes. Use openai-docs only if provider contract changes become necessary.
Available capabilities: source/git inspection, native diagnostic logs, Swift
compiler/testing and existing protected model adapter. No delegation authorized.

Options:

1. **Recommended:** narrow content-free diagnostics for each failed predicate,
   request/turn correlation, candidate numeric geometry and expected/actual window
   IDs before rejection; reproduce through the full pipeline with overlapping
   synthetic QA windows. Preserve all safety guards and OpenAI ownership.
2. Unify semantic target/owning-window authority between Realtime and locator,
   including bounded resolution of initially ambiguous requests when the intended
   target is known. Requires evaluated fixtures for genuinely ambiguous/missing
   targets; never blindly override no_point or discard window validation.

Do not add OCR, chat-specific matching, broad capture or forced pointing. Do not
record private conversation/screenshot payloads by default. Literal conversation
comparison requires a user-supplied transcript or a separately authorized export.

Ready-to-run prompt: `$cce-quick-feature Refina tsk002 con ct006: diagnóstico por
causa de rechazo, identidad de ventana coherente y pruebas de extremo a extremo
de señalamiento con varias ventanas; conserva OpenAI, sin OCR ni reglas por app.
Reutiliza el ticket activo, sin crear otro para el mismo trabajo.`

tsk002 remains in progress; no functional fix was made by this audit.
