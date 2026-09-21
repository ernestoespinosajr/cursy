# Project logbook

**Last updated:** 2026-09-21
**Project status:** bootstrap complete; internal macOS prototype
**Current focus:** authorized native Home text/mic/shortcut/selected-text port (tsk007); physical QA, indicator regions and guide prerequisites stay open

## Snapshot

- 2026-09-21: usuario autoriza commit/push a dev. Memoria consolidada en
  [decisiones y aprendizajes](product-and-platform-lessons.md): diseño aprobado,
  selección aislada, detección AX por capacidades, audio y límites de validación.
  Incluye Home/indicadores/prototipo y correcciones nativas acumuladas. Imagen de
  concepto de branding excluida por ser ajena a este conjunto; gates siguen abiertos.

- 2026-09-21 tsk007: usuario acepta colocación GPT; Claude/Outlook revelan límites
  de sondeo/acción única. Nuevo SelectionMenuSearch compartido con tests barre la
  franja y recupera el contenedor completo, sin reglas por app.232/27 pasan en
  ejecución final. Xcode remoto no respondió; Build/Run y QA física pendientes.

- 2026-09-21 QA visual tsk007: usuario confirma oferta y reporta mala colocación.
  Se contrasta anclaje AX con arrastre actual y amplía detección de menú; barra/
  input se alinean encima del menú con12pt, fallback debajo.225/26 pasan offline.
  Automatización Xcode agotó tiempo al verificar último build; Run/QA de ubicación
  pendientes. Sin cambios de diseño, audio, permisos ni contexto seleccionado.

- 2026-09-21 corrección autorizada tsk007: preparación AX por capacidad con
  warmup2.3s sin reiniciar debounce, lectura ligada a ventana, búsqueda paginada
  priorizando áreas web y ráfagas de foco a menú sin cancelar el gesto.11 nuevas
  regresiones;219/26 pasan, Xcode Build/Run. Mantiene barra compacta y contexto
  solo seleccionado. QA física en Comet/Claude/GPT pendiente; automatización
  confirma selección AX, no presencia de barra. Detalles y límites en tsk007.

- 2026-09-21 investigación tsk007: barra compacta aceptada; selección aún falla
  según usuario en Comet/GPT/Claude con menús. Comet expone selección a CUA nativo;
  logs Cursy muestran fallos pre-presentación y límite48. Detectado desajuste
  espera120ms vs debounce2s upstream Electron; foco/búsqueda/geometry siguen frágiles.
  Diagnóstico y propuesta en tsk007, sin modificación de runtime, build o pruebas
  nuevas. No causa única confirmada en las tres apps ni bloqueo demostrado.

- 2026-09-21 seguimiento tsk007: usuario confirma selección en otra app, aún
  ausente en GPT. Oferta compacta160×32 sin logo en app/prototipo. Se añade
  activación AXManualAccessibility por capacidad (documentada por Electron) y
  conservación breve del anclaje mouse-up ante notificaciones AX tardías.
  208 pruebas/25 suites nativas y28 Node pasan; Xcode Build succeeded15:09.
  Causa concreta/aceptación en GPT sigue pendiente; no bloqueo demostrado,
  clipboard/OCR ni promesa de compatibilidad universal.

- 2026-09-21 QA tsk007: usuario reporta selección ausente en ChatGPT y luego hang
  al probar entrada integrada. Se corrigen rutas de micrófono predeterminado y
  prueba aislada del hilo UI; selección AX amplía rangos web/ancestros y eventos
  nativos. Sin app-specific rules/clipboard/OCR. Verificación física sigue abierta;
  203 tests/25 suites pasan (capturador simulado). No cierre del ticket ni
  afirmación de compatibilidad universal o prueba de audio real.

- 2026-09-21: neutral UI borders in prototype/native captions; cursor/icons and
  actual guidance retain tint. Native text streaming/drafts, mic UID/local test,
  shortcut recorder, selected-text AX offer→input→isolated chat/voice integrated.
  Actual playback completion starts capture after greeting. No clipboard/OCR or
  screen input in selection chats. AX compatibility/audio/focus acceptance remains;
  tsk007 records limits. Final offline191 tests/24 suites +28 Node passed;
  Xcode UI Build Succeeded13:15 and Running Cursy13:16, no audio/provider test.

| State | Count |
|---|---:|
| Planned | 9 |
| In progress | 4 |
| Completed | 10 |
| Failed | 0 |

## Project profile

- **Name/type:** Cursy, native macOS menu-bar AI companion; MIT-derived from Clicky.
- **Stack:** SwiftUI/AppKit, AVFoundation, ScreenCaptureKit, Accessibility;
  TypeScript Cloudflare Worker. macOS deployment target 14.2; Swift language mode
  5.0 in Xcode project (installed compiler is Swift 6.4).
- **Packages:** Sparkle 2.9.0 via SPM; Wrangler ^4.135.0 via npm lockfile.
- **App validation:** open `cursy-app/Cursy.xcodeproj`, use Cursy scheme,
  Build/Run and Product → Test in Xcode. Never terminal xcodebuild (repo policy).
- **Worker validation:** in `cursy-app/worker`, `npm test` runs Node contract tests
  and bundled-handler integration in workerd with mocked outbound requests.
  `npx wrangler deploy --dry-run --outdir /private/tmp/cursy-worker-check`
  bundles without upload. No configured lint/typecheck script.
- **Release:** `cursy-app/scripts/release.sh` signs/notarizes/publishes and pushes;
  not a routine validation command; requires separate authorization/review.

## Structure and component registry

Paths below are repository-relative.

