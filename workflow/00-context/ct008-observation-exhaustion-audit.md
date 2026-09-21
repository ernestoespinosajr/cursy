# ct008 — Live observation exhaustion audit

- Date: 2026-09-18
- Mode: analysis only; no runtime, prompt, deployment or permission changes.
- Related: tsk002 / ct007, tsk003 conversation continuity.
- Skills: cce-ask for evidence/routing; write-swift for event/state review.

## Request and inspected evidence

User supplied the console output from the first live test of bounded visual
observation and asked to review the conversation. Read the supplied attachment,
VisualObservation, capture utility, Realtime event handlers, manager callbacks,
ConversationSession and observation fixtures. Existing dirty tree preserved.
No new screenshot, microphone capture, model request or credential access.

The attachment contains character counts, not literal user/assistant utterances.
ConversationSession stores text only in process memory; this audit did not extract
that memory. Thus exact wording and the actual images seen by the model are unknown.

## Verified findings

- Two requests captured display 1 at 1728×1117 with five visible windows. Initial
  capture latency was approximately 277 ms and 89 ms. This is not evidence of
  which application/item occupied that display; it is not a second-monitor test.
- Both observation IDs refreshed at revision 1/count 1 and revision 2/count 2,
  then ended with reason=exhausted. Neither log sequence contains a point accepted,
  point rejected, or resolved no_point event. This is refresh-budget exhaustion
  before a recorded final visual decision, not a demonstrated coordinate error.
- Each request logged four assistant transcript callbacks: 109/105/89/111 and
  62/92/74/142 characters. The log named "response completed" is printed by
  onTranscriptCompleted, not by the response.done/session completion handler.
  It cannot establish that four separate user turns completed or every audio
  buffer was heard. Replay changed 0→2 text items, indicating history was sent,
  but does not establish its semantic correctness.
- OpenAIRealtimeVoiceClient's audio/transcript handlers permit events while
  didPoint=false without requiring didResolveVisualGuidance. Tool decisions are
  processed later, on response.done. Thus intermediate audio can play and its
  transcript can be appended before pointing/refresh resolution. The supplied
  ordering demonstrates pre-resolution transcript callbacks.
- refreshIfNeeded runs before applying a visual tool decision. Before verify sets
  a target, comparisonRegion is the whole display. geometryChanged also checks
  every captured window and its order. Unrelated changes can consume retries;
  refresh sets target=nil and restores whole-display comparison.
- Native cursor is hidden and Cursy's own windows are excluded from screenshots.
  Do not assume its cursor animation is the direct pixel-change source.
- Current invalidation logs do not distinguish scroll events, changed raster
  region, window identity/order/geometry or torn capture. JPEG byte counts alone
  cannot establish a meaningful scene change.

## Hypotheses, not established causes

Background animation or unrelated window content may trigger these refreshes.
If Xcode's console was visible on the captured display, repeated sample logging
could itself change the captured pixels and create feedback. Neither hypothesis
is proved without region/reason diagnostics or the actual captured frames.
The generic Intents/layout/audio warnings do not establish causation for this
visual failure. Audio capture and model responses proceeded in both requests.

## Recommended correction and alternatives

Complexity 5/10 (technical 5, integration 6, tests 5, rollout 2).
Owner: cce-mobile; companion write-swift. Add cce-ai-engineer/openai-docs if changing
provider response contracts. Available capabilities: local source/git inspection,
Swift compiler/testing and existing native logs. No delegation authorized.

1. Recommended: refine existing tsk002, not a new subsystem. Separate visual
   decision/refresh from authorized spoken continuation in the event state
   machine. Reject intermediate audio/transcripts from playback AND replay history.
   Add content-free invalidation reasons, scoped geometry and changed-region
   metrics. Use current target/application scope when known, without assuming the
   foreground window is always the requested target. Test irrelevant animation,
   visible debug-console feedback and real target scroll across multiple apps.
2. Temporary diagnostic comparison: turn off "Actualizar indicación" and repeat
   a stationary-target request. This isolates the added observation loop but is
   not a solution and does not validate moving targets.

Do not merely increase retry/time limits, drop current-window validation, add OCR,
or introduce contact/application-specific rules. Literal transcript comparison
requires user-supplied text or a separately scoped diagnostic export; never start
persistent private transcript logging by default.

Ready-to-run: `$cce-quick-feature Refina tsk002 usando ct008: bloquear voz e historial
intermedios durante decisiones visuales, diagnosticar invalidaciones por causa y
evitar refrescos por cambios ajenos al objetivo; conservar captura actualizada,
límites, OpenAI y validación geométrica, sin OCR ni reglas por aplicación.`

tsk002 remains in progress; previous isolated test success does not cover this
live mixed audio/tool event sequence or real animated-desktop invalidation.
