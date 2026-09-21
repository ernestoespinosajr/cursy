# Adaptive guidance — proposed contract v2

Design contract for tsk005, coordinated with tsk009/tsk010. **Not a shipped model
schema or live observation implementation.** The lab substitutes synthetic DOM
rectangles for grounded regions; browser appearance approximates native glass.

## Decision and appearance

| Tool | Use | Required geometry |
| --- | --- | --- |
| none | Conversation/explanation needs no visual cue; target is missing or stale | No coordinates |
| cursor | One precise, isolated control | Validated point |
| ellipse | Compact object, button, part of a diagram | Validated region; enclose it with optical padding, not a fixed radius |
| rectangle | Paragraph, panel, related controls or drop area | Validated region enclosing the intended content, never a guessed size from a point |
| arrow | Direction or relation from source to destination | Two validated anchors; length follows distance, tip reaches destination |
| label | Short context attached to a target | Validated anchor + bounded text; measured text layout and collision-free placement |

The agent owns choosing, combining, replacing and retiring indications. The user
chooses only the companion's cosmetic tint, shared by cursor, strokes, glow and
captions. Do not ask the user to configure tools. Prefer the smallest sufficient
set. A single pointer should not also receive a decorative circle and rectangle.
At most three logical marks per step; captions belong to their mark rather than
counting as new targets. Suppress a caption if no safe placement is available.

Continuous thin colored rim, restrained matching shadow, translucent fill that
does not blur text inside a region, glass caption outside it. Shape interiors
remain legible. Dual contrast for light/dark surfaces; opaque backing under high
contrast/reduced transparency. No pulse, wandering marks or stretching of text.
On a new target, Cursy's visual companion approaches, presses, creates the shape
and releases. Rectangle: drag from top-left to opposite corner, growing the box.
Ellipse: follow its contour from the left. Arrow: follow the shaft and arrowhead.
Label: place the explanation directly above its target with a small gap, no
connector line. Unlike geometric tools, explanations use the guide-caption bubble
entrance, never an artist/drag gesture. Reveal text progressively while reserving
the full layout size; expose complete accessible text rather than character-by-
character announcements. Reduced motion shows the full text, and cancellation
stops pending typing. This demo is not evidence of model streaming. If
there is no safe room above, retain collision-safe placement rather than cover
the target. One artist handles multiple marks sequentially, never duplicate
companions. The physical mouse is never moved or clicked. Use deliberate pacing,
not an initial speed burst; final semantic bounds are fixed, while the intermediate
visual construction is decorative, not new grounding evidence. Never block user
input on animation. A restrained specular reflection may follow
the pointer while the figure itself stays fixed. No idle shimmer. Cancel obsolete
animations on replacement/retirement. Respect reduced motion with opacity only
and no moving reflection; high contrast/reduced transparency suppress reflection.
No per-figure selector or delete control. Session-level cancel/pause and screen
sharing opt-out remain available; hiding a tool is not removing user consent.

## Proposed data boundary

```typescript
type Region = { x: number; y: number; width: number; height: number };
type Anchor = { x: number; y: number };
type Mark = {
  id: string;
  targetID: string;
  role: 'focus' | 'source' | 'destination' | 'route' | 'context';
  geometry:
    | { kind: 'cursor'; point: Anchor }
    | { kind: 'ellipse' | 'rectangle'; region: Region }
    | { kind: 'arrow'; from: Anchor; to: Anchor; destinationTargetID: string }
    | { kind: 'label'; anchor: Anchor };
  caption?: string; // bounded 120 characters; app measures text, not the model
};
type GuidanceProposal = {
  version: 2;
  sessionID: string; turnID: string; stepID: string; revision: number;
  captureID: string; displayID: number; capturedAt: string;
  imageWidth: number; imageHeight: number;
  coordinateSpace: 'image-pixels-top-left';
  action: 'show' | 'replace' | 'retire' | 'no_guidance';
  marks: Mark[]; // 0..3, unique IDs; empty for retire/no_guidance
  completionCriterion?: string; // verifiable result, not 'a click occurred'
};
```

App-owned evidence binds every targetID to its verified window/screen identity.
Do not trust model echoes of capture IDs, dimensions, or timestamps. Reject
nonfinite/out-of-image points, nonpositive regions, oversized payloads, unknown
kinds, duplicated IDs, stale revisions, unsupported cross-display routes and
missing target ownership. Verify the whole region belongs to the current visible
target scope, not just its center. Re-localize if obscured or uncertain. Convert
pixels to the captured display exactly once; keep decoration padding separate
from semantic bounds. Never clamp an invalid model box into apparent validity.
Near an edge a valid ellipse may become a bounded rectangle; never crop the
target merely to keep the oval. A route is atomic: no source/destination subset
should survive invalidation and imply a different instruction.

This needs a region-capable localization extension and evaluation, not a cosmetic
change to today's point contract. Keep existing native controls' verified geometry
fast path. No provider/model change is implied. Native v1 remains fixed-size.

## Multi-mark guide and observation lifecycle

`idle → authorized guide → locate → validate → show current step → observe`

Observing can yield verified completion (retire old group; locate next step),
uncertain (pause/ask), changed scene (retire immediately; re-localize), or
cancelled/expired (clear buffers and marks; stop observation). A drop gesture is
not proof a real application accepted the item; require fresh result evidence.
Do not infer completion from elapsed time, speech or a cursor crossing a box.

After verified success, acknowledge the user's progress briefly: a final step
gets congratulations (for example, “¡Muy bien! Has completado la entrega.”); an
intermediate step gets congratulations plus the next action (“¡Muy bien! Ahora
revisa la entrega.”), with the next validated target indicated. Do not announce
internal cleanup such as “la guía se retira”. Uncertain or stale evidence must
not trigger congratulations or advancement. These phrases illustrate tone, not
hard-coded instructions for a particular application.

Observation belongs to an explicitly active, visible, pausable guide. Reuse
single-flight capture, change-triggered refresh, bounded sampling/inference and
budgets. No indefinite background watching; never extend today's 30-second,
two-refresh lease silently. tsk009 owns steps; tsk010 owns bounded verification.
PTT interruption, privacy opt-out, closing the guide or an obsolete step cancels
outstanding work. No physical clicks/dragging are performed by the agent.

## Acceptance before native rollout

- Full paragraph coverage under wrapping, resizing and multi-display coordinates.
- Regions do not cover unrelated content; labels avoid target and other labels.
- All five tints on light/dark and accessibility modes; thin readable boundaries.
- Grouped source/route/destination updates are atomic; changed scene hides all.
- Failed/cancelled drop never advances. Success needs app-specific evidence from
  the general observation contract, not runtime rules tied to the demo document.
- Live region/step accuracy and cost/latency measured separately from DOM tests.
- Keep manual design acceptance before native region/observation implementation.