| Boundary | Evidence / reusable component |
|---|---|
| Native entry/lifecycle | `cursy-app/Cursy/CursyApp.swift`: AppDelegate starts manager, status panel, login item; Sparkle startup currently commented out |
| Conversation coordinator | `cursy-app/Cursy/CompanionManager.swift`: PTT, voice states, screenshots, fallback, in-memory last 10 exchanges |
| Native controls/language | `cursy-app/Cursy/MenuBarPanelManager.swift` routes to official Home; `HomeSettingsView.swift`, `CursyLanguage.swift`; preferences in UserDefaults |
| Visual output | `cursy-app/Cursy/OverlayWindow.swift`, `cursy-app/Cursy/CursyCursorShape.swift`, `cursy-app/Cursy/CompanionResponseOverlay.swift` |
| Realtime | `cursy-app/Cursy/OpenAIRealtimeVoiceClient.swift`: protected broker, direct ephemeral-token WebSocket, PCM queue/capture/playback and bounded route recovery |
| Legacy voice | `cursy-app/Cursy/BuddyDictationManager.swift`, `cursy-app/Cursy/BuddyTranscriptionProvider.swift`, `cursy-app/Cursy/BuddyAudioConversionSupport.swift`; AssemblyAI/OpenAI/Apple Speech providers |
| Fallback vision/TTS | `cursy-app/Cursy/VisionAPI.swift`, `cursy-app/worker/src/vision.ts`, `cursy-app/Cursy/ElevenLabsTTSClient.swift`; protected OpenAI vision adapter; separate legacy TTS |
| Capture/permissions | `cursy-app/Cursy/CompanionScreenCaptureUtility.swift`, `cursy-app/Cursy/WindowPositionManager.swift`, `cursy-app/Cursy/GlobalPushToTalkShortcutMonitor.swift` |
| Visual localization/validation | `cursy-app/Cursy/ElementLocationDetector.swift`, `cursy-app/Cursy/VisualTurnContext.swift`, `cursy-app/Cursy/ScreenWindowGrounding.swift`; OpenAI image interpretation plus content-free native window/geometry validation, no local OCR |
| Worker | `cursy-app/worker/src/index.ts`, `cursy-app/worker/wrangler.toml`, `cursy-app/worker/package.json` |
| Native tests | `cursy-app/CursyTests/CursyTests.swift` (Swift Testing: geometry, motion, PCM, language, permissions); `cursy-app/CursyUITests/CursyUITests.swift` (XCTest launch scaffolding) |
| Packaging/config | `cursy-app/Cursy.xcodeproj/project.pbxproj`, `cursy-app/Cursy/Info.plist`, `cursy-app/Cursy/Cursy.entitlements`, `cursy-app/scripts/release.sh` |
| Visual lab | `prototypes/VoiceContourPrototype.swift`: independent native demo, no microphone/network |
| Landing page | `hellocursy/README.md`: reserved workspace, implementation not present |
| Persistent context | `workflow/` only; specialist instructions in `.agents/skills/` |

## Active work

- 2026-09-21 tsk007 prototype morph: Ask Cursy button transforms into compact
  input over250ms; only material scales, text crossfades and focus is immediate.
  Cancellation cleanup, keyboard bypass and reduced-motion fade retained.
 28 Node tests pass; browser verifies intermediate/final state and Escape.
 Native unchanged.

- 2026-09-21 tsk007 selection refinement: one-line370×46 input,12px corners,
  compact340px notch notification with clipped symmetric400ms reveal/retract.
  Synthetic app-menu bounds drive collision-free placement (above preferred,
  below fallback, suppress when crowded); no native screen/menu detection.
  26 Node tests pass; browser verifies layout, send and animated exit. Native
  unchanged; selection snapshot/consent boundaries retained.

- 2026-09-21 tsk007 selected-text prototype: selecting the synthetic document
  offers Ask Cursy → contextual input/mic. Text opens a fresh selection-only chat;
  voice previews Cursy-first greeting then listening in the existing notch.
  Exact snapshots, no prior-chat/screen context, cancellable greeting token.
  Native unchanged; no AX, real audio or network. 22 Node tests pass; browser
  verifies both paths and early cancellation. Design/native integration pending.

- 2026-09-21 tsk007 F3 design preview: existing notch web lab now includes text
  composer, per-chat drafts, send/stop example replies and Voice/Microphone/Shortcuts
  settings. Device list, level test, permission failures and shortcut capture are
  explicitly simulated; no audio, network, native preferences or manual objective.
  Shared gradient/SF Symbols retained. 17 Node tests pass; browser checks cover
  text, multiline drafts, mic failures and shortcut capture/cancel. Native app
  untouched; awaiting design feedback before implementation. No task closure.

- 2026-09-21 tsk007 follow-up: user rejects manual conversation-objective setup.
  Removed field in Home and unreachable legacy view plus editing/focus plumbing;
  Home is non-key/non-main again. Existing request/history remain the source of
  conversational intent; no extra model call or automatic authority inference.
  Setup guard and all other migrated controls retained. Offline184 tests/22 suites
  pass; Xcode UI Build Succeeded11:21 and diff check clean. No app restart or
  model evaluation; this is UI simplification, not a new goal-extraction system.

- 2026-09-21 tsk007: user promotes Home to official/default interface. Status
  icon no longer creates legacy menu; missing objective, permissions, introduction,
  feedback and quit migrated into General/Privacy/Help. Shared gradient and accepted
  animations retained, preferences untouched. Editing is explicit; hover stays
  nonactivating, setup/editing retain Home. PTT no longer dismisses the retired
  menu, preserving automatic island. Final184 tests/22 suites and Xcode11:16
  build pass; diff check clean. Physical focus/permission QA
  remains; no restart, deployment or commit. tsk007 stays open for text/mic/settings.

- 2026-09-21 tsk005 native single-target visual port: shared cursor tint/glass rim,
  companion-authored1000ms trace, independent typed captions and safe cancellation.
  Read-only verified AX extents size circles/rectangles; unavailable bounds fall
  back to cursor. No per-mark settings/clear. Offline181 tests/22 suites pass;
  native light/dark render reviewed. Xcode UI Build succeeded10:52 with existing
  warnings; no app restart or live input. User motion/AX quality QA pending. Generic
  image-region locator and multi-mark/live-guide lifecycle are NOT implemented;
  tsk005/009/010 remain open. No models, Worker deployment, commit or push changed.

- 2026-09-21 tsk005 prototype revision 4: Cursy approaches/presses/drags to grow
  rectangles and traces circles/arrows. One synthetic actor,
  sequential marks, 1600ms drawing. No physical pointer or native change.
  Eleven motion/geometry tests pass; browser reviewed shapes and stale cancellation.
  User loves the design; after pacing refinements, applied uniform 1.6×
  playback, preserving choreography and accessibility. Single-target native port
  is summarized in the newer entry; generic regions and multiple marks remain pending.
  Explanations appear directly above target with caption entrance + typing, no
  connector or artist. Thirteen tests pass; browser verified stable typing layout.

- 2026-09-21 tsk005 prototype revision 3: one-shot smooth contour tracing,
  pointer-reactive glass rim and brief success/next-step congratulations.
  User asks for a slower premium feel: trace now 1400ms at even pace, soft opacity
  entrance and 450ms captions, replacing the fast-start 650ms ease-out.
  Geometry stays fixed; reduced motion suppresses tracing/reflection. Browser
  checked final/intermediate outcomes and stale-step blocking; five geometry tests
  and syntax/diff checks pass. Prototype only; native and live verification pending.

