# tsk001 — Liquid Glass cursor morph

**Status:** completed — user visually accepted fixed-orientation morph

Accepted on 2026-09-18: clear Liquid Glass, compact size, neutral shadow, fixed
-35-degree orientation, symmetric 0.30-second morph response. No dynamic cursor
rotation. User: “excelente ya esta perfecto”. Identity is translucent glass,
not metallic blue. Separate voice-surface enhancement is tracked as micro005.
Manual accessibility/multi-display matrix was not independently re-run here.
**Type:** quick feature
**Complexity:** 5/10
**Created:** 2026-09-18
**Started:** 2026-09-18
**Related work:** `micro004-native-menubar-language-picker`, `ct001-capability-roadmap`

## 1. Goals and requirements

### Current acceptance override — fixed orientation

The user explicitly requested removal of all cursor rotation after directional
settling continued to look like a blink. This supersedes the directional-heading
requirements below: both following and navigation now retain a fixed -35-degree
orientation. Only silhouette morphs, using a symmetric 0.30-second spring
response with no additional settling delay or nonlinear rotation compensation.
The surface interpolates a single scalar; dynamic overlay rotation is removed.
Earlier directional decisions remain below as historical context.

### Goal

Redesign Cursy's blue companion cursor from the current rigid triangle into the
soft, concave arrow silhouette supplied by the user, rendered as native Liquid
Glass where available. The cursor must communicate motion physically: it
streamlines into a direction-aware speed droplet while traveling and reforms
into the arrow when it stops or arrives to point at a specific element.

### Actor goals

- As a user following Cursy across the screen, I can read its movement state
  instantly without a distracting animation.
- As a user receiving visual guidance, I see the arrow return at the target and
  point precisely at the referenced element.
- As a user with motion or transparency accessibility preferences, I retain a
  clear cursor without blur or shape motion that conflicts with my settings.

### Scope

- Replace `Triangle` with one custom `Shape` whose topology supports continuous
  interpolation between rounded arrow and streamlined speed droplet.
- Render the cursor with a glass surface, fine highlight, refraction-like depth,
  and restrained blue tint rather than a flat fill and neon glow.
- Drive presentation from an explicit state model:
  `restingArrow`, `movingComet(intensity)`, `travelingComet`, `pointingArrow`.
- Detect actual pointer movement with velocity plus an idle hysteresis window;
  do not oscillate between shapes because of sub-pixel jitter.
- Preserve multi-display following, target navigation, cancellation, voice
  waveform/spinner states, bubbles, and coordinate pointing.

### Non-goals

- No changes to AI responses, screen-coordinate detection, keyboard shortcuts,
  audio, or menu-bar panel.
- No particle trails, perpetual pulse, ornamental looping, or exaggerated
  bounce. The morph exists for state indication, not decoration.
- Do not reproduce the reference image as a bitmap; it is a silhouette reference.

### Measurable acceptance criteria

- Resting and pointing states show the rounded concave arrow silhouette.
- Pointer-following streamlines into a direction-aware droplet only after
  intentional movement crosses the defined velocity threshold.
- Droplet deformation increases across stable slow, medium, and fast tiers.
- The droplet returns to the arrow after roughly 160 ms without pointer movement.
  Sub-threshold precision movement remains a stable arrow, while an already
  active gesture may slow down without repeatedly collapsing and re-entering.
- Forward and return target flights remain fully streamlined and aligned to the
  path tangent, returning to an arrow only after landing.
- Morph retargeting is continuous from the current presentation value with no
  pop, crossfade seam, rotation jump, or one-frame duplicate across displays.
- Target accuracy changes by no more than 1 point relative to the current cursor.
- Normal rendering remains smooth at the display refresh rate on Retina and
  multi-monitor setups, with no new per-frame heap allocation visible in review.

## 2. User experience

### State journey

1. **Resting:** rounded glass arrow, default cursor-like angle, subtle static
   highlight and thin edge definition.
