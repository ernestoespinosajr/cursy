# Cursy - Agent Instructions

<!-- This is the single source of truth for all AI coding agents. CLAUDE.md is a symlink to this file. -->
<!-- AGENTS.md spec: https://github.com/agentsmd/agents.md — supported by Claude Code, Cursor, Copilot, Gemini CLI, and others. -->

## Overview

macOS menu bar companion app. Lives in the macOS status bar (no dock icon, no main window). Clicking the status icon opens the official notch-integrated Home, shared with camera hover, chats and settings. The legacy companion popup is no longer instantiated. Uses OpenAI Realtime push-to-talk (ctrl+option), with explicit screen-sharing consent. A glass cursor points at validated controls. Text fallback uses VisionAPI through the Worker; its separate legacy audio providers remain available. The ct010 /vision Worker is deployed and smoke-verified; the user accepted the native result and tsk002 is completed.

All API keys live on a Cloudflare Worker proxy — nothing sensitive ships in the app.

## Architecture

- **App Type**: Menu bar-only (`LSUIElement=true`), no dock icon or main window
- **Framework**: SwiftUI (macOS native) with AppKit bridging for menu bar panel and cursor overlay
- **Pattern**: MVVM with `@StateObject` / `@Published` state management
- **AI Chat**: OpenAI Realtime is primary. Conversational fallback VisionAPI uses GPT-4.1/mini and normalized SSE. A separate localization client defaults to GPT-6 Astra via Responses/original and strict record-only output; Astra/Sol are the localization allowlist. The corresponding ct010 Worker is deployed and the user accepted tsk002 (2026-09-18). Provider credentials never enter the native client.
- **Speech-to-Text**: AssemblyAI real-time streaming (`u3-rt-pro` model) via websocket, with OpenAI and Apple Speech as fallbacks
- **Text-to-Speech**: ElevenLabs (`eleven_flash_v2_5` model) via Cloudflare Worker proxy
- **Screen Capture**: ScreenCaptureKit (macOS 14.2+), multi-monitor support
- **Voice Input**: Push-to-talk via `AVAudioEngine` + pluggable transcription-provider layer. System-wide keyboard shortcut via listen-only CGEvent tap.
- **Realtime Voice**: Internal builds with a Keychain-backed bearer mint a short-lived OpenAI credential through the Worker and use native WebSocket PCM streaming. Explicit PTT starts local capture before network setup; bounded RAM delivery preserves release-before-connect audio. Missing configuration retains the established provider → VisionAPI → ElevenLabs pipeline. Once early capture begins, startup failure ends the turn for explicit retry, never silently switches recorders. Release capture overlaps pending sends; response creation still waits for screen context and the mandatory visual decision.
- **Element Pointing**: OpenAI Realtime must call `resolve_visual_guidance`. Generic targets in Realtime, fallback and silent refresh pass through `ElementLocationDetector` and the independent localization client. `VisionLocalizationImage` retains the evaluated raster bounds (short side <=768, long side <=2048, aspect preserved). Locator output contains pixels/window/intent; the caller supplies captureID and exact prepared dimensions, never model echoes. Realtime's separate initial decision contract still carries its image metadata. `ImagePointingTarget` normalizes once; `ScreenCoordinateSpace` maps to the captured display and overlay. Capture identity, age, display, geometry and z-order are validated, not semantic target identity. Native window/Dock controls retain verified AX identity. Legacy POINT tags never drive pointing. No OCR, actions or app-specific rules. Zero failures in a small QA sample is not a guarantee of perfect accuracy.
- **Concurrency**: `@MainActor` isolation, async/await throughout
- **Analytics**: Disabled by default through the no-op `CursyAnalytics.swift` interface

### API Proxy (Cloudflare Worker)

The app never calls external APIs directly. All requests go through a Cloudflare Worker (`worker/src/index.ts`) that holds the real API keys as secrets.

| Route | Upstream | Purpose |
|-------|----------|---------|
| `POST /vision` | OpenAI Chat Completions for conversation; Responses for localization | Deployed protected purpose/model allowlists; normalized SSE or structured locator JSON. Old /chat returns 410 |
| `POST /tts` | `api.elevenlabs.io/v1/text-to-speech/{voiceId}` | ElevenLabs TTS audio |
| `POST /transcribe-token` | `streaming.assemblyai.com/v3/token` | Fetches a short-lived (480s) AssemblyAI websocket token |
| `POST /openai/realtime/session` | `api.openai.com/v1/realtime/client_secrets` | Creates a short-lived, internally authorized Realtime client secret |

