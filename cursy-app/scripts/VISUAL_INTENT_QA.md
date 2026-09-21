# Visual intent/window QA (tsk004)

Build and run the Cursy scheme from Xcode. Do not reinstall or reset permissions.
Enable screen sharing and place the physical cursor on the monitor being tested.
The existing deployed locator is sufficient; this change needs no Worker deploy.

## Acceptance scenarios

1. Put one app in front and leave an identifiable portion of a different app's
   window visible. Ask naturally to show the background app. The pointer must
   identify an exposed part of the requested app or its verified Dock icon,
   never a point on the covering app. The foreground app must not become a
   compulsory scope. Codex/Xcode is one QA example, not a production exception.
2. Repeat with a visible button, file, setting, tab and list item. Request the
   target in ordinary language and include follow-ups ("now show me that one").
3. Repeat on a second monitor, keeping the physical cursor there when requesting.
4. Ask for a truly absent/fully hidden target, then an ambiguous name shared by
   two items. Cursy must not invent a point or claim it pointed; a short limitation
   or clarification is acceptable after visual review.
5. Close/minimize window and Dock requests retain verified native pointing.
6. Scroll/move the target while analyzing; no obsolete point is published. Bounded
   refresh may update it, or end safely if the scene does not settle.
7. Interrupt with another request or use New conversation during analysis. A late
   response must not replace the new turn's cursor or speak an obsolete confirmation.
8. Ask an unrelated conversational question with sharing on. No unnecessary
   localization request should be made.

Successful points keep the concise existing confirmation ("Ahí está." / "There it
is."). Zero failures in these cases is an acceptance gate, not universal accuracy.

## Diagnostics and offline checks

`bash scripts/test-native-regressions.sh` compiles the native module except the
Sparkle app entry and runs the isolated regression test files (excluding the broad
pre-existing CursyTests.swift and UI suite). No live model, screen or mic tests.

Look for `Visual semantic review ... preliminary=target_missing ... locatorInvoked=true`
when Realtime initially doubts visibility, followed by provider/validation outcome.
A `pointing_not_requested ... locatorInvoked=false` event is expected for unrelated
conversation. No user text, screenshot pixels or full tool payloads are logged.
Logs cannot reconstruct exact recognized words or historical images; do not claim
otherwise when investigating later reports.
