# Dependencies and integrations

**Last updated:** 2026-09-19
**Discovery status:** repository mapped; ct010 Worker deployment and protected routes smoke-verified

## Runtime dependencies

| Dependency | Version / boundary | Evidence |
|---|---|---|
| Apple frameworks | SwiftUI/AppKit UI; AVFoundation PCM; ScreenCaptureKit; Accessibility; Security Keychain; ServiceManagement login item | `cursy-app/Cursy/CursyApp.swift`, `cursy-app/Cursy/OpenAIRealtimeVoiceClient.swift`, `cursy-app/Cursy/WindowPositionManager.swift` |
| macOS | Deployment target 14.2; native glass availability gated at 26; throwing audio tap at 27 | `cursy-app/Cursy.xcodeproj/project.pbxproj`, cursor and Realtime source |
| Sparkle | SPM minimum/resolved 2.9.0; updater startup currently disabled | `cursy-app/Cursy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `cursy-app/Cursy/CursyApp.swift` |
| Worker | Cloudflare fetch runtime, compatibility date 2024-01-01; no production npm dependencies | `cursy-app/worker/wrangler.toml`, `cursy-app/worker/package.json` |
| Storage | UserDefaults preferences, Keychain internal bearer; conversation history in memory, no database configured | `cursy-app/Cursy/CompanionManager.swift`, Realtime source |

## Development and validation

| Tool / command | Evidence / result |
|---|---|
| Xcode project, Cursy / CursyTests / CursyUITests targets | project.pbxproj; Swift language mode 5.0. Open project and run/test in Xcode; terminal xcodebuild prohibited by repository policy |
| Local compiler | `swift --version`: Apple Swift 6.4, arm64 macOS 27.2 target; not the project's deployment minimum |
| npm / Node | local Node 24.19.0, npm 11.17.0. Wrangler installed 4.135.0 requires Node >=22; README Node 18 guidance stale |
| Wrangler | package range ^4.135.0, package-lock.json; dev/deploy plus npm test (Node and installed workerd/Miniflare runtime) |
| Worker safe bundle check | From worker directory: `WRANGLER_LOG_PATH=/private/tmp/cursy-bootstrap-wrangler.log ./node_modules/.bin/wrangler deploy --dry-run --outdir /private/tmp/cursy-bootstrap-worker`; passed, no upload |
| Config checks | `plutil -lint` for Info.plist, entitlements and project.pbxproj; passed |
| Release syntax | `bash -n cursy-app/scripts/release.sh`; passed without executing script |
| Native tests | Swift Testing in CursyTests; XCTest in CursyUITests. Full suite not executed by bootstrap |
| Session core validation | `bash cursy-app/scripts/test-session-core.sh`: 17 pure tests/2 suites, no app/credentials/network; manual checklist scripts/SESSION_QA.md. Resumed integration regression71 tests/11 suites via swiftc (no xcodebuild), excludes app entry/Sparkle and full UI tests |
| Native regression runner | `bash cursy-app/scripts/test-native-regressions.sh`: tsk006 first integration native module compiles, 101 isolated tests/13 suites pass. Excludes Sparkle entry, broad pre-existing CursyTests.swift and UI suite; no real provider/capture/mic. Live gates scripts/ANNOTATION_QA.md and scripts/SPATIAL_CONTEXT_QA.md |
| Automation | Worker npm test: 19 passing contract/runtime checks, mocked outbound requests; no repository CI YAML, lint/typecheck scripts or tsconfig |

Bootstrap performed no deploy, release, secret provisioning or package installation.
Wrangler help initially hit sandbox log-write restriction; redirected logs to
/private/tmp for successful dry-run.

## External boundaries

| System | Flow / configuration names | Current limitations |
|---|---|---|
| OpenAI Realtime | App → Worker POST /openai/realtime/session (internal bearer) → ephemeral secret → direct provider WebSocket PCM. OPENAI_API_KEY, CURSY_INTERNAL_API_TOKEN | Model/voice in Worker: gpt-realtime-2.1 / marin; mint HTTP200 and unauthenticated HTTP401 rechecked after ct010 deployment; no new audio-session test |
| Vision/chat | App VisionAPI → protected Worker POST /vision → OpenAI Chat Completions; OPENAI_API_KEY and CURSY_INTERNAL_API_TOKEN | Deployed; text and streaming smoke tests pass. Old /chat retired; no Anthropic key required. tsk002 delivery accepted; optional legacy voice services remain separate |
| Localization (ct010, deployed) | Independent VisionAPI purpose=localization → /vision → OpenAI Responses original + strict record-only function; default GPT-6 Astra | Version 107dd830-4209-4525-aaac-c2075acb310a; synthetic present/absent targets HTTP200, invalid model/stream HTTP400. User accepted native delivery and tsk002 closed. Sonnet/DeepSeek evaluation only; no new secrets provisioned |
| AssemblyAI | Provider → token broker POST /transcribe-token → streaming provider; ASSEMBLYAI_API_KEY | Client broker URL remains placeholder |
| ElevenLabs | App → Worker POST /tts; ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID | Voice ID placeholder; legacy route protection missing |
| Apple Speech / OpenAI transcription | Alternative providers behind BuddyTranscriptionProvider | Not exercised by bootstrap; do not infer all variants are configured |
| GitHub / Apple notarization / Sparkle distribution | scripts/release.sh and appcast.xml | Requires signing, gh, create-dmg, Keychain credentials and publication authority; readiness unverified |

Secrets are not stored in this registry. worker/.dev.vars is ignored. During ct010,
credentials were read by authorized evaluation/smoke checks in memory, never printed
or copied into source. Remote secret names confirmed OPENAI_API_KEY and
CURSY_INTERNAL_API_TOKEN; no Anthropic/DeepSeek deployment. Values were unchanged.

Worker runtime constraint: workerd at the configured compatibility date rejects
redirect:error even though Node accepts it. Use manual redirects and reject non-OK
responses without following or exposing provider bodies. Runtime regression tests
exercise the bundled handler, not just Node mocks; keep them in npm test.

## Task relationships and reuse

tsk017 latency depends on accepted tsk003 turn isolation, tsk006 capture binding
and current Realtime audio/response gates. It is independent of tsk007's now
authorized native visual port; both share the next physical QA build. No model,
provider, Worker or stored-schema changes in F1/F2;
fast routing/prewarming waits for measured physical baseline and safety evaluation.

### Programme ct012 — planned on 2026-09-19

tsk006 remains in progress for evaluation; tsk007 F1 is authorized (ct017),
tsk008–016 remain plans. The user explicitly
authorized starting six remotely before accepting five; tsk005 QA remains pending.
tsk012 is deferred during prototype experience validation, not removed as a launch gate.
No parallel agent work authorized. Shared manager/overlay/Worker files require
serial integration even when product workstreams are logically independent.

| Ticket | Hard prerequisites | Contract / primary reuse |
|---|---|---|
| tsk006 spatial context | accepted tsk002–004; tsk005 QA separately pending | Ephemeral current-scene path; single-flight capture/coordinates/localizer |
| tsk007 Home/settings | implemented tsk006 contracts; evaluation separate | F1 observes existing session without new audio/network; design gate before F2/F3 |
| tsk008 conversations | tsk007; accepted tsk003 | Durable store separate from bounded model history |
| tsk009 walkthroughs | tsk006, tsk008 | Persistent steps, manual confirmation, fresh localization |
| tsk010 verification | tsk009 | Consent-scoped evidence/advance; separate observation lease |
| tsk011 dictation | tsk007 | Single mic owner + destination-bound insertion; independent of guides |
| tsk012 service security | existing Worker/client | Identity, quotas, protected legacy routes; may move earlier |
| tsk013 bounded agents | tsk008, tsk012 | Run IDs, budgets, attachments/artifacts and public read-only research |
| tsk014 local actions | tsk010, tsk012, tsk013 | Typed approval, revalidation, execution receipt |
| tsk015 integrations | tsk012, tsk013 | Revocable scopes, real health checks, first read-only connector |
| tsk016 routines | tsk012, tsk013, tsk015 | Opt-in schedule/slot idempotency and notification policy |

tsk012 is mandatory before multiuser rollout, regardless of ticket number.
Remote connector writes remain out of tsk015 and need a separate approved phase
using tsk014-equivalent authorization. tsk013 public research is bounded reading,
not computer use; it does not depend on tsk014. Routine MVP is local while the app
is open, not execution with the Mac off. Identity vendor, monetary ceilings,
first connector and actual deployments require later explicit decisions.

All new storage/transport contracts are proposed, versioned and feature-gated.
Retain macOS14.2, current Swift language mode, provider separation and no OCR.
No new package, database or external service was installed by planning.

tsk007 F1: MenuBarPanelManager starts HomePanelController's passive hover monitors
at initialization; the panel is created on first use. HomeView reads
CompanionManager/ConversationSession; HomePresentation contains pure projection
and geometry. No second session, mic owner, broker or storage. Capture's existing
bundle-wide exclusion also excludes Home. Capsule uses safeAreaInsets plus the
auxiliary menu areas to surround the camera with lateral controls; external displays retain
a safe floating margin. HomeReveal is presentation-only, with no audio changes.
HomeGlassSurface adds OS-gated Liquid Glass (26+) or NSVisualEffectView behind-window
fallback (14/15), no capture/network/dependencies. Accessibility can force opaque.
HomeHoverPolicy gates delayed opening/closing; existing voiceState keeps an active
conversation visible. HomeSurfaceShape covers the camera with an opaque neck;
HomeIslandShape reserves its center. HomeNotchInteraction shares the display/camera
anchor with OverlayWindow for presentation-only flights; voice input never waits.
No pointer path storage, new polling, permission or capture. Header replaces
the footer with voice shortcut, consent state and session lifetime.
Native isolated suite now 150 tests/19 suites. Settings,
text input and physical focus/accessibility/performance gates remain pending.

tsk007 selected-text interoperability (2026-09-21): SelectedTextPanelController
uses SelectedTextReader (off-main AX IPC) and SelectedTextSearch (shared traversal,
capability warmup and lifecycle fixtures). Delayed remote AX readiness and
document/window ownership are separate from menu placement. No app-name branches,
clipboard, OCR, whole-document context, new permission or provider changes.
SelectionMenuSearch now shares bounded strip sampling and single-action/container
detection with fixtures. Offline tests do not substitute physical application QA.

tsk006 compatibility discovery: deployed locator allows exactly one image and a
16k-character prompt. Initial path integration preserves this boundary and locator
selection: optional normalized/versioned metadata through existing context, with
prepared-raster dimensions. The initial single-scene implementation was later
extended in Realtime only (below); current-scene acceptance is not multiscene acceptance. Local
scene checks reuse VisualSceneFingerprint (luminance only), not text recognition.

ct013 local refinement is implemented before multiscene expansion: content-free
delivery diagnostics and typed outcomes through manager/Realtime; native module
compiles and 110 isolated tests/14 suites pass. Explanatory no-point continuation
is separate from a rejected indication. No Worker/protocol/provider change.
General semantic evaluation requires cost authorization; mocks only prove
transport/logic. Live acceptance, performance and multisegment remain pending.

ct014 native repair keeps those provider and Worker boundaries. Realtime alone
receives a gesture-marked reference copy of the current clean image with bounded
size/ownership, plus typed explain/locate/combined intent. The UI locator is not
required for content explanations; fallback/locator retain one image. Added image
cost/latency and semantic quality remain unmeasured; no Deepgram/Cerebras integration.

tsk006 multiscene continuation: SpatialSceneEvidence adds up to two earlier verified
snapshots of the same held Talk, each paired with its own path/marked reference.
Realtime sends these before the final CURRENT pair, within a shared 3 MiB image
budget (up to six images for three scenes). Current evidence wins; omissions are
explicit. Historical images never enter the locator, fallback or live pointing
lease. No Worker changes/deployment or new provider. Offline benchmark measures
preparation/JSON only; semantic and physical end-to-end gates remain separate.

- ct011 → tsk004 visual intent/window resolution, reusing the deployed ct010
  localization adapter and tsk003 turn/capture ownership. Native routing/prompt
  change implemented; semantic targetQuery enables qualified review of generic and
  negative decisions without a hard preliminary-window restriction. Actual target
  binds freshness/geometry/native validation. No Worker deployment or credentials
  required. User accepted tsk004 after a successful live test on 2026-09-19;
  tsk003 continuity/interruption/reset independently accepted on 2026-09-19.

- ct007 → tsk002 bounded-observation refinement (integrated; delivery accepted).
  Reuse tsk003 session identity without reopening completed turns; short visual
  observation owns its own cancellable lifetime. Reuse capture/pipeline/provider
  and geometry. No OCR, permanent stream, new package or deployment anticipated.
  Keep two-monitor scroll/cancellation cases as regression tests for later work;
  user acceptance does not represent a measured exhaustive device/performance matrix.

- tsk000 complete → ready to plan ct001 sessions/contracts (order 1).
- micro001 → micro002 → micro003 delivered internal Realtime foundation.
- micro004 → tsk001 → micro005 delivered accepted native controls/cursor.
- Revised user priority: tsk002 voice + screen + pointing (completed with user
  acceptance) → full sessions core (tsk003) → annotations → persistent
  walkthroughs → step verification. Reuse existing capture/overlay/transports.
- Full roadmap Realtime/barge-in/routing scope is not complete merely because
  internal push-to-talk works. Production auth/quotas and safe local actions remain
  separate work; no autonomous action subsystem is presumed present.
- User authorized parallel tsk002 focus refinement and tsk003 session core.
  ConversationSession now owns bounded fallback history and turn/capture identity;
  Realtime now enables gpt-4o-mini-transcribe and correlates user transcription
  by committed item_id; bounded text history is replayed per connection.
  Resumed tsk003 adds immutable session/turn startup ownership, 8,000-character
  retained texts and 2,000-character explicit objective at the core boundary.
  Native acceptance of continuity/interruption/reset received 2026-09-19; tsk003 closed.

- tsk005 annotations reuse tsk004 validated publication and tsk002 observation
  clearing. Structured style is local Realtime-tool metadata; localization and
  Worker contracts stay unchanged. No deployment/new dependencies. Circles and
  rectangles mark a point, not a semantic element bounding box. Realtime chooses
  style; fallback/automatic uses Cursor, without stored user preferences.

## Durable constraints

- 2026-09-21 native F3: HomeComposer → VisionAPI text stream (no images); selection
  AX snapshot → fresh ConversationSession.selectedText → text or current Realtime.
  Selected scope blocks visual capture/gesture paths. Realtime output-only greeting
  waits for actual playback completion before PTT capture. No Worker/provider change.
  HomeMicrophone shares route preference across existing recorders and local15s test;
  QA repair isolates test graph operations, preserves default input without HAL
  reassignment, and keeps capture ownership through async teardown. Selection IPC
  is actor-owned; native/web AX ranges and AX notifications share the same reader.
  Lazy AX trees may opt into documented AXManualAccessibility only when settable;
  this is capability-based and does not grant OS permissions. Delayed AX events
  retain only a same-process mouse anchor for1s, invalidated on new input.
  manager cancels test before voice. Custom shortcuts reuse the listen-only event tap.
  Native menu avoidance uses exposed nearby AX geometry, not universal visual detection.

- tsk005 adaptive guidance v2 locator/multi-mark contract remains proposed:
  prototypes/notch-voice/guidance-contract.md. Native single-target motion/tint and
  verified AX extents are ported; image/canvas extents still need a region-capable
  locator. Without verified extent circle/rectangle safely use cursor. Multiple marks share a
  step/revision and invalidate together. tsk009 owns guides; tsk010 owns explicitly
  authorized bounded observation and evidence-based progression. No always-on
  capture or per-figure user settings implied by the design. Keep session cancel.

- Native tsk005 presentation does not alter models, Worker schemas or observation
  budgets. One shared artist traces at1.6× and typed labels have no artist/leader.
  The short hold/fade retires an indication, never verifies an action or advances
  a guide. Hide/opt-out/new turn/replacement revoke animation identity. AX static
  text extent correctness (requested word versus whole paragraph) remains live QA.

- 2026-09-21 tsk005 direction supersedes the manual style preference: the agent
  chooses guidance style/timing/target, with native validation before publication.
  Prototype and native Home/legacy selectors are removed; stored defaults are
  ignored. Realtime is instructed to choose; live quality evaluation remains.
  Legacy fallback retains Cursor; refresh retains the agent choice. Preview controls
  are lab-only, never saved app preferences or evidence of actual inference.

- tsk007 limited F2 uses HomeChatLibrary for 20 memory-only chat snapshots backed
  by ConversationSession (text bounds unchanged, no images/audio retained). Restoring
  creates a fresh session identity; switching cancels active work. Durable storage,
  deletion/retention UX and restart recovery remain tsk008, not implicitly complete.
  HomeSettingsView reuses manager setters. CursyCursorTint stores only appearance
  preference; no provider/Worker/package dependency. Presentation activation UUIDs
  coordinate curved flight/click/reveal without delaying microphone startup.
  HomePanelController publishes presentation-only HomeSpatialHintAnchor from the
  visible panel/display; the existing overlay shows guidance only during real
  listening + recording/limited. Symmetric400 ms hint animation never owns audio
  readiness or delays logical cancellation. Sidebar/settings share HomeGlassSurface.

- 2026-09-21 tsk007 promotion: status item and camera hover now share the same
  official Home. Legacy CompanionPanelView has no construction path. User follow-up
  removes the manual objective field and editing infrastructure; intent continues
  to use the existing request/history, without a new inference call or inferred
  objective stored as explicit user authorization. Privacy owns existing permission
  actions; Help owns intro, feedback and quit. Home remains non-key/non-main.
  Setup guards autohide; PTT must not send the
  old-menu dismissal (which would suppress the island). Onboarding still dismisses
  Home. No new provider, defaults migration, consent or persistence; tsk008 remains.

- No terminal xcodebuild, app reinstallation or TCC reset for routine validation.
- Preserve compact optical scale 0.32, mint default with user-selectable tints,
  80% capped visual deformation,
  fixed cursor orientation and accepted AirPods transport.
- App is not sandboxed (Cursy.entitlements); Accessibility and screen/microphone
  permissions are sensitive boundaries, not blanket action authorization.
- Current [POINT:...] guidance and ten-turn history are not persistent walkthroughs
  or long-term memory. Avoid adding more orchestration directly to the manager.