Worker secrets: `OPENAI_API_KEY`, `CURSY_INTERNAL_API_TOKEN`,
`ASSEMBLYAI_API_KEY`, `ELEVENLABS_API_KEY`
Worker vars: `ELEVENLABS_VOICE_ID`

### Key Architecture Decisions

**Menu Bar Entry**: `NSStatusItem` routes directly to the single HomePanelController.
Click opens hidden Home, expands the listening island or closes expanded/detached
Home. CompanionPanelView remains unreachable legacy source, not a fallback UI.

**Official Home (tsk007)**: Hovering the real camera housing (180 ms dwell),
or clicking the status icon, opens one reusable nonactivating/non-main
HomePanelController panel. MenuBarPanelManager starts passive pointer monitors at
initialization; the actual panel is still created only on demand. Compact/expanded
surface now covers the physical camera region with solid black, derived from safeAreaInsets and
auxiliary menu areas; compact controls live strictly on its sides. External displays retain a 12-point
gap; detached mode is draggable and reattaches to its current display.
HomeView projects the existing manager/session without owning audio, capture or model calls.
HomeChatLibrary retains up to 20 memory-only text snapshots; selecting cancels the
current turn and restores with a fresh session ID, without captures or active work.
HomeComposer adds text streaming through VisionAPI without automatic screen/audio,
per-chat drafts, Enter/Shift+Enter and stop. Durable history remains tsk008.
Settings includes General/Voice/Microphone/Shortcuts/Cursor/Privacy/Help.
General has no manual conversation-objective field: intent comes from the request
and bounded conversation context, not another user configuration step.
Privacy includes the existing OS permission actions and first-run Start. Help
contains introduction replay, feedback mail and Quit. Opening does not request
permissions or change consent. Pending setup routes to Privacy and prevents
autohide. Home stays non-main/passive on hover; CursyEditingPanel becomes key only
for explicit text/shortcut editing. Closing/compacting releases editing ownership.
PTT must not emit the old panel-dismiss signal, which would suppress automatic
island presentation; onboarding still uses it to dismiss Home.
Sidebar/settings extend to the bottom of the same HomeGlassSurface; do not add
independent opaque backgrounds or an outside bottom padding strip. UI pictograms
and modifier keys use SF Symbols; the live cursor retains its custom identity.
HomeSpatialHint reads actual listening plus recorder state and an anchor published
by HomePanelController only after the panel is visible. It uses the existing
click-through overlay, below camera/compact island, with symmetric400 ms ease
slide/fade (reduced-motion fade150 ms). Keep its retained exit separate from the
immediate input trail and audio lifecycle; no animation may delay capture.
Escape is observed without consuming it. Attached Home hides
800 ms after leaving while idle; pointer inside, voice activity, dragging and
VoiceOver and incomplete setup prevent auto-hide. Detached stays visible. Explicit X/Escape suppresses
hover until the pointer leaves; re-entry reverses an automatic close. No polling,
new persistence. Voice automatically shows a hidden Home as a compact island;
explicit dismissal suppresses it for that turn, detached stays independent.
HomeNotchInteraction shares geometry/policy with the existing cursor overlay:
the visual buddy flies along an 800 ms S-curve, presses visually for 140 ms and
acknowledges an activation UUID before the listening island reveals. It hides
above the camera while listening/processing, then exits toward
a validated target or resumes following. No physical pointer or audio changes.
Navigation revisions invalidate old bubble/return callbacks. User design
and physical focus/accessibility gates are in scripts/SETTINGS_QA.md. Home promotion
and all legacy-control migration are authorized. F3 is integrated, with physical
focus, devices, provider behavior and compatibility acceptance still pending.
Five CursyCursorTint choices tint native glass and matching shadow; preference
persists, unknown values fall back to mint, optical size remains unchanged.
Listening feedback consumes currentAudioPowerLevel: stationary in silence,
bounded volume bars and bottom mint/blue/violet glow, no timer or extra audio.
Reduce Motion keeps geometry static; Reduce Transparency hides the glow.
HomeGlassSurface uses native clear Liquid Glass on macOS 26+, with a behind-window
NSVisualEffectView fallback on macOS 14/15. Black density decreases across the
surface (1 → 0.18), not just a transparent skirt; text has local dark backing.
Reduce Transparency or Increase Contrast selects solid black. No private blur
API or new screen sampling. HomeSurfaceShape adds camera-height coverage plus
14-point shoulders; the neck/header are opaque black above the gradient.
HomeIslandShape wraps the camera with concave corners. Voice shortcut, screen consent icon
and temporary-session label live in the header, not a bottom status bar.
HomeReveal masks from the camera in 250 ms
without scaling text; Reduce Motion uses opacity only. Transition IDs prevent
late close completions from hiding a reopened panel. Layout changes retract then
reveal; native window resizing is never animated (no stretched text). The panel
overrides visible-frame constraints because layout already bounds each mode.