- 2026-09-21 tsk005 prototype revision 2: adaptive region-sized tinted guidance,
  full-paragraph focus and three-mark drag/drop sample. Shares Cursor palette;
  no per-mark clear control. Proposed contract in prototypes/notch-voice/guidance-contract.md
  covers validated bounds/group lifetime; tsk009/010 retain guide/observation work.
  Synthetic DOM geometry only, no native region or continuous observation port.
  Browser reviewed; five geometry tests pass. Await design acceptance.

- 2026-09-21 native tsk005/tsk007 follow-up: removed Home and legacy-menu style
  selectors and the persisted preference reader/writer. Realtime chooses style;
  nil/automatic/legacy fallback uses Cursor, refresh retains the chosen mark.
  Clear/cancel and target validation unchanged. Offline 175 tests/22 suites pass;
  Xcode UI Build succeeded 07:42 (existing warnings). Live style quality remains
  an explicit QA gate; no new provider, deployment, Run or commit.

- 2026-09-21 user feedback: tsk017 response time has improved (qualitative acceptance,
  not a measured p50/p95 or device matrix); tsk007 animations now match the desired
  design. Keep remaining phases open. tsk005 design clarified: the agent chooses
  visual guidance style, time and validated destination, not a user preference.
  Existing prototype gains five synthetic examples and removes General's style
  picker. Native preference/routing migration remains pending; no model calls,
  native code, build or deployment in this design pass.

- tsk017 in progress: native F1/F2 implemented (early capture, bounded PCM,
  release-before-connect, parallel screenshot/commit, numeric timing). Offline
  168 tests/21 suites pass; Xcode UI Build succeeded, no Run/live calls.
  Physical latency/first-word/device gate pending; F3 routing/prewarm awaits
  measured baseline and safety evaluation. Models and tsk007 design gate unchanged.

- tsk007 authorized: ct017 incorporated into the existing 11-layer plan; begin
  F1 opt-in Home prototype driven by the existing session. Preserve models,
  cursor, microphone ownership and external focus. Manual design gate before
  F2/F3; no new router, agents, deployment or closure of tsk005/006.
  F1 implemented: menu entry “Probar Home · Beta”, single non-key panel,
  compact/expanded/detached views, live session projection and original settings
  shortcut. User-requested listening polish reuses the real microphone meter:
  five voice bars and diffuse bottom mint/blue/violet light, static in silence,
  reduced-motion/transparency alternatives, no extra audio/timer. 131 tests/16
  suites pass; native module compiles. Physical/design acceptance pending in
  scripts/SETTINGS_QA.md; no text composer in F1.
  Build repair: explicit CoreGraphics/Combine imports in HomePresentation/HomeView;
  offline runner now enforces Xcode's MemberImportVisibility. Xcode UI Build
  succeeded on 2026-09-19 (no app launch); previous offline build missed this flag.
  Notch refinement: compact/conversation now attach flush below the real camera
  housing; black-to-transparent surface, white text, top-origin reveal, reduced
  motion/transparency alternatives and external-display fallback. 134 tests/16
  suites pass; Xcode UI Build succeeded (16:00), synthetic renders reviewed.
  Physical notch/motion/focus acceptance remains pending; F2/F3 not started.
  Glass refinement: actual Liquid Glass (macOS 26+) / behind-window material
  fallback, broad black-to-clear gradient, locally protected text. Reduced
  transparency/increased contrast use solid black. 137 tests/17 suites pass;
  Xcode UI Build succeeded (16:07), synthetic color-backdrop renders reviewed.
  Latest refinement: notch-hover open (180 ms), idle exit hide (800 ms), activity/
  pointer/drag/VoiceOver guards, detached exemption and reversible auto-close.
  Camera-width neck with curved shoulders; footer removed, status/shortcut/session
  lifetime integrated in header. 144 tests/18 suites pass; physical hover/design
  acceptance remains pending. Xcode UI Build Succeeded (22:38); final light/dark
  renders reviewed. No audio/model/Worker changes or new ticket.
  2026-09-20: user reports tinted notch join/small gap and requests smaller,
  automatic voice capsule. User then requests DESIGN FIRST; native implementation
  paused pending selection. Isolated `prototypes/notch-voice/index.html` now compares
  Compacta / Ampliada: both wrap the camera with lateral voice content, replacing
  rejected below-notch chips. Expanded Home uses one continuous black neck/body
  silhouette; gradient starts below the neck. Synthetic controls/browser checks
  pass; native integration still awaits user selection and physical validation.
  Prototype now includes the cursor→notch listening sequence, hidden processing,
  exit-to-target and return, plus reversible 250 ms surface reveals (no text scale).
  Replay/stop, manual states and reduced-motion preview are available; simulation
  only, without microphone or real pointer control. Native gate remains unchanged.
  Native integration authorized 2026-09-20: Ampliada-style island surrounds the
  measured camera (width +252 pt, minimum height 52 pt), opaque neck/header and
  lateral controls. Voice opens it automatically; explicit dismissal suppresses
  that turn, detached/no-notch fallback retained. Existing buddy flies to camera,
  hides during listening/processing and exits for a validated target/response.
  Reveal/cursor flights 250 ms, reduced-motion alternatives, stale callbacks
  invalidated, no physical pointer/audio/model changes. Offline 150 tests/19 suites
  pass; production-view light/dark renders reviewed. F1 physical acceptance remains
  pending; F2/F3 not started. Xcode UI Build Succeeded 2026-09-20 17:49; no Run.
  Latest explicit request authorizes limited F2: chat/settings sidebar, five cursor
  glass tints with matching shadows, 800 ms curved arrival +140 ms visual click
  before island reveal. Audio remains immediate. Up to 20 memory-only chats with
  terminal text snapshots and fresh session identities; durable storage still tsk008.
  Settings reuse real controls; no new models/audio or fake capabilities. 155 tests/
  20 suites pass; final Xcode UI Build Succeeded 19:51. Native optics, timing and focus
  acceptance pending; remaining F2/F3 not claimed complete.
  User requests design-first correction after screenshots: revision 3 of the
  existing web lab now has a full-height transparent sidebar/settings over one
  gradient, actual locally rendered SF Symbols, and spatial hint below camera.
  Chats/settings/colors and previous curved-flight sequence are previewed together.
  Browser geometry/navigation/cancellation checks pass; native app unchanged.
  Await this design's approval before porting corrections; see prototype README.
  User likes revision 3 and requests a notification-like hint: prototype now
  slides it out of a clipped notch-edge slot (250 ms, no text scale; reduced
  motion fades only). Browser confirms start/end geometry and cancellation.
  No new native implementation authorization inferred from aesthetic approval.
  Latest: prototype separates connecting/listening; spatial hint and input waves
  stay hidden while connecting. Read-only native latency review finds serialized
  broker/socket/history before mic and visual decision before speech. Existing
  logs: captures 78–121 ms, capture-ready→visual decision 2.665–4.377 s, one
  localization adds 4.347 s. Initial PTT→first PCM and first-audio latency remain
  unmeasured. Native optimization/gating recommendation recorded in tsk007;
  no native/provider/model changes, real mic tests or deployment this revision.
  Hint polish: user requests gentler entrance; prototype now uses synchronized
  400 ms ease slide/fade in both directions (user also requested a gentler exit),
  and reduced-motion fade only. Browser
  verifies timing/state gates; no input delay or native changes.
  User now explicitly authorizes the native port before combined testing:
  full-height sidebar/settings over shared gradient, SF Symbols, and camera-safe
  real-listening hint with symmetric400 ms slide/fade (reduced150 ms). Existing
  flight/click activation and tsk017 early capture remain independent. 173 tests/
  22 suites pass; four static native layouts reviewed. Physical acceptance pending;
  no models, providers, Worker, microphone tests or Run changed by this port.
  Final Xcode UI Build Succeeded 22:26; offline rerun173/22 passes; diff-check clean.

