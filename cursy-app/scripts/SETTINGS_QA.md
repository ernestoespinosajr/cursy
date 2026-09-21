# tsk007 — Home/settings acceptance

## Regression gate: selection + integrated microphone (2026-09-21)

- Select ordinary non-sensitive text in a native editor, a browser document, and
  an Electron-style conversation. Repeat by drag, double click, Shift+arrows and
  Select All. Offer must preserve the exact selection; app-provided toolbars stay
  unobstructed. The reported ChatGPT case is a QA fixture, never a runtime rule.
- Selection must work before and after opening/closing its editor. Reselect,
  scroll, switch apps or cancel during the AX lookup; no stale offer may reopen.
- Secure fields and missing accessible selection produce no guessed context;
  clipboard and entire document must remain untouched. Mouse anchor fallback is
  placement only, not a claim of exact selection geometry.
- Test system default and explicitly selected integrated mic. UI must stay
  responsive while opening/closing; meter starts only on real input. No input in
  five seconds means a timeout notice. No recording/upload. Close during startup,
  navigate away, press Talk and unplug selected input. A closing test blocks a
  second recorder and offers explicit retry after release.
- Repeat with a different input, then return to system default in legacy and
  Realtime capture. Missing UID must fail rather than use another mic silently.
- Offline tests do not validate hardware or cross-app AX support. ChatGPT host
  is unavailable to the current automation tool; physical acceptance is pending.

## Native F3 / selection port — physical acceptance still required

Offline evidence:191 tests/24 suites, 28 prototype tests; Xcode UI Build Succeeded
13:15 and final Run13:16 on2026-09-21. No live audio/model request during checks.

- Open by hover: external editor retains key focus. Click composer: editable,
  Enter sends once, Shift+Enter inserts newline, IME doesn't submit prematurely.
  Switch chats: draft/history/selected fragment remain isolated. Stop/reset while
  streaming: no late response or automatic audio; text sends no screen capture.
- Select synthetic text in a native editor and browser. Verify offer above the
  selection/exposed action menu, below if necessary, absent if crowded/unsupported.
  Secure fields must never offer. No clipboard changes. Click offer: material
  morphs, glyphs never stretch. Escape/outside/key/scroll clears old offer.
- Send selected text: fresh context only. Microphone: actual greeting completes
  before first capture; notification emerges below notch. Finish via button/PTT;
  close/cancel/new chat must prevent any late greeting from restarting capture.
- Microphone Settings: enumerate devices, choose UID, unplug/reconnect, system
  default. Test is local, maximum15s; stop on route/page/Home close or Talk.
  Denied permission and a dismissed permission prompt must not reopen capture.
- Record Control+Shift+K, hold/release key and modifiers in either order. Escape
  cancels recording; reserved combos reject; reset restores Control+Option.
  Other apps' global conflicts cannot all be detected: test chosen combination.
- Read text aloud off/on: only on sends completed reply for output-only Realtime.
  Neither opening Home nor selection offer accesses network/audio. Provider tests
  require explicit synthetic requests; offline tests do not establish latency.
- Check neutral borders/captions on bright/dark backgrounds, Increase Contrast,
  Reduce Motion, VoiceOver, two displays and full screen. Icons/marks retain tint.

## Official Home with notch hover

Build/Run the Cursy scheme in Xcode (never terminal xcodebuild). Click Cursy's
status icon to open Home directly, or hold the pointer at the real notch for
180 ms. External screens retain the status icon and detached window; no invisible
full-width activation zone. There is no legacy menu or Beta entry in the live UI.

Home projects the existing temporary session. Talk remains Control + Option.
General/Cursor/Privacy/Help are integrated into the same gradient surface.
There is no manual objective field or text-message composer yet.
Opening Home adds no microphone engine, network request, model, persistence,
capture or permission request. Permission buttons act only on explicit clicks.

### Legacy-menu migration (2026-09-21)

- Status click opens hidden Home, expands a compact island, and closes expanded
  or detached Home. Repeated clicks/reveal interruption must leave one panel.
- General retains language/model, without a manual objective field. Intent comes
  from the spoken request and current conversation context. + still creates a new
  temporary chat. Do not add another objective configuration step.
- Privacy retains screen consent, refresh, spatial context and adds all four
  permission statuses/actions, including Accessibility's Finder/settings route.
  Screen Content appears after Screen Recording is granted. Existing defaults
  are untouched; granting OS access must not enable screen sharing.
- On first setup/revoked access, open Privacy. Keep Home visible while completing
  setup (even outside its frame), but allow X/Escape. Verify denial, return from
  System Settings and enabling Start only when permissions are ready. Do not reset
  working TCC permissions for this test; use a separate authorized test environment.
