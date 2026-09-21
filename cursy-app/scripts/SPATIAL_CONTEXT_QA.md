# tsk006 — Spatial input QA (not yet accepted)

## Current integration

Build/run the Cursy scheme from Xcode; never terminal xcodebuild. In the menu,
enable Share screen, then **Contexto espacial · Beta / Spatial context · Beta**.
The separate setting defaults OFF. During Control+Option Talk, wait for the
“Point while speaking” notice, then point at or circle an element **without
clicking** and say e.g. “What does this do?” or “Show me this control”. Release.
During Talk, Escape cancels that turn, not the conversation history. Disabling spatial input
also cancels its pending turn. Existing cursor style/voice transport are unchanged.

The input trace is different from tsk005's AI-generated output annotations.
The path is direct feedback, no opening animation, works with Reduce Motion;
the status has a solid variant for Reduce Transparency. The overlay remains
click-through and excluded from capture. Plain spoken descriptions still work.

## Actual privacy and bounds

- Only opt-in Talk, after input-ready: local pointer sampling up to 30 Hz, for 30 s.
- Clean local screenshots: on arming, after a 500 ms quiet period following an
  invalidation, then at most once/second in a stable scene. No model call per move.
- One current scene plus up to two verified earlier scenes of the SAME held Talk,
  not a video stream. Scroll, display/app/geometry/content changes end a segment
  and clear the live trail. Only a checkpoint verified by a matching periodic image
  can be retained for historical interpretation. Samples after that capture began
  are not silently carried over. Unverified short gestures may be omitted.
- On release, sampling stops; a fresh screenshot must match geometry and path
  region. Otherwise no path is sent, and context asks for clarification when needed.
- Realtime sends the clean current image plus <=128 normalized timestamped points
  and, when valid and within budget, a gesture-marked copy of that SAME image.
  Magenta represents user input, not a verified AI output. The clean image is
  unchanged; ALL encoded images together are <=3 MiB, reference dimensions
  <=2048 each. Invalid ownership/revision/path or refresh excludes the reference.
  This can increase image inference cost/latency; no live measurements yet.
  Fallback and locator still send one image. Locator metadata reuses its prepared raster size.
  Historical scenes arrive as separately labelled clean/reference pairs, oldest to
  newest, followed by CURRENT. At most three scenes/six images, 128 points per scene.
  Current evidence has priority; entire old pairs are omitted under budget and
  omissions are disclosed. No old coordinates or native/window IDs enter publication.
  Fallback/locator cannot compare history: they explicitly retain current-only context.
  Max 512 live local points, bounded decimation. Optional metadata never truncates JSON
  to satisfy the existing 16k-character locator prompt limit.
- No disk storage or coordinate/transcript logging. Buffers are purged on consume,
  reset, cancellation, revocation or 30 s deadline. No background recording at rest.
- New-conversation/reset and late callbacks cannot transfer a trace to another turn.
  Underlying cursor-screen capture is single-flight even after a wrapper timeout.
- The existing provider selection, output validation and observation budget remain.
  Refreshed screenshots do not inherit spatial paths.

Realtime can receive verified earlier gestures across scenes/monitors within one
held Talk. This increment is implemented and offline-tested, NOT yet semantically
accepted. Crossing displays restarts the live trail on the new monitor; it never
draws the previous trail there. Gestures during preparation are not retained.
Text selection/drag changes still invalidate the current segment; no drag-to-mark
mode. No history crosses turns. A visual refresh discards the earlier sequence.

For manual multiscene QA, hold Talk, point/circle in scene A long enough for a
periodic checkpoint (about one second after preparation), then scroll or move to
another monitor and point in scene B. Ask to compare the first indicated item
with the second, then release. Expect the earlier-scene counter, no stitched trail,
and a comparison of the supplied images, not an assertion that A is still visible.
Repeat with a very brief first gesture, >3 scenes, Escape and new conversation:
omitted evidence must not be invented. A request to mark A requires finding it
again on the current screen, never using its historical coordinates.

## Offline evidence

`bash cursy-app/scripts/test-native-regressions.sh` from repository root.
Tests use synthetic pixels, clocks, pointer positions and mocked URLSession only.
They cover geometry, caps, revisions, release/cancellation, permission, capture
serialization and provider-neutral transport. They do NOT evaluate semantic model
understanding, physical latency, accessibility rendering or actual microphones.

## Manual regression checklist

1. With flag off, ordinary Talk and accepted pointing still work; no spatial trail.
2. Point at a generic button and ask what it does, then circle an image and ask
   about it. Repeat with text and a diagram detail. These are explanations, not
   highlight requests: expect an answer, not a safe-highlighting error. Then ask
   explicitly to indicate a location, and separately to explain AND indicate it.
   Only the latter two request output marks. Compare two regions of the SAME scene. Test ES and EN.
