# tsk005 — Validated visual annotations

Status: in progress
Current direction (2026-09-21): agent-selected guidance, not a user-configurable
style. Design preview and native selector/default removal implemented;
Realtime contextual choice still requires live quality evaluation.
Design extension (2026-09-21): native single-target visual port implemented;
accessible-element extents are verified, generic image regions and multi-mark
guide lifecycle remain pending. Prototype v2 is not a shipped locator schema.
Date: 2026-09-19
Complexity: 5/10
Owner: cce-mobile with write-swift, apple-design; cce-ai-engineer for typed style routing.

## 1. Goals and requirements

Add circle, arrow, rectangular focus marker and label to the existing cursor
guidance. User accepted tsk003. ct001 places annotations before persistent
walkthroughs. https://www.heyclicky.com/ currently advertises drawing on screen;
it does not document exact geometry/API. Original commit 97c5406 supports POINT
tags and a cursor bubble, not a reusable annotation protocol. Reuse its overlay.
Only validated points may become annotations. No OCR, clicks or new providers.

## 2. Experience

The following menu-preference behavior describes the existing implementation,
superseded as a product goal by the user's 2026-09-21 clarification below.

Menu selects default style; voice can request an explicit shape through the
existing structured visual decision. Default remains cursor for compatibility.
Circle/rectangle are bounded focus markers centered on a verified point, NOT
inferred element bounding boxes. Labels stay within the captured display.
Clear indication removes all marks and stops its short observation. New turn,
reset, screen opt-out and invalidation also clear. No new motion or timers.
SF text/symbols, neutral outline for contrast, click-through overlay.

## 3. Technical design

VisualAnnotation is an immutable presentation value from a validated global
point, display frame and label. Pure layout maps global AppKit to overlay once.
Realtime decision adds an optional typed style; automatic uses menu preference.
Style passes to native and generic paths without affecting locator coordinates;
silent refresh preserves it. Fallback uses menu preference. Worker unchanged.
No guessed element dimensions, no unvalidated provider coordinates published.

## 4. Dependencies

Closed tsk002/tsk003/tsk004; reuse overlay, coordinate conversion, lifetime and
localization gates. No packages, credential operations, deployment or database.
macOS14.2-compatible SwiftUI/AppKit; retain approved cursor and audio behavior.

## 5. Implementation

Close tsk003; introduce value/layout/view, structured style plumbing and common
validated publication helper, native menu choices/clear, tests and QA checklist.
Preserve existing dirty changes. Swift compiler only, never terminal xcodebuild.
No private screenshot upload in validation. No new continuous capture.

## 6. Validation and rollback

Offline tests: enum decoding/default/rejection; native/generic routing; display
mapping with negative origins, edge placement and finite geometry; reset/clear.
Run native regression runner, diff checks. Manual gate: user runs Xcode and
tests each style, second monitor, scroll invalidation, cancel/reset and clicks
passing through. Remain in progress until user accepts visible delivery.
Rollback: select Cursor; code rollback limited to this feature, never reset tree.
Next: persistent walkthrough plan, then supervised step verification.

Execution: `$cce-dispatch execute tsk005-visual-annotations` (authorized this turn).

## Implementation and evidence — 2026-09-19

- Added VisualAnnotation.swift: typed styles, immutable validated-presentation
  value, exact global-to-overlay conversion, fixed focus marks, display-bounded
  compact labels, dual-contrast strokes, Reduce Transparency support. No motion.
- VisualTurnContext/OpenAIRealtimeVoiceClient route explicit voice style through
  the existing tool. Unknown styles reject; omitted/automatic preserves default.
  Native fast path and generic semantic review retain existing safety checks.
- CompanionManager shares validated publication across native, generic, legacy
  fallback and silent refresh; refresh preserves style, invalidation clears the
  presentation. OverlayWindow draws only on its matching display and avoids a
  second old-style bubble. Legacy onboarding remains untouched.
- CompanionPanelView adds a persisted default style and Clear indication.
  Default Cursor retains the accepted experience. Voice-style override applies
  to Realtime only; legacy fallback uses menu selection. No deployment required.
- Skills influenced value-type presentation, main-actor publication, small native
  labels, click-through behavior and accessibility. No new dependencies, OCR,
  audio changes, external action or private data upload.
- `bash cursy-app/scripts/test-native-regressions.sh`: native module compiled
  excluding Sparkle entry; 85 tests / 12 suites passed in 0.797s. Build artifacts
  /private/tmp/cursy-native-regression.SGb6Xu. Existing warnings unchanged.
  Initial new test compile ambiguity and invalid native fixture suffix corrected;
  no production safety checks weakened to pass tests.