**Cursor Overlay**: A full-screen transparent `NSPanel` hosts the glass cursor companion. It's non-activating, joins all Spaces, and never steals focus. The cursor position, response text, waveform, and pointing animations all render in this overlay via SwiftUI through `NSHostingView`.

**Native indication design port (tsk005)**: One validated target per turn. Regions
come only from the exact accessible element at the verified point (no ancestor
container expansion); display/window/PID and complete window occlusion are checked.
No verified extent means circle/rectangle fall back to cursor. Generic image/canvas
regions still need a locator contract extension. VisualAnnotationMotion shares a
1.6× monotonic drawing clock with the existing glass companion; no second cursor
or physical input. Rectangle drag, ellipse/arrow trace, independent typed labels,
shared tint and pointer-driven rim. Cancellation invalidates identity; a short
hold/fade retires the indication without claiming success. No per-mark clear UI;
session cancel, consent opt-out and hide remain. Multi-mark guides/verification
remain tsk009/010. Reduced motion shows static geometry and full text with a fade.

**Global Push-To-Talk Shortcut**: Background push-to-talk uses a listen-only `CGEvent` tap instead of an AppKit global monitor so modifier-based shortcuts like `ctrl + option` are detected more reliably while the app is running in the background.

**Shared URLSession for AssemblyAI**: A single long-lived `URLSession` is shared across all AssemblyAI streaming sessions (owned by the provider, not the session). Creating and invalidating a URLSession per session corrupts the OS connection pool and causes "Socket is not connected" errors after a few rapid reconnections.

**Transient Cursor Mode**: When "Show Cursy" is off, pressing the hotkey fades in the cursor overlay for the duration of the interaction (recording → response → TTS → optional pointing), then fades it out automatically after 1 second of inactivity.

## Key Files

Selected-text entry (tsk007): event/AX-notification-triggered bounded AX selected text/range only;
no clipboard/OCR/full document or screenshots. Secure/unsupported selections omit
the offer. Nearby exposed menu/group geometry informs above/below placement; this
is not universal menu recognition. SelectedTextReader isolates synchronous AX IPC
off MainActor, searches hit/focus ancestry and bounded structural children, and
supports native ranges plus web text-marker ranges without app-name branches.
SelectedTextSearch supplies the shared production/test traversal, capability
warmup and read-generation lifecycle. Web-area ancestry is preferred; bounded
DFS pages through siblings, and menu focus bursts do not cancel a gesture read.
Preparation reads AXRole and requests writable AXManualAccessibility once per
pending process, allowing the remote debounce before the final bounded retry.
Retries remain bound to the original main window; secure inputs are excluded.
Confirmed selected text lacking bounds may use a mouse placement anchor, never
a guessed text extent. Late reads are revoked on input/app/session changes.
The mouse-down/up band can reject stale AX placement coordinates but never
supplies text. Menu placement waits140ms for selection UI to settle and probes
compact accessible control groups within300ms; no app-specific menu labels.
SelectionMenuSearch shares production/fixture logic: bounded horizontal strip
sampling (40pt columns/16pt rows), single-action support and compact ancestor
envelopes. It treats nearby accessible controls as obstacles, not semantic proof
of a selection menu; unexposed menus remain an interoperability limitation.
Offer/editor stack12pt above nearby menus (below selection if there is no room).
Offer morphs to compact editor without glyph
scaling. Explicit send/mic creates a fresh memory-only selected-text session; scope
blocks screen/gesture input. Realtime output-only greeting completes playback before
the existing PTT recorder starts. New turn/reset/cancel revokes callbacks. Local
microphone test owns audio only while idle, stops on navigation/close/Talk, and
never stores/sends audio. Its actor owns blocking graph operations; input readiness
has a5s watchdog and teardown keeps ownership until complete. Talk during release
requires explicit retry, not concurrent engines. Fresh engines retain the default
route without HAL reassignment (also when that UID is selected explicitly).
Stored UID is applied by both existing recorders; missing
device requires explicit route choice. Shortcut recorder reuses global tap and
rejects reserved combinations, but cannot detect all third-party conflicts.
Neutral hairlines/shadows belong to UI/captions; cursor color belongs to icons and
actual guidance figures. Do not restore decorative colored strokes everywhere.

