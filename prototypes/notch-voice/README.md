# Cursy notch design lab

Local, synthetic design preview; no microphone, capture, model calls, app preference
writes or conversation persistence. Open the existing localhost:8776 server.

## Selected-text entry preview — 2026-09-21

Button → input now morphs as one material surface over250ms (WAAPI,
ease-in-out), with a100ms outgoing label and150ms incoming editor after80ms.
Only the background material scales; text/icons stay unscaled. Input focus is
immediate, not deferred until animation completion. Keyboard skips the morph;
reduced motion fades only. Closing/reselection cancels all transient layers.
If collision handling moves the field across a menu to the opposite side, use a
fade rather than sweeping through the obstacle.28 Node tests pass; browser
checked intermediate material transform with unscaled editor, final editable
focus, Escape cleanup and keyboard bypass. Native app unchanged.

Refinement: single-row input (370×46px at desktop size), 12px surface corners,
8px internal controls. The original 450px-wide voice card becomes a 340px-wide
notification (89px in listening, content-dependent greeting height). It slides
from a clipped slot directly beneath the current notch variant and retracts on
the same path using the accepted hint's symmetric400ms ease. Transform/opacity
only; keyboard opens immediately and reduced motion fades without travel.
Simulation actions moved into lab controls, not the notification. Full selected
text remains in the scoped chat; the compact preview truncates visually only.

**Menú de otra app · Simulado** toggles a synthetic third-party selection toolbar;
select again after changing it. Cursy's offer/input measures occupied rectangles
and sits12px above the menu. If there is insufficient space, it falls below the
selection/menu group; if neither side fits, it suppresses the offer. Geometry
handles multiple obstacles and unrelated horizontal regions without app-name
rules. This is DOM-fixture collision handling, NOT actual screen/menu detection
or model analysis. A native implementation needs trustworthy current menu bounds.
Validation now26 Node tests, including obstacle stacking, top-edge fallback,
oversized/no-room suppression; browser reviewed menu/no-menu, input submission,
notch reveal and intermediate exit, isolated context and console (no errors).

Choose **Probar texto seleccionado**, then select text in the sample paragraph.
The nearby **Preguntarle a Cursy** button becomes a compact input with SF Symbols
microphone/send controls. **Seleccionar una frase de ejemplo** offers a repeatable
keyboard-accessible sample. Only this document is observed, not other Mac apps.

- Text submission opens a fresh Home chat with the exact selected fragment shown
  as its context. Other chats, the surrounding document and screen are excluded;
  the screen control is disabled for these sample chats. Responses remain fake.
- Microphone opens the existing notch presentation: Cursy greets first, then a
  simulated playback-completion timer (3s) advances to listening. The greeting
  is shown as a caption, not synthesized audio. **Simular mi respuesta** previews
  a subsequent turn; **Ver chat** or the notch opens the same scoped chat.
- Selection snapshots survive focus moving to the input. Escape/outside dismissal,
  scroll/resize, cancellation and mode changes retire obsolete offers; cancelling
  the greeting invalidates delayed listening. Unsent text is retained as a draft
  when switching to voice, never silently submitted.
- Uses the browser's native Popover API instead of adding a React/library stack
  to this plain-JS lab ([platform reference](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using)).
  Occasional state/spatial feedback: 200ms opacity/5px translation with the shared
  ease-out token; input content is never stretched. Keyboard entrance is immediate,
  reduced motion removes travel, and the voice caption uses opacity only.

Validation: 22 Node tests (five selection snapshot/lifecycle/placement tests plus
the existing 17); JS syntax and diff checks. Browser checked real text selection,
input, scoped-chat submission, greeting → listening, cancellation before greeting
completion, opening Home through the notch and console errors (none observed).
The first keyboard check exposed a conflict with the variant-picker arrows;
selection navigation now stops propagation to that picker. Physical cross-app
selection/AX permissions, actual audio and native integration are not implemented.

## Home text and settings preview — 2026-09-21

F3 extends the accepted Home surface, not the native app. Start with **Nueva
conversación** and type into the composer: Enter sends, Shift+Enter inserts a
line, and drafts survive switching between sample chats. Replies are explicitly
synthetic; pending work can be stopped and late replies are invalidated on cancel,
chat changes, closing or changing voice mode. Reload clears all demo state.

In **Ajustes → Micrófono**, select a sample device and start/stop the simulated
level test. Expand **Escenarios de prueba** to try permission denial or adjust
the sample level; the disconnected-device option previews recovery copy. No
device discovery, browser permission request, recording or audio upload occurs.
Testing stops when changing section/device, closing Home or entering voice mode.