2. **Following movement:** once meaningful pointer velocity is observed, the
   arrow streamlines into a glass droplet oriented along the motion vector.
   Faster tiers produce a longer, narrower tail while position continues to
   follow with the existing spring.
3. **Movement stops:** after the hysteresis window, the droplet reforms into the
   arrow with a restrained micro-morph. It must not bounce repeatedly.
4. **Navigating to a target:** the arrow becomes a fully streamlined droplet
   before the first flight frame and follows the existing bezier tangent.
5. **Pointing:** on arrival, the droplet reforms into an arrow oriented so its tip
   resolves on the target coordinate; the bubble appears only after the arrow is
   legible.
6. **Returning:** it streamlines again for the return flight, then reforms to the
   normal arrow beside the live pointer.
7. **Listening/processing/responding:** preserve current waveform/spinner and
   visibility rules. Transitions into and out of those voice indicators must not
   expose the old triangle for one frame.

### Motion specification

- Purpose: state indication and prevention of a jarring shape change.
- Frequency: high; therefore the effect remains restrained, but live review uses
  a critically damped 300 ms response so intermediate geometry stays legible.
- Use an interruptible SwiftUI animation tied to a single morph progress value;
  never use timer-driven keyframes for the shape.
- Retarget from the current interpolated shape when direction or mode changes.
- Reuse the project's cursor-position spring rather than adding a second motion
  system. Remove flight scale pulsing so it does not compete with the droplet.

### Accessibility

- `accessibilityReduceMotion`: keep the stable arrow and use only a short opacity
  change during travel, with no geometric morph, scale pulse, or rotation sweep.
- `accessibilityReduceTransparency`: replace live glass/refraction with an
  opaque, high-contrast adaptive material and clear border.
- `accessibilityDifferentiateWithoutColor`: shape states remain distinguishable
  without relying on blue tint.
- Cursor and pointing bubble contrast must remain legible over light, dark, and
  high-detail content.

## 3. Technical design

### Verified current architecture

- `OverlayWindow.swift` owns `Triangle`, `BuddyNavigationMode`, cursor tracking,
  the 60 Hz tracking timer, bezier target flights, rotation, scale pulse, and the
  waveform/spinner substitutions.
- Position and navigation already have one authority in `BlueCursorView`; the
  new presentation state should be derived there rather than introduced in
  `CompanionManager`.
- One overlay exists per display, so state transitions must continue honoring
  `buddyIsVisibleOnThisScreen` to prevent duplicates.

### Proposed components

1. `CursyCursorShape: Shape`
   - `morphProgress` is `Animatable` (`0 = arrow`, `1 = full speed droplet`).
   - Arrow and droplet use the same ordered cubic-bezier control-point topology.
   - Arrow geometry follows the supplied silhouette: rounded apex, rounded lower
     lobes, and a shallow concave base centered on the vertical axis.
2. `CursyCursorPresentationState: Equatable`
   - Closed value enum for resting, pointer movement, target travel, and pointing.
   - Provides target morph, orientation policy, and glass emphasis.
3. Pure movement-state reducer
   - Inputs: prior sample, current sample, timestamp, navigation mode, and idle
     deadline. Output: presentation state and next deadline.
   - Velocity threshold plus distance epsilon rejects sensor/sub-pixel jitter.
4. `CursyGlassCursorView`
   - Stable rendering container whose shape animates internally.
   - On macOS 26+ use native Liquid Glass APIs and a shared glass container when
     needed; on macOS 14–25 use native material, specular gradient, adaptive
     border, and restrained shadow.
   - Availability isolation keeps the current macOS 14.2 deployment target.

### Data flow

`NSEvent.mouseLocation` sample → pure movement reducer → presentation enum →
`morphProgress`/orientation/glass emphasis → `CursyCursorShape` rendering.
Navigation mode overrides ordinary pointer motion so target flights cannot be
interrupted by incidental samples except through the existing cancellation rule.