- Help provides replay/start introduction, feedback mail link and Quit. Confirm
  introduction dismisses Home, feedback opens a draft (never sends), and Quit uses
  the existing stop lifecycle. Do not actually send feedback as a QA step.
- Home remains non-key/non-main: hover, clicks, compacting and X/Escape must not
  steal the external app's keyboard focus. Keep the setup autohide guard.
  PTT must still open the automatic voice island; the retired menu's close signal
  must not suppress it. Onboarding dismissal remains separate from PTT.

Evidence after removing manual objective: 184 tests/22 suites pass (artifacts
`/private/tmp/cursy-native-regression.3fiQqA`), Xcode UI Build Succeeded11:21 and
clean diff check. These verify compilation and pure routing/retention decisions,
not the physical focus or permission flows above. No app restart or TCC reset.

- Expand/collapse with the chevrons; the PiP button detaches the panel. Detached
  mode can be dragged by the background. Pin reattaches at the current screen's
  top edge. Compact surrounds the camera with lateral controls; expanded has a
  black neck covering the camera, with curved shoulders below. No text/control
  may overlap the camera. External displays retain a 12-point top margin.
  Transparent shoulders must pass clicks through to the menu bar behind them.
  Voice automatically shows the compact island even if Home was never opened.
  Explicit X/Escape dismisses it for the current turn; a new turn can show it again.
- Hover quickly past the notch: no accidental open; stay 180 ms: open. Move from
  notch to panel/header/conversation: remain open. Leave while idle: hide after
  800 ms. Return before/during close: cancel/reverse it. Move within the trigger:
  dwell must not continually restart. Drag across notch: do not open.
- While voice is connecting/listening/processing/responding, leaving must not
  hide Home. After idle, hide only if the pointer remains outside. Starting voice
  during an auto-close reverses it; explicit X/Escape still works while busy.
  Detached and VoiceOver modes must not auto-hide. Repeat on multiple displays.
- Open/close: black surface reveals from the physical camera in 250 ms and
  retracts on close; changing compact/expanded retracts then reveals without
  stretching text. Close then immediately
  reopen, including during resizing: no delayed close may hide the new panel.
  Drag detached Home to the other screen, then pin: reattach to that screen.
- Check black upper surface blends into the notch; no light border/shadow seam.
  Text and buttons remain readable on white, dark and busy backgrounds, including
  the header. There is no bottom status bar. Header shows mic/Control+Option hint,
  actual screen-consent icon (tooltip and accessible label), temporary-session
  label; remove future-feature placeholder text. Black fades into translucent glass,
  not just an empty bottom skirt. Move a colored/background window underneath:
  lower glass should reflect the live background; upper notch join stays black.
  macOS 26+ uses native Liquid Glass; 14/15 uses behind-window blur (not identical
  lens optics). Verify on each OS before claiming older-system visual acceptance.
  Existing
  listening color stays subtle, without flare or a looping shine.
- Check the actual listening/thinking/responding state while using Talk in
  another app. Do not activate sharing solely for testing Home unless intended.
  Opening Home itself must not start capture, audio or a remote call.
- The Cursy visual cursor flies into the camera when listening begins and stays
  hidden while listening/processing. Audio begins immediately, not after flight.
  It exits to a validated target or resumes following on response; your physical
  pointer must never move. Repeat PTT during entry, exit and pointing: no stale
  bubble, delayed return, duplicate buddy or permanently hidden cursor.
  Cancel/reset/error/close/detach mid-flight and remove/change displays. Detached
  and no-notch displays keep the ordinary cursor behavior. Cross-monitor targets
  must show only one buddy on the target display, no ghost on the camera display.
- Check a real transcript/answer appears once. Reset via existing settings;
  Home must reflect the empty session, never recover previous messages by itself.
- While “Te escucho / Listening” is visible, alternate silence, soft speech and
  louder speech: five small bars follow the existing microphone level, while
  mint/blue/violet light rises softly from the header's bottom. Silence leaves
  short stationary bars and a faint glow in expanded Home; compact stays solid
  black. There is no simulated looping voice.
  Stop/cancel/fail the turn: listening bars/glow disappear, even with an old meter
  value. Header/capsule size, text and controls must not move with volume.
- Enable Reduce Motion: bar/glow geometry stays fixed; only opacity responds.
  Opening/closing uses only a brief fade; no moving mask or animated resizing.
  The cursor also skips spatial flights when Reduce Motion is active.
  Enable Reduce Transparency: solid black, no glow, meter readable. Increase
  Contrast also forces solid black and a clearer lower rim. No added animated flare.
  Verify both themes and normal/reduced settings during actual Talk in Xcode;
  offline renders do not establish live responsiveness or accessibility acceptance.