tsk006 first integration (not fully accepted): SpatialContextRecorder samples the
pointer only during explicitly opted-in Talk, starting at input-ready. Its clean
local snapshots and normalized path are scene/turn-bound; only one current image
and <=128 points reach the existing Realtime/fallback/locator context. Realtime
also receives a bounded, gesture-marked reference copy of that same scene (not a
second observation); fallback/locator retain their single-image contracts. No OCR or
model call per move. Scroll, changes and monitor crossing clear the live path;
Realtime may retain up to two earlier VERIFIED scene checkpoints of the same Talk
for comparison only. SpatialSceneEvidence contains no live window/native IDs;
historical coordinates never enter publication. Up to three scenes/six clean-and-
reference images share a 3 MiB total budget; current pair wins, old pairs are
omitted whole with notice. Checkpoints exclude samples after capture start;
short/unverified gesture tails are not assumed valid. Historical buffers clear on
consume/cancel/expiry and are excluded from VisualObservation and silent refresh.
Provider understanding of this extension awaits evaluation. SpatialTrailView is immediate,
click-through feedback, distinct from AI output annotations. Buffers are ephemeral
and capped at 30 s; Escape cancels the turn. VisualCaptureSlot serializes underlying
cursor screenshots even after deadline cancellation. No Worker/model changes.
Flag defaults OFF; manual/provider/performance gate: scripts/SPATIAL_CONTEXT_QA.md.

ct013 refinement: spatial delivery has typed inclusion/omission reasons and
content-free stage diagnostics (IDs/counts/UTF-16 size, never paths or screen text).
Realtime/native localization callbacks preserve VisualGuidanceOutcome instead of
Bool; providerNoTarget is not a coordinate-validation error. Refreshed contexts
explicitly invalidate old gestures. Explanatory no-point requests can answer
normally; publication is still required before confirming a highlight. Actual
gesture interpretation by the provider remains an evaluation gate, not a unit-test claim.

ct014 repair: Realtime declares explain/locate/explain_and_locate explicitly.
An explanation routes to conversation even with a target description; publication
still uses the qualified locator and all existing checks. SpatialReferenceImage
renders only attached, capture/display/revision/turn-owned input, with the clean
image unchanged; max 2048 per dimension and 3 MiB combined decoded image payload.
Refresh drops the reference. This is a native-only change, no Worker deployment,
new provider, OCR or paid evaluation. Extra image inference cost/latency is unmeasured.

tsk005 adds point-centered visual annotations without changing localization:
VisualAnnotation.swift holds style, bounded display layout and the click-through
SwiftUI renderer. Circle/rectangle are focus markers, NOT element bounding boxes.
Realtime chooses style contextually in its structured decision and honors explicit
spoken requests. No user style selector or stored style preference is consumed;
automatic/omitted decisions and legacy fallback use Cursor. Refresh retains the
current indication style. Validated publication alone
creates marks; invalidation/reset/opt-out clear them. No additional capture/timer,
OCR or Worker deployment. Live acceptance: scripts/ANNOTATION_QA.md.

`VisualObservation.swift` (~427 lines) owns a short visual lease independent of
voice-turn completion: local scene comparison, scroll invalidation, monotonic
deadlines, two-refresh budget, cancellation and silent relocalization. It reuses
the existing capture/provider/geometry paths; no OCR or automatic input. The
manager binds it to session/turn identity without reopening terminal turns.
Realtime returns the previous tool result, appends a fresh image and requires a
new visual decision before confirmation; fallback shares the same lease policy.
User acceptance closed tsk002; exhaustive physical capture/perception performance
qualification remains future release QA, not a claimed benchmark.
tsk004 semantic routing: Realtime includes a bounded targetQuery restating the
spoken request, including for missing/ambiguous/unverified outcomes. Generic points
and these negative decisions pass through independent Astra localization before
final speech; unrelated conversation skips it. The locator resolves the actual
app/window from the whole authorized display and metadata, without a hard window
restriction inherited from Realtime. Preliminary coordinates are never published.
Verified native decisions retain their fast path; reviewed native results still
require captured AX identity and current OS validation. Observation is scoped to
the resolved target, not the initial guess. No local OCR or app-specific branches.
Run `bash scripts/test-native-regressions.sh`; live gate: scripts/VISUAL_INTENT_QA.md.

Realtime decision responses explicitly request text-only output. The response gate
correlates request metadata and server response IDs before accepting audio or
assistant transcripts; only a spoken continuation enters local replay history.
Observation uses the model-selected window (not automatically the foreground app),
defers initial pixel invalidation until scope is known, and buffers numeric change
diagnostics until observation ends to avoid visible-console feedback.

