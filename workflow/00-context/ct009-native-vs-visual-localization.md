# ct009 — Native versus image-localized pointing

- Date: 2026-09-18
- Scope: user asks why native window/Dock targets succeed but an internal visible
  list item receives the wrong point. Read-only runtime audit; no app changes.
- Related: tsk002, ct006–ct008. CCE Ask, Write Swift, AI evaluation guidance.
- Independent bounded coordinate audit corroborated the main source/log review.

## Evidence and verified cause boundary

Reviewed user-supplied screenshot, current source, and unified logs scoped to
Cursy's subsystem. Last relevant generic target, 22:14:27.502, declares and receives
an 1188×768 image and returns pixel (199,633); point accepted at 22:14:27.650.
The preceding captured display is 1, 1728×1117. No refresh was used for this turn.
Observation ended unavailable after the accepted point; this later event does
not explain its initial wrong coordinates.

Mapping the candidate through normalization/display coordinates and the existing
overlay (+8,+12) point offset predicts cursor center (340.66,1068.75) in the
1979×1280 rendered attachment. That matches the visible misplaced cursor near
the lower-left of the app, not the requested row. The supplied image proves the
row is visible there; it is not the actual earlier model-input raster. No literal
conversation or saved runtime screenshot was available, so exact perception cause
and every intermediate model response are unknown.

- Native window/Dock controls: ElementLocationDetector.resolve, lines 134–155,
  selects verified nativeControlID and returns the current AX frame center.
  Model identifies the control, but does not estimate its final pixel location.
- Generic internal elements: CompanionManager lines 745–774 passes the model's
  semantic target to a separate VisionAPI localization request. Its returned
  coordinate is the published point after validation. Selected vision model uses
  the provider-neutral adapter, configured for OpenAI; specific live selection
  was not independently queried during this audit.
- VisionLocalizationImage tracks the actual resized raster; ImagePointingTarget
  normalizes once and ScreenCoordinateSpace correctly converts to AppKit/overlay.
  No scale/origin defect was found explaining this candidate's displayed position.
  Native success alone would not prove the generic mapping, but the logged numeric
  candidate plus screenshot corroborates it for this attempt.
- GenericPointingPipeline checks intent/window agreement, freshness and current
  geometry. ScreenWindowGrounding checks display/window bounds and z-order, not
  whether the requested label/control is at that pixel. A semantically incorrect
  point inside the correct visible window can pass. Correct tooltip text is not
  proof of correct localization.
- The eight/twelve-point overlay offset is inherited unchanged from HEAD and
  applies to both native and generic targets. It cannot explain the large error.

## Implications and routes

This is a visual-localization quality failure accepted by geometry validation,
not evidence that the item was absent or that more retries alone will fix it.
The ct008 audio/freshness correction addresses a different failure mode.
No OCR, app-specific/contact-specific rules, mouse automation or weakened native
guards should be introduced.

Recommended next work within tsk002, complexity 6/10 (technical 5, integration 6,
evaluation 6, rollout 3): evaluate exact model-input/output alignment across
generic list rows, files, tabs and settings, then improve model-based target
localization/verification. Owner cce-ai-engineer, companion cce-mobile/write-swift
for crop transforms/transport changes. Consult official model documentation if
changing image preparation or provider contracts. Local source, numeric logs,
Swift tests and existing protected vision adapter are available; live API/image
evaluation must be scoped and distinguished from deterministic tests.

Options:

1. Recommended experiment: model-selected window/region localization followed by
   focused visual verification of the returned element, with explicit crop-to-full
   transforms and a rejection path. Benchmark first; do not claim a second model
   pass guarantees correctness or expand retries without bounds.
2. Evaluate a stronger/provider-supported localization model behind the same
   contract using the same labeled fixtures. Native successes are not its benchmark.

Ready-to-run: `$cce-quick-feature Refina tsk002 con ct009: evaluación y corrección
del localizador visual para elementos internos, verificación del elemento indicado
y coordenadas de recorte explícitas si se usan. OpenAI activo, sin OCR, sin reglas
por aplicación y sin alterar controles nativos que ya funcionan.`

No builds, new captures, credential reads, paid API calls or runtime edits occurred.
tsk002 remains open; prior deterministic test success is not model-accuracy acceptance.