- Offline renderer prototypes/VisualAnnotationPreview.swift compiled and emitted
  /private/tmp/cursy-annotation-preview.png; inspected all four styles in light/
  dark, reduced oversized labels. This is synthetic static rendering, not live
  overlay/provider or accessibility acceptance. `git diff --check` passed.
- Added scripts/ANNOTATION_QA.md. Required remaining gate: user tests in Xcode,
  shape requests, both monitors, click-through, refresh/cancel/reset and platform
  accessibility settings. tsk005 stays in progress. Then plan walkthroughs.

## Design clarification and preview — 2026-09-21

- User requests the figures in the existing prototype and rejects General's
  visual-indicator selector: the agent chooses how, when and where to guide.
  No user must draw or configure the shapes. Keep explicit user requests/clear
  available, but do not make a stored preference drive ordinary guidance.
- Prototype removes the selector and its mock preference. A separate, labelled
  design lab shows cursor, circle, arrow, rectangle and label on synthetic content;
  sample requests demonstrate decisions, not settings or real inference.
  Light/dark backdrop, clear/restore and keyboard dialog dismissal are available.
- Reuses native circle50, rectangle72×46/radius8, arrow48×44 and dual strokes.
  Browser glass/labels are visual approximations. Fixed focus regions are NOT
  semantic bounding boxes; full-element outlining requires a separately validated
  extent contract, not a guessed expansion in this preview.
- Next native work: remove Home and legacy-menu style pickers, retire/ignore
  stored style defaults, and make agent style choice explicit across Realtime,
  fallback and refresh. Preserve validation/no-target/clear semantics and avoid
  keyword-based product rules from these synthetic scenarios. This is pending,
  not silently implemented by removing a prototype control.
- CCE Frontend + Emil Design Engineering: shared tokens, dual contrast, SF Symbol
  UI icon, isolated dialog with focus restoration. Existing prototype refined;
  no new competing visual variants or changes to accepted notch motion.
- Validation: browser reviewed all five examples, light/dark backgrounds and
  absence of General's selector; JS syntax/diff checks. No native run/model calls.

## Native preference removal — 2026-09-21

- User confirms styles are the agent's tools, not a user setting. CCE Mobile +
  Write Swift remove the HomeSettingsView/CompanionPanelView pickers and manager's
  preferredAnnotationStyle. Old UserDefaults key is no longer read or written;
  no external defaults deletion or unrelated preference migration.
- CCE AI Engineer adjusts only the existing Realtime tool description: choose a
  context-appropriate style, honor explicit requests, never ask to configure it,
  retain no-point policy and fixed-focus (not full-region outline) limits.
  No schema, model, Worker, capture or validation changes. Shared publication
  uses VisualAnnotationStyle.resolve; missing/automatic and legacy fallback use
  Cursor. Refresh keeps the current style. Clear/reset remain available.
- Legacy fallback does not yet make contextual multi-style decisions. Do not
  claim that part of the prior broad migration is implemented or close tsk005.
- ANNOTATION_QA defines 12 ordinary ES/EN requests over two layouts: zero unsafe
  marks/configuration questions; at least 10/12 useful presentations. Explicit
  styles and no-point/cancel are separate checks. Live model quality is untested.
- Validation: bash cursy-app/scripts/test-native-regressions.sh passed 175 tests
  in 22 suites; new policy cases cover all five agent styles and nil→Cursor.
  Xcode UI Build succeeded 2026-09-21 07:42 with existing warnings; no Run or live
  mic/API tests. git diff --check clean; source search finds no style preference
  consumer or selector. Native artifacts: /private/tmp/cursy-native-regression.HTcNgu.

## Adaptive guidance design revision 2 — 2026-09-21

- User prioritizes modern Cursy-tinted indicators that fit whole targets; requests
  agent-owned style and retirement, multiple marks for a step, and later continuous
  screen-aware progression. Current authorization: analyze and update prototype.
- Existing annotations lab now measures synthetic DOM regions, including a wide
  or wrapped paragraph. Ellipse encloses compact bounds; rectangle includes full
  region; arrow connects independent anchors; labels measure content and fit the
  canvas. Shared cursor palette, glass-like borders/captions and restrained shadow.
- Six synthetic scenarios; drag/drop sample shows source, route and destination,
  with keyboard simulation alternative. Success retires the old group; invalid
  drop returns to pickup. Scene invalidation clears all marks and blocks progress
  until simulated verification. No model, native capture or observation performed.
- Removed per-mark clear from the lab; agent owns figure lifetime, but cancelling
  help/withdrawing screen consent stays possible. Native Clear indication is not
  removed in this prototype-only turn; reconcile it in the later native port.
