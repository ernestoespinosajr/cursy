# tsk017 — Voice latency and lifecycle acceptance

## Implemented scope

Native Realtime now starts AVAudioEngine before broker/WebSocket/history waits.
Audio remains in RAM until configuration/history have been sent, then drains FIFO.
Preconnection audio is bounded to 960,000 bytes (20 s PCM24k mono Int16); the
whole utterance to 5,760,000 bytes (120 s), including device rebuilds. A separate
20 s startup deadline stops the turn if the network is not ready.

Release closes the audio mailbox/stops capture immediately, even during setup.
A valid utterance (at least 4,800 bytes) waits for transport, commits once, and
answers once. Failed setup after capture asks for retry rather than silently
switching recorders and losing words. Nothing is recorded while idle.

The release screenshot starts independently of pending audio/network work.
Audio commits before waiting for the screenshot; response.create still waits
for context. Screen consent, capture/turn identity, refresh, localization and
the silent visual-decision response gate remain unchanged. Disabling screen
sharing cancels the turn and its pending screenshot. The spatial hint only
appears while actual microphone buffers have made voiceState listening.

Protocol reference: [OpenAI Realtime WebSocket audio flow](https://developers.openai.com/api/docs/guides/realtime-conversations#handling-audio-with-websockets).
With manual turn detection, audio commit and response creation are separate.

## Offline evidence / limitations

Run `bash scripts/test-native-regressions.sh` from cursy-app. The input delivery
tests use synthetic PCM and injected clock readings, not microphone/network.
They cover readiness/release in either order, one-shot flush/finish, cancellation,
new turns, minimum duration, buffer/turn caps, closed mailbox drain, fallback
policy and phase timing. Existing screen/pointing/response-gate regressions run too.
They do not prove OS audio readiness, WebSocket event ordering against the live
provider, perceptual latency or Bluetooth behavior. Xcode Build is separate.

## Real-device procedure (manual gate)

Build and Run through Xcode only. Use non-sensitive test content and the existing
screen consent. These tests send audio and, when enabled, screen context to the
configured services; no automatic live tests are run by the offline runner.

1. Internal mic, cold start: hold Control+Option and begin a sentence immediately.
   Check its first word is retained; listening/hint reflects real capture, not
   connection status or the cursor's animation. Repeat 10 times.
2. Release a 0.5–1 s utterance before the first network connection is ready.
   Recording must stop immediately. Exactly one answer arrives after setup;
   the microphone must not restart when setup completes. A sub100ms tap discards.
3. Escape during setup, during held recording, after release and while waiting
   for speech. Start another turn quickly. No old audio/image/answer may leak.
4. Offline/slow setup: failure must end capture, clear the gesture and stop the
   hint within the startup bound; no automatic second recorder or response.
5. Repeat with Bluetooth. Disconnect/change input while holding, and release
   during route recovery: no stale listening hint and no restart after release.
6. Screen on/off: voice-only responses; explanation of supplied content; explicit
   pointing; missing target; scroll/window change during pending connection;
   gestures across scenes. Old release images must not authorize stale pointing.
7. Disable screen sharing during setup/release work: no queued image is sent
   after cancellation. Confirm no mic samples/indicator while idle.

## Measure, do not infer from UI animation

In Console/Xcode filter `VoiceLatency` (subsystem `com.hellocursy.Cursy`, category
`RealtimeCapture`). A trace UUID groups one attempt. Only enumerated phase names
and numeric monotonic milliseconds are recorded, never speech, images or secrets.
`start_ms` begins inside startPushToTalk just before engine setup, not at hardware
key-down. `release_ms=-1` means release has not happened. `firstPCM` is when the
first converted buffer reaches MainActor, a capture-readiness proxy, not speech
detection. `transportReady` means configuration/history sends completed, not a
separate server acknowledgement. `playbackScheduled` is scheduling, not proof
of sound emerging from the speaker. Repeated phases record their first occurrence.

Collect phase intervals:

| Metric | Difference |
|---|---|
| Input readiness | firstPCM.start_ms − captureRequested.start_ms |
| Broker | brokerReady.start_ms |
| Ready transport | transportReady.start_ms |
| Release-to-first-audio | firstAudioReceived.release_ms |
| Output setup | playbackScheduled.start_ms − firstAudioReceived.start_ms |
| Visual decision | visualDecisionReady − visualDecisionRequested |
| Localization | localizationFinished − localizationStarted |
| Spoken generation | firstAudioReceived − spokenResponseRequested |

For comparable baseline/updated runs keep device, connection, models, history,
screen dimensions and prompts stable. Record p50 and p95 plus failed/cancelled
attempts separately; do not count cancellation as fast success. Separate cold
sessions, Bluetooth and pointing from explanation/voice-only calls. A provisional
internal-mic readiness target is p95<250ms, not an achieved result or SLA.

## Remaining phase F3

The mandatory visual decision remains: bypassing it previously allowed spoken
pointing claims without publication. After this measured baseline, evaluate a
smaller decision contract or safe fast route using 5 trials each of conversation,
explanation, pointing, absent target, follow-up after scrolling and multiscene
gestures. Require no false publication claims and no regression in accepted
cases. Session reuse/prewarming needs an explicit idle/cost/privacy policy.
No Deepgram/Cerebras, model swaps or Worker deployment are part of this change.
