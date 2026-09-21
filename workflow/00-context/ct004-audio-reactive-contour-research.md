# Audio-reactive contour research

Date: 2026-09-18
Status: research only; no application edits
Related: micro005, ct002, ct003

Request: explain why deformation looks triangular rather than fluid audio waves;
research Swift/animation skills and primary web references before another change.

Verified code: CursyCursorShape.voiceCircleGeometry applies a nonlinear radial
transform to endpoints and control points of just four cubic arcs. This is not
sampling a radial wave; transformed handles do not preserve the original tangent
constraints. The angular harmonics have no time-dependent phase. All rings reuse
the cursor path with a fixed pressure stored at emission and only grow/fade.
Input for visual motion is one RMS amplitude value, not a waveform or spectrum.

Diagnosis: implementation changes the amount of one static distortion; it cannot
produce travelling local undulations at constant amplitude. More gain accentuates
lobes/cusps rather than solving that missing temporal/spatial representation.
Native glass optics may influence final appearance but are not established as
the cause. Prior numerical tests proved bounds/centering, not fluid wave motion.

Recommendation: continuous polar contour with 64–96 angular samples as a
prototype starting point, periodic smooth interpolation and bounded radius.
Use a small sum of angular waves with independent, continuous phases modulated
by time. Existing smoothed RMS drives amplitude and activity gating. Different
phase rates must deform the contour without rotating the entire object. Rings
carry a delayed envelope/phase history and continue undulating as they expand,
not a frozen distorted silhouette. Test seam/tangent continuity and visible
change at constant nonzero amplitude over time. Compare at actual 16 pt scale.

Core glass and Canvas rings share contour calculations, not duplicate glass
layers. Preserve approved arrow/comet geometry when voiceBlend is zero. For morph,
resample compatible boundaries or an equivalent continuous topology; do not swap
unrelated paths with a crossfade. Gate input to avoid ambient-noise waves; silence
relaxes the core and finishes existing waves, never creates new ones. Reduced
Motion and hidden-state behavior remain mandatory.

Alternatives: (1) recommended RMS-modulated procedural waves, entirely visual;
(2) actual short-time waveform/spectral bands from Accelerate, more signal detail
but requires a new analysis data path; (3) Metal field/shader, defer until measured
Canvas/native-glass performance or optics justify complexity. RMS cannot recover
phonemes/frequency content; label option 1 as stylized audio-reactive animation.
Do not alter the now user-accepted AirPods transport to implement option 1.

Evidence: Apple documents Canvas + TimelineView dynamic drawing; SiriWave's own
repository exposes amplitude/speed/frequency and dense curve drawing with evolving
phase; it is a third-party recreation, not Apple's Siri source or a circular API.
Apple Accelerate spectrogram sample is the separate richer-analysis alternative.

Complexity technical 5, integration 4, testing 6, rollout 2; overall 5/10.
Route: $cce-quick-feature, keep implementation in existing micro005.
Owner cce-mobile; companions write-swift, animate, apple-design.
Available tools: source/SDK inspection, official web docs, Swift isolated checks,
Xcode preview source, native UI tooling. No xcodebuild or deployment in research.
Next prompt: "$cce-quick-feature Usa ct004 para un prototipo de contorno polar
audio-reactivo en micro005, con revisión visual antes de integrar y sin cambiar
la captura ni la recuperación de AirPods."

Sources:
- https://github.com/kopiro/siriwave
- https://raw.githubusercontent.com/kopiro/siriwave/master/src/ios9-curve.ts
- https://developer.apple.com/videos/play/wwdc2021/10021/
- https://developer.apple.com/videos/play/wwdc2026/322/
- https://developer.apple.com/documentation/accelerate/visualizing-sound-as-an-audio-spectrogram
