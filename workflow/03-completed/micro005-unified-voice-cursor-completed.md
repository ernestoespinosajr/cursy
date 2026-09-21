# micro005 — Unified glass voice cursor

Status: completed
Completed: 2026-09-18
Implementation: unified fluid voice cursor and bounded Bluetooth route recovery
Latest revision: soft mint, 80% maximum visual deformation, constant 0.32 optical scale
Latest acceptance: user explicitly approved closing this task after the compact-size
correction. Earlier user testing confirmed working AirPods sessions.
Related: tsk001, micro003

## Final accepted baseline

- Compact single Liquid Glass cursor; neutral shadow, fixed orientation, no inset
  duplicate, no metallic-blue branding. Arrow/comet movement remains approved.
- Connecting/thinking breathe; listening uses soft mint (RGB 0.30/0.72/0.60),
  continuous 96-point contour and up to three accent-triggered undulating rings.
- Visual deformation capped at 80%, modulated by microphone level, not audio gain.
  Silence stops new rings and restores the circle; reduced-motion fallback kept.
- Native optical scale remains 0.32 in every mode (never interpolate to 1).
- Prototype retained for comparison. Tests/type-checks passed as detailed below.
  No full Xcode suite or exhaustive device-route/accessibility matrix claimed.
  Historical pending-review entries below are superseded by this user acceptance.

Request: preserve the approved fixed-orientation glass cursor; replace separate
voice spinner and waveform with breathing and audio-reactive morphs of that same
surface. Use pearl, cyan and champagne highlights inspired by the supplied image.

Approach: one persistent cursor surface for idle/listening/processing/responding;
bounded audio normalization, processing-only timeline, reduced-motion static
feedback and reduced-transparency fallback. No added bitmap or dependency.

Acceptance: no cursor replacement or rotation; processing breathes, listening
reacts to existing microphone level, movement returns to approved behavior.
Validate Swift integration; live material/audio appearance requires visual review.

Skills: cce-mobile, write-swift, animate, apple-design; cce-micro-task owns memory.

Files: CursyCursorShape.swift, OverlayWindow.swift, identity documentation/prompts.

Implemented:
- Persistent glass cursor across all voice states; removed spinner/waveform views
  and the obsolete blue-triangle rendering switch.
- Two-second processing breath, bounded microphone-reactive morph/highlights,
  fixed orientation and neutral shadow. Palette is derived visually from the
  reference, not a claim to reproduce its unknown rendering technique.
- Added Realtime RMS metering from the existing tap, matching legacy gain; no
  extra capture session, persistence or audio logging. Legacy meter cannot
  overwrite Realtime levels. Reduced Motion pauses breathing and audio geometry.
- Removed blue-cursor descriptions from active prompts and documentation.
- Archived tsk001 following explicit user visual approval; stored fixed-angle
  identity and no-rotation decision in the logbook.

Validation: app-source Swift type-check excluding Sparkle entry point passed
with pre-existing warnings; parse and git diff --check passed. Live glass,
microphone response and accessibility appearance have not been visually tested.

Follow-up — duplicate lens and microphone crash:
- Removed native shape fill/stroke overlays: their layout-sized silhouettes
  appeared inside the larger optical glass surface. Voice color now tints the
  native lens itself; fallback materials retain their matched-shape highlights.
- Log identified a fatal 24 kHz hardware / 48 kHz client tap mismatch during
  Bluetooth reconfiguration. Recreate the input engine for each capture, use
  hardware-format validation and nil tap format, with public throwing
  installAudioTap on macOS 27 and the legacy API on older supported systems.
- Keep one converter per capture, discard queued samples from old captures,
  remove an installed tap even when engine startup fails, and check cancellation
  after broker setup. The converter remains responsible for 24 kHz wire PCM.
- A standalone synthesized-buffer check passed 48k → 24k → 48k input changes.
  It does not reproduce a real Bluetooth route change or verify live glass.
- Used write-swift and cce-mobile guidance on owned buffer lifetimes and
  recoverable errors; checked AVAudioNode declarations in the installed Apple SDK.
- Intents registration warning is not the failing stack shown by the user;
  no evidence yet links that warning to either the shape or audio crash.

Follow-up — explicit mode morph:
- User confirms duplicate cursor is gone. Latest log completes a Realtime reply;
  HAL/Intents warnings remain and are not declared resolved.
- Moved the persistent animated surface outside TimelineView. A background clock
  supplies processing targets; explicit transactions retarget persistent morph
  and activity state when voice mode changes, including return to cursor.
- Mode transition spring response is 0.45 s, motion/audio response stays 0.30 s.
  Listening now targets 0.65–0.95 morph instead of 0.30–0.65, making the shape
  change clearer while retaining the single tinted lens and fixed orientation.
