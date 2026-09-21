# ct014 — Spatial delivery succeeds; understanding and pointing remain coupled

Date: 2026-09-19
Status: investigation only; no runtime changes
Related: tsk006 in progress, ct013; tsk005 acceptance remains separate

## Request and scope

User tested pointing at text and regions of a human-body illustration and reports
no useful answer. These are general spatial-understanding QA examples, not a
request for anatomy-specific runtime rules or medical diagnosis. Investigate the
actual attempts, including the integration rather than assuming provider failure.

CCE Ask owns this analysis; CCE AI Engineer and Write Swift guide the source audit;
OpenAI Docs supplies official vision limitations. No parallel agents used.

## Evidence inspected

- Logbook, dependencies, ct013 and existing tsk006 phases/gates.
- SpatialContext, recorder integration, capture exclusions, VisualTurnContext,
  Realtime decision/continuation, manager, PointingDiagnostics, VisualObservation,
  ElementLocationDetector, VisionLocalizationImage, Worker vision adapter/tests.
- Authorized read-only unified-log query, subsystem com.hellocursy.Cursy and
  process Cursy, last 25 minutes. This excludes regression-test process output.
  Initial broader query included historical attempts and tests; not used as the
  current acceptance sample. Relevant current process: 69635, local 12:45–12:47.
- Offline Swift probe against the previously compiled ct013 production module at
  /private/tmp/cursy-native-regression.12YDcA, no API or UI operations.

## Current attempt evidence

| Local time | Capture prefix / display | Delivery | Observed outcome |
| --- | --- | --- | --- |
| 12:45:46 | 27A833CA / 1 | 89 points attached and sent to Realtime; 89 prepared for locator and response completed | Provider returned a coordinate; no publication. Scene pixel changes invalidated evidence; two refreshes removed path and observation exhausted |
| 12:46:25 | 60B9DAEA / 2 | 100 points attached and sent | pointing_not_requested, locatorInvoked=false; entered normal conversation route. Exact answer is not in these logs |
| 12:46:51 | 5FA2A8C7 / 2 | 113 points attached and sent; 113 prepared for locator and response completed | preliminary=pointing_not_requested yet locatorInvoked=true, then providerNoTarget |
| 12:47:10 | BC8F6735 / 1 | 105 points attached and sent | Transcription retained; no decision recorded before observation expired at 30 seconds. Provider response/cancellation cause not established |

For these four initial captures, loss of the packet before Realtime is ruled out
by app-side serialization/send completion, not a server acknowledgement of visual
understanding. No prompt-budget omission is recorded. Both displays were captured.
Literal speech, targetQuery, response text, screenshot pixels and path coordinates
were not retained; cannot assign the text/anatomy examples to individual rows or
assert semantic correctness of the returned coordinate.

## Verified integration problems

1. **Explanatory route remains fragile.** VisualGuidanceDecision.route returns
   conversation only for no_point + pointing_not_requested + empty targetQuery.
   A nonempty query routes the same declared intent to localization. The tool
   prompt asks for an empty query, but the runtime contract permits this mismatch.
   The 12:46:54 log proves this branch occurred. The existing test explicitly
   enforces it for locating requests; it does not cover a descriptive query.
   Offline production-module probe with the same reason and query "Explain the
   indicated region" prints `empty=false route=localize`; empty prints conversation.
   This is not proof of that private utterance, but deterministic reproduction of
   the integration gap. Do not simply trust either field or unconditionally skip
   localization: preserve qualified review for real missing/ambiguous locate requests.
2. **The downstream contract is UI-only.** Native system instructions specify
   a UI coordinate locator, visible UI elements and interactive elements, and
   explicitly return null for requests without visual indication. Worker tool
   description independently says visible UI target. It cannot return a grounded
   explanatory result: output is a point or null. Thus an explanatory request
   misrouted here can be correctly rejected under the wrong contract. This fits
   providerNoTarget, but exact private request and model rationale are unavailable.
3. **Publication controls can erase useful input context.** In the first attempt,
   scope/window 831 changed by 553, then 562, then 1059 downsampled pixels. Two
   refreshes explicitly sent sceneRefreshed with zero points. Comparison uses the
   whole target window, not the spatial evidence region. Whether changes were
   relevant, incidental animation or a visible log console is unknown. The latter
   is a risk because new SpatialInput diagnostics emit immediately, whereas
   VisualObservation intentionally buffers its diagnostics to avoid console feedback.
   Dirty observation also makes isCurrent false and is reported as staleTurn;
   this reason does not by itself prove a replaced conversational turn.