- tsk006 multiscene continuation: Realtime receives up to two verified earlier
  scene checkpoints plus the current clean/reference pair, bounded to 3 MiB total.
  History is interpretation-only; no old coordinates/window IDs enter publication
  or the live observation lease. Scroll/monitor boundaries clear the live trail;
  unverified tails and over-budget history are explicitly omitted. Offline tests
  and synthetic preparation benchmark pass (execution details in tsk006).
  No provider/model/Worker changes, paid evaluation or deployment. User accepted
  the tested multiscene experience on 2026-09-19; broader semantic evaluation and
  physical end-to-end latency remain pending. User subsequently authorized
  tsk007 Home prototype after the ct017 review; no inference of full tsk006 closure.

- tsk006 / ct014 repair: native Realtime separates explain/locate/combined intent;
  explanation no longer routes to the control locator because of a nonempty query.
  Valid gestures gain a bounded marked reference copy alongside the unchanged clean
  image; turn/display/revision checks and existing publication validation remain.
  No new providers, OCR, Worker changes or deployment. Offline 115 tests/14 suites
  pass. User reports the correction works perfectly (2026-09-19): current tested
  interaction accepted. Broader semantic evaluation, cost/latency, multisegment
  and full-ticket acceptance remain open; no additional scenario coverage inferred.

- ct016: user Deepgram/Cerebras research checked against official docs. Separate
  STT/TTS/vision/inference; Spanish TTS needs Aura-2, not English-only Flux TTS.
  Cerebras has model-specific multimodal options with endpoint/access caveats;
  provider presence does not establish HeyClicky's exact routing. Preserve voice
  while fixing tsk006; later benchmark quality and end-to-end latency separately.
  Analysis only: `workflow/00-context/ct016-voice-inference-provider-roles.md`.

- ct015: official HeyClicky research identifies announced Fable 5 screen default
  and Realtime 2.1 voice, plus deeper-model routing; exact current backend mapping
  remains undisclosed. Recommend evaluating current Fable 5.1 against Astra only
  after ct014 semantic-contract fixes, not replacing providers as a presumed cure.
  Fable 5.1 forced-tool incompatibility needs adapter design. No runtime changes,
  paid calls or deployment; `workflow/00-context/ct015-spatial-model-selection.md`.

- ct014: diagnosis before the user-accepted repair above. Four initial attempts sent 89–113
  path points; packet loss is not the observed initial failure. Logs show one
  scene-refresh exhaustion, one conversation route, one pointing_not_requested
  incorrectly diverted by a nonempty query to the UI-only locator (no target),
  and one unobserved decision before expiry. Offline production-route probe
  reproduces the routing conflict. Recommend refining existing tsk006 to separate
  content understanding from mark publication, then evaluate gesture encoding.
  Investigation only; no runtime changes or provider calls. Exact private
  utterances/images unavailable; `workflow/00-context/ct014-spatial-understanding-routing.md`.

- ct013: user sees spatial trail but no safe highlight. Recent logs show four
  providerNoTarget results (locator invoked; display 2 captured), not rejected
  coordinates. Bool callback masks causes as validation_failed. Spatial packet
  delivery is not logged, so its loss versus semantic failure remains unknown.
  Read-only diagnosis: `workflow/00-context/ct013-spatial-input-no-target.md`.
  Refine existing tsk006 diagnostics/outcomes/evaluation; beta not accepted.
  Refinement local phases implemented: delivery diagnostics, typed voice outcomes,
  explicit refresh loss and UTF-16 budget. Fixed contradictory instruction forcing
  limitations for explanatory no-point requests. Synthetic transport mocks pass;
  **110 tests/14 suites**, native module compiles. Provider evaluation requires
  cost authorization; semantic accuracy, live QA and multisegment remain open.

- tsk006 first integration: opt-in Talk input trail, normalized scene/turn-bound
  metadata through existing Realtime/fallback/locator; current scene only. Local
  snapshots, no per-move model calls/OCR, single-flight capture and cancellation.
  Native module compiles; **101 tests/13 suites pass**. No deployment/real capture.
  Multi-scene evidence, provider evaluation, latency and live acceptance remain;
  `scripts/SPATIAL_CONTEXT_QA.md`. tsk005 still awaits its independent visual test.

- ct012 programme planned at user request as tsk006–016, one file per delivery.
  Priority: spatial input → Home/settings → durable conversations → guides →
  verification → dictation → service security → bounded agents → confirmed local
  actions → scoped integrations → opt-in routines. tsk012 is a launch gate and
  can move earlier; dictation is independent of guides. Next implementation:
  tsk006 now authorized while user is remote; tsk005 manual acceptance is NOT granted.
  tsk012 is deferred for the experience prototype, still required before rollout.

- tsk005 in progress: typed circle/arrow/rectangular-focus/label presentation on
  validated points; reuses overlay/observation and current providers. No element
  bounding boxes inferred from a point. User accepted tsk003 continuity,
  interruption and reset on 2026-09-19; session ticket is completed.
  Implementation ready for live acceptance: default-style menu, explicit Realtime
  voice override, clear/reset/invalidation and shared publication. Native module
  compiles, 85 isolated tests/12 suites pass; static light/dark sheet inspected.
  Manual gate scripts/ANNOTATION_QA.md. No Worker deployment or audio changes.

- tsk004 implemented from ct011: typed semantic query routes generic and negative
  locate decisions to Astra without a hard preliminary window constraint. Resolved
  target owns freshness/geometry checks; native fast path retained. Native module
  compiles, 81 isolated tests/11 suites pass. User tested successfully and accepted
  delivery on 2026-09-19; tsk004 completed. Broader QA checklist remains regression
  coverage, not an exhaustively executed matrix. No OCR/app-specific rules.
