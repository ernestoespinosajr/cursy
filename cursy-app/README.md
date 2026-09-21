# Cursy for macOS

> Tu amigo con IA que vive en tu Mac.

Cursy is a native macOS companion that can see the screen when invited, listen through push-to-talk, respond with voice, and point to interface elements with an animated cursor overlay.

This project is based on Farza's open-source [Clicky](https://github.com/farzaa/clicky) project and remains subject to its MIT license. Cursy has its own product name, bundle identifiers, source layout, prompts, and roadmap.

## Requirements

- macOS 14.2 or newer
- Xcode 15 or newer
- Node.js 18 or newer for the Cloudflare Worker
- API keys for OpenAI, AssemblyAI, and ElevenLabs

## Run the API proxy

The app sends requests through a Cloudflare Worker so provider secrets are never included in the macOS bundle.

```bash
cd worker
npm install
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put CURSY_INTERNAL_API_TOKEN
npx wrangler deploy
```

Set `ELEVENLABS_VOICE_ID` in `worker/wrangler.toml`. Then replace the placeholder Worker URL in:

- `Cursy/AssemblyAIStreamingTranscriptionProvider.swift`

### Enable OpenAI Realtime for internal macOS testing

Realtime uses a short-lived OpenAI client secret minted by the Worker. The
long-lived OpenAI key never enters the app. Set one random internal bearer as
the `CURSY_INTERNAL_API_TOKEN` Worker secret, then store the same value in the
developer Mac's login Keychain:

```bash
security add-generic-password -U \
  -s com.hellocursy.Cursy \
  -a cursy-internal-api-token \
  -w 'THE_SAME_INTERNAL_TOKEN'
```

For an ephemeral local Xcode run, `CURSY_INTERNAL_API_TOKEN` can instead be an
environment variable in the scheme. Never commit the token or put it in
`Info.plist`. If neither source is configured, Cursy automatically keeps using
the AssemblyAI → OpenAI vision → ElevenLabs fallback pipeline.

For local Worker development, create `worker/.dev.vars` with the same keys and run `npx wrangler dev`.

## Run the macOS app

```bash
open Cursy.xcodeproj
```

In Xcode, select the `Cursy` scheme, choose your signing team, and run the app. Cursy lives in the menu bar and requests microphone, accessibility, screen recording, and ScreenCaptureKit permissions during onboarding.

The menu-bar panel uses the native macOS translucent popover material and SF
system typography. Its language menu persists either Spanish or English and
uses that selection for both the interface and spoken responses; Cursy does not
auto-switch response language per utterance.

### Internal visual voice test

The menu's **Share screen / Compartir pantalla** switch is off on each launch.
When enabled, releasing Ctrl+Option captures only the display containing the
pointer and sends one aspect-preserving JPEG (up to 1920 px on its longest side
and 1 MiB) to OpenAI with that voice turn. Cursy's own windows are excluded.
Images are not saved locally; this is not continuous monitoring.
Disable sharing to cancel the current visual turn. Capture failure continues
Realtime without an image, and the assistant is instructed not to claim sight.

Realtime can request one validated overlay pointer per turn; it never clicks or
types. Generic elements receive a separate OpenAI visual-localization request
before pointing. That request uses an aspect-preserving, model-compatible raster
and returns pixels against its exact dimensions; native window/Dock controls use
verified system geometry. This adds one model call for generic targets; it does
not run local OCR or capture another screen. Use a non-sensitive test window,
ask where a visible control is, and check
the spoken answer and pointer together. Test repeated AirPods turns, both languages,
and sharing off. The user accepted this internal delivery after ct010 deployment;
tsk002 is closed. Retain these scenarios as regression coverage for future changes.

The locator now uses GPT-6 Astra with Responses, original image detail
and a strict record-only function, independently of Realtime voice and the
conversational fallback picker. Capture identity and raster dimensions stay owned
by the native request. GPT-4.1/mini remain conversational fallback, not coordinate
localizers. Claude and DeepSeek were evaluated separately; they are not silently
selected as runtime substitutes. No model can guarantee error-free localization.

