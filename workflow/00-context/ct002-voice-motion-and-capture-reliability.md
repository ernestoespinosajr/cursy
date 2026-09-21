# Voice motion and capture reliability research

Date: 2026-09-18
Status: analysis only; no app source changes
Related: micro005 (in progress), micro003, accepted tsk001

Request: investigate distinct thinking/listening/speech-reactive states after
user observed an orange oval; analyze HAL errors and rejected 85 ms audio commit.

## Verified evidence

- CursyCursorShape.swift:204–240 interpolates only arrow and movement-comet
  geometry. Voice modes at 412–420 reuse that same scalar; listening/processing
  ranges overlap. There is no dedicated voice silhouette.
- Native rendering at 490–507 uses one uniform tint, trending warmer as activity
  grows. The pearl gradient is only used in fallback/opaque rendering, not native
  glass. Thus the reference's localized spectral highlight is not implemented.
- Audio RMS gain is 10.2 in OpenAIRealtimeVoiceClient.swift:275, followed by
  normalization gain 2.85 in CursyCursorShape.swift:408. Visual input saturates
  around RMS 0.0352; actual microphone levels have not been measured.
- finishInputAndRequestResponse at client:213–225 stops capture then commits
  unconditionally. There is no minimum successfully-sent PCM duration check.
- Tap callback at 279–287 creates independent MainActor tasks and suppresses
  send errors. stopMicrophoneCapture at 309–316 invalidates captureID and can
  discard queued callbacks. No explicit append-drain barrier precedes commit.
- Startup waits for session minting before starting microphone. Manager:593–597
  finishes immediately if shortcut was released during startup.
- No AVAudioEngineConfigurationChange observer found in app source.
- SDK AUComponent.h:835 maps -10877 to kAudioUnitErr_InvalidElement.
- Latest user logs explicitly show input commit rejected: 85 ms versus minimum
  100 ms; HAL StartIO fails and reports an existing IO thread. Earlier transcript
  completion does not demonstrate subsequent capture or playback health.

## Inferences and unknowns

Uniform warm tint plausibly explains orange appearance, but live background and
glass optics were not measured. HAL messages suggest engine/device lifecycle
trouble; they do not prove concurrent app starts or a Bluetooth-only root cause.
No app-side Intents registration call was found; do not call private LN APIs.
No runtime trace or microphone capture was performed in this analysis.

## Recommended direction

Keep accepted fixed-angle resting/movement cursor. Introduce a dedicated voice
contour with compatible control-point topology: a compact fluid ribbon/lens,
not an ellipse and not a second shape inside the cursor. Listening silence is
quiet; real speech modulates bounded contour lobes using smoothed RMS envelope;
processing uses a slow autonomous breathing contour. No rotation/spinner.
Pearl-neutral material with restrained cyan/violet highlights; warm reference
tones only as tiny highlights, never a whole-surface orange tint. Visual prototype
must validate native glass geometry before adding complex highlights/shaders.
Separate connecting, capture-ready, thinking and audible-output state signals.
Reduced Motion retains static distinguishable states; Reduce Transparency uses
opaque fallback. Freeze simulation/timers while hidden or settled.

Alternatives: native single-shape glass (recommended first), custom shader for
localized spectral lighting (only after a native prototype proves insufficient),
separate waveform (reject: contradicts user's single-cursor requirement).

Audio first: serialize per-session append/finish/cancel, drain accepted chunks,
count successfully sent PCM frames (2400 frames / 4800 bytes = 100 ms at 24 kHz
mono PCM16), cancel short input cleanly without response.create or silent padding.
Handle configuration changes explicitly and trace session IDs, engine transitions,
hardware format, frame counts and send errors; do not log voice content/secrets.
Compare internal mic and Bluetooth with rapid press/release and repeated turns.

## Complexity and route

Technical 6/10; integration 6/10; testing 7/10; rollout 3/10. Overall 6/10.
Recommended route: $cce-quick-feature; owner cce-mobile, companions write-swift,
animate and apple-design; openai-docs for transport contract. Keep micro005 active;
do not duplicate its implementation tracking with another formal task.
Available capabilities: source/SDK inspection, official web docs, Swift isolated
checks and native UI tools. No terminal xcodebuild per repository policy.

Next prompt: "$cce-quick-feature Usa ct002 para especificar la corrección del ciclo
de audio y el prototipo de estados de voz; conserva micro005 como ejecución y
exige aceptación visual antes de cerrar el trabajo."

## Sources

- https://developer.apple.com/design/human-interface-guidelines/motion
- https://developer.apple.com/videos/play/wwdc2025/219/
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://developer.apple.com/documentation/accelerate/vdsp/rootmeansquare(_:)-9xkkk
- https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange
- https://developers.openai.com/api/docs/guides/realtime-conversations#push-to-talk
