# Cursy for macOS

> Tu amigo con IA que vive en tu Mac.

Cursy is a native macOS companion that can see the screen when invited, listen through push-to-talk, respond with voice, and point to interface elements with an animated cursor overlay.

This project is based on Farza's open-source [Clicky](https://github.com/farzaa/clicky) project and remains subject to its MIT license. Cursy has its own product name, bundle identifiers, source layout, prompts, and roadmap.

## Requirements

- macOS 14.2 or newer
- Xcode 15 or newer
- Node.js 18 or newer for the Cloudflare Worker
- API keys for Anthropic, AssemblyAI, and ElevenLabs

## Run the API proxy

The app sends requests through a Cloudflare Worker so provider secrets are never included in the macOS bundle.

```bash
cd worker
npm install
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
npx wrangler deploy
```

Set `ELEVENLABS_VOICE_ID` in `worker/wrangler.toml`. Then replace the placeholder Worker URL in:

- `Cursy/CompanionManager.swift`
- `Cursy/AssemblyAIStreamingTranscriptionProvider.swift`

For local Worker development, create `worker/.dev.vars` with the same keys and run `npx wrangler dev`.

## Run the macOS app

```bash
open Cursy.xcodeproj
```

In Xcode, select the `Cursy` scheme, choose your signing team, and run the app. Cursy lives in the menu bar and requests microphone, accessibility, screen recording, and ScreenCaptureKit permissions during onboarding.

## Create the DMG

The release helper archives the app, signs it, and creates a DMG. Review the signing, notarization, and Sparkle values in `scripts/release.sh` before using it:

```bash
./scripts/release.sh 0.1.0
```

## Architecture

- SwiftUI and AppKit menu bar app
- ScreenCaptureKit screen capture with multiple-display support
- AssemblyAI streaming speech-to-text
- Claude vision and conversation through a Cloudflare Worker
- ElevenLabs text-to-speech
- Transparent `NSPanel` overlay for cursor guidance

See `AGENTS.md` for the detailed architecture and engineering conventions.

## License and attribution

The original Clicky code is Copyright (c) 2026 Farza and licensed under the MIT License. See `LICENSE`. New Cursy-specific work should retain that notice wherever required by the license.
