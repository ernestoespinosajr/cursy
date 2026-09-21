# tsk004 — Visual intent and window resolution

Status: completed
Date: 2026-09-19
Context: ct011; follow-up to accepted tsk002, reuses in-progress tsk003
Complexity: 6/10 (technical 5, integration 6, testing 6, rollout 4)
Owner: cce-ai-engineer; companion: write-swift; orchestration: CCE Dispatch
Authorization: user explicitly requested planning and implementation together.

## 1. Goals and requirements

As a user I can ask naturally to locate an app/control in any visible window,
without categorizing it or having the foreground app override my explicit request.
Realtime's preliminary coordinates/window are not binding semantic evidence.
An explicit missing/ambiguous visual decision must receive qualified localization
before final rejection. Non-pointing conversation does not incur that extra call.
No OCR, app-specific production rules, autonomous input, new model, audio/cursor
redesign, unlimited retries or claims of 100% model accuracy.

## 2. User experience

Reuse analyzing/updating/pointed states and current accessible UI. On success,
publish the cursor before the existing concise spoken confirmation. On failure,
briefly explain inability to verify, not claim the app is absent without evidence.
No new controls. Native close/minimize/zoom/Dock targets retain verified-ID handling.
Live QA: named background app, generic visible controls and absent/ambiguous targets
on both monitors. Confirm reset and interruption never publish stale results.

## 3. Technical design

Add bounded semantic target-query data to the existing Realtime decision contract.
Route generic point and missing/ambiguous/unverified locate decisions into the same
qualified vision stage. A valid native point retains its fast path. Use the tool's
faithful restatement of the current spoken request, plus correlated transcript when
available and existing session context; never an empty query or prior-turn transcript.
Remove mandatory preliminary-window restriction from localization. Resolve the
returned actual window and native/generic intent, then enforce existing capture,
display, age, owner, geometry, occlusion and scene checks before publication.
Defer observation scope to the resolved target so a wrong initial window cannot
spend the refresh budget. Keep the existing two-refresh/30-second bounds.

Reuse VisualTurnContext, GenericPointingPipeline (adapt its responsibility),
VisualObservation, VisionAPI and deployed Astra endpoint. No Worker protocol change.
Affected: Realtime client, manager, visual decision, detector, pipeline diagnostics,
tests and documentation. Prefer typed value contracts and post-await ownership checks.

## 4. Dependencies

Depends on ct010 deployed localization and tsk003 session ownership, not on closing
tsk003's manual gate. No package, secret or persistent schema changes. Keep provider
interfaces replaceable. No deployment necessary for native prompt/routing changes.

## 5. Implementation

1. Typed semantic routing, bounded query, locator prompt and pipeline changes.
2. Connect Realtime including no-point review; retain native fast path and response
   gate; apply resolved-target freshness before publication and post-call refresh.
3. Deterministic tests for actual production seams, background-window correction,
   missing/ambiguous review, malformed/empty request, no extra call for conversation,
   native results, cancellation, scene/geometry rejection and multi-monitor mapping.
4. Compile native module and run isolated regression suite without xcodebuild,
   app launch, credentials or provider calls. Document manual Xcode acceptance.

Security: screen remains opt-in and untrusted input; no contents in logs or disk.
Performance: one locator per visual decision, bounded refresh reuses existing lease.
Risks: model misinterpretation, malformed semantic query, extra latency on negative
decisions, freshness invalidation during provider wait. Fail closed, no fallback
to unchecked Realtime coordinates. Log stages/IDs/reasons only.

## 6. Validation and rollback

Automated gate: regression tests and source compilation pass; native/geometry safety
tests retained, explicit new-window success and occluded-window rejection covered.
Manual gate: user Build/Run in Xcode and acceptance of foreground/background/absent
and two-monitor cases. Keep task in progress until this gate passes.
Document evidence in this task/logbook, architecture in app AGENTS and QA checklist.
Rollback only this task's scoped hunks, not user changes or shared session work.
No commit, deployment, reinstall or TCC reset is part of this request.

Execution handoff: `$cce-dispatch execute tsk004-visual-intent-window-resolution`

## Execution — 2026-09-19

- Implemented with CCE AI Engineer/Write Swift: typed VisualGuidanceRoute and
  bounded VisualLocalizationRequest, 2,000-character faithful tool query, optional
  current-turn-only transcript bounded at 8,000. Does not wait for or substitute
  an old transcript; current audio interpretation remains available in the tool.
- Generic points and missing/ambiguous/unverified outcomes route to Astra. Only
  unrelated conversation with empty query skips localization; verified native
  decisions retain existing fast path. Contradictory/stale/empty locate contracts
  fail closed. Tool envelope bound raised to 16 KiB for bounded Unicode query.
- Removed detector's hard expected-window prompt and pipeline window-equality
  requirement. Qualified result determines actual target/window, then checks
  capture/age, identity, native-ID membership, scene freshness and OS geometry.
  Native results from semantic review use live AX validation, not pixel estimates.
- Observation scope is not prepared from the initial generic guess. Freshness is
  evaluated using the resolved target before cursor publication; existing refresh
  budget, response gate and post-await ownership guards remain intact.
- Reused files: VisualTurnContext, OpenAIRealtimeVoiceClient, CompanionManager,
  ElementLocationDetector, PointingDiagnostics; extended VisualTurnTests and
  PointingPipelineTests; updated VisualObservationTests for target-aware verifier.
  Added scripts/test-native-regressions.sh and VISUAL_INTENT_QA.md, app AGENTS and
  scripts README documentation. No model/Worker/API credentials/audio/cursor change.

Validation:

- `bash cursy-app/scripts/test-native-regressions.sh`: source module compiles;
  **81 tests / 11 suites pass**, 0.760 seconds runtime. Includes 10 added test
  functions with parameterized domains, missing/ambiguous decisions, exposed
  background-window correction, occlusion rejection and native identity handling.
- Artifacts: `/private/tmp/cursy-native-regression.T26bhu` (build.log,
  tests-build.log, tests-run.log). Isolated source build excludes Sparkle app entry;
  tests exclude broad pre-existing CursyTests.swift and UI suite. Not a signed
  Xcode build or live model/voice accuracy result. Existing warnings left unchanged.
- First sandbox build could not execute SwiftUI macros. Approved offline build
  outside sandbox was repeated after a formatting edit invalidated its input;
  final stable-source run above passed. No TCC reset, reinstall, app launch or
  external provider call performed.
- Manual Xcode gate pending: foreground/background natural-language requests,
  native controls, both monitors and absent/ambiguous targets. User should Stop/Run
  from Xcode with the updated sources; no Worker deployment is needed.

## User acceptance — 2026-09-19

User reports testing the correction successfully: "ya probé y funciona".
Accepted delivery and closed tsk004. This is user-reported live acceptance, not
evidence that every row of the broader QA matrix ran or proof of perfect accuracy.
The previous 81-test/source compilation evidence remains unchanged; no runtime
edits, new tests or deployment performed for closure. Broader device/edge-case
coverage remains release regression work. tsk003 retains its separate manual
continuity/interruption/reset acceptance gate.