- Type-check, parse and diff checks passed; live transition still needs review.

Follow-up — user reports mode transition still snaps:
- Replaced implicit Animatable surface interpolation with explicit presentation
  springs. The persistent glass lens now receives intermediate geometry at up
  to 60 Hz; rendering transactions deliberately disable secondary interpolation.
  The old implicit transaction/internal animation suppression was a suspected
  failure boundary, not a proven runtime cause.
- A critically damped analytic spring preserves position/velocity on retarget;
  the clock pauses at rest, and Reduced Motion snaps to static feedback.
  Kept approved geometry, optical scale, fixed angle and single native lens.
- Standalone executable compiled against the actual cursor source passed:
  49 intermediate entry frames, return convergence, interruption continuity and
  static snap. Added equivalent Swift Testing regressions to CursyTests.
- App-source type-check (excluding Sparkle entry point), syntax parse including
  tests and git diff --check passed. Full test target and live glass rendering
  were not run. No xcodebuild/reinstall or permissions changes performed.
- Supplied logs contain a completed Realtime response, not visual frame data;
  HAL/Intents warnings remain out of scope and are not declared fixed.

Follow-up — approved ct002 recommendation:
- Added a bounded, lock-protected PCM inbox between the audio callback and main
  actor. Close/drain retains accepted final samples. Serialized session-scoped
  sends precede commit; count successfully sent PCM bytes and discard <4800-byte
  inputs cleanly without commit/response or artificial silence. No suppressed
  send errors. Capture memory/queued PCM capped to 120 seconds.
- Releasing during connection cancels startup. Stale receive/playback callbacks
  are session guarded. Fresh output graph per session, input/output configuration
  notifications terminate the failed session. Hardware startup/runtime errors do
  not immediately launch a legacy engine on the same route; broker failures can
  still fall back. Diagnostics log format/byte counts, not captured content.
- Added connecting state; processing persists until output playback starts.
- Dedicated four-curve membrane geometry, continuously blended from the accepted
  cursor topology. Voice uses a quiet contour, bounded audio envelope/ripples;
  thinking breathes independently. No dynamic rotation or additional silhouette.
- Removed warm native tint and second audio gain. Native glass stays near-neutral
  pearl; cyan/violet fallback highlights are restrained. Native spectral highlights
  are deliberately deferred pending visual validation, rather than stacked glass.
- Reduce Motion uses static state geometry; hidden overlays pause frame clocks.
  Existing approved arrow/comet movement remains separate from voice deformation.
- Added DEBUG Xcode preview with state buttons, simulated voice and a manual
  level slider; no microphone, credentials or network needed for this prototype.
- Standalone executable using production sources passed 85/100 ms boundary,
  closing drain, late callback rejection, 100 concurrent mailbox appends, memory
  cap, 101 finite geometry blends and spring convergence. Geometry contact sheet
  inspected; it is not a native Liquid Glass rendering test. Regression tests
  added to CursyTests. DEBUG source type-check passed with existing warnings.
- Still required: Xcode live glass review, rapid PTT, repeated internal-mic and
  Bluetooth turns/route changes, accessibility and real speech response. No live
  API/microphone test, full Xcode test suite, build/install or TCC changes run.
  HAL and Intents warnings are not claimed resolved without device verification.

Follow-up — ct003 approved, AirPods confirmed:
- User's new log confirms our configuration-change guard cancels later turns;
  first capture sent 245904 PCM bytes, so the old 85 ms commit issue is not shown.
  No claim that all HAL errors or network timeouts share that root cause.
- Replaced voice membrane target with a four-arc circle, preserving continuous
  topology and fixed orientation. Connecting emits neutral rings; listening uses
  translucent blue tint and amplitude-driven rings; processing breathes. At most
  three Canvas strokes, 1.1 s lifetime, no additional glass surface or inner icon.
  Accessibility disables travelling waves; clocks stop when hidden/settled.
- Input configuration changes drain accepted PCM, pause capture and rebuild after
  300 ms with at most two recovery attempts per turn. Release/cancel invalidates
  pending recovery. Two-second first-sample watchdog uses the same bounded policy.
  UI indicates listening only on actual microphone samples, not engine.start().
- Output configuration changes rebuild playback with the same two-attempt bound;
  retain unconfirmed PCM deltas and reschedule them in order. Generation guards
  discard callbacks from stopped graphs. A partially played chunk may repeat
  after a hardware interruption; no sample-accurate replay claim.
- Type-check (including DEBUG preview), source/test parse and diff checks passed.
  Standalone production-source test passed round geometry, pulse lifetime,
  finite morph frames, spring convergence and existing mailbox/PCM tests.
  Recovery itself is not hardware-tested; repeated AirPods turns, release during
  renegotiation and physical route changes remain required manual acceptance.

