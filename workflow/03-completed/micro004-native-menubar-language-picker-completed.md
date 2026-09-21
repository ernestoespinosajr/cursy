# micro004 — Native menu-bar panel and preferred language

**Status:** completed
**Started:** 2026-09-18
**Completed:** 2026-09-18
**Related work:** `micro003-openai-realtime-macos-client`

## Request

Redesign the menu-bar interface as a native translucent macOS panel inspired
by the supplied ChatGPT reference, use the SF system typeface, and add a
persistent English/Spanish preference that makes Cursy speak directly in the
selected language instead of detecting it per turn.

## Scope and approach

- Replace the opaque custom surface with an AppKit vibrancy/material backdrop
  and semantic SwiftUI colors, controls, typography, spacing, and SF Symbols.
- Preserve onboarding, permissions, model selection, feedback, replay, and quit
  capabilities in a more compact native hierarchy.
- Model language as a value enum persisted through `UserDefaults`.
- Apply the selected language to both OpenAI Realtime and the legacy
  Claude/ElevenLabs fallback prompt.
- Keep the macOS 14.2 deployment target while adopting the visual language of
  current macOS, including accessibility behavior for reduced transparency.

## Acceptance criteria

- [x] Panel is translucent and adapts to light/dark appearance.
- [x] All visible text uses semantic SF system styles.
- [x] English and Spanish can be selected from the panel and persist.
- [x] Realtime answers only in the selected language.
- [x] Legacy fallback answers in the selected language.
- [x] Existing permission and lifecycle actions remain available.
- [x] Swift parsing/type validation and diff checks pass.

## Execution log

- Inspected the supplied reference and the existing AppKit panel/SwiftUI view.
- Selected native visual-effect material rather than a painted translucent color.
- Rebuilt the panel with `NSVisualEffectView.Material.popover`, semantic colors,
  SF text styles, SF Symbols, and native buttons/pickers.
- Added `CursyLanguage`, persisted through `UserDefaults`, and wired it into
  Realtime instructions, the Claude fallback prompt, onboarding copy, and the
  local spoken error fallback.
- Updated panel positioning to remain inside the active screen's visible frame.
- Full source type-check passed for the app target sources excluding the Sparkle
  entry point; remaining warnings are pre-existing. Swift parsing and
  `git diff --check` passed. Per repository policy, no terminal `xcodebuild` ran.

### Post-completion visual correction — 2026-09-18

- Removed the SwiftUI drop shadow that was being clipped to the rectangular
  `NSHostingView` bounds and appearing as a gray box around the rounded panel.
- Added a transparent `NSHostingView` subclass and matched its continuous
  16-point corner mask to the SwiftUI material, leaving shadow ownership to the
  native transparent `NSPanel`.
- Replaced the hand-drawn status-bar triangle with the SF Symbol
  `cursorarrow.motionlines`, using `cursorarrow` as the supported-system fallback.
- Audited visible panel imagery: header, close, microphone, language, model,
  permissions, feedback, navigation, quit, replay, and status-item glyphs now
  use SF Symbols or native control-provided symbols.
- Swift parse, full source type-check, and `git diff --check` passed. The
  type-check emitted only warnings that predate this correction.

## Affected files

- `cursy-app/Cursy/CursyLanguage.swift`
- `cursy-app/Cursy/CompanionPanelView.swift`
- `cursy-app/Cursy/MenuBarPanelManager.swift`
- `cursy-app/Cursy/CompanionManager.swift`
- `cursy-app/Cursy/OpenAIRealtimeVoiceClient.swift`
- `cursy-app/CursyTests/CursyTests.swift`
- `cursy-app/README.md`
- `cursy-app/AGENTS.md`
