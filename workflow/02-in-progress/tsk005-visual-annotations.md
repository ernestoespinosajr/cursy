# tsk005 — Validated visual annotations

Status: in progress
Date: 2026-09-19
Complexity: 5/10
Owner: cce-mobile with write-swift, apple-design; cce-ai-engineer for typed style routing.

## 1. Goals and requirements

Add circle, arrow, rectangular focus marker and label to the existing cursor
guidance. User accepted tsk003. ct001 places annotations before persistent
walkthroughs. https://www.heyclicky.com/ currently advertises drawing on screen;
it does not document exact geometry/API. Original commit 97c5406 supports POINT
tags and a cursor bubble, not a reusable annotation protocol. Reuse its overlay.
Only validated points may become annotations. No OCR, clicks or new providers.

## 2. Experience

Menu selects default style; voice can request an explicit shape through the
existing structured visual decision. Default remains cursor for compatibility.
Circle/rectangle are bounded focus markers centered on a verified point, NOT
inferred element bounding boxes. Labels stay within the captured display.
Clear indication removes all marks and stops its short observation. New turn,
reset, screen opt-out and invalidation also clear. No new motion or timers.
SF text/symbols, neutral outline for contrast, click-through overlay.

## 3. Technical design

VisualAnnotation is an immutable presentation value from a validated global
point, display frame and label. Pure layout maps global AppKit to overlay once.
Realtime decision adds an optional typed style; automatic uses menu preference.
Style passes to native and generic paths without affecting locator coordinates;
silent refresh preserves it. Fallback uses menu preference. Worker unchanged.
No guessed element dimensions, no unvalidated provider coordinates published.

## 4. Dependencies

Closed tsk002/tsk003/tsk004; reuse overlay, coordinate conversion, lifetime and
localization gates. No packages, credential operations, deployment or database.
macOS14.2-compatible SwiftUI/AppKit; retain approved cursor and audio behavior.

## 5. Implementation

Close tsk003; introduce value/layout/view, structured style plumbing and common
validated publication helper, native menu choices/clear, tests and QA checklist.
Preserve existing dirty changes. Swift compiler only, never terminal xcodebuild.
No private screenshot upload in validation. No new continuous capture.

## 6. Validation and rollback

Offline tests: enum decoding/default/rejection; native/generic routing; display
mapping with negative origins, edge placement and finite geometry; reset/clear.
Run native regression runner, diff checks. Manual gate: user runs Xcode and
tests each style, second monitor, scroll invalidation, cancel/reset and clicks
passing through. Remain in progress until user accepts visible delivery.
Rollback: select Cursor; code rollback limited to this feature, never reset tree.
Next: persistent walkthrough plan, then supervised step verification.

Execution: `$cce-dispatch execute tsk005-visual-annotations` (authorized this turn).

## Implementation and evidence — 2026-09-19

- Added VisualAnnotation.swift: typed styles, immutable validated-presentation
  value, exact global-to-overlay conversion, fixed focus marks, display-bounded
  compact labels, dual-contrast strokes, Reduce Transparency support. No motion.
- VisualTurnContext/OpenAIRealtimeVoiceClient route explicit voice style through
  the existing tool. Unknown styles reject; omitted/automatic preserves default.
  Native fast path and generic semantic review retain existing safety checks.
- CompanionManager shares validated publication across native, generic, legacy
  fallback and silent refresh; refresh preserves style, invalidation clears the
  presentation. OverlayWindow draws only on its matching display and avoids a
  second old-style bubble. Legacy onboarding remains untouched.
- CompanionPanelView adds a persisted default style and Clear indication.
  Default Cursor retains the accepted experience. Voice-style override applies
  to Realtime only; legacy fallback uses menu selection. No deployment required.
- Skills influenced value-type presentation, main-actor publication, small native
  labels, click-through behavior and accessibility. No new dependencies, OCR,
  audio changes, external action or private data upload.
- `bash cursy-app/scripts/test-native-regressions.sh`: native module compiled
  excluding Sparkle entry; 85 tests / 12 suites passed in 0.797s. Build artifacts
  /private/tmp/cursy-native-regression.SGb6Xu. Existing warnings unchanged.
  Initial new test compile ambiguity and invalid native fixture suffix corrected;
  no production safety checks weakened to pass tests.
- Offline renderer prototypes/VisualAnnotationPreview.swift compiled and emitted
  /private/tmp/cursy-annotation-preview.png; inspected all four styles in light/
  dark, reduced oversized labels. This is synthetic static rendering, not live
  overlay/provider or accessibility acceptance. `git diff --check` passed.
- Added scripts/ANNOTATION_QA.md. Required remaining gate: user tests in Xcode,
  shape requests, both monitors, click-through, refresh/cancel/reset and platform
  accessibility settings. tsk005 stays in progress. Then plan walkthroughs.
