# tsk003 — Typed in-memory session core

Status: completed
Date: 2026-09-18
Owner: cce-mobile + write-swift; coordinator integration, bounded delegated core/tests.

Current phase: user accepted continuity, interruption and new-conversation reset
on 2026-09-19. Integration and automated regressions complete.
Historical gaps below are superseded by the later implementation entries.

## 1. Goals
Associate voice turn, screen capture and response with explicit IDs; retain a
bounded conversation independently of provider. Reject stale turn updates.
Explicit objective storage only; do not infer a walkthrough goal.

## 2. Experience
No new visible controls or motion. Existing PTT/cursor remains unchanged.
Cancellation and new turns supersede old work; no persistence after app exit.

## 3. Design
Value-type ConversationSession with typed state/turn IDs, current turn, optional
objective, last ten exchanges and capture metadata (never image/audio bytes).
CompanionManager owns session; existing provider generation guards remain.

## 4. Dependencies
tsk002 visual delivery accepted by user and completed on 2026-09-18.
Its closure unblocks continued session work; this ticket retains its own live
continuity/reset/cancellation gate and is not implicitly closed by that acceptance.
Reuse existing Realtime transport and VisualTurnContext; no provider/API change.

## 5. Implementation
Core and pure tests in isolated files; coordinator integrates manager lifecycle,
fallback history and Realtime response/capture metadata. No PCM lifecycle edits,
new network endpoints or deployment.

## 6. Validation
Core executable tests: supersession, stale IDs, reset, history bounds, capture.
Swift type-check app/test files; git diff check. Live PTT regression remains a
manual acceptance gate before completion. Rollback limited to integration/core.
No autonomous steps, disk history or cross-session restoration in this ticket.

## Execution

- Bounded parallel agent implemented ConversationSession and six Swift Testing
  cases; coordinator integrated CompanionManager lifecycle and capture references.
- Session/turn IDs, forward states, supersession, cancellation/failure, explicit
  optional objective and last ten complete exchanges implemented. No image/audio
  storage. Fallback history now comes from session; async transcript/capture
  updates and pointer acceptance check active turn and capture ID.
- Realtime assistant transcript is explicitly treated as assistant output.
  Current transport does NOT provide user transcription; no fabricated user
  exchange and no full Realtime conversational continuity claimed. Adding that
  transport contract and replaying conversation context remains a next phase.
- Pure tests executed: 6/6 session plus 2/2 focus-policy tests through temporary
  SPM harness. Swift module emission excluding Sparkle entry passes with existing
  warnings. Relevant native tests type-check. No audio-engine/cursor changes.
- Still in progress: live PTT/cancel/fallback regression acceptance and complete
  Realtime history contract. This is the integrated foundation, not walkthroughs.

## Realtime continuity implementation

- Scope explicitly expanded by user approval: user transcription, text history
  replay and new-conversation reset. Optional editable objective added to menu;
  not inferred automatically. No PCM engine/routing/cursor changes.
- session.update enables gpt-4o-mini-transcribe with selected es/en language.
  Track committed item_id; completed/failed transcription settles only matching
  turn once. Output transcripts stay separate and deduplicate by item_id.
- After output playback, wait at most 3 seconds for missing transcription; failure/
  timeout shows local notice, never invents a complete exchange. Cancellation
  resets deadline and state; existing transport generation guards remain.
- Each new socket replays at most ten user/assistant text pairs and optional
  explicit objective before microphone starts. No image/coordinate/tool replay.
  Fallback and its detector also receive shared history/objective.
- Menu: optional objective and New conversation/Nueva conversación. Reset cancels
  all current tasks/voice, clears local session, transcript, notice and pointing.
  Not a request to delete provider-side data. History remains memory-only.
- Official reference verified: https://developers.openai.com/api/reference/resources/realtime/client-events
  (transcription config and input_text/output_text message content), and
  https://developers.openai.com/api/docs/guides/realtime-transcription
  (item_id correlation and asynchronous completion ordering).
- Validation: app module emits successfully except excluded Sparkle entry with
  existing warnings; isolated 13-test suite passes, including duplicate/foreign/
  expired transcript and text-only replay/reset fixtures. No live mic/API test.
- Manual gate remains: two consecutive voice turns with "ya lo abrí, ¿qué sigue?",
  new conversation reset, AirPods stability, delayed/failed transcription notice.
  No automatic walkthrough, disk persistence or autonomous app action.