**Deployment status (2026-09-18):** the updated Worker is deployed and passed
10 remote smoke checks using a synthetic image, including present/absent targets,
legacy conversation and Realtime credential minting. The user subsequently
confirmed that the native result works and accepted the delivery. Continue testing
multiple apps, both monitors, scroll and absent/ambiguous targets for future
releases; this acceptance is not a guarantee of universal model accuracy. See
[the isolated evaluation guide](scripts/LOCALIZATION_QA.md) for reproducible QA;
its screenshot tests do not replace complete app acceptance.

## Conversation sessions (tsk003)

Conversation context stays in memory until New conversation or app shutdown.
The core keeps the latest ten requests/completed exchanges, bounds retained text
to 8,000 characters per message and the explicit objective to 2,000, and rejects
late writes after a turn ends or is replaced. Realtime retains already-transcribed
requests even if the reply is interrupted; missing transcription is not invented.
New conversation clears local history, objective and indication, not provider data.

Run `bash scripts/test-session-core.sh` for offline regression tests. Follow
[the session checklist](scripts/SESSION_QA.md) in Xcode for continuity/reset
acceptance; this is separate from tsk002's accepted pointing delivery.

## Create the DMG

The release helper archives the app, signs it, and creates a DMG. Review the signing, notarization, and Sparkle values in `scripts/release.sh` before using it:

```bash
./scripts/release.sh 0.1.0
```

## Architecture

- SwiftUI and AppKit menu bar app
- Native translucent menu-bar panel with persistent Spanish/English selection
- ScreenCaptureKit screen capture with multiple-display support
- AssemblyAI streaming speech-to-text
- OpenAI Realtime speech-to-speech for configured internal builds, with fallback
- OpenAI vision and conversation through a provider-neutral Cloudflare Worker
  contract; future providers such as Claude can implement the same contract
  without changing capture, session, or pointing behavior
- ElevenLabs text-to-speech
- Transparent `NSPanel` overlay for cursor guidance
- Morphable Liquid Glass cursor that streamlines into a speed droplet while
  moving and reforms as a rounded arrow, retaining a fixed orientation throughout
- The same glass surface breathes while processing and reacts to microphone
  intensity while listening, with pearl, cyan and champagne highlights

See `AGENTS.md` for the detailed architecture and engineering conventions.

### On-demand visual refresh (internal builds)

Enable **Share screen** and **Refresh indication** in Cursy's panel. On shortcut
release, Cursy analyzes the display containing the pointer. During this request,
scroll events and local image comparison invalidate old coordinates. Cursy waits
for stability, sends a fresh image to OpenAI and locates the same requested target.
It does not click, type, advance walkthrough steps or run local OCR.

Observation is bounded to 30 seconds from its start and at most 5 seconds after
the first accepted point, whichever ends first. At most two refresh cycles follow
the initial analysis. Local samples are not uploaded unless selected for a refresh;
images are not saved to disk. Sampling reuses the permission-gated capture path,
excludes Cursy/cursor, and runs serially at a 500 ms interval plus capture time.
Pre-publication checks also take a local sample. Image comparison uses reduced
luminance, not text recognition. Small differences below its tolerance can be
missed; animations inside the target window can cause conservative invalidation.
Once the model identifies a target, freshness checks use its window and possible
occluders, not unrelated windows. Initial samples wait for that scope before
pixel changes consume retries. Visual decisions request no audio; only the final
spoken response is accepted for playback and local conversation history.
Content-free change diagnostics are emitted after observation ends, not on each
sample, so a visible debug console does not create periodic capture feedback.

Changing requests, clearing the indication, disabling sharing/refresh or stopping
the app cancels tracking. Disabling refresh restores the one-image-per-request
path. Only the current cursor display is sampled; moving the cursor to another
monitor invalidates the earlier scene. A missing/ambiguous target is not replaced
with coordinates from the old image. Updates after the initial spoken confirmation
are silent. This is short-lived pointing, not a persistent walkthrough.

Validate in Xcode with real scrolling on both monitors, both before and after
pointing, plus cancellation and consecutive AirPods turns. Automated fixtures do
not establish real-model accuracy or physical capture CPU/latency.

## License and attribution

The original Clicky code is Copyright (c) 2026 Farza and licensed under the MIT License. See `LICENSE`. New Cursy-specific work should retain that notice wherever required by the license.
