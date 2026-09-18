# Cursy

> Tu amigo con IA que vive en tu Mac.

Cursy is an AI companion for macOS that can see what you see with explicit permission, listen through push-to-talk, talk back, point at interface elements, guide you step by step, and eventually take actions on your behalf in real time.

## Repository structure

- `cursy-app/` — native macOS application and Cloudflare Worker proxy
- `hellocursy/` — landing page for [hellocursy.com](https://hellocursy.com)

The first distribution target is a signed and notarized macOS `.dmg`.

## Product direction

Cursy is a visual contextual copilot rather than only an AI tutor. The initial focus is software onboarding and guided workflows: understand the current screen, explain the next step, and point directly at the relevant control.

## Open the app project

```bash
open cursy-app/Cursy.xcodeproj
```

Setup and release instructions live in `cursy-app/README.md`.

## Upstream attribution

The macOS app began from the MIT-licensed [farzaa/clicky](https://github.com/farzaa/clicky) codebase. The upstream license is preserved in `cursy-app/LICENSE`.
