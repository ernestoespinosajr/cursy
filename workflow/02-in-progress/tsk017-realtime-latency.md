# tsk017 — Captura inmediata y menor latencia de respuesta

Status: in-progress · Priority: high · Created/started: 2026-09-20
Authorization: user requests a new ticket, deeper design and implementation.
Complexity: 8/10 (audio lifecycle7, integration8, testing8, rollout6).
Owner: CCE Mobile + Write Swift; CCE AI Engineer / OpenAI Docs for API contracts.
Execution: serial, no delegation. Related: tsk003, tsk006, tsk007, ct017.

## 1. Purpose

Reduce PTT→first captured PCM and release→first spoken audio without model changes
or weakening visual publication validation. Fast feedback must represent real state.

## 2. Needs

User speaks immediately, may release before network readiness, cancel, interrupt,
switch microphones or start a new turn. No ambient recording or added permission.
Internal prototype first; perceptual and physical QA remains a manual gate.

## 3. Requirements / non-goals

- Capture on explicit PTT before waiting for broker/socket/history.
- Bound unsent PCM in memory; preserve ordering and minimum100ms rule.
- Stop capture synchronously on release; exactly one eventual commit/response.
- Keep listening based on actual samples, not animation/network status.
- Instrument numeric monotonic phase durations, no content/credentials.
- Overlap independent release work; preserve screen consent/turn ownership.
- Do not change providers/models, deploy Worker, port tsk007 visual design,
  add hot-mic, speculative paid calls or permanent background sessions.

## 4. Evidence / history

Current start waits broker → socket/session.update → history → microphone.
Finish drains send queue then captures screen then commits audio and asks model.
Existing RealtimeCapture logs: capture78–121ms; capture-ready→visual decision
2.665–4.377s; one locator/publication interval4.347s. These are not isolated
inference measurements or a statistically representative latency benchmark.
tsk002 required visual decision after optional tooling produced false guidance;
do not simply change required to auto. Response already streams PCM chunks.
HeyClicky changelog confirms prewarming/routing, not its implementation details.

## 5. Boundaries

OpenAIRealtimeVoiceClient owns capture/transport lifetime. Add a pure bounded
RealtimeInputDelivery state to isolate preconnection buffering/release/flush.
Existing ordered sendTail retains transport order. Manager owns user intent and
turn IDs; release no longer implies cancel network startup if PCM was accepted.
SpatialTrailView receives listening gate, including audio route recovery.
No second audio engine owner, no new backend or package.

## 6. State / contracts

Input delivery: accepting → released; transport can become ready before/after
release. Pending bytes flush once when configured; post-release input ignored.
Cancellation clears buffers and invalidates generation. Preconnection cap20s
(960KB of24kHz mono16-bit), total turn120s; network startup deadline20s.
Short/no-sample releases discard. Startup failure after capture cannot silently
switch provider and lose speech: report retry instead. Existing permission flow
is retained. No schema or persistent migration.
Official contract checked: append → commit → response.create, VAD disabled;
commit/transcription separate from response generation:
https://developers.openai.com/api/docs/guides/realtime-conversations#handling-audio-with-websockets

## 7. Privacy / safety

Capture only while held, including network stalls. RAM only, bounded buffers,
clear on cancel/error/new turn. No auto-retry with a different capture owner after
speech has begun. No screen permission expansion. Current target/freshness and
response gates unchanged. Generic labels/counts/times only in diagnostics.

## 8. Reliability / metrics

Record startup, mic-start, first PCM, broker-ready, session configuration sent,
release, capture-ready, commit, response request, visual decision/localization,
first output chunk and playback scheduling. Unique random trace per turn.
Target (not measured promise): internal mic first PCM p95<250ms after granted
permissions; remove network from that critical path. Compare release→first audio
p50/p95 on same network/device/questions; no accuracy regression allowed.
Cancel/timeout/stale callbacks cannot resurrect recording or speech.

## 9. Dependencies

Existing AVFoundation, URLSession, Worker ephemeral broker and Realtime model.
Reuse responseGate, capture slot, visual freshness/localizer and regression runner.
macOS14.2+, current Swift5 mode; no concurrency-setting migration or xcodebuild.

## 10. Phases / rollout / rollback