Session foundation: `ConversationSession.swift` (~184 lines) owns in-memory typed
session/turn states and bounded fallback exchanges. `ScreenContextPolicy.swift`
shares active-window interpretation and focus-first enumeration. Neither stores
screenshots/audio. RealtimeConversationMemory.swift (~50 lines) correlates committed
audio item IDs and builds bounded input_text/output_text history. Realtime now
transcribes user speech, waits up to three seconds after playback for late text,
and offers a local new-conversation reset and optional objective in the menu.
Transcribed user requests are retained independently of completed answers (last
ten, memory only), so interrupting playback does not discard received user text.
Realtime replays these requests with completed answers when available; diagnostic
logs expose counts/status only, not the conversation contents.
The core bounds each retained message to 8,000 characters and the explicit objective
to 2,000. Async startup captures immutable session/turn ownership and rechecks it
after suspension and before error cleanup. Reset revokes ownership and clears local
context. Run `bash scripts/test-session-core.sh` for offline tests; manual acceptance
is defined in `scripts/SESSION_QA.md`. No automatic walkthrough is implied.
`ScreenWindowGrounding.swift` correlates AX and captured-window identities without
interpreting screen content. OpenAI owns visual understanding and target-coordinate
selection; local code only verifies that a returned point belongs to the authorized
display and a still-current visible window. Generic visual targets use
ScreenCaptureKit/CGWindow identity and revalidate owner/frame/z-order before pointing.
Native window controls still require AX IDs. No local OCR is used or logged.
`NativeTargetPolicy.swift` (~15 lines) validates native intent/ID combinations;
`ElementLocationDetector.swift` also reads and revalidates visible Dock application
items. Dock pointing never launches applications or invokes AX actions.