## Representation and model limits — facts versus hypotheses

Capture excludes Cursy windows and sets showsCursor=false. The remote image is
clean; the gesture arrives as JSON tuples [normalized x, y, milliseconds], not a
visible drawn trail. The model must associate those numbers with image content.
Delivery is now evidenced; comprehension of this representation is still unmeasured.
Normalized points are remapped to locator raster metadata; no coordinate conversion
defect is demonstrated. Locator still downsizes to a 768px short side; Realtime
receives the larger screenshot. Small-text fidelity is an evaluation variable,
not an established cause of this particular failure.

Official OpenAI documentation confirms that vision can describe images/read text,
but warns of small-text and precise-spatial-reasoning limitations. It recommends
original detail where supported for fine detail/coordinates; the Worker already
uses original for its prepared raster. This does not recover resolution removed
locally and does not guarantee gesture understanding. Source, fetched 2026-09-19:
https://developers.openai.com/api/docs/guides/images-vision#limitations

Unknown: literal conversation, whether each explanatory answer misunderstood a
region, why the fourth decision was absent, and whether a visual gesture encoding
improves accuracy. No claim that the model cannot reason or that a provider switch
alone resolves these integration defects.

## Recommended refinement within the existing ticket

Separate **understand the indicated content** from **publish a mark**. A reference
to a region is not itself an instruction to move the assistant cursor. Preserve
the distinction in a typed semantic contract and route explanation/description/
comparison without making successful UI localization a precondition for an answer.
Explicit marking still requires a verified location. Handle combined explain-and-
mark requests without the current unconditional one-phrase pointing confirmation
discarding the requested explanation.

- Use a qualified image+gesture interpretation step with general content scope
  (text, diagrams, objects, controls). Reuse existing capture/turn/provider boundary;
  do not invent local OCR or anatomy/app/person-specific branches.
- Define outcomes for resolved reference, genuine ambiguity, missing input and
  technical failure; include a bounded model-derived description usable by voice.
  Exact provider/Worker contract changes must be planned, not silently piggybacked
  on the point-or-null schema.
- Separate immutable evidence for understanding a submitted scene from freshness
  required to publish on the current desktop. Preserve cancellation and permission
  revocation. Never transfer old coordinates onto a changed scene. Diagnose scoped
  invalidation and console feedback before changing thresholds or retry limits.
- Evaluate clean image + tuples against an explicitly labelled visual gesture
  representation/region view, keeping original pixels and coordinate mapping.
  This is a proposed A/B experiment, NOT a verified cure. Auxiliary images would
  require adapting the current one-image locator contract and deployment approval.
- Add content-free decision/response lifecycle diagnostics to distinguish the
  fourth attempt's unobserved decision from actual semantic rejection. Exact
  private replay needs a separate explicitly consented diagnostic capture, not
  permanent transcript/screen logging.

Alternatives: (A) routing/prompt-only correction is smaller but leaves gesture
comprehension unmeasured; (B) typed understanding separate from publication plus
bounded general evaluation is recommended; (C) replacing the provider or removing
validation is not justified by current evidence.

## Validation and route

Complexity 6/10: semantics/contracts 6, native integration 5, evaluation 6,
rollout 4 if Worker changes. CCE Quick Feature should refine tsk006, no new ticket.
Execution owner: cce-ai-engineer, with write-swift for native paths and backend
specialist only if the accepted design changes the Worker.

Offline probe succeeded (exit 0). No new full regression run; the earlier 110
tests are transport/logic evidence, not provider comprehension. No runtime edits,
app launch/capture, API-key read, paid call, deployment, commit or private upload.
Available capabilities: source/log reads, native test runner, official-doc search,
authorized future provider evaluation. User still has not set the evaluation cost
ceiling. Build general fixtures before any paid A/B trial; retain original 20×3
semantic gate, no wrong publication in admission sample and ≥90% resolved unambiguous
requests. Do not request another unqualified manual retry as proof of a fix.

Next prompt: `$cce-quick-feature Refina tsk006 con ct014: separa comprensión espacial
de publicación, resuelve el conflicto de enrutamiento y el alcance UI-only, diseña
la evaluación general de imagen+gesto y conserva validaciones, privacidad y gates.`
