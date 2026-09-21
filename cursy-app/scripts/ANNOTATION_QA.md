# Visual annotation acceptance (tsk005)

Build/run in Xcode; do not use terminal xcodebuild or reset permissions.
Screen sharing must be enabled. Use ordinary controls in several applications;
named apps/files/contacts below are test data, never special product rules.

1. Verify General and the legacy menu have no indication-style selector, including
   after upgrading with an old saved style. No per-mark clear control; session
   cancel/new conversation, screen opt-out and hide Cursy remain available.
2. Request a visible control, a local focus region and a directional cue without
   naming a shape, in Spanish and English. Cursy chooses presentation without asking
   the user to configure it. Circle/rectangle use verified accessible element bounds,
   including text blocks when exposed as one accessible element. An unavailable,
   occluded or invalid region falls back to the precise cursor, NOT a guessed box.
   Images/canvases without accessible extents still need the region-capable locator.
3. Realtime voice override: “señala con una flecha el botón de cerrar”,
   “rodea con un círculo el archivo indicado”, “marca con un rectángulo esa
   opción”, “pon una etiqueta en ese control”. Also test English equivalents.
   Legacy fallback and omitted/automatic decisions use Cursor, never saved style
   preferences. Autonomous multi-style choice currently belongs to Realtime only.
   Evaluate at least 12 ordinary requests (three scenarios × two languages × two
   screen layouts): zero configuration questions, zero unsafe/unrequested marks,
   and useful presentation in at least 10/12. Separately exercise all five explicit
   styles, explanation-only/no-point, missing targets and cancellation. These are
   live acceptance criteria, not outcomes established by deterministic tests.
4. Place target near each display edge and repeat on another monitor (including
   a monitor left of/above the primary). Label stays inside the captured screen;
   arrow tip/mark center remains on exactly the validated point, no extra scale.
5. Scroll/move window while marked: invalidation clears mark and label with the
   cursor, then bounded refresh may relocate the same target with the same style.
   Observation disabled: existing single-indication lifetime applies.
6. Cancel session, New conversation, new PTT, hide Cursy and screen opt-out remove marks.
   No old mark should reappear after cancellation. Missing/ambiguous targets must
   not produce shapes from preliminary coordinates.
7. Click through the mark into the app. It must not steal focus. Test light/dark
   content, Increase Contrast and Reduce Transparency. No idle pulsing.
8. Cursy approaches, presses and creates one shape: rectangle drags from top-left;
   ellipse and arrow trace at the tip. Drawing lasts 1000ms (accepted 1.6× pacing).
   It returns to following while the mark stays briefly, then fades out. This
   retirement never announces user success. Repeat/relocalize/new PTT during every
   phase; no old cursor, caption or mark may return. Cross displays mid-animation.
9. Label appears above its target (safe below fallback), without connector or artist;
   text types progressively in a reserved layout. Long/emoji text must not resize,
   split graphemes or announce every character. Reduced motion: full geometry/text
   with short fade, no tracing/travel or moving reflection.
10. Change all five cursor tints and move the pointer around a mark: thin specular
    reflection follows it; target geometry remains stationary. Optical accessibility
    modes suppress reflection. Foreground overlays that obscure only a region's
    edge must reject the entire region even if its center remains visible.

Native port limitations: one target per turn and a short directional arrow (not a
verified source→destination route). Multi-mark step groups and actual success/
next-step verification belong to tsk009/010. No Worker/model/deployment changes.
Fallback/automatic still uses cursor. Live semantic accuracy and actual animation
feel remain manual gates; offline tests are not evidence of provider performance.

Automated: `bash cursy-app/scripts/test-native-regressions.sh` compiles native
sources (except Sparkle entry), tests layout/style routing plus prior regressions.
It does not exercise real mic/provider/display rendering. User acceptance needed.