| File | Lines | Purpose |
|------|-------|---------|
| `HomeComposer.swift` | ~127 | Explicit-edit NSPanel/NSTextView bridge, per-chat draft/composer and submit/stop/voice controls. |
| `HomeInputSettings.swift` | ~90 | Real mic/shortcut settings, recording/reset and dynamic shortcut hints. |
| `HomeKeyboardShortcut.swift` | ~75 | Typed custom shortcut validation/transitions and local recorder sharing global tap. |
| `HomeMicrophone.swift` | ~250 | Default-safe input UID routing, actor-owned local15s test, startup deadline and release ownership; no uploads. |
| `SelectedTextContext.swift` | ~46 | Exact bounded selection scope and pure display/menu-safe placement. |
| `SelectedTextPanelController.swift` | ~320 | Input/AX event observation, cancellable offer, morph, isolated chat/voice and notch notification. |
| `SelectedTextReader.swift` | ~210 | Bounded off-main AX selection-only reader: native/web ranges, ancestry, menu geometry and content-free diagnostics. |
| `SelectedTextSearch.swift` | ~105 | Shared bounded traversal backend, delayed AX warmup and cancellable gesture lifecycle. |
| `SelectionMenuSearch.swift` | ~100 | Bounded menu geometry search, single-action/container support; shared with regression fixtures. |
| `HomePresentation.swift` | ~80 | Pure Home activity/history projection and safe display geometry; independent presentation versus activity. |
| `HomePanelController.swift` | ~420 | Single passive/explicit-edit Home, status toggle, setup-guarded hover/reveal, voice island and display changes. |
| `HomeNotchInteraction.swift` | ~55 | Shared camera geometry, cubic arrival curve and activation/docking policy; no audio or target authority. |
| `HomeHoverPolicy.swift` | ~23 | Pure pointer intent; detached, busy, dragging, VoiceOver and explicit-dismissal guards. |
| `HomeSurfaceShape.swift` | ~78 | Opaque camera neck/shoulders and lateral island silhouettes, rounded fallback without notch. |
| `HomeView.swift` | ~382 | ES/EN Home, chats/settings sidebar and camera-reserved voice controls; composer/context projection. |
| `HomeChatLibrary.swift` | ~45 | Bounded memory-only chats, terminal text snapshots and independent selection. |
| `HomeSettingsView.swift` | ~228 | General/Voice/Microphone/Shortcuts/Cursor/Privacy/Help without manual objective, existing permission/onboarding/support actions and tint picker. |
| `HomeSpatialHint.swift` | ~112 | Display-safe hint anchor, real-listening policy and reversible clipped notification; no audio ownership. |
| `CursyCursorTint.swift` | ~30 | Typed tint palette, localized names and preference fallback. |
| `HomeVoiceFeedback.swift` | ~80 | Bounded listening meter, voice bars and bottom glow; real input only, reduced-motion/transparency alternatives. |
| `HomeReveal.swift` | ~40 | Top-origin presentation mask with bounded geometry and Reduce Motion opacity fallback; no audio or capture. |
| `HomeGlassSurface.swift` | ~90 | Availability-gated native glass, AppKit fallback, graded black tint and opaque accessibility policy. |
| `scripts/RenderHomePrototype.swift` | ~55 | Offline production-view rendering with synthetic data, no manager/capture/network. |
| `scripts/SETTINGS_QA.md` | ~55 | F1 design/focus/manual gate and remaining F2–F4 checks. |
| `SpatialContext.swift` | ~249 | Versioned ephemeral path, typed delivery states, bounded gesture-reference raster, numeric diagnostics and UTF-16-bounded metadata composition. |
| `SpatialSceneEvidence.swift` | ~76 | Immutable verified historical image/path pairs, ownership/time checks and current-first bounded Realtime history transport. Never publication geometry. |
| `SpatialContextRecorder.swift` | ~355 | Opt-in Talk lifecycle, verified historical checkpoints, local scene sampling, revision/turn ownership, cancellation and explicit attachment rejection causes. |
| `scripts/SpatialPreparationBenchmark.swift` | ~80 | Offline 1920x1200 synthetic one/three-scene preparation and JSON benchmark (30 samples each), not real capture or model latency. |
| `scripts/benchmark-spatial-preparation.sh` | ~16 | Reuses isolated native regression module to run the benchmark without credentials/network. |
| `SpatialTrailView.swift` | ~50 | Immediate click-through input trail, with separately animated camera-safe ES/EN hint. |
| `scripts/SPATIAL_CONTEXT_QA.md` | ~80 | First-integration limits, offline evidence and pending physical/provider acceptance matrix. |
| `VisualAnnotation.swift` | ~100 | Typed verified-region presentation, no-extent cursor fallback, enclosing ellipse and display-safe caption geometry. |
| `VisualAnnotationMotion.swift` | ~115 | Pure phase timing, curved approach, synchronized arc-length ink/tip samples and grapheme-safe caption progress. |
| `VisualAnnotationView.swift` | ~100 | Click-through tint/glass marks, pointer reflection, stable typed captions and accessibility variants. |
| `VisualTurnContext.swift` | ~245 | Immutable capture evidence, bounded semantic query and typed visual routing, pixel normalization and capture deadline. Preliminary generic window/coordinates are not semantic authority. |
| `scripts/test-native-regressions.sh` | ~43 | Offline module compilation and isolated regression runner; excludes Sparkle entry, broad pre-existing app tests and UI suite. No xcodebuild or app launch. |
| `scripts/VISUAL_INTENT_QA.md` | ~40 | General foreground/background, native, missing/ambiguous, two-monitor and interruption acceptance scenarios for tsk004. |
| `VisualObservation.swift` | ~427 | Short cancellable visual lease, model-scoped luminance/geometry checks, two-refresh budget and silent target relocalization; no OCR or permanent observation. |
| `RealtimeResponseGate.swift` | ~37 | Correlates response metadata/IDs and separates silent visual decisions from authorized spoken replies; rejects late audio/transcripts. |
| `CursyApp.swift` | ~89 | Menu bar app entry point. Uses `@NSApplicationDelegateAdaptor` with `CompanionAppDelegate` which creates `MenuBarPanelManager` and starts `CompanionManager`. No main window — the app lives entirely in the status bar. |
| `CompanionManager.swift` | ~1710 | Central state machine. Coordinates dictation, shortcut monitoring, screen capture, spatial-input recorder, provider-neutral vision fallback, ElevenLabs TTS and overlay. Tracks voice/session ownership and bounded observation; spatial policy/state live in the recorder. |
| `MenuBarPanelManager.swift` | ~48 | NSStatusItem routes to one official Home; first-run opening and onboarding dismissal, no legacy panel creation. |
| `CompanionPanelView.swift` | ~430 | Unreachable legacy view retained as source; all controls now live in Home/settings. Do not restore as a second UI. |
| `CursyLanguage.swift` | ~60 | Spanish/English preference model, locale metadata, and provider-specific response-language instructions. |
| `OverlayWindow.swift` | ~1060 | Full-screen transparent overlay hosting the glass cursor, response text, audio-reactive voice states and cancellable companion-authored annotation choreography. Shared single-artist display ownership, multi-monitor mapping and fade-out transitions. |
| `CursyCursorShape.swift` | ~690 | Arrow/comet-to-circle geometry, bounded audio-reactive pulse rings, presentation springs, native glass, accessibility variants, and interactive DEBUG preview with simulated voice. |
| `CompanionResponseOverlay.swift` | ~217 | SwiftUI view for the response text bubble and waveform displayed next to the cursor in the overlay. |
| `CompanionScreenCaptureUtility.swift` | ~268 | Multi-monitor screenshot capture using ScreenCaptureKit. Captures the cursor display with image dimensions, window metadata and torn-snapshot checks; supports quiet local observation samples. |
| `BuddyDictationManager.swift` | ~866 | Push-to-talk voice pipeline. Handles microphone capture via `AVAudioEngine`, provider-aware permission checks, keyboard/button dictation sessions, transcript finalization, shortcut parsing, contextual keyterms, and live audio-level reporting for waveform feedback. |
| `BuddyTranscriptionProvider.swift` | ~100 | Protocol surface and provider factory for voice transcription backends. Resolves provider based on `VoiceTranscriptionProvider` in Info.plist — AssemblyAI, OpenAI, or Apple Speech. |
| `AssemblyAIStreamingTranscriptionProvider.swift` | ~478 | Streaming transcription provider. Fetches temp tokens from the Cloudflare Worker, opens an AssemblyAI v3 websocket, streams PCM16 audio, tracks turn-based transcripts, and delivers finalized text on key-up. Shares a single URLSession across all sessions. |
| `OpenAIAudioTranscriptionProvider.swift` | ~317 | Upload-based transcription provider. Buffers push-to-talk audio locally, uploads as WAV on release, returns finalized transcript. |
| `AppleSpeechTranscriptionProvider.swift` | ~147 | Local fallback transcription provider backed by Apple's Speech framework. |
| `BuddyAudioConversionSupport.swift` | ~108 | Audio conversion helpers. Converts live mic buffers to PCM16 mono audio and builds WAV payloads for upload-based providers. |
| `GlobalPushToTalkShortcutMonitor.swift` | ~132 | System-wide push-to-talk monitor. Owns the listen-only `CGEvent` tap and publishes press/release transitions. |
| `VisionAPI.swift` | ~105 | Protected purpose-aware vision client, separate localization model, streaming validation, history and image MIME detection. |
| `scripts/evaluate-localization.mjs` | ~285 | Offline-default bounded provider comparison; private fixtures outside repo, content-free metrics, no computer execution. Usage: scripts/LOCALIZATION_QA.md. |
| `scripts/test-session-core.sh` | ~32 | Repeatable isolated compilation/tests of session and replay sources without xcodebuild, app launch, network or credentials. |
| `scripts/SessionTestRunner.swift` | ~8 | Swift Testing entry point for the isolated runner; not part of the app target. |
| `scripts/SESSION_QA.md` | ~35 | Manual continuity/interruption/reset gate and truthful memory limits. |
| `ScreenWindowGrounding.swift` | ~35 | Content-free AX/ScreenCaptureKit window correlation and model-point geometry validation. |
| `PointingDiagnostics.swift` | ~121 | Typed rejection/publication outcomes, reason-specific voice continuation and shared async generic-pointing pipeline. Tests replace provider/OS/publication boundaries, not production validation. |
| `OpenAIAPI.swift` | ~142 | OpenAI GPT vision API client. |
| `OpenAIRealtimeVoiceClient.swift` | ~1225 | Protected Realtime transport, early PTT capture, startup deadline, release-safe ordered PCM drain/commit with 100 ms minimum, parallel release capture, phase metrics, session isolation and bounded route recovery/playback. Preserves visual decision/publication safety. |
| `RealtimeInputDelivery.swift` | ~90 | Pure bounded preconnection PCM delivery and once-only release/finish policy; content-free monotonic phase trace. |
| `scripts/VOICE_LATENCY_QA.md` | ~90 | Offline versus physical latency evidence, numeric metric definitions, lifecycle/device/privacy checks and F3 routing gate. |
| `ElevenLabsTTSClient.swift` | ~81 | ElevenLabs TTS client. Sends text to the Worker proxy, plays back audio via `AVAudioPlayer`. Exposes `isPlaying` for transient cursor scheduling. |
| `ElementLocationDetector.swift` | ~436 | Read-only AX/window grounding, verified accessible annotation extents, validated coordinates and provider-neutral vision localization. |
| `DesignSystem.swift` | ~880 | Design system tokens — colors, corner radii, shared styles. All UI references `DS.Colors`, `DS.CornerRadius`, etc. |
| `CursyAnalytics.swift` | ~28 | No-op analytics interface reserved for a future privacy-reviewed integration. |
| `WindowPositionManager.swift` | ~262 | Window placement logic, Screen Recording permission flow, and accessibility permission helpers. |
| `AppBundleConfiguration.swift` | ~28 | Runtime configuration reader for keys stored in the app bundle Info.plist. |
| `worker/src/index.ts` | ~260 | Cloudflare Worker proxy. Routes for protected vision (vision.ts adapter), ElevenLabs, AssemblyAI tokens, and protected OpenAI Realtime client secrets. |
| `worker/src/runtime.test.ts` | ~86 | Bundled Worker integration in workerd at configured compatibility date, synthetic bindings and mocked outbound requests; auth, conversation, localization and redirect rejection. Included in npm test alongside vision.test.ts. |

