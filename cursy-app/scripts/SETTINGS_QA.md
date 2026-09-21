# tsk007 — Home/settings acceptance

## F1: Home prototype with notch hover

Build/Run the Cursy scheme in Xcode (never terminal xcodebuild). Open Cursy's
menu-bar panel and choose **Probar Home · Beta / Try Home · Beta**, or hold the
pointer at the real notch for 180 ms. External screens without a notch retain the
menu entry and detached window; no invisible full-width activation zone.

This increment is a read-only projection of the existing temporary session.
It adds no microphone engine, network request, model, persistent conversation,
text input, agent, or permission prompt. Talk remains Control + Option. Settings
now opens the integrated General/Cursor/Privacy sidebar; remaining preferences
and text input belong to later phases.

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
- Confirm the frontmost external app stays active when opening, clicking,
  collapsing or dragging Home. No text caret should move from the external app.
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
the original menu, defaults, cursor and voice pipeline remain available.

HomeNotchInteractionTests cover docking priorities, explicit dismissal, lateral
space/negative origins, camera-preserving reveal, continuous neck and compact hover.
They do not validate real animation callbacks or physical multi-monitor handoff.

## Sidebar, color and curved activation (2026-09-20)

- Create two chats using +; ask different questions, switch back and confirm each
  keeps only its own text/context. Switch during connecting/listening/processing/
  speaking; old callbacks must not change the selected chat or restart its audio.
  New chat clears active context, not other sidebar records. Up to 20 temporary
  chats, no silent eviction; quit clears them. Durable storage is not implemented.
- Gear and sidebar Settings show General/Cursor/Privacy within the same Home.
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