Follow-up — organic voice accents (visual-only):
- Replaced periodic listening emissions with an amplitude-envelope accent
  detector: noise gate, fall/rearm hysteresis and minimum interval. Sustained
  amplitude emits once, not on a repeating clock; loading cadence unchanged.
- Smoothed microphone energy now drives subtle centered contour deformation
  for the core and outgoing rings. No rotation or position shifts. Keep at most
  three live rings and let them fade naturally; no forced removal on new accents.
- Processing retains autonomous circular breathing; Reduced Motion retains
  static geometry and no travelling rings. Capture/transport files untouched.
- Executable against production cursor source passed accent/rearm, sustained
  amplitude, silence, NaN and 100 centered deformation steps. Source/test syntax
  parse and git diff --check passed. Added matching Swift Testing regressions.
  Live visual feel of this refinement has not been verified by the agent.

Follow-up — user cannot perceive the deformation:
- Increased visual pressure response with a bounded square-root mapping after
  a 0.04 normalized noise gate, without changing audio capture/gain. Geometry
  uses centered second/fourth angular harmonics with substantially larger lobes.
- Outgoing rings retain the originating accent's deformation (minimum 0.55),
  rather than becoming circles when the current microphone level drops. Stronger
  1 pt strokes and opacity; expanded local canvas avoids clipping broad lobes.
- Removed periodic connecting waves per latest instruction: waves only emit on
  listening accents with current signal above the gate. Connecting now breathes.
  Existing waves fade naturally. This is amplitude gating, not speech recognition;
  sufficiently loud background noise can still activate the visual response.
- Swift DEBUG type-check, parse, diff check and isolated production-source tests
  passed for sensitivity/gating, retained ring distortion, accents and 100 finite
  centered deformations. Native optical appearance still needs live acceptance.
  Audio/AirPods transport unchanged.

Follow-up — ct004 standalone contour prototype:
- User approved prototype-first validation. Added isolated SwiftUI demo in
  prototypes/VoiceContourPrototype.swift; no app target or transport changes.
- 96 periodic samples joined by Catmull–Rom-derived cubic curves. Independent
  time phases create local undulation at constant amplitude without rotation.
  Expanding rings continue deforming; simulated silence stops emission and
  restores the circle via a smoothed envelope. Maximum three live rings.
- Native demo offers actual-size and 4x views, sustained/phrase/silence signals,
  intensity, slow motion, reduced motion, glass and background controls.
- swiftc standalone compilation and executable geometry tests passed: temporal
  change at constant level, silence stability, periodic seam, 23040 finite bounded
  samples. git diff --check passed. Native window launch and screenshot verified;
  screenshot revealed redundant optical scale, removed for the 16 pt core.
- This is simulated input, not microphone validation. User visual acceptance and
  integration with the production accent detector remain pending.

Follow-up — prototype palette comparison:
- Added eight named palettes (ice blue, lavender, mint, rose, champagne, copper,
  silver, graphite) and independent soft/metallic-style finishes. Both core and
  rings share the chosen gradient; metallic appearance uses static light bands,
  not physical metal rendering or additional animation. Existing light/dark and
  glass toggles allow comparison. No production branding decision made.
- Standalone swiftc compilation and git diff --check passed. Opened updated demo;
  production cursor and audio remain unchanged. User preference pending.

Follow-up — approved soft mint / 80% integrated:
- User selected mint, soft finish, Liquid Glass, 80% in prototype. Integrated
  96-point phase-driven contour into production voice shape, sampling existing
  arrow/comet curves for a continuous morph. Idle arrow path remains unchanged.
- Visual pressure capped at 0.8 (not audio gain); ring contours continue evolving
  during expansion. Preserve speech-accent gating, at most three rings, silence
  settling, reduced motion, and fixed orientation. No audio transport changes.
- Native lens uses mint tint without a separate inset overlay; voice optical
  scale interpolates to the prototype scale, leaving navigation size unchanged.
  Soft mint gradients on waves; transparent desktop background, not demo black.
- Swift type-check and isolated executable passed: 80% cap, invalid input,
  silence stability, 240 bounded evolving contours, finite morph frames and
  accent gating. Updated source regression expectations; git diff --check passed.
- Full app build/live appearance requires Xcode run; no terminal xcodebuild,
  installation or TCC changes. Keep task open for visual acceptance.

Follow-up — oversized voice lens regression:
- User reported enlarged rather than actual-size voice cursor. Integration had
  interpolated the native optical scale from 0.32 to 1 with voiceBlend, increasing
  lens size 3.125x. Restored constant 0.32 optical compensation for all modes.
- Mint, 80% visual pressure, contour motion, rings and audio unchanged. Swift
  type-check and diff check passed; live size acceptance remains pending.
