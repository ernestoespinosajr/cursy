# Circular voice pulses and repeated-session investigation

Date: 2026-09-18
Status: research only; no app changes
Related: micro005, ct002, accepted tsk001

User reports substantial visual improvement but only one successful live turn.
Requests circle during activation with outward loading pulses, then blue-tinted
circle with small audio-reactive outward waves. This supersedes the membrane
direction for voice only; neutral fixed-angle navigation remains accepted.

Evidence: current connecting state targets a partial membrane with no pulse;
listening deforms its contour from RMS. Existing presentation springs, normalized
level, accessibility switches, visibility-aware clock and DEBUG preview are reusable.
Input and output configuration observers in OpenAIRealtimeVoiceClient terminate
the session on every configuration change. Latest failure log was not supplied.

Recommendation: one persistent cursor-to-circle contour, a native glass center,
and at most two or three ordinary stroked rings behind it (not additional glass).
Connecting rings are periodic and neutral; active listening center is translucent
blue and rings respond to smoothed amplitude/onsets, with a noise threshold and
emission-rate cap. Silence stops new waves; existing rings finish fading. Thinking
uses a slow autonomous center breath, distinguishable from audio-driven rings.
No dynamic rotation. Reduced Motion uses static state/color changes; timers stop
when hidden. Do not use symbolEffect(.pulse) as a substitute for expanding rings:
Apple documents it as a symbol-layer opacity effect, not radial propagation.

Alternatives: a few Circle strokes (recommended simplest); Canvas if measurement
justifies more complex rendering. No shaders or external animation dependency.

Audio diagnosis: a legitimate device/sample-rate renegotiation may trigger the
current conservative observer policy. This is a hypothesis, not a confirmed cause
of the second-turn failure. Obtain latest failed-turn log and input/output route;
compare internal microphone and Bluetooth across repeated turns. Log session,
start/stop/configuration events and PCM counts, not audio content or credentials.
Do not declare HAL/Intents or repeated-session failures fixed from a successful
first call or isolated geometry tests.

Complexity: technical 4, integration 5, testing 6, rollout 2; overall 5/10.
Route: $cce-quick-feature; continue micro005, do not duplicate task tracking.
Owner cce-mobile; companions write-swift, animate, apple-design.
Tools available: official web docs, source/SDK inspection, Swift isolated checks,
Xcode preview source and native UI tools. No terminal xcodebuild.
Next prompt: "$cce-quick-feature Especifica ct003 dentro de micro005 y usa el
registro del segundo intento para diagnosticar el audio antes de implementar."

Sources:
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://developer.apple.com/documentation/symbols/pulsesymboleffect
- https://developer.apple.com/documentation/swiftui/canvas
- https://developer.apple.com/videos/play/wwdc2021/10021/
- https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