- An interrupted or failed turn must not remain labelled “Thinking”. Older
  partial text is not a success receipt; source history remains bounded.
- Confirm the frontmost external app stays active on opening/hover/clicks and
  closing Home. No objective editor or hidden text field may acquire focus.
- Close via X or Escape. Escape is observed, not consumed: existing cancellation
  behavior and the external app's shortcut still apply. It must not reopen under
  the same stationary pointer: leave the notch/panel and return to reopen.
- Open/close 50 times: only one Home panel; no doubled audio, event monitors or
  responses. Settings replaces the Home sidebar with categories; never two Home instances.
- Test on notch and external displays (including negative origin), different
  scaling, fullscreen/Spaces, and removal/rearrangement of the selected display.
- Check Spanish/English, light/dark, Reduce Transparency, Increase Contrast,
  VoiceOver labels and Escape. F1 has no keyboard text focus or tab-navigation
  mode; explicit keyboard interaction/composer is a later gate, not claimed done.
- Confirm Cursy's own screen captures exclude Home as well as existing overlays.

Design acceptance needed before F2: size/readability, compact versus expanded,
top capsule versus detached placement, hover sensitivity and header discoverability.
No user acceptance or physical latency measurement is inferred from offline tests.

## Offline evidence

`bash cursy-app/scripts/test-native-regressions.sh` compiles all native sources
except the Sparkle entry and runs isolated Swift Testing suites. Home tests cover
projection/reset/deduplication, terminal status, safe bounds and negative origins.
New cases cover flush camera attachment on both origins, detached/external
fallback and bounded top-anchored reveal geometry (including non-finite input).
HomeGlassMaterialTests cover OS fallback and accessibility precedence. They do
not measure native blur/refraction. Color-backdrop static renders verify layout,
gradient distribution and text; AppKit bitmap caching is not a compositor capture.
HomeVoiceFeedbackTests cover noise floor, invalid/clipped values, proportional
level response, non-listening states and static reduced-motion bar geometry.
HomeHoverPolicyTests cover idle/busy/inside/detached/drag/VoiceOver decisions,
explicit-dismissal suppression, automatic-close reversal intent, delay ordering
and camera-neck shape bounds. These are not physical event-monitor/timer tests.
It does not launch the signed app or test physical focus/capture/audio.

Optional static review uses `RenderHomePrototype.swift` linked to that runner's
testable Cursy module. It renders the production view with synthetic messages,
without instantiating CompanionManager. PNGs are QA artifacts, not app assets.
The two compact rows show attached and external-display layouts at level 0.75;
synthetic camera housings overlap attached compact and conversation geometry.
These are static renders, not evidence of live animation or physical notch fit.

## Remaining phases

F2 preferences, F3 text/voice/microphone wiring, F4 physical acceptance and warm
open p95 ≤150 ms (target, not measured). Full keyboard traversal, VoiceOver,
AirPods transitions, migration, shortcut conflicts and onboarding remain gates.
No Worker changes/deployment are required by F1. Close Home to dismiss it;
avoid the notch or detach to keep it independent of hover (no disable toggle yet).
The original menu is retired; defaults, cursor and voice pipeline are preserved.

HomeNotchInteractionTests cover docking priorities, explicit dismissal, lateral
space/negative origins, camera-preserving reveal, continuous neck and compact hover.
They do not validate real animation callbacks or physical multi-monitor handoff.

## Sidebar, color and curved activation (2026-09-20)

- Create two chats using +; ask different questions, switch back and confirm each
  keeps only its own text/context. Switch during connecting/listening/processing/
  speaking; old callbacks must not change the selected chat or restart its audio.
  New chat clears active context, not other sidebar records. Up to 20 temporary
  chats, no silent eviction; quit clears them. Durable storage is not implemented.
- Gear and sidebar Settings show General/Cursor/Privacy/Help within the same Home.
  Back restores chats and selection. Collapse sidebar, resize on a smaller external
  monitor, scroll long content: no clipped controls or hidden content under camera.
- Choose all five cursor colors; native glass and shadow match, shape/size stay
  constant. Relaunch preserves color only. Test light/dark backgrounds, macOS26
  glass and older material fallback, Reduce Transparency, and cursor visibility.
  Visibility must use the existing setter, update overlay and persist preference.
- From a closed Home, hold Talk: mic starts immediately, cursor travels smoothly
  along an S-curve (~800 ms), presses visually (~140 ms), then island reveals
  (~250 ms). No real click, pointer jump or focus theft. Test short utterances,
  rapid cancellation/new turn, reply during arrival and missing overlay fallback.
  Reduce Motion skips spatial flights; no-notch/detached behaviors remain usable.