**Voz** previews automatic read-aloud without playing audio or inventing provider
voice/speed options. **Atajos** previews capture, Escape cancellation, reset and
a small reserved-combination check; it does not register a system shortcut.
General, Cursor, Privacy and Help retain the shared gradient. No manual objective
field or visual-tool selector. Icons reuse local SF Symbols masks. No new motion
or external dependencies; native focus/audio coordination remains future work.

| Before | After | Why |
| --- | --- | --- |
| Conversation only displays sample exchanges | Integrated composer, per-chat drafts, send/stop | Try written interaction without losing the accepted Home layout |
| No microphone settings preview | Explicitly simulated device selection, meter and failure states | Review the local test flow before requesting real audio access |
| General/Cursor/Privacy only | Voice, Microphone, Shortcuts and Help in the same sidebar | Keep settings together without a second visual surface |

Validation: 17 passing Node tests across `home-input-model.test.cjs`,
`guidance-geometry.test.cjs` and `guidance-motion.test.cjs`; JS syntax and diff
checks. Browser verified send/example response, multiline drafts across chats,
new chat, mic test/permission denial/disconnection, shortcut capture/Escape/reset,
voice toggle and final layout. No browser console errors observed. Native code,
model behavior, permissions, actual devices and system shortcut conflicts are
not validated by this prototype. tsk007 remains open pending design acceptance
and native implementation.

## Visual guidance lab — 2026-09-21

Use **Ver figuras de Cursy** in the lab controls. Revision 4 previews cursor,
adaptive ellipse, full-paragraph rectangle, variable arrow, fitted label and a
three-mark source/route/destination guide. The same five-color cursor palette
drives outlines, captions and matching glow; changes sync with Cursor settings
inside the prototype, never native preferences. No manual figure selector or
clear-mark control. Scenario buttons and simulated scene changes are lab controls.

Try **Probar párrafo estrecho**: DOM bounds are remeasured, so the whole wrapped
paragraph remains enclosed. Drag the synthetic document to the destination, or
use the labelled simulation buttons/keyboard. An invalid drop returns to step 1;
a successful local drop completes the sample and removes the three marks.
**Simular pantalla cambiada** retires the whole group until new verification.
This models behavior, not actual screen observation or model judgment.

`guidance-contract.md` proposes the v2 geometry/ownership/lifecycle boundary for
tsk005 and tsk009/010. Native still has fixed marks: its selector removal shipped
in the previous local change, but adaptive bounds and active guides have NOT.
Web glass is an approximation. SF Symbols reuse local masks; no bitmap assets or
dependencies added. Final target bounds stay fixed. Revision 4 replaces the
independent contour animation with a single Cursy artist: curved 700ms approach,
180ms press, 1600ms deliberate drawing, release and withdrawal. Rectangles grow
from top-left under a diagonal drag; ellipses trace from the left; arrows include
their head in the drawn path. Explanatory labels now appear like guide captions,
without the artist: their text types progressively (24ms/grapheme, capped at 1s).
The bubble reserves its full text size to avoid layout jumps, remains 12px above
the target and has no connector line. Reduced motion/keyboard show the full text.
Multiple marks are drawn sequentially by the same actor.
Following user acceptance and pacing refinements, the figure choreography
plays at **1.6×** speed (drawing 1000ms instead of 1600ms), preserving curves
and reduced-motion timing.
Cursor and ink share one
frame clock; this deliberately paints SVG geometry for the requested tool effect,
bounded to three marks. No physical pointer events or native app actions occur.
Captions enter over 450ms after drawing; pointer-reactive glass reflection remains.
Reduced motion uses a short opacity reveal and no moving reflection; keyboard
activation skips the trace. Closing, scene changes and redraw cancel old animations.
Use **Repetir marcación** to replay; **Guía con otro paso** previews congratulations
followed by a new review target. Final completion congratulates the user instead
of announcing removal of the marks. All completion evidence is simulated here.
The accepted notch animations are unchanged. Escape closes the lab and restores
focus. No microphone, provider calls, uploads or physical actions on other apps.