- ct011 diagnosis: latest named-app QA captured display 1 successfully. Two locator
  calls returned no target while constrained to the same preliminary window; its
  frame matches foreground Xcode in the attachment (identity inference). Final
  Realtime target_missing bypassed the locator. Correction accepted in tsk004.
  Literal transcript/image from that historical attempt not retained.
- tsk002 completed: user explicitly accepted the deployed voice + screen + pointing
  delivery. Sessions subsequently accepted; next: annotations, walkthroughs and
  step verification. Acceptance is user-reported, not an exhaustive QA matrix.
- ct010 Worker deployed and smoke-verified: independent Astra localization
  via Responses/original/strict function, caller-owned capture metadata. Repeated
  fixture results: Astra12/12, Sonnet12/12, Sol8/8; DeepSeek3/4, GPT-4.1 1/4.
  User requires zero observed failures for admission, not a claim of infallibility.
  Worker19 tests, evaluator11, native65 pass; 10 remote smoke checks pass.
  User accepted the native result after deployment; retain broader regression QA
  before future releases. No new native build/test executed for documentary closure.
- tsk002 ct007 refinement integrated: bounded visual lease, scene invalidation,
  recapture and silent relocalization, with Realtime/fallback guards. 54 isolated
  tests passed at that phase; included in the final user-accepted delivery.
- ct008 correction integrated: silent visual decisions, response-ID audio/history
  gate, model-selected window comparison and deferred diagnostic emission. 62 tests
  in 11 suites passed at that phase; final delivery subsequently accepted.
- Follow-up: ElementLocationDetector supplies AX grounding to Realtime and uses
  provider-neutral VisionAPI for text-fallback localization. Anthropic direct
  detector removed; OpenAI /vision adapter deployed and remote smoke tests pass.
  Native window controls require verified IDs; final delivery accepted.
- Multimonitor: sample cursor display immediately before capture, reject crossing/
  layout changes during capture, rebuild overlays on display-configuration changes.
  Five geometry layouts covered by added tests; user confirmed multimonitor works.
- Bootstrap and cursor work are complete; product roadmap rows are recommendations,
  not already-created implementation tickets.
- User accepted basic visual/multimonitor flow; active-window clarification
  refinement implemented (explicit JSON active window, focus-first ordering).
- Dock follow-up: bounded AX application-item names/IDs + visible hit-test and
  revalidation; dock_application intent requires real control ID. Shared guidance
  no longer equates "show me how to open" with performing a click.
- Provider-vision correction supersedes the interim local OCR experiment. OpenAI
  interprets the authorized screenshot and supplies image-pixel target coordinates
  with exact raster dimensions (normalized only at the internal boundary);
  native code only validates capture/window/display geometry. WhatsApp remains a
  QA fixture, not a product rule; preserve multi-monitor regression coverage.
- Shared visual policy generalized: visible target first for any application/UI
  element, not chats; preserve target/app/constraints across follow-up steps.
- Multimonitor visual grounding correlates AX and ScreenCaptureKit/CGWindow IDs
  without reading screen text. Model coordinates bind to actual captured windows
  and revalidate frame/z-order before pointing. Cursor-display images preserve up
  to 1920 px on the long side within 1 MiB.
- Visual turns now require an explicit `resolve_visual_guidance` tool decision
  before spoken output. Location requests are cursor-first; accepted points get
  only a brief spoken confirmation, while unsafe targets produce clarification
  instead of unverified spatial directions. Fallback follows the same general rule.
- The interim hybrid OCR recovery was removed by user decision. OpenAI must make
  the semantic visible-target decision from the image; an incorrect `target_missing`
  is handled through provider evaluation/prompting rather than a local text engine.
- Capture publishes canonical visual-window identities; legacy AX aliases normalize
  by owner/frame. Returned model coordinates still require current window, display
  and z-order validation. Content-free rejection diagnostics remain.
- tsk003 continuity integrated: user transcription correlated to committed audio,
  bounded text-only Realtime history replay, optional objective and new-conversation
  reset. User reported live context loss; follow-up retains transcribed requests
  even when replies are interrupted, clarifies automatic capture, adds content-free
  diagnostics. Resumed hardening adds immutable async session/turn ownership and
  core text limits; 17 focused tests and 71 isolated regression tests pass.
  Run `bash cursy-app/scripts/test-session-core.sh`; checklist in
  `cursy-app/scripts/SESSION_QA.md`. User accepted continuity/interruption/reset
  on 2026-09-19; tsk003 completed.

## Task index

