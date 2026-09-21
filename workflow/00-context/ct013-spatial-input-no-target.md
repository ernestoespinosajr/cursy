# ct013 — Spatial input visible, localization returns no target

Date: 2026-09-19
Status: diagnosis; runtime unchanged
Related task: tsk006 (in progress); tsk005 acceptance remains separate

## Request and evidence

User reports that the spatial trail works but Cursy says it could not highlight
the indicated target safely and asks for a description. This is a failed beta
acceptance case, not evidence that the user must phrase the request differently.

Read the logbook, dependencies, tsk006 execution record, spatial recorder/packet,
manager capture/localization callbacks, Realtime tool continuation, detector and
PointingDiagnostics. Used CCE Ask and Write Swift for read-only diagnosis.

Read macOS unified logs for subsystem com.hellocursy.Cursy, last 30 minutes.
Sandbox blocked the initial command; authorized read-only escalation succeeded.
Recent attempts at 12:16–12:18 local time show:

- Three display-2 captures at 1920x1080, each with three visible windows; Realtime
  classified the request as ambiguous but DID invoke the independent locator.
- Each returned providerNoTarget. GenericPointingPipeline emits this when the
  locator returns nil, before coordinate/freshness/publication validation.
- A fourth attempt began on display 1, was rejected as staleTurn, then refreshed
  to display 2 and also returned providerNoTarget. No point was published.
- These are recent candidate attempts; exact spoken request, images and trace
  delivery are not retained, so correlation to the user's exact utterance and
  semantic cause cannot be proven retrospectively.

## Verified code gaps versus hypotheses

Verified: Realtime receives only Bool from the manager's localization callback.
All false results become validation_failed and the instruction to say the target
could not be highlighted safely. Its log also says local validation rejected the
point even for providerNoTarget. User-facing explanation collapses distinct causes.

Verified: the recorder can omit a visible earlier trail at final attach for
expiry, missing samples, geometry or region change. It has no content-free delivery
diagnostics. Prompt-budget omission is another possible path. Consequently the
current logs cannot prove that the spatial packet reached either model.

Verified: a refreshed scene intentionally has no old path. The fourth attempt
therefore needs explicit handling of lost deictic evidence, not guessed reuse.

Verified scope mismatch to evaluate: the detector prompt permits only a visible
UI element and returns null if no visual indication is requested; spatial QA also
includes image/diagram details and explanatory requests. This may exclude intended
spatial uses, but the user's actual wording/target in these attempts is unknown.

Not established: incorrect screen selection, coordinate conversion defect, provider
incapability, actual trace omission, or incorrect user gesture. Do not assert these
as root causes. A visible trail alone does not prove model delivery.

## Recommended refinement within tsk006

Complexity 5/10: native lifecycle 5, typed model outcome integration 5,
regression/evaluation 6, rollout 2 (no deployment presumed).

1. Add bounded content-free diagnostics for recorded/attached/omitted paths and
   omission reasons, capture/turn identity, sample count and prompt delivery. Do
   not log points, image pixels, screen text or transcripts.
2. Preserve typed localization outcomes through manager and Realtime so no target,
   missing spatial evidence, scene change and invalid geometry are not conflated.
3. Reproduce with general synthetic button, image detail and diagram fixtures,
   testing evidence delivery separately from semantic interpretation. Real model
   evaluation requires authorization for cost; no private screenshot uploads.
4. Refine semantic handling only after identifying the failing boundary; support
   explanatory spatial requests without forcing every gesture into UI pointing.
   Keep fresh-image and geometry validation, no OCR or app-specific rules.

Alternatives: instrumentation/outcome separation first (recommended); change
prompts blindly (insufficient evidence); remove validations (reject, unsafe).

Owner: cce-mobile with write-swift; cce-ai-engineer for semantic evaluation.
Available capabilities: local source/log reads, Swift regression runner, optional
authorized provider evaluation. No UI capture or provider request performed.
No new formal task: refine the existing tsk006 rather than duplicating it.

Next: `$cce-quick-feature Refina tsk006 con el diagnóstico ct013: trazabilidad
espacial sin contenido privado, resultados tipados y evaluación general antes de
cambiar la interpretación. Conserva las validaciones y los gates pendientes.`