## Build & Run

```bash
# Open in Xcode
open Cursy.xcodeproj

# Select the Cursy scheme, set signing team, Cmd+R to build and run

# Known non-blocking warnings: Swift 6 concurrency warnings,
# deprecated onChange warning in OverlayWindow.swift. Do NOT attempt to fix these.
```

**Do NOT run `xcodebuild` from the terminal** — it invalidates TCC (Transparency, Consent, and Control) permissions and the app will need to re-request screen recording, accessibility, etc.

## Cloudflare Worker

```bash
cd worker
npm install

# Add secrets
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put CURSY_INTERNAL_API_TOKEN

# Deploy
npx wrangler deploy

# Local dev (create worker/.dev.vars with your keys)
npx wrangler dev
```

## Code Style & Conventions

### Variable and Method Naming

IMPORTANT: Follow these naming rules strictly. Clarity is the top priority.

- Be as clear and specific with variable and method names as possible
- **Optimize for clarity over concision.** A developer with zero context on the codebase should immediately understand what a variable or method does just from reading its name
- Use longer names when it improves clarity. Do NOT use single-character variable names
- Example: use `originalQuestionLastAnsweredDate` instead of `originalAnswered`
- When passing props or arguments to functions, keep the same names as the original variable. Do not shorten or abbreviate parameter names. If you have `currentCardData`, pass it as `currentCardData`, not `card` or `cardData`