F1 now: measured early capture + bounded delivery + short/released/cancel/error
lifecycle, readiness notification gate. Offline tests and native compilation.
F2 now: overlap screenshot with pending audio sends; commit audio without waiting
for screenshot. Keep response.create after all context. Instrument unchanged
decision/localization/speech to establish baseline.
F3 after physical baseline: evaluate fast conversation routing and connection
reuse/prewarming; must not let unvalidated visual confirmations enter speech.
No keyword-only bypass or new heavyweight router by default. Alternative is
keep mandatory decision and reduce its output after provider quality evaluation.
Proposed test set: simple conversation, explanation of visible content, explicit
pointing, absent target, follow-up after scroll, multiscene gestures (5 each).
Required: zero false publication confirmations; no regression in accepted QA;
compare time to useful answer, not filler speech. Live evaluation needs explicit
test data/provider-call consent. Warm sessions need idle/cost/privacy policy.
Rollback: revert only this ticket's native hunks/new files, preserve dirty tree.
Do not reset repository or unrelated UI changes. No launch/deployment this turn.

## 11. Gates / documentation

Automated: ordering both readiness/release orders, once-only finish, sub100ms,
caps, cancellation/reset, stale ownership guards, phase-timing tests, existing
visual/audio regressions. Xcode UI Build if available, never terminal xcodebuild.
Manual gate: internal mic/Bluetooth, cold/warm starts, release while connecting,
offline, rapid PTT/cancel, screen on/off and multiscene; measure before F3.
Document results and residual risks in this ticket and scripts/VOICE_LATENCY_QA.md.
Keep in progress until physical/performance and F3 disposition are resolved.

Dispatch: `$cce-dispatch tsk017` — implement F1/F2, preserve models and safety
gates, stop at the documented live evaluation gate with truthful evidence.

## Execution record — 2026-09-20

F1/F2 implemented, offline verified, physical acceptance pending. No model,
Worker, paid evaluation or prototype-animation changes. Ticket stays in progress.

- Local capture starts before awaiting broker; generation-guarded setup has a
  20 s deadline. RealtimeInputDelivery bounds preconnection PCM to 960,000 bytes
  and total accepted PCM to 5,760,000 bytes across route changes. Release closes
  the mailbox and stops input now, retaining valid audio for a single later flush
  and finish. Short taps discard. Cancellation releases pending PCM/image state.
- Startup failures after early capture do not start a replacement legacy recorder.
  Manager also clears the now-possible preconnection gesture/observation. A queued
  response.cancel cannot target a replacement session.
- Release begins screen capture independently of pending connection/audio sends.
  Commit happens after FIFO PCM; context is then delivered before response.create.
  Visual decision, localization, freshness and responseGate remain authoritative.
- Content-free VoiceLatency phases use monotonic uptime and first-occurrence
  timestamps. Completion/failure/discard are terminal, not miscounted as cancellation
  during cleanup. Spatial hint is gated by actual listening state, including recovery.

Changed files: Cursy/OpenAIRealtimeVoiceClient.swift, RealtimeInputDelivery.swift,
CompanionManager.swift, SpatialTrailView.swift, OverlayWindow.swift;
CursyTests/RealtimeInputDeliveryTests.swift; scripts/VOICE_LATENCY_QA.md,
scripts/README.md; AGENTS.md architecture/index. Paths relative to cursy-app.
Workflow logbook/dependencies updated in project root.

Validation:

- `bash cursy-app/scripts/test-native-regressions.sh`: native module compiles;
  **168 tests in 21 suites pass** (13 added), 0.928 s test execution.
  Artifacts: `/private/tmp/cursy-native-regression.MFbEX9/`.
  First sandbox attempt failed to launch Swift macro plugins (sandbox_apply),
  not application compilation. Authorized unsandboxed offline runner then found
  mutating-value assertions incompatible with macro expansion; corrected tests
  and reran successfully. Existing unrelated compiler warnings preserved.
- Xcode UI Cmd+B on Cursy/My Mac: **Build Succeeded**, observed 10:10 PM.
  Did not Run, use terminal xcodebuild, record microphone or call providers.
- `git diff --check`: clean for tracked changes.
- Reviewed ownership after each network/capture suspension, release before/after
  setup, capture failure during route recovery, and screen-consent cancellation.
  Pure delivery/clock tests are not full AVFoundation/WebSocket integration tests.

Residual gates: run VOICE_LATENCY_QA on real hardware; compare readiness and
release-to-first-audio p50/p95 with failures counted separately. No speedup number
or instantaneous-response claim is established. Slow connections can age release
captures; existing refresh/rejection must still protect pointing. F3 is unimplemented
pending measured baseline, provider evaluation and any warm-session policy choice.

Lesson: moving capture earlier changes failure and release ownership, not just
the order of two calls; preserve first words and clean up gestures on startup errors.
Manual VAD permits commit before screenshot readiness without requesting speech.
Reference: https://developers.openai.com/api/docs/guides/realtime-conversations#handling-audio-with-websockets