| ID | Status | Type | Path | Goal | Related context |
|---|---|---|---|---|---|
| tsk006-spatial-context | in progress | feature | `workflow/02-in-progress/tsk006-spatial-context.md` | Contexto espacial durante la voz | ct012; tsk005 manual QA pending |
| tsk007-home-notch-settings | in progress | feature | `workflow/02-in-progress/tsk007-home-notch-settings.md` | Official Home + legacy controls migrated; text/mic/settings and physical QA pending | ct012, ct017; implemented tsk006 contracts |
| tsk008-persistent-conversations | planned | feature | `workflow/01-planned/tsk008-persistent-conversations.md` | Conversaciones persistentes y memoria controlada | ct012; tsk007 |
| tsk009-persistent-walkthroughs | planned | feature | `workflow/01-planned/tsk009-persistent-walkthroughs.md` | Guías paso a paso persistentes | ct012; tsk006, tsk008 |
| tsk010-step-verification | planned | feature | `workflow/01-planned/tsk010-step-verification.md` | Verificación visual y avance supervisado | ct012; tsk009 |
| tsk011-safe-universal-dictation | planned | feature | `workflow/01-planned/tsk011-safe-universal-dictation.md` | Dictado universal seguro | ct012; tsk007 |
| tsk012-identity-quotas-provider-security | planned | feature | `workflow/01-planned/tsk012-identity-quotas-provider-security.md` | Identidad, cuotas y seguridad del servicio | ct012; base actual |
| tsk013-bounded-agent-workspaces | planned | feature | `workflow/01-planned/tsk013-bounded-agent-workspaces.md` | Agentes persistentes, adjuntos y resultados | ct012; tsk008, tsk012 |
| tsk014-confirmed-local-actions | planned | feature | `workflow/01-planned/tsk014-confirmed-local-actions.md` | Acciones locales verificadas y autorizadas | ct012; tsk010, tsk012, tsk013 |
| tsk015-scoped-integrations | planned | feature | `workflow/01-planned/tsk015-scoped-integrations.md` | Integraciones con permisos por capacidad | ct012; tsk012, tsk013 |
| tsk016-opt-in-routines-notifications | planned | feature | `workflow/01-planned/tsk016-opt-in-routines-notifications.md` | Rutinas y avisos proactivos controlados | ct012; tsk012, tsk013, tsk015 |
| tsk005-visual-annotations | in progress | quick feature | `workflow/02-in-progress/tsk005-visual-annotations.md` | Validated point-centered focus marks and labels | `ct001`, `tsk003`, `tsk004` |
| tsk004-visual-intent-window-resolution | completed | quick feature | `workflow/03-completed/tsk004-visual-intent-window-resolution-completed.md` | User-accepted natural-language target/window resolution; safety preserved | `ct011`, `tsk002`, `tsk003` |
| tsk002-realtime-screen-pointing | completed | quick feature | `workflow/03-completed/tsk002-realtime-screen-pointing-completed.md` | User-accepted voice, screen and pointing delivery | `ct001`, `ct005`–`ct010`, `micro003`, `micro005` |
| tsk003-session-core | completed | quick feature | `workflow/03-completed/tsk003-session-core-completed.md` | User-accepted session continuity, interruption and reset | `tsk002` |
| tsk000-initial-project-context | completed | bootstrap | `workflow/03-completed/tsk000-initial-project-context-completed.md` | Build the initial project intelligence baseline | built in |
| tsk001-liquid-glass-cursor-morph | completed | quick feature | `workflow/03-completed/tsk001-liquid-glass-cursor-morph-completed.md` | Approved fixed-orientation glass cursor morph | `micro004`, `ct001` |
| micro005-unified-voice-cursor | completed | micro-task | `workflow/03-completed/micro005-unified-voice-cursor-completed.md` | Accepted soft-mint fluid voice cursor, 80% visual intensity | `tsk001`, `micro003`, `ct004` |
| micro001-configure-openai-worker-secret | completed | micro-task | `workflow/03-completed/micro001-configure-openai-worker-secret-completed.md` | Configure the OpenAI secret for the Worker without exposing it | `ct001` |
| micro002-openai-realtime-session-endpoint | completed | micro-task | `workflow/03-completed/micro002-openai-realtime-session-endpoint-completed.md` | Deploy a protected OpenAI Realtime session endpoint | `ct001` |
| micro003-openai-realtime-macos-client | completed | micro-task | `workflow/03-completed/micro003-openai-realtime-macos-client-completed.md` | Integrate protected Realtime voice into the macOS push-to-talk flow with fallback | `ct001`, `micro002` |
| micro004-native-menubar-language-picker | completed | micro-task | `workflow/03-completed/micro004-native-menubar-language-picker-completed.md` | Redesign the menu-bar panel and add a persistent preferred language | `micro003` |

## Context index

| ID | Topic | Path | Recommendation |
|---|---|---|---|
| ct017 | User research: model routing and Home states | `workflow/00-context/ct017-home-routing-research-review.md` | Refine existing tsk007 with session-driven presentation; preserve accepted models, no general router/agents scope expansion; analysis first |
| ct016 | Deepgram/Cerebras roles and evaluation boundaries | `workflow/00-context/ct016-voice-inference-provider-roles.md` | Keep spatial correctness first; evaluate specific vision models, voice separately; no migration authorized |
| ct015 | HeyClicky disclosures and spatial model selection | `workflow/00-context/ct015-spatial-model-selection.md` | Refine tsk006 with ct014; compare Astra/Fable 5.1 for understanding, preserve voice; no untested provider switch |
| ct014 | Delivered gestures, understanding versus pointing | `workflow/00-context/ct014-spatial-understanding-routing.md` | Refine tsk006 semantic routing/content scope and evaluate representation; no provider switch or validation removal inferred |
| ct013 | Spatial delivery and rejection diagnostics | `workflow/00-context/ct013-spatial-input-no-target.md` | Local diagnostics/outcomes implemented; current acceptance evidence in ct014, semantic evaluation pending |
| ct012 | Spatial context and workspace programme | `workflow/00-context/ct012-heyclicky-spatial-workspace-research.md` | tsk006 first integration in progress by user authorization; tsk007–016 planned; tsk005 acceptance pending |
| ct011 | Visual intent/window routing | `workflow/00-context/ct011-visual-intent-routing-audit.md` | tsk004 accepted and completed; semantic scope resolution and qualified review of premature missing decisions; safety/no-OCR boundary retained |
| ct010 | Localization provider evaluation | `workflow/00-context/ct010-localizer-provider-evaluation.md` | Astra adapter deployed, smoke verified and delivery accepted by user; independent voice/fallback/locator settings. No claim of guaranteed accuracy |
| ct009 | Native versus visual localization | `workflow/00-context/ct009-native-vs-visual-localization.md` | Last logged generic coordinate maps to the misplaced cursor. Native AX targets bypass visual estimation; generic geometry checks do not prove target identity. Evaluate/fix model localization rather than cursor offsets or retry limits |
| ct008 | Live observation exhaustion | `workflow/00-context/ct008-observation-exhaustion-audit.md` | Both live attempts exhausted two refreshes without a resolved point. Gate pre-decision audio/history; diagnose whole-display invalidation before changing limits. Literal conversation absent from supplied log; analysis only |
| ct001 | Capability roadmap | `workflow/00-context/ct001-capability-roadmap.md` | Use `$cce-feature`; bootstrap first, then sessions/contracts and visual annotations before walkthroughs, realtime voice, tools, or agents |
| ct002 | Voice motion and capture reliability | `workflow/00-context/ct002-voice-motion-and-capture-reliability.md` | Audio lifecycle/minimum-duration fix first; dedicated single-surface voice contour and visual prototype within micro005 |
| ct003 | Circular voice pulses | `workflow/00-context/ct003-circular-voice-pulses.md` | User prefers round activation/listening with blue audio-reactive rings; obtain failed-turn log before attributing repeated-session failure |
| ct004 | Fluid audio contour research | `workflow/00-context/ct004-audio-reactive-contour-research.md` | Replace static four-arc distortion with sampled continuous phase-driven contours; prototype before integrating; preserve AirPods transport |
| ct005 | Last visual conversation prompt audit | `workflow/00-context/ct005-last-visual-conversation-prompt-audit.md` | Prompt interpolation fix retained; local OCR recommendation superseded by OpenAI screenshot interpretation plus content-free native geometry validation |
| ct006 | Live pointing rejection audit | `workflow/00-context/ct006-live-pointing-rejection-audit.md` | Latest QA captured display 1; detector/window and geometry rejections preceded final Realtime ambiguity. Split diagnostic causes and test complete multi-window flow within tsk002; no runtime changes in audit |
| ct007 | On-demand visual observation | `workflow/00-context/ct007-on-demand-visual-observation.md` | Official Computer Use loops refresh observations; refine tsk002 with bounded recapture and scene invalidation after scroll, without OCR. Each current PTT request already captures anew; distinguish mid-turn changes from fresh-request failures |