### Affected files

- `cursy-app/Cursy/OverlayWindow.swift` — integrate state and replace triangle.
- `cursy-app/Cursy/CursyCursorShape.swift` — new geometry and glass view.
- `cursy-app/CursyTests/CursyTests.swift` — movement reducer and state tests.
- `cursy-app/AGENTS.md` — update cursor architecture and motion contract.
- `cursy-app/README.md` — document the native morphing cursor capability.

## 4. Dependencies and compatibility

### Internal dependencies

- Existing `BuddyNavigationMode`, cursor timer, bezier flight, display ownership,
  voice state, and target coordinate flow.
- Existing reduced-motion environment support from SwiftUI/AppKit.
- The menu-bar redesign is complete; this ticket can execute independently.

### External dependencies

- SwiftUI and AppKit only. Add no package or animation dependency.
- Native Liquid Glass is availability-gated; fallback is required because the
  project deployment target remains macOS 14.2.

### Risks

- Shape control points with different winding/topology can self-intersect during
  interpolation. Prototype the normalized path before styling glass.
- The existing frame-based flight and implicit SwiftUI animations can compete.
  Position remains owned by the flight timer; only shape progress is implicit.
- Live glass over a full-screen transparent panel may be expensive. Keep the
  effect localized to the 16–22 point cursor bounds and avoid animating blur.
- High-frequency direction changes can create rotational noise, so heading is
  updated only for meaningful movement and deformation uses three stable tiers.

## 5. Implementation plan

### Phase 1 — State and geometry

1. Extract a testable movement reducer and presentation enum.
2. Build normalized arrow/droplet cubic paths with identical segment counts.
3. Replace the triangle with the morphable shape using the current size and
   coordinate anchor to prevent pointing drift.

### Phase 2 — Motion integration

1. Feed pointer velocity and idle hysteresis from the existing tracking timer.
2. Force maximum droplet deformation throughout forward and return flights.
3. Restore and orient the arrow on arrival before revealing the pointing bubble.
4. Remove conflicting triangle rotation/scale animations and verify interruption
   uses the current morph value.

### Phase 3 — Liquid Glass and accessibility

1. Add the availability-gated native glass renderer.
2. Add the macOS 14–25 material fallback and adaptive edge/highlight.
3. Implement reduced-motion and reduced-transparency variants.

### Phase 4 — Verification and documentation

1. Add unit tests for jitter rejection, movement start, idle return, navigation
   overrides, landing, return flight, and rapid retargeting.
2. Type-check and parse without terminal `xcodebuild`, per repository policy.
3. Manually run from Xcode and inspect on light/dark busy backgrounds, Retina,
   multiple displays, reduced motion, and reduced transparency.
4. Record slow-motion capture at 4× duration for frame-by-frame morph review,
   then restore production timing.
5. Update architecture documentation and capture final validation evidence.

### Security, privacy, and data

No network, credential, screen-capture, or persistence changes. Pointer samples
remain transient in memory and must not be logged or added to analytics.

### Performance

- Do not animate blur radius or allocate paths/material containers every frame.
- State changes occur only when thresholds/deadlines cross, not on every timer tick.
- Keep drawing localized and preserve the current overlay display ownership.

### Rollout and rollback

- Ship behind one internal `UserDefaults` feature flag for the first manual
  acceptance pass; default it on only after visual/performance approval.
- Rollback is removal of the new shape/view/state files and restoration of the
  current `Triangle` rendering block; navigation and AI behavior are untouched.

## 6. Validation and ownership

### Quality gates

- Pure reducer tests pass for all state transitions and jitter boundaries.
- Swift source type-check and parse pass; no new warnings in affected files.
- `git diff --check` passes.
- Manual Xcode acceptance shows no pop, duplicate, target drift, clipped glass,
  or stutter on each supported display configuration.
