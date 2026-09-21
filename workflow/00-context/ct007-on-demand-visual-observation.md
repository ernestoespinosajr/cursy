# ct007 — On-demand visual observation after screen changes

Date: 2026-09-18
Status: research only; runtime unchanged
Related: tsk002, tsk003, ct006

## Request and evidence

User reports initial pointing succeeds but loses the target after scrolling;
requests research into OpenAI/Claude Computer Use and Chrome DevTools approaches.
Concrete applications/contacts remain QA examples, never product rules.

- `OpenAIRealtimeVoiceClient.finishInputAndRequestResponse` calls
  `captureVisualContext` for each finished push-to-talk request and attaches the
  resulting image. It is not a single screenshot reused for the entire conversation.
- `CompanionManager` binds capture identity to the active turn; independent visual
  localization uses that same captured image.
- `ScreenWindowGrounding` checks current window identity, frame, z-order, display
  and point containment. `VisualTurnContext` checks age and capture identity.
  These do not establish content freshness after scrolling within an unchanged
  window. The overlay target is not currently tracked across such changes.
- Inference: scroll during analysis or after pointing can stale the coordinates.
  If the user scrolls BEFORE a new completed PTT request, another image is already
  captured; a failure then needs correlated capture/model/rejection evidence and
  cannot automatically be attributed to screenshot reuse. No new runtime trace
  was supplied for this particular test.

## Official research

- [OpenAI Computer Use](https://developers.openai.com/api/docs/guides/tools-computer-use):
  the application executes tool requests and returns updated screenshots;
  observation repeats throughout the task. It documents resolution/coordinate
  mapping, preserving environment state, and bounded/cancellable execution.
- [Claude Computer Use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool):
  client-owned agent loop returns tool results, including fresh screenshots;
  screenshot/zoom can inspect updated state and small targets. The model has no
  direct connection to the desktop merely because the OS permission exists.
- [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md):
  latest accessibility-tree snapshot exposes element UIDs, alongside screenshot
  tools. This structured browser mechanism is not a universal native-app adapter.
- [OpenAI Realtime image inputs](https://developers.openai.com/api/docs/guides/realtime-conversations):
  images can be attached to user messages. Sending further images is possible;
  implementing a safe observation/reasoning loop remains the application's job.

These are documented integrations, not claims about proprietary ChatGPT or Claude
consumer-app internals. Official OpenAI docs MCP is configured but unavailable to
this tool session; official web documentation used as fallback.

## Alternatives and recommendation

1. Keep one screenshot per request: smallest cost, but cannot recover from changes
   during reasoning or keep an existing marker aligned after a scroll.
2. Recommended: bounded on-demand visual observation during a guidance request.
   Preserve semantic target, observe the authorized display/window, invalidate
   pending results and hide stale markers when the scene changes, wait for a short
   stable interval, recapture and ask the provider to locate again. Check the scene
   version immediately before publishing. Allow a provider-requested fresh view or
   zoom for uncertain/small targets. Limit retries, duration and spend; stop on
   cancellation, sharing disabled, new request, or expiry. No automatic UI actions.
3. Persistent supervised walkthrough: maintain observation across user actions and
   multiple steps. Useful later, but requires explicit session controls, lifecycle,
   privacy/cost policy and step verification beyond this focused refinement.

Proposed stability interval/retry limits require measurement, not vendor-mandated
constants. Local event/frame-change signals may mark a scene dirty without reading
its text; they must exclude Cursy's own overlay and avoid irrelevant animations
causing endless retries. OpenAI owns semantic interpretation; no local OCR.
Repeated images improve freshness but do not guarantee perception/localization.

## Reuse, scope and risks

Reuse VisualCaptureRequest, capture IDs, VisualTurnContext, GenericPointingPipeline,
provider-neutral VisionAPI, session cancellation and existing geometry checks.
Likely affected: capture utility, CompanionManager, Realtime voice client, visual
turn/session contracts, pointing pipeline/overlay invalidation, tests.
No need to replace accepted voice/cursor UI or introduce application-specific rules.

Risks: out-of-order model responses, target disappearance, monitor migration,
animated content, screen-sharing consent, extra latency/cost, stale voice claims.
Validation must cover scrolling during requests and after pointing, fresh second
requests, target offscreen, two monitors, moved windows, concurrent/new turns,
cancel/sharing-off and retry exhaustion. Test buttons/files/settings/list rows,
not only the reported chat. Keep separate live-provider and deterministic evidence.

Complexity: 6/10 for bounded per-request observation; persistent walkthrough would
be a separate higher-complexity feature. Refine existing tsk002, do not duplicate it.
Routing: cce-quick-feature → cce-dispatch + cce-mobile/write-swift;
cce-ai-engineer for model tool orchestration/evaluation. No delegation authorized.
Tools: source inspection, official docs, Swift/native deterministic checks; live
Xcode QA for scrolling and monitor routing. Never terminal xcodebuild.

Ready prompt:

`$cce-quick-feature Refina tsk002 usando ct007: ciclo visual bajo demanda con
recaptura tras cambios, invalidación de coordenadas antiguas, identidad de escena,
relocalización con OpenAI y límites/cancelación; sin OCR, sin acciones automáticas
y sin reglas específicas por aplicación. Define pruebas generales y aceptación
en dos monitores antes de implementar.`