## Decisions and reusable patterns

- Natural-language understanding is Cursy's responsibility: resolve ordinary
  requests using current visual/session context before asking users to categorize
  the target. Clarify genuine ambiguity, not an unverified initial model guess.

- Permanent user criterion: scenarios reported during testing are QA examples,
  never implicit special-case product rules. Fix general causes; keep prompts and
  behavior application/domain-independent. Retain concrete scenarios as regression
  tests and check representative alternatives. Applies to all future project work.

- Coordinate quality: do not choose a cheaper model that failed the localization
  evaluation. Zero observed failures is an admission gate, not proof of 100% future
  accuracy. Bounds/window/freshness checks cannot certify semantic identity.

- Accepted localization architecture: independent GPT-6 Astra locator via
  Responses/original/strict record-only function; Realtime voice and GPT-4.1/mini
  conversational fallback stay separate. Provider-neutral client contracts preserve
  future adapters; evaluated Claude/DeepSeek are not active runtime substitutes.
- Coordinate debugging: compare the actual connected base flow, model image-pixel
  output and final mapping before changing offsets. Native controls can succeed
  while semantic visual localization fails. Capture IDs/dimensions belong to the
  caller, not generated metadata; preserve display/window/freshness validation.
- Deployment lesson: Node mocks do not prove workerd compatibility. Keep bundled
  runtime regression tests, authenticated smoke and a known rollback version.
  Use manual provider redirects plus non-OK rejection; never follow with secrets.
  QA/acceptance evidence is scoped; a successful sample is not universal accuracy.

- Visual-provider boundary: OpenAI is the active provider for Realtime and fallback
  image interpretation. Native code must not duplicate that interpretation with
  local OCR. Capture, session and pointing consume provider-neutral contracts so a
  future Claude adapter can be added behind the same boundary without app-specific
  branches or behavior changes.

- Accepted cursor identity: compact translucent Liquid Glass; user now requests
  selectable mint/blue/coral/gold/violet tint and matching shadow (2026-09-20),
  fixed -35-degree orientation; no rotation, no metallic-blue branding. Keep
  symmetric 0.30-second morph response and stable precision-movement detection.
- Voice identity: breathing neutral circle while connecting, soft mint circle
  with 80%-capped audio-reactive deformation and accent-driven rings while
  listening; thinking breathes. Outgoing rings keep undulating as they fade.
  Navigation keeps the approved glass arrow/comet geometry with the selected tint.
  Native glass optical scale is constant 0.32 in every mode; interpolating to 1
  enlarged the voice lens 3.125x and was reverted. User accepted final size.

- Public session-minting endpoints require an internal authorization layer in
  addition to provider credentials; Realtime uses short-lived client secrets and
  `Cache-Control: no-store`.

## Risks and blockers

- Legacy AssemblyAI token URL is still a placeholder; VisionAPI/TTS use the
  configured Worker base URL. ElevenLabs voice ID is a placeholder in Wrangler.
  Current remote secret presence was not queried during bootstrap.
- Realtime and deployed /vision check internal authorization; /chat is retired.
  /tts and /transcribe-token need protection/quotas before broader use.
- Internal bearer provisioning is per developer Mac; no production user auth yet.
- Worker has 19 passing contract/runtime tests; no CI, lint script or tsconfig.
  Full native tests and physical route/accessibility matrices not run here.
- README minimum tool versions are stale: installed Wrangler requires Node >=22;
  current source uses newer Apple SDK APIs than Xcode 15. Deployment minimum and
  compiler SDK requirement are different.
- `cursy-app/Cursy/AGENTS.md` lists absent ContentView/FloatingSessionButton/
  ScreenshotManager files. Use actual entry point above; reconcile that stale
  instruction inventory in a documentation follow-up.
- README color descriptions are historical; accepted voice identity above wins.
  Release readiness, signing, notarization and auto-update activation unverified.

## Recent activity

- 2026-09-20: User requests commit/push to dev. Prepared the accumulated native,
  Worker, prototype, test and workflow changes as one coherent development
  checkpoint; existing main matches origin/main and remote dev does not yet exist.
  Exclude credentials, generated output and personal Xcode state. Native evidence
  remains 173 tests/22 suites and Xcode UI Build Succeeded; physical gates stay open.
  Worker pre-commit validation: 19 tests pass with mock-only outbound requests
  (sandbox first blocked the local test listener; permitted rerun passed).
  Publication is a Git checkpoint, not deployment or release acceptance.

- 2026-09-19: User requested tickets after functional reverse engineering of
  supplied HeyClicky research. CCE Feature created tsk006–016 with 11 layers each,
  dependency graph, bounded phases, manual/security gates, budgets and rollback.
  Write Swift/Apple Design informed ownership, cancellation, focus and native
  compatibility. tsk012 gates multiuser/agent rollout; no runtime code, deployment,
  credential access or test execution. Documentation integrity checks recorded
  in ct012; tsk005 remains the sole in-progress task.

- 2026-09-19: Compared 16 user-supplied HeyClicky UI captures, official public
  changelog/privacy statements and current/base source in ct012. Distinguished
  input gestures from output annotations and active-request sampling from
  continuous surveillance. Documented proposed milestones; no app changes,
  runtime tests, provider calls or deployment. Task counters unchanged.

- 2026-09-19: User confirms tsk004 correction tested and working. CCE Dispatch /
  Context Manager record acceptance and close the task; no runtime changes or
  new validation runs. Next: tsk003's specific continuity/reset acceptance, then
  visual annotations, persistent walkthroughs and supervised step verification.

- 2026-09-19: CCE Quick Feature → Dispatch implemented tsk004 with AI Engineer and
  Write Swift. Qualified vision resolves generic/missing/ambiguous targets and
  actual window before validation; no hard Realtime-window lock. 81 isolated
  tests pass, native source module compiles. User live acceptance remains; no
  deployment, app launch, secret access, capture upload, audio/cursor changes.

- 2026-09-18: Resumed tsk003 with CCE Mobile/Write Swift. Guarded async startup and
  cleanup against replaced/reset turns; bounded stored text in the session core;
  cleared stale reset notices and removed raw legacy-transcript log. Added reusable
  offline runner and manual QA checklist. 17 focused /71 regression tests pass;
  native module compiles (Sparkle entry excluded). No app launch/deploy/audio or
  locator changes. tsk003 awaits its own live continuity/reset acceptance.