- Proposed v2 contract: prototypes/notch-voice/guidance-contract.md. Region evidence
  cannot be inferred from today's single point. Versioned scene/step ownership,
  full-region validation, max three marks, no stale partial group, truthful success
  evidence and bounded authorized observation. tsk009/010 own actual guide steps
  and verification; do not silently enlarge current 30s/two-refresh lease.
- CCE Frontend + Emil design use existing tokens/SF masks and one shared tint;
  Animate gate keeps guidance stationary (no decorative target motion), retaining
  100ms button feedback with reduced-motion support. No accepted notch changes.
- Validation: five geometry tests pass (adaptive bounds, invalid regions, edges,
  enclosing ellipse, arrow endpoints); node syntax checks and git diff --check.
  Browser reviewed six scenarios, wide/wrapped paragraph containment, palette,
  light/dark, successful local drag/drop, button step flow, stale group clearing.
  Native untouched this turn; quality of model-generated bounds remains untested.

## Guidance motion and success copy — 2026-09-21

- User requests fluid figure drawing, pointer-reactive glass light and encouraging
  completion/next-step wording. CCE Frontend + Animate refine the existing lab;
  native app, models and accepted notch motion are unchanged.
- New guidance-motion.js isolates finite 650ms SVG stroke tracing (50ms mark
  stagger), 250ms caption entrance and pointer-driven radial reflection. Semantic
  target geometry never moves; maximum three marks. Stroke painting is a deliberate
  exception to transform/opacity-only guidance for the explicitly requested trace.
  No idle loop, input delay or model call. Redraw/close/hidden-tab cancel animations;
  reduced motion uses opacity only, keyboard skips trace, optical accessibility
  modes suppress reflection. Pointer updates are batched by animation frame.
- Lab controls replay tracing and toggle an additional review step. Verified
  synthetic drop congratulates the user; additional step congratulates and points
  to review. Final review congratulates completion. Stale scene clears marks and
  disables both review actions until simulated verification. Production success
  still requires tsk010 evidence, not a click, timer or this DOM simulation.
- Validation: node syntax checks for annotations.js/guidance-motion.js; all five
  guidance geometry tests pass; git diff --check clean. Browser observed changing
  stroke offset ending at zero, light coordinates following pointer, both success
  branches, disabled stale review, reduced-motion no-trace/no-reflection, Escape
  close and restored entry focus. No native build or live model accuracy claim.
- Affected: annotations.js/css, guidance-motion.js, index.html, README and proposed
  guidance contract. Await user design acceptance before native port.

### Motion pacing refinement — 2026-09-21

- User emphasizes slow, smooth, premium formation rather than speed. Replaced
  650ms strong ease-out stroke with 1400ms linear travel (no initial speed burst),
  300ms opacity entrance, 80ms stagger and 450ms captions. Longer timing is
  intentional for this requested illustrative trace, not a global UI delay.
  Existing cancellation, stable geometry, pointer optics and reduced motion remain.
- Prototype-only; no native change. Syntax/geometry checks and browser replay
  validate mechanics; the desired subjective feel still needs user review.

## Companion-authored figures — revision 4, 2026-09-21

- User approves testing Cursy visibly creating each tool rather than independent
  outline animation. CCE Frontend + Animate own implementation; Emil guidance
  informs tip anchoring, interruption and no text scaling. Existing lab only.
- One tinted SF Symbol actor approaches on a curved path (700ms), presses (180ms),
  draws (1600ms), releases and withdraws. Rectangles grow from a fixed top-left
  anchor to the validated opposite corner. Ellipses start at their left edge;
  arrowheads are part of the drawn path, not a prematurely visible marker. Labels
  open through clipping with text at its final size. Multiple tools run sequentially.
- Stroke/geometry updates and artist position share a bounded requestAnimationFrame
  clock; approach/press/caption use WAAPI. Intentional paint-based explanatory
  animation, not a compositor-only claim. Native pointer/input never changes.
  Close/replay/new scene cancel async continuations and settle obsolete geometry;
  reduced motion shows static bounds with fade. Duplicate ResizeObserver delivery
  cannot cancel the initial demonstration. Reflection and success copy preserved.
- Validation: 11 Node tests (six motion + five geometry) pass; syntax and diff
  checks. Browser observed partial rectangle width paired with actor corner,
  circle/arrow stroke progress, label sequence, and scene invalidation during guide
  drawing leaving zero actors/marks. No native build, API calls, or deployment.
- Await user feel/design acceptance. Active observation still belongs to tsk010;
  this demo does not verify progress in another app.

### Accepted choreography, pacing tweak — 2026-09-21

- User loves revision 4 and requests 10–15% faster playback. Applied uniform
  1.12× to WAAPI phases and the shared ink/actor frame clock (~1429ms drawing).
  Paths, easing, synchronization and reduced-motion fades are unchanged. Updated
  midpoint regression timing; all 11 motion/geometry tests pass. Prototype only.
