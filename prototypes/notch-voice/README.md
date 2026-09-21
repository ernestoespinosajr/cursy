# Cursy notch design lab

Local, synthetic design preview; no microphone, capture, model calls, app preference
writes or conversation persistence. Open the existing localhost:8776 server.

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