- 2026-09-18: User reports «funciona a la perfección» after ct010 deployment and
  authorizes closure. CCE Dispatch/Context Manager archive tsk002 as completed,
  retain accumulated test/deploy evidence and general lessons without claiming
  exhaustive manual coverage. No app changes, deployment, commit or push. tsk003
  remains in progress with its separate continuity/reset acceptance gate.

- 2026-09-18: User authorized ct010 deployment. First publication failed /vision
  smoke and was rolled back safely. Actual workerd reproduced unsupported
  redirect:error; changed to manual + non-OK rejection, added runtime regression.
  Version 107dd830-4209-4525-aaac-c2075acb310a now deployed: 19 local tests and
  10 remote smoke checks pass (synthetic image only; secrets unchanged).
  Astra localization, legacy conversation and Realtime mint verified. No native
  build/launch; tsk002 remains open for multi-app/two-monitor/scroll acceptance.

- 2026-09-18: ct010 deepens source/base/log audit and official-provider research.
  User supplies keys and funds Claude; repeated provider comparison completed.
  Astra local adapter prepared and tested (actual Worker adapter4/4 on fixture),
  no deployment. Native65/Worker14/evaluator11 tests pass. See ct010 for detailed
  scores, cost assumptions and limits; real app acceptance remains mandatory.

- 2026-09-18: ct009 read-only audit contrasts native successes with incorrect
  internal-element point. Live candidate (199,633) in 1188×768 predicts the shown
  wrong position through current mapping. No systematic transform defect found;
  generic checks accept window geometry, not element identity. App unchanged.

- 2026-09-18: User authorized ct008 correction within tsk002. Added text-only
  decision requests and correlated spoken-output gate; window-scoped comparison
  before first refresh, scope retention, scoped scroll and occlusion checks.
  Removed per-sample logs; buffered content-free reasons emit only at stop.
  62 isolated tests pass (0.801 s), source module compiles; no deployment/live API.

- 2026-09-18: ct008 audits first live ct007 trial. Two attempts captured display 1,
  each exhausted both refreshes and recorded four assistant transcript callbacks
  without an accepted point. Found pre-decision audio/history gate gap and broad
  invalidation scope; exact change triggers/utterances unknown. No app changes.

- 2026-09-18: Implemented ct007 in tsk002. VisualObservation shares capture and
  limits refresh to two retries, 30 s total / 5 s after first point. Local pixel
  comparison and scroll invalidation, no OCR. Old results/voice confirmations
  suppressed, short tracking independent of completed voice turn. 54 tests pass;
  source module compiles, no live API/capture/audio test. Xcode acceptance pending.

- 2026-09-18: Cce Quick Feature refined existing tsk002 from ct007 as requested.
  Defined freshness revisions, one operation at a time, two refreshes maximum,
  proposed 30 s deadline / 5 s post-point watch, terminal cancellation and shared
  Realtime/fallback tests. Plan only, no app changes or validation claims. Swift
  guidance keeps completed voice turns terminal while observation has its own lease.

- 2026-09-18: User reports first-point success, then target loss after scrolling.
  ct007 compares official OpenAI/Claude observation loops and Chrome DevTools
  snapshots with current one-image-per-turn implementation. Recommends bounded
  refresh/invalidation, not permanent streaming. Research only; runtime unchanged.

- 2026-09-18: Implemented ct006 diagnostic refinement within tsk002. Distinct
  decoder/refinement/geometry rejection reasons, numeric capture-correlated logs
  before rejection, one current-window snapshot and production-shared async
  pipeline. 27 tests in 7 suites pass (including 16 rejection fixtures and three
  monitor layouts); source module compiles. This is local integration evidence,
  not a live OpenAI/OS/overlay acceptance run. Reproduce from Xcode next.

- 2026-09-18: Latest live QA did not pass: one initial point accepted, two later
  targets rejected (detector/window agreement and local visibility/geometry), then
  Realtime no_point/ambiguous. ct006 distinguishes these events from actual visual
  absence. Prior 4/4 fixture run exercised the locator with a synthetic full-image
  window, not end-to-end multi-window validation. tsk002 remains open.

- 2026-09-18: Audited inaccurate list-row pointing against the original pixel
  pipeline. AppKit/overlay conversion passes executable regressions. Connected
  the existing visual detector to generic Realtime points and restored explicit
  model-compatible image preparation; independent OpenAI localization completes
  before cursor/voice continuation. No OCR, UI-specific rules or Worker deployment.
  22 executable tests and 4/4 model fixtures on the supplied screenshot passed.
  Evidence is in active tsk002; live Xcode acceptance remains.

- 2026-09-18: Audited the base repository and confirmed its visual localization
  was model-driven, not local OCR. Removed the interim Apple Vision/lexical resolver;
  OpenAI now owns current screenshot interpretation through Realtime and the
  provider-neutral Worker path. Native validation remains content-free. Raised
  external-monitor image fidelity to an aspect-preserving 1920 px maximum and
  made successful point replies exact and terminal. Live Xcode acceptance remains.

- 2026-09-18: Earlier implemented the ct005 hybrid visible-target experiment and
  fixed continuation prompt interpolation. The OCR/recovery portion was later
  superseded and removed by the provider-vision decision above; only the general
  prompt/continuation lessons remain applicable.

- 2026-09-18: User approved deployment. Worker version
  da28d78e-f2f9-49a3-9ffd-a124763c8dac deployed; /vision returns 401 without
  auth, 400 for unsupported model, 200 for GPT-4.1/mini and completed streaming.
  Synthetic text only; in-app fallback/visual acceptance still pending.

- 2026-09-18: Corrected verbal-only visual guidance. Realtime changed from
  optional `tool_choice: auto` to one mandatory visual decision with local target
  validation and cursor-before-audio continuation. Swift module emits; visual
  tests type-check; isolated pure suite 21/21. Live Xcode acceptance pending.

- 2026-09-18: tsk002 code integrated with default-off sharing, single-display
  capture, bounded target validation, tool continuation and stale-session guards.
  Source type-check and synthetic visual tests pass; full test suite has existing
  standalone compile issues. Live API/AirPods/pointing acceptance still pending.
- 2026-09-18: Completed tsk000 with source-backed architecture/dependencies,
  command inventory, safe Worker dry-run, plist/project validation and release
  script syntax check. No deployments, credential reads or app modifications.
- 2026-09-18: User accepted micro005: compact soft-mint fluid voice cursor,
  80% visual pressure, fixed optical scale. Full history in completed record.
- 2026-09-18: Completed micro001–004 and tsk001: internal Realtime broker/client,
  bilingual native panel and fixed-orientation glass movement.