- Physical acceptance is pending. HomeWorkspaceTests validate model isolation,
  bounded retention, tint defaults, activation correlation and curve geometry,
  not real NSPanel timing, native optical compositing or audio handoff.

## Revision 3 native port — combined QA with tsk017 (2026-09-20)

Use the same Xcode Run for this section and `VOICE_LATENCY_QA.md`. Do not accept
measured latency or physical animation behavior based on offline evidence alone.

- Chats sidebar reaches the rounded bottom with no separate strip. Open each
  Settings section: navigation and content share the continuous black-to-clear
  gradient; no dark inner rectangle or horizontal cutoff. Check bright/dark/busy
  backgrounds, small external display, scrolling and accessibility contrast.
- Control/Option, navigation and color-picker pictograms are native SF Symbols.
  The live colored Cursy pointer keeps its existing silhouette and matched shadow.
- Press Talk from hidden Home: microphone capture is independent of flight/click.
  The guidance waits for both actual listening and the visible island. Expanded
  Home places it below the physical camera, not on the camera or toolbar buttons.
  Compact places it 10pt below the island, expanded 7pt below the camera. Check
  external/detached displays, negative origins, moving the panel and bottom edges.
- Connecting/reconnecting never starts the guidance or input waveform. Listening
  slides/fades the hint out of the notch-edge slot in400ms; release, reconnect,
  Escape/error or hide retracts it along the same path in400ms. No text stretching,
  sudden unmount, stale reappearance or blocking of underlying clicks. Try rapid
  release/new Talk during entry and exit. The outgoing fade is not active listening.
- Reduce Motion uses only150ms fade both ways. The pointing trail itself remains
  immediate. Changing these visual states must not restart audio or delay first PCM.
- Offline evidence: 173 tests/22 suites, including HomeSpatialHintTests for state,
  placement and symbols. Static chats/cursor renders check layout, not live timing.
# Selección contextual compacta — seguimiento 2026-09-21

- Regresión Claude: selección multilínea muy ancha con menú desplazado a izquierda;
  Cursy centrado encima del menú entero, no al centro del párrafo ni al lado.
- Regresión Outlook: menú con una única acción; oferta e input deben evitar todo
  el contenedor, con su padding. Variar ancho de ventana y sentido del arrastre.
  Confirmar que GPT sigue colocado correctamente y que texto estático/botones
  lejanos no desplazan la barra. Son casos QA, no excepciones por nombre de app.
- Repetir los tres casos aportados por usuario: último párrafo, dos bullets y
  primera línea. Arrastrar en ambos sentidos. Oferta centrada con menú propio,
 12pt encima, sin superposición. Input debe mantener la misma exclusión al abrir.
- Verificar primera selección, cambios rápidos de rango y menú que aparece con
  retraso; no conservar posición del rango anterior. Cerca del borde superior,
  fallback debajo; también con monitor de origen negativo. Menú no expuesto por
  AX sigue requiriendo aceptación separada: no afirmar detección universal.
- Repetir en Comet, Claude y GPT como casos QA, no reglas de producto. Activar la
  app físicamente y seleccionar texto de respuesta/documento, no solo un input.
  Registrar por separado texto AX, aparición de barra, colocación sobre el menú
  propio y click/morph. Una selección automatizada en segundo plano no es PASS.
- Primera entrada a un runtime con AX diferida: permitir el retry tras2.3s;
  siguientes selecciones no deben reiniciar el debounce. Nueva selección, cambio
  de ventana/app, scroll o Esc durante la espera nunca muestran la selección vieja.
- Seleccionar entre varios nodos/párrafos: contexto debe conservar el rango completo.
  Teclado sin bounds y campos protegidos omiten la oferta; no recuperar por copy/OCR.
- Suite offline219/26 incluye el buscador real con backend simulado; no prueba
  las respuestas AX particulares ni menús de las versiones instaladas.
- Oferta solo texto, sin logo,160×32 en español; click conserva input/mic.
- Probar selección con mouse y teclado en documento nativo y app web, incluyendo
  una con menú propio. Ninguna barra debe cubrir ese menú ni un campo seguro.
- Las notificaciones AX tardías conservan el anclaje de mouse por máximo1s en
  el mismo proceso; mouse-down, tecla, scroll y cambio de app lo invalidan.
- Apps compatibles pueden recibir `AXManualAccessibility=true` solo si el
  atributo es escribible y no estaba activo. No modifica permisos del sistema;
  no fuerza `AXEnhancedUserInterface`, clipboard, OCR ni acceso a texto completo.
- 208 tests/25 suites offline y28 Node pasan. Activación real del árbol y caso
  GPT requieren prueba física; la automatización no permite operar la app host.
