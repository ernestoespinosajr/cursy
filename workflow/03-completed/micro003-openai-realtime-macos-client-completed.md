# micro003 — OpenAI Realtime macOS client

**Status:** completed
**Started:** 2026-09-18
**Completed:** 2026-09-18
**Related context:** `ct001-capability-roadmap`

## Goal

Connect the macOS push-to-talk interaction to the protected Worker session
broker and OpenAI Realtime, with bidirectional PCM audio, immediate playback
interruption, and automatic fallback to the existing transcription → Claude →
ElevenLabs pipeline.

## Decisions

- Use native `URLSessionWebSocketTask`; avoid a new runtime dependency.
- Request short-lived credentials from the Worker and never ship the OpenAI key.
- Read the internal development bearer from Keychain (environment fallback only
  for local Xcode runs); never put it in source, plist, logs, or workflow files.
- Preserve the current pipeline whenever Realtime is unavailable or not
  configured.
- Keep the current hold-to-talk interaction: append PCM16 while held, commit and
  request the response on release.

## Implementation checklist

- [x] Worker session broker client and response validation
- [x] Realtime WebSocket event transport
- [x] 24 kHz mono PCM input and output
- [x] Push-to-talk lifecycle, interruption, and fallback wiring
- [x] Development credential provisioning
- [x] Focused automated/static validation
- [x] Architecture and workflow documentation

## Validation evidence

- `swiftc -target arm64-apple-macosx14.2 -typecheck` passed for the Realtime
  client and shared audio converter.
- `swiftc -parse cursy-app/Cursy/*.swift` passed for the app source set.
- `npx wrangler deploy --dry-run` produced a valid 6.41 KiB Worker bundle. It
  also emitted a non-fatal sandbox warning because Wrangler could not write its
  debug log outside the workspace.
- `git diff --check` passed.
- Rotated the production `CURSY_INTERNAL_API_TOKEN`, stored the matching value
  in the developer login Keychain, and verified the authenticated broker
  returned HTTP 200 with a non-empty ephemeral secret, `gpt-realtime` session,
  and integer expiration. No credential value was logged or written to the
  repository.
- Per repository policy, no terminal `xcodebuild` was run; live microphone and
  playback acceptance remains an Xcode/manual check after credential setup.

## Affected files

- `cursy-app/Cursy/OpenAIRealtimeVoiceClient.swift`
- `cursy-app/Cursy/CompanionManager.swift`
- `cursy-app/README.md`
- `cursy-app/AGENTS.md`
- `workflow/dependencies.md`
- `workflow/logbook.md`

## Follow-up

Run the app from Xcode and perform one manual push-to-talk exchange to validate
microphone capture, speaker routing, and perceived interruption latency under
the app's existing TCC grants.

## Post-completion update — bilingual voice

- Added explicit Spanish/English turn-language matching, with neutral Latin
  American Spanish as the fallback when the language is ambiguous.
- Changed the Realtime output voice from `alloy` to `marin`.
- Migrated the broker from deprecated `gpt-realtime` to `gpt-realtime-2.1`.
- Deployed Worker version `2a21697e-853e-4307-af94-f640ee65d72c` and verified
  HTTP 200, the expected model and voice, and a valid ephemeral secret.