## Failed live continuity test and follow-up

- User reports correct WhatsApp Dock pointing, request for a manual screenshot,
  then loss of the requested chat name after saying WhatsApp was open on display 2.
- No persisted conversation transcript exists to reconstruct the exact provider
  exchange. Source evidence: only completed pairs entered replay; an interrupted
  answer could discard an already-transcribed user request. This is a verified
  failure path, not proof that it caused this particular live failure.
- Retain at most ten transcribed user requests independently of completed answers;
  replay user-only requests if interrupted, never fabricate assistant completion.
  Reset clears both lists; stale turn updates still rejected. No image/audio storage.
- Shared guidance explicitly forbids requesting manual screenshots, describes
  automatic capture on shortcut release and uses the pending goal for follow-ups.
  Current capture remains cursor display only: move pointer to the target display.
  Continuous observation/automatic walkthrough remains unimplemented.
- Added content-free diagnostic logs for replay count, retained transcript and
  transcript timeout. Missing transcription before interruption remains a limit.
- Isolated Swift Testing harness: 15/15 passed, including interrupted WhatsApp
  follow-up, bounded requests and reset. Live voice acceptance remains pending.

## Resumed hardening and reproducible QA — 2026-09-18

User requests resuming tsk003 after closing tsk002. CCE Dispatch/Mobile and
Write Swift guide value ownership, bounded memory and revalidation after await.
No new ticket, provider selection, deployment, cursor/PCM changes or delegation.

- Reviewed the integrated core, replay, manager lifecycle and existing fixtures.
  Realtime continuity was already connected; do not implement a second session
  store or imply automatic walkthroughs. Legacy fallback keeps completed pairs;
  Realtime additionally replays already-transcribed interrupted requests.
- Added immutable ConversationTurnContext (sessionID + turnID). Realtime startup
  snapshots history/language before scheduling and verifies ownership before and
  after await, including error cleanup. A stale startup cannot fail/cancel a newer
  session or initiate fallback. Legacy startup/submission and response-task entry
  also validate ownership; late fallback cleanup cannot set another turn to idle.
- Disabling visual refresh now cancels pending Realtime startup as well as the
  active client. New conversation also clears stale visual notices/audio level.
  No changes to AVAudioEngine or provider WebSocket protocol.
- Core—not just UI/replay—enforces ten retained requests/exchanges, 8,000 characters
  per retained transcript/answer (including deltas), 2,000 per explicit objective.
  Cancelled/failed partial answers never become completed exchanges. Session reset
  replaces identity and removes requests, exchanges, objective and current turn.
- Removed raw legacy-transcript console output; log only length. No user payloads,
  screen images, audio or credentials stored in task records.
- Added pure ownership/terminal-state/bounds/empty-input tests plus general editor
  two-turn replay and eviction tests. Existing concrete chat fixture remains QA
  data only; no app-specific production behavior.
- Added scripts/test-session-core.sh, SessionTestRunner.swift and SESSION_QA.md.
  Repeatable pure test command: `bash cursy-app/scripts/test-session-core.sh`.
  17 tests/2 suites pass, including three parameterized terminal-state cases.
- Full native source module/library compiled with swiftc in language mode5,
  excluding only CursyApp.swift/Sparkle entry point. Sandbox initially blocked Apple
  macro plugins; approved compiler execution outside sandbox succeeded with existing
  warnings. No xcodebuild, app launch, TCC changes or microphone/Keychain/API access.
  Expanded isolated regression:71 tests/11 suites pass; includes session/replay,
  visual observation, geometry and mocked VisionAPI. Not the entire Xcode UI suite.
  Artifacts: /private/tmp/cursy-tsk003-build.CkYFqu.

Remaining manual gate: run latest app in Xcode, two consecutive requests retaining
the target, interrupted reply, New conversation/reset while waiting, short PTT
and normal AirPods/language/display regression. Checklist: scripts/SESSION_QA.md.
Transcription absent/late past deadline cannot be recovered; app must disclose it.
Do not close tsk003 from tsk002's pointing acceptance or isolated tests alone.

## Acceptance — 2026-09-19

User explicitly marked the three session checks verified: follow-up retains the
objective, interruption preserves context, and New conversation clears context
and pending responses. This supersedes the manual gate above and closes tsk003.
No claim that every device/language edge case in SESSION_QA was re-executed.
Next bounded delivery is visual annotations, not persistent walkthroughs yet.
