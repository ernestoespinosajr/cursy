# Visual annotation acceptance (tsk005)

Build/run in Xcode; do not use terminal xcodebuild or reset permissions.
Screen sharing must be enabled. Use ordinary controls in several applications;
named apps/files/contacts below are test data, never special product rules.

1. Menu → Indicación / Indication: choose Circle, request a visible control.
   Cursor reaches the validated point; a 50pt circle marks it with one label.
2. Repeat with Arrow, Rectangle, Label and Cursor. Rectangle is a 72×46pt
   focus mark, NOT the boundaries of the whole row/button. Cursor restores the
   prior presentation. Preference applies to the next indication.
3. Realtime voice override: “señala con una flecha el botón de cerrar”,
   “rodea con un círculo el archivo indicado”, “marca con un rectángulo esa
   opción”, “pon una etiqueta en ese control”. Also test English equivalents.
   A request without explicit style uses the menu preference. Legacy fallback
   uses menu preference only; it does not parse shape requests from text.
4. Place target near each display edge and repeat on another monitor (including
   a monitor left of/above the primary). Label stays inside the captured screen;
   arrow tip/mark center remains on exactly the validated point, no extra scale.
5. Scroll/move window while marked: invalidation clears mark and label with the
   cursor, then bounded refresh may relocate the same target with the same style.
   Observation disabled: existing single-indication lifetime applies.
6. Clear indication, New conversation, new PTT and screen opt-out remove marks.
   No old mark should reappear after cancellation. Missing/ambiguous targets must
   not produce shapes from preliminary coordinates.
7. Click through the mark into the app. It must not steal focus. Test light/dark
   content, Increase Contrast and Reduce Transparency. No added pulsing/motion.

Automated: `bash cursy-app/scripts/test-native-regressions.sh` compiles native
sources (except Sparkle entry), tests layout/style routing plus prior regressions.
It does not exercise real mic/provider/display rendering. User acceptance needed.