- Follow-up asks for a little more speed: increased shared playback from 1.12×
  to 1.25× (~11.6% faster than the previous revision; 1280ms drawing). No changes
  to trajectories, easing or reduced motion. All 11 tests pass again.
- User removes the explanatory connector line: label now sits 12px above target
  (safe fallback if space is insufficient), retaining its lateral creation gesture
  and tint. Updated prototype copy/contract; other figures and native app untouched.

### Faster figures and independent typed explanations — 2026-09-21

- User requests faster animations and no artist for explanatory labels. Figure
  playback is now 1.6× (28% faster than 1.25×; 1000ms draw). Curves, gestures and
  reduced-motion duration stay unchanged. Accepted notch motion is out of scope.
- Explanation uses the existing guide-caption reveal, followed by progressive
  grapheme-safe text (24ms/grapheme, 300–1000ms bounded duration), no artist job,
  drag or connector. Full-text reserve prevents bubble resizing; accessible full
  text is supplied without per-character announcements. Keyboard/reduced motion
  skip typing; scene/replay/close/hidden cancellation restores complete text and
  clears pending frames. This is synthetic presentation, not real model streaming.
- Thirteen motion/geometry tests pass, including typing progression, cancellation
  and reduced motion. Browser saw partial then full text with zero artists and
  constant 240.97px bubble width. Syntax/diff checks pass. Native app untouched.

## Native visual port — 2026-09-21

- User approves the refined prototype and authorizes native implementation for
  testing. Continue this ticket, not a duplicate. CCE Mobile + Write Swift own
  isolated presentation values and cancellable main-actor playback; Animate and
  Apple Design preserve accepted 1.6× pacing, fixed typography and reduced motion.
  CCE AI Engineer limits tool copy to actual single-target/native-bound support.
- VisualAnnotationMotion/View reuse the real companion and cursor preference:
  curved approach, press, 1000ms drawing, release/return; growing rectangle,
  arc-length ellipse/arrow tracing, pointer-driven rim and matching tint/shadow.
  One artist identity shared across displays. Label uses no artist or connector;
  reserved text layout, whole-grapheme typing bounded to1s, full accessibility label.
  Reduced motion uses complete geometry/text and fade. Optical accessibility
  settings suppress reflection. Caption backing remains dark on light backgrounds.
- Region acquisition is deliberately bounded: read-only AX hit of the exact
  element at the already validated point, no ancestor expansion, text/image
  interpretation or extra provider call. Restrict to controls/static text, not
  image/canvas/container bounds. Validate owning PID/window/frame and full region
  against front windows, display and anchor. Native controls reuse their identity.
  Missing/occluded extents choose cursor; no fabricated point-sized rectangle.
  Semantic accuracy of an AX text extent still requires live QA (word vs paragraph).
- Hide/new turn/opt-out/replacement/view removal cancel presentation; no stale
  callbacks may reset replacement ownership. After drawing, mark remains4s then
  fades and retires, retaining prior short-indication semantics. This is NOT
  completion evidence or automatic next-step progress. No per-mark Clear control;
  session cancel and screen consent remain. No changed model, Worker or deployment.
- NOT PORTED: generic image-based region contract, independent route endpoints,
  simultaneous multiple marks, durable guides, live verified success/next-step
  congratulations. tsk009/010 own guide lifecycle; tsk005 still owns locator
  extents and quality evaluation. Legacy fallback still chooses cursor.
- Validation: offline runner181 tests/22 suites passed (1s; artifacts
  /private/tmp/cursy-native-regression.UD4fCa). Added adaptive/invalid bounds,
  ellipse edges, whole-region occlusion, ink/tip phase alignment, typing and
  label-no-geometry regressions. Initial test import/mixed-number assertion issues
  were corrected; no production checks weakened. Sandbox blocked Swift macros;
  approved offline runner outside sandbox succeeded, no network or credentials.
- Native ImageRenderer light/dark sheet inspected; fixed disappearing glass
  backing by applying independent dark contrast after material. Static rendering
  is not end-to-end motion/voice acceptance. Updated ANNOTATION_QA and key files.
  Manual Xcode feel, AX extent quality, multi-display interruption and live style
  choice remain gates. Keep tsk005 in progress; no commit/push.
- Xcode UI final Build succeeded2026-09-21 10:52 (3.9s),28 pre-existing
  warnings. Corrected the new timer's actor-isolation warning without changing
  unrelated warnings. No Run, microphone, provider requests or permission reset.
  git diff --check passed. User must rebuild/run withCmd+R for physical QA; the
  already-running app was not restarted by the build.