3. Scroll, move/resize/occlude a window while holding Talk: old trail disappears;
   new evidence only after preparation. Repeat on negative-origin/external monitors.
4. Cross displays while speaking; only the new display's verified path survives.
   Disconnect/rearrange a monitor. Never display an old path on a different scene.
5. Release immediately; remain stationary; speak >30 s; no phantom path or cut audio.
6. Escape, reset conversation, disable screen sharing/flag, lock/sleep and interrupt
   with another utterance. No old overlay, capture or answer may revive.
7. Denied/revoked permissions and capture timeout: voice recovers, no old geometry.
8. AirPods + built-in mic; transient cursor mode; click-through; Reduce Motion,
   Reduce Transparency, high contrast, keyboard and VoiceOver preference navigation.

## Provider admission and remaining gates

Not run. With explicit authorization for provider cost, use 20 synthetic scenarios
three times each: buttons, files, settings, tabs, list rows, image details, diagrams,
charts, background windows, ambiguous duplicates, absent targets, text paragraphs,
two same-scene regions, stationary pointer, circle path, changing scene, secondary
display, Retina, near-edge target and no gesture. Keep expected referent/rectangle
outside prompts; score interpretation separately from coordinate publication.

Gate: >=90% resolved nonambiguous requests and zero incorrect published targets
in that sample, not a universal guarantee. Rejections are reported separately.
Measure local-feedback and preparation p50/p95 over >=30 physical interactions;
targets <=50 ms feedback and <=300 ms added preparation remain UNMEASURED.
Finish multi-segment semantic evaluation, user interaction choice and live acceptance
before closing tsk006. tsk005 remains independently pending.

Rollback: switch spatial input OFF. No deployment or provider change was required.

## ct013 refinement — reading the next attempt

Native diagnostics now use category `SpatialInput` and fixed states. Filter this
category alongside `PointingValidation`/`RealtimeCapture` in Console or Xcode.

- `attachment`: whether the final image received the path; reasons include
  noSamples, expired, captureFailed, geometryChanged, regionChanged and permissionRevoked.
- `realtimePrepared` / `realtimeSent`: the actual current image message preparation
  and completion of its WebSocket send. This is NOT proof of model understanding.
- `referencePrepared`: whether the gesture-marked reference copy was included,
  with byte count and display/capture IDs only. `Visual request mode` distinguishes
  explain, locate, explain_and_locate and legacy decisions. An explanatory mode
  must not invoke the locator merely because targetQuery contains a description.
- `historyPrepared`: historical pair count, omitted count, total encoded image
  bytes and local message-preparation milliseconds. It does not measure capture,
  visible feedback, network/model latency or semantic accuracy.
- `locatorPrepared` / `locatorCompleted`: packet inclusion in the prepared-raster
  request and completion of HTTP analysis. `promptBudgetExceeded`/`packetTooLarge`
  explicitly mean the path was omitted. No old path survives `sceneRefreshed`.
- `fallbackPrepared` / `fallbackCompleted`: equivalent conversational context
  preparation/response in the legacy path. These do not prove correct semantics.
- Publication outcomes preserve `providerNoTarget`, scene/geometry rejection and
  technical failure. No-target is no longer logged as local coordinate validation.

Only app IDs, enum reasons, display/revision, counts and context size are logged;
no trace points, screenshots, transcription or model labels. The locator still
has a 16k UTF-16 prompt budget; optional packet omission is whole, never partial JSON.
Explanation without requested pointing may answer normally (the previous final
instruction incorrectly forced a limitation whenever pointed was false).

New offline fixtures exercise the production locator request with synthetic button,
image-detail and diagram content plus budget omission; HTTP returns a mocked null.
They validate transport/raster/rejection handling, NOT semantic model success.
Do not ask for final user acceptance until the authorized provider evaluation
and remaining tsk006 gates have been addressed. No paid calls have been run here.

## Reproducible local preparation benchmark

After the native runner, pass its absolute artifact directory to
`bash cursy-app/scripts/benchmark-spatial-preparation.sh <artifact-directory>`
from repository root. This compiles a separate fixture program, with no app launch,
screen capture, credentials or network. It runs 30 samples for one scene and 30 for
three scenes, each 1920x1200 and 128 points, reporting p50/p95/max and JSON bytes.
This is NOT a complete end-to-end or physical UI benchmark and imposes no flaky
timing assertions on unit tests. Model cost/precision and physical feedback need
their separate authorized evaluation.