- Voice waveform/spinner and speech bubbles remain behaviorally unchanged.
- Accessibility variants are manually confirmed.

### Ownership and specialist routing

- CCE owner: `cce-mobile`.
- Companion skills: `write-swift`, `animate`, and `apple-design`.
- No `imagegen`: the supplied image is a shape reference, and the production
  asset should remain vector/native at every scale.

### Documentation

Update `cursy-app/AGENTS.md`, this task record, dependency notes if a new OS API
constraint is found, and the logbook on completion.

## 7. Execution record

### Implementation

- Added `CursyCursorPresentationState` and a pure
  `CursyCursorMotionReducer` with a 0.15-point accumulation epsilon, 24 pt/s
  movement threshold, two-sample entry confirmation, and 160 ms idle hysteresis.
- Added `CursyCursorShape`, which interpolates four compatible cubic Bézier
  segments between the rounded concave arrow and a streamlined speed droplet.
- Added `CursyGlassCursorView` with native Liquid Glass on macOS 26+, a
  material-based fallback for macOS 14–25, and opaque/crossfade accessibility
  variants for reduced transparency and reduced motion.
- Integrated the state reducer into the existing 60 Hz pointer tracker and
  forced streamlined presentation for both target flights. The pointing arrow now
  resolves before its bubble is revealed.
- Removed the conflicting flight scale pulse while preserving the existing
  position spring, Bézier paths, display ownership, cancellation behavior,
  waveform, spinner, and speech bubbles.
- Kept the legacy triangle behind the internal `useLiquidGlassCursor` rollback
  flag. Absence of the preference enables the new cursor by default.

### Validation evidence

- `swiftc -parse cursy-app/Cursy/*.swift cursy-app/CursyTests/*.swift` — passed.
- Full app-source `swiftc -typecheck` for `arm64-apple-macosx14.2`, excluding
  the Sparkle-dependent app entry point — passed with only pre-existing
  warnings.
- Standalone reducer harness — passed movement, idle return, jitter rejection,
  travel override, pointing override, speed-tier progression, rightward heading,
  and streamlined-droplet geometry checks.
- Temporal-stability harness — passed slow quantized movement continuity, true
  idle return, and shortest-path heading behavior across angular wrapping.
- Precision-movement harness — passed stable-arrow behavior for sparse
  half-point steps and uninterrupted comet behavior while an active movement
  decelerates.
- Offscreen shape rendering — inspected the arrow, medium-speed morph, and full
  speed droplet with no path self-intersection.
- `git diff --check` — passed.
- Terminal `xcodebuild` was intentionally not run because repository guidance
  prohibits it to avoid invalidating macOS permissions.

### Remaining acceptance gate

Manual execution from Xcode is still required to confirm live backdrop glass,
target alignment, multi-display ownership, reduced-motion behavior, and
reduced-transparency behavior. Keep the task in progress until the user confirms
that visual acceptance pass.

### Visual acceptance correction — 2026-09-18

The first live macOS 27 review exposed three optical issues that static path
rendering could not reproduce: the native glass sampling region made the cursor
appear several times larger than its 22-point layout frame, the regular tinted
material read as opaque gray, and the blue glow contaminated the glass edge.

- Reduced the logical cursor frame to 16 points and applied a 0.32 optical
  compensation scale to the complete native glass result so its visible form
  matches the smaller arrow seen inside the initial oversized lens.
- Switched native Liquid Glass from blue-tinted `.regular` to untinted `.clear`.
- Removed all blue glow from native and compatibility renderers.
- Replaced it with a short, low-opacity neutral shadow and a finer adaptive
  white highlight.
- Kept the solid blue treatment only for the explicit Reduced Transparency
  accessibility fallback, where shape contrast takes priority over translucency.

### Directional speed-droplet refinement — 2026-09-18

After approving the corrected optical size and clear material, the user chose a
directional speed droplet instead of a circle for the movement state.