### Code Clarity

- **Clear is better than clever.** Do not write functionality in fewer lines if it makes the code harder to understand
- Write more lines of code if additional lines improve readability and comprehension
- Make things so clear that someone with zero context would completely understand the variable names, method names, what things do, and why they exist
- When a variable or method name alone cannot fully explain something, add a comment explaining what is happening and why

### Swift/SwiftUI Conventions

- Use SwiftUI for all UI unless a feature is only supported in AppKit (e.g., `NSPanel` for floating windows)
- All UI state updates must be on `@MainActor`
- Use async/await for all asynchronous operations
- Comments should explain "why" not just "what", especially for non-obvious AppKit bridging
- AppKit `NSPanel`/`NSWindow` bridged into SwiftUI via `NSHostingView`
- All buttons must show a pointer cursor on hover
- For any interactive element, explicitly think through its hover behavior (cursor, visual feedback, and whether hover should communicate clickability)

### Do NOT

- Do not add features, refactor code, or make "improvements" beyond what was asked
- Do not add docstrings, comments, or type annotations to code you did not change
- Do not try to fix the known non-blocking warnings (Swift 6 concurrency, deprecated onChange)
- Keep the project directory, target, and scheme named `Cursy`.
- Do not run `xcodebuild` from the terminal — it invalidates TCC permissions

## Git Workflow

- Branch naming: `feature/description` or `fix/description`
- Commit messages: imperative mood, concise, explain the "why" not the "what"
- Do not force-push to main

## Self-Update Instructions

<!-- AI agents: follow these instructions to keep this file accurate. -->

When you make changes to this project that affect the information in this file, update this file to reflect those changes. Specifically:

1. **New files**: Add new source files to the "Key Files" table with their purpose and approximate line count
2. **Deleted files**: Remove entries for files that no longer exist
3. **Architecture changes**: Update the architecture section if you introduce new patterns, frameworks, or significant structural changes
4. **Build changes**: Update build commands if the build process changes
5. **New conventions**: If the user establishes a new coding convention during a session, add it to the appropriate conventions section
6. **Line count drift**: If a file's line count changes significantly (>50 lines), update the approximate count in the Key Files table

Do NOT update this file for minor edits, bug fixes, or changes that don't affect the documented architecture or conventions.
