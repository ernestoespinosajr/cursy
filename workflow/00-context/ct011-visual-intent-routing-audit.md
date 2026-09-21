# ct011 — Visual intent and window routing audit

Date: 2026-09-18
Status: analysis only; no runtime changes or deployment
Related: accepted tsk002, in-progress tsk003, ct006, ct008, ct010

## Request and product criterion

Investigate a natural-language request to locate a named app that resulted in
an irrelevant clarification and a claim that the target was absent. Treat this
as a Cursy product failure, not a requirement for the user to know model/tool
terminology. Interpret ordinary language against current visual context before
requesting clarification. Genuine ambiguity still warrants a concise question;
never promise universal understanding or manufacture a point.

App names in user QA are fixtures only. All fixes must generalize to applications,
windows, files, controls, tabs and list items. No local OCR or app-specific rules.

## Evidence and limits

Inspected repository logbook/dependencies, current capture, Realtime tool routing,
manager, locator, provider contract and generic pointing pipeline. Queried macOS
unified logs for Cursy's subsystem, then narrowed to process Cursy and local time
23:28:00–23:30:00. This excludes regression-tests sharing that subsystem.

Observed process 63311:

| Local time | Confirmed event |
|---|---|
| 23:28:25 | Display 1 captured at 1728×1117; 359620 JPEG bytes; 8 window records; transcription completion retained |
| 23:28:35 | `providerNoTarget`, expectedWindow=6197; generic locator returned no target |
| 23:28:40 | Two bounded scene refreshes; observation cancelled and pending candidate rejected as staleTurn |
| 23:28:44 | Fresh display-1 capture, same dimensions, 359888 bytes, 8 windows; transcription retained |
| 23:28:52 | Again providerNoTarget with expectedWindow=6197; Realtime reports point rejected |
| 23:29:08 | Fresh display-1 capture, same dimensions, 358753 bytes, 8 windows; transcription retained |
| 23:29:14 | After one refresh, Realtime resolves `target_missing`, explicitly `locatorInvoked=false`; observation ends noTarget |

The expected window's AppKit frame is (173,127,1172,900) on a 1728×1117
display. Its top-left image bounds are (173,90,1172,900), matching the foreground
Xcode window's proportions in the user attachment. **Inference:** the locator was
restricted to Xcode rather than the requested, partially visible background app.
The log does not retain the window-ID-to-app mapping, so this is not an exact
historical identity lookup. The user attachment is evidence of visibility at its
own capture time, not a saved copy of the provider's image.

No literal input transcripts, spoken replies, tool labels, screenshot rasters or
complete metadata payloads are persisted by these paths. Therefore the exact
recognized name, exact per-turn words and provider-visible pixels cannot be
recovered from these logs. Do not claim a transcription error or prove its absence.
Replay counts increased 0→1→2; this supports retained user context, not proof of
complete assistant-response history or semantic understanding.

## Verified code causes / architectural gaps

- `CompanionScreenCaptureUtility.captureCursorScreen` captures the entire cursor
  display excluding Cursy itself, not a crop of the foreground window. It builds
  active-window/native and visual-window metadata and fresh JPEG context.
- `CompanionManager.onPointingTarget` passes the Realtime-selected window to
  `ElementLocationDetector.detectElementLocation(expectedWindowID:)`.
- The locator prompt explicitly restricts the search to that already selected
  window and requires null when absent there. Thus independent pixel localization
  cannot correct a wrong upstream window selection.
- `GenericPointingPipeline.run` additionally requires the refined window to equal
  the original. Its providerNoTarget branch follows a completed locator call with
  a nil result; it is not evidence of bad coordinate conversion.
- Localization is configured independently as GPT-6 Astra. Native controls use a
  different verified-ID route. No inference that Claude is the runtime provider.
- Realtime's valid no_point branch calls onVisualNoPoint and speaks a limitation
  without invoking the locator. The final logged attempt followed that branch.
- Shared instructions already prioritize an explicitly named app over focus and
  inspect visible targets first. A new hardcoded app-name instruction is not a fix.

## Reuse, affected areas and options

Reuse VisualTurnContext, ConversationSession turn ownership, bounded observation,
provider-neutral VisionAPI, structured output and native geometry/freshness checks.
Likely changes: visual decision/intent contract, Realtime routing, manager-to-locator
handoff and pipeline tests. Keep audio transport, cursor design and coordinate
transforms unchanged unless independent tests demonstrate defects.

1. Prompt-only clarification of app versus file: low cost but existing policy already
   covers named apps; does not remove the hard window restriction. Not recommended.
2. **Recommended:** separate semantic target/window resolution from final geometric
   validation. Let the qualified vision stage resolve the requested object against
   the authorized display and metadata; treat preliminary window selection as a
   hypothesis, not a binding identity. Validate the newly resolved actual window
   before publication. Explicit user scope must remain authoritative.
3. Move all visual decisions to a single qualified vision stage, retaining Realtime
   for conversation/audio. Cleaner authority but broader latency/contract changes;
   evaluate during planning rather than silently replacing the whole flow.

For option 2, a visual locate request must receive a bounded semantic review before
final target_missing/ambiguous. Preserve a structured target query even for no_point;
do not invoke localization for unrelated conversation. Correlate any required
transcription with the current turn before using it; no stale/empty request fallback.
This is not permission to remove safety checks, force a point or retry indefinitely.

## QA and observability

- Foreground app differs from explicitly requested partially visible app.
- Visible and absent targets across apps/files/buttons/tabs/list items; duplicate
  names and genuinely ambiguous requests; natural follow-ups and two monitors.
- Wrong preliminary window can be corrected; final coordinates must still belong
  to the verified window and current image. Hidden/occluded targets must not point.
- Explicit missing decision gets bounded vision review for a locate request;
  cancellation, new conversation, late transcript and scene changes stay safe.
- Test orchestration deterministically before provider evaluation. Do not treat
  successful coordinate fixtures as end-to-end intent accuracy.
- Keep content-free diagnostics for chosen-window provenance, stage and reason.
  Exact payload replay would require an explicit, temporary, user-approved capture
  diagnostic design; do not silently begin storing conversation/screenshot content.

## Complexity and route

Technical 5/10; integration 6/10; testing 6/10; rollout 4/10; overall 6/10.
Recommend `$cce-quick-feature`, with cce-ai-engineer ownership and write-swift for
native contracts/concurrency; official OpenAI documentation only if API behavior
changes. Available tools: repository shell/source/tests and read-only system logs;
no new plugin required. No external provider call, secret read, live screenshot,
build, test run or deployment performed in this audit. Only this context and the
logbook are updated. Keep tsk003 open and tsk002's historical acceptance intact.

Next prompt:

`$cce-quick-feature Planifica ct011: resolver intención y ventana mediante visión antes del señalamiento o de declarar target_missing, sin convertir la hipótesis de Realtime en una restricción irrevocable. Reutiliza proveedor, sesión y observación; conserva validación geométrica, frescura, privacidad y límites. Incluye pruebas generales, sin OCR ni reglas específicas por aplicación.`