- Replaced the circle endpoint geometry with a tapered, rounded droplet that
  preserves the arrow's four-segment topology.
- Added slow, medium, and fast deformation tiers so speed is legible without
  reacting to every noisy velocity sample.
- Added heading output to the pure movement reducer and aligned ordinary pointer
  movement to its velocity vector.
- Reused the existing tangent rotation for forward and return Bézier flights.
- Changed the rotation transition to the same critically damped 200 ms spring
  used by the shape, keeping retargeting interruptible and free of bounce.
- Reduced Motion now keeps a stable arrow and uses only a subtle opacity change.

### Temporal continuity correction — 2026-09-18

Live review showed that the morph could read as a blink during ordinary pointer
movement. The problem was temporal rather than geometric: instantaneous samples
could cross velocity thresholds on alternating frames, the logical enum was
used directly as the animation target, and wrapped headings could request an
almost-full rotation when crossing the `-180°/180°` boundary.

- Added low-pass velocity smoothing and hysteresis around deformation tiers.
- Reduced the coordinate-change epsilon and refresh the idle deadline for small
  samples that belong to an already-active gesture.
- Increased the true-stationary deadline to 160 ms.
- Added one persistent visual morph scalar that retargets a critically damped
  300 ms spring from its current presentation value.
- Unwrapped pointer and Bézier headings to the nearest equivalent angle, so a
  boundary crossing moves approximately 2° instead of 358°.
- Added regression coverage for slow quantized movement and angular wrapping.

### Precision-movement correction — 2026-09-18

The first continuity correction removed full-speed flashing, but very slow
movement could still blink. The remaining cause was sample quantization: the
reducer advanced its velocity timestamp on every 60 Hz timer tick, including
ticks where the coordinate had not changed. A later one-pixel step was therefore
measured as if it happened in 16 ms instead of across the full interval since
the last distinct position.

- Velocity is now measured between distinct pointer coordinates; sub-epsilon
  changes accumulate naturally instead of becoming isolated spikes.
- Entering the droplet requires two velocity-qualified samples within 100 ms,
  rejecting a solitary quantized step without delaying continuous movement by
  more than one display frame.
- Slow precision movement below 24 pt/s remains a stable arrow.
- Once the droplet is active, slower position updates keep the gesture alive so
  deceleration remains continuous until true rest.
- Added regression coverage and a standalone harness for both slow quantized
  input and fast-to-slow continuous movement.

$cce-dispatch execute tsk001-liquid-glass-cursor-morph

## Execution log

- 2026-09-18: User still perceived a flash during large downward-to-rest turns.
  Increased the shared resting spring response from 0.40 to 0.65 seconds
  (response is not a fixed duration). Applied the continuous mapping p*(2-p)
  to shape interpolation in both directions, retaining the streamlined form
  longer during rotation without timers or a discontinuity on interruption.
  Moving response remains 0.30. This also makes intermediate speed silhouettes
  somewhat more streamlined. Visual acceptance remains pending.

- 2026-09-18: Direction-dependent stopping correction: replaced the separate
  parent rotation and delayed onChange morph with one Animatable surface whose
  pair carries angle and shape progress. A shared critically damped spring uses
  response 0.40 at rest and 0.30 in motion. Glass receives interpolated frame
  geometry without a second nested animation; the position spring no longer
  controls the rotation. Pointer targets unwrap relative to the actual previous
  overlay target, including after navigation reset. Flight headings also use
  the shared spring; flight position remains timer-driven. Reduced Motion fixes
  orientation at -35 degrees. Parse, app-source type-check (excluding the
  Sparkle entry point; existing warnings only), and diff check passed;
  live downward/lateral stopping and interrupted turns still need visual review.

- 2026-09-18: Dispatch started with `cce-mobile` as owner and `write-swift`,
  `animate`, and `apple-design` as companion skills.