Validation: `node --test prototypes/notch-voice/guidance-geometry.test.cjs` (five
tests), JS syntax/diff checks, browser scenarios, both backgrounds, five tints,
paragraph resize, local drag/drop, simulated stale scene and keyboard step controls.
Revision 3 additionally checked progressive stroke offset, pointer-reflection
coordinates, final/next-step congratulations, disabled stale review, reduced-motion
rendering and Escape focus restoration. Native motion is unchanged in this revision.
Revision 4 follow-up: eight motion tests plus five geometry tests; browser checked rectangle
growth/cursor alignment, circle and arrow drawing, label flow and cancellation
during a multi-mark guide. Repeat with **Repetir marcación** to review the feel.
Typing tests cover intermediate text, completion, cancellation and reduced motion;
browser verified zero artists and unchanged bubble width during/after typing.

| Before | After | Why |
| --- | --- | --- |
| General asks the user to choose a visual indicator | No style preference; agent-choice explanation | Guidance is the agent's responsibility |
| Figures cannot be inspected in the web lab | Synthetic scenarios with marks and reasoning | Review contrast and meaning before native integration |
| Fixed marks cover only a word or point | Bounds-sized focus and measured captions | Show the complete intended region |
| Black/white double stroke unrelated to Cursy | Shared cursor tint, translucent rim and restrained glow | One visual identity without hiding text |
| Clear each mark by hand | Agent-owned group lifecycle in the sample | Tools serve the active step; consent remains cancellable |

User accepts native animation design and reports faster responses on 2026-09-21;
broader QA and unimplemented ticket phases are not implicitly complete.

## Revision 3 — continuous workspace

- Chats and General/Cursor/Privacy navigation share one black-to-clear surface.
  Sidebar reaches the rounded bottom; no bottom content padding outside it.
- All UI pictograms use actual macOS SF Symbols via local `symbols/*.png` masks.
  Reproduce using `RenderSymbols.swift` (AppKit, synchronous main actor). The
  preview assets are for this local Apple-platform design lab, not a web icon library.
- Five colors, chat switching/creation and preference controls are simulations.
  Backdrop blur/glass on the web is an approximation, not native Liquid Glass.
  The synthetic document is softened while the panel is open to compensate for
  embedded-browser backdrop compositing; native optical acceptance stays separate.
- Listening guidance: camera bottom 31px; island bottom 44/52px; hint starts
  54/62px. Expanded listening moves it into the neck at y38px, below the camera.
  User-approved follow-up: hint slides out from a clipped slot at the island's
  lower edge with synchronized 400ms `ease` movement/fade (softened on user
  feedback); exits toward the same origin with the same 400ms movement/fade. It waits
  for cursor activation, never paints over camera, uses opacity only with reduced
  motion and cancels with the current listening state. No text scaling.
- Connecting and listening are separate preview states. Connecting hides the
  spatial hint and input waveform, even after the cursor activation animation.
  Listening reveals the hint; reconnecting, processing or cancellation retracts
  it. The demo's fixed delays illustrate state changes, never real readiness.
- Prior requested motion is represented: 800ms S-flight, 140ms visual press,
  250ms panel reveal; timer/frame cancellation and reduced-motion alternative.
  This delays no real input because there is no microphone in the lab.

## Design review

2026-09-21: selection input/morph surface, contextual quote and explanatory
captions now use neutral hairlines/shadows. Accent remains on icons and actual
guidance geometry. Same visual policy ported to native tsk007/tsk005. Home text,
device test/preferences, shortcut recording and selected-text flow now have native
implementations; browser fixtures remain simulations. Native AX/menu compatibility,
voice and physical focus acceptance are tracked in SETTINGS_QA.md, not assumed
from this preview. Multiple-step guides remain tsk009/010.

| Before | After | Why |
| --- | --- | --- |
| Sidebar ended before the bottom | Shared full-height workspace clipped by the outer radius | No visible strip or squared internal corner |
| Separate dark settings/sidebar layers | Transparent navigation/content over one global gradient | Continuous material instead of stacked rectangles |
| Unicode/custom icon stand-ins | Named SF Symbols rendered locally | Match the Apple-platform icon language |
| Guidance overlapped the camera area | Hint below island, or below camera in expanded neck | Reserved camera region stays empty and opaque |

Validated in the embedded browser: both variants, chat/settings navigation,
color selection, light/dark backgrounds, click/flight cancellation and reduced
motion. Measured sidebar bottom equals panel bottom; both internal backgrounds
are transparent. Native port authorized and implemented on 2026-09-20 under
tsk007: shared gradient, full-height navigation, SF Symbols and real-listening
hint with symmetric400ms ease. Physical acceptance alongside tsk017 latency is
pending; browser timing and static native renders do not establish live behavior.
