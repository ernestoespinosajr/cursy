# ct010 — Evaluate localization providers before promoting a replacement

- Date: 2026-09-18. Related: tsk002, ct009, ct006.
- User first requested deeper investigation of wrong internal-element points,
  then authorized considering Claude and DeepSeek alongside OpenAI and supplied
  their credentials in the ignored Worker local environment file.
- Skills: CCE Ask for diagnosis; CCE AI Engineer and Backend for evaluation and
  the prepared adapter; Write Swift for immutable request context and native tests.
  Evaluation initially prepared local changes only. User subsequently authorized
  Worker deployment; remote smoke passed. User then accepted the native result;
  tsk002 is completed (see closure note below).

## Verified findings

- Last supplied test: at 22:23:34 the locator returned (201,611) in an 1188×768
  raster, accepted by local geometry checks. Mapping to the supplied 1979×1280
  attachment predicts approximately (344,1032), matching the wrong indicator.
  This confirms the published wrong point came from the locator. The actual
  model-input screenshot and literal conversation are not stored.
- A distinct attempt at 22:23:21 was rejected for captureMismatch. Asking a model
  to echo immutable capture metadata introduces avoidable failure. Bind that
  metadata in application code; do not remove freshness/cancellation validation.
- Production path at the start of this audit permitted GPT-4.1/mini only, via Chat Completions and
  `detail: high` (worker/src/vision.ts). The full capture is reduced from
  1728×1117 to 1188×768 by VisionLocalizationImage for localization. This reduces
  detail; it is not evidence of a downstream double-scale or Y-flip bug.
- `selectedVisionModel` also controls mandatory Realtime generic localization,
  although the UI calls it the fallback model. Voice and locator configuration
  should be independent. A preferences read found no stored override in the
  current bundle domain; source default is GPT-4.1, not proof of live selection.
- The HEAD detector declared Claude `computer_20251124` and parsed tool_use
  coordinates, but HEAD CompanionManager did not call it. The base manager used
  textual POINT tags. Do not claim a proven working Computer Use integration was
  replaced merely by changing a model name.
- Locator prompts mix screenshot pixels, AppKit display points and normalized
  metadata. They pass a target label but not explicitly the selected window ID
  in the request; agreement is checked afterward. These are integration risks,
  not established explanations for every inaccurate candidate.
- Generic validation establishes current display/window/z-order, not the identity
  of the requested element at the returned coordinate. Test plumbing success is
  not a model-accuracy score.

## Official documentation checked

- [OpenAI image detail](https://developers.openai.com/api/docs/guides/images-vision):
  precise-coordinate inputs should use original detail when supported. GPT-4.1
  remains tile-based; GPT-4.1 mini does not support original. Spatial localization
  remains a stated limitation. A different integration/model must be evaluated.
- [OpenAI computer integration](https://developers.openai.com/api/docs/guides/tools-computer-use-integration):
  recommends original-detail screenshots and explicit resize transforms; custom
  UI function tools are supported. The built-in computer tool is not mandatory.
- [Claude computer tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool):
  current computer_toolset_20260801 exposes member calls, per-member disabling
  and screenshot-pixel coordinates. Earlier computer_20251124 remains available.
  Model choice and image resolution affect precision; bigger is not automatically
  better for clicking. We only interpret proposed coordinates, never execute input.
- [Claude model lineup](https://platform.claude.com/docs/en/models/overview):
  Sonnet 5 and Opus 5 are initial comparison candidates; Fable 5.1 is an escalation
  option, not an assumed winner for single-element localization.
- [DeepSeek vision](https://api-docs.deepseek.com/guides/vision/): deepseek-flash
  currently accepts images. API format compatibility does not itself prove
  Computer Use tool compatibility or localization accuracy.

## Bounded comparison

Use an isolated, offline-by-default script, not a production provider switch.
Fixture input contains a local image, exact dimensions, a requested element and
a predeclared normalized acceptance rectangle (or null for absent targets).
Do not check private images, labels, utterances or credentials into the repository.
Output only anonymous case IDs, model IDs, numeric positions, status, latency and
token counts. Do not print raw provider bodies or error messages.

Initial matrix: GPT-4.1 baseline, current OpenAI GPT-5.6 Sol, Claude Sonnet 5
Computer Use and DeepSeek Flash; four cases each (16 bounded requests, no retries).
Compare the same prepared image first, then repeat promising candidates and
evaluate resolution/region changes separately. Include Opus 5 if Sonnet falls
short. Never silently replace unavailable model IDs. A single positive result
does not establish a production winner.

The attachment is a QA fixture, not the saved runtime image. It contains an
assistant annotation absent from the intended capture policy; instructions must
ignore annotations and select the actual interactive element. Do not confuse this
controlled comparison with replaying the full voice/capture/window-validation loop.

## Route and constraints

Complexity 6/10: technical 5, integration 6, evaluation 6, rollout 4.
CCE AI Engineer owns model evaluation; CCE Backend owns provider adapters;
Write Swift accompanies eventual native routing changes. Available tools are
source/git/log inspection, Node mock tests, Swift image preparation and public
official documentation. Credentials are used only for the requested comparison.

Recommended: evaluate candidates, then refine existing tsk002 with independent
locator selection, one coordinate convention, caller-owned capture metadata and
the measured winning provider. Alternative: retain OpenAI with a newer supported
model and improved input contract if it wins. Do not add all providers to the live
app simply because keys are available. Preserve native AX targets, voice, cursor,
multimonitor checks, no OCR, no app-specific behavior and no clicks/typing.

Ready-to-run planning prompt: `$cce-quick-feature Refina tsk002 con ct010 y los
resultados medidos: separa voz y localización, integra el proveedor ganador con
contrato de coordenadas explícito y metadatos ligados localmente; sin OCR,
excepciones por aplicación ni ejecución de acciones.`

Worker activation was subsequently authorized and completed (see deployment
evidence below); user acceptance followed. Adding keys to
.dev.vars configures local development only, not deployed Worker secrets.

## Executed comparison and decision

All live comparisons used the same user-provided attachment prepared through the
production raster helper at 1188×768. Acceptance rectangles were fixed before calls.
case-01 is the reported row; case-02 a search field; case-03 a navigation control;
case-04 an absent element. The label/contact is private fixture data, not a runtime
rule or repository artifact. Outputs retained here are aggregated/content-free.

| Model/adapter | Resolved cases | Median request time | Result |
|---|---:|---:|---|
| GPT-4.1 / Chat Completions high | 1/4 | 833 ms | All three visible targets missed; absent target rejected correctly |
| GPT-5.6 Sol / Responses original + strict function | 8/8, two rounds | 2634 ms | No observed failure |
| GPT-6 Astra / Responses original + strict function | 12/12, three rounds | 1944 ms | No observed failure |
| Claude Sonnet 5 / Computer Use mouse_move, never executed | 12/12, three rounds | 1651 ms | No observed failure; additional initial case-01 smoke also passed |
| Claude Opus 5 / same Computer Use adapter | 3/4 | — | Three visible hits; absent-case response rejected by strict parser, not a false published point |
| DeepSeek Flash / image + JSON | 3/4 | 2766 ms | Missed case-01; other two visible targets and absent case passed |

Claude initially returned four HTTP400s. One synthetic 1×1 diagnostic identified
insufficient prepaid credit, not a schema failure. Those calls do not count toward
accuracy. User replenished credit and explicitly authorized the private attachment
upload; subsequent Sonnet/Opus calls used the original documented schema successfully.

These are repeated cases on ONE screenshot, not independent samples across apps,
monitors or scroll positions, nor a replay of the literal runtime conversation.
100% here is NOT a guarantee of future accuracy. User's new quality requirement:
exclude observed failing configurations from coordinate selection; do not trade
pointing correctness for lower price. Never call any model infallible. Current
geometry/freshness checks do not establish semantic identity of an internal item.

Selected and subsequently deployed candidate: Astra, separate from voice/conversational fallback,
using Responses original detail and a forced record-only function. Sonnet also
qualifies for broader evaluation; it is NOT yet wired to the production contract.
DeepSeek and GPT-4.1 are excluded from the new localization allowlist. GPT-4.1/mini
remain conversational fallback only. No automatic provider/model substitution.
Provider-specific request/response logic remains in the Worker for future swaps.

Price check (2026-09-18, standard uncached tokens):
[Astra](https://developers.openai.com/api/docs/models/gpt-6-astra) $10/$50 per
million input/output tokens;
[Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol) $4/$20;
[Sonnet](https://platform.claude.com/docs/en/about-claude/pricing) $2/$10.
Using measured token counts, estimated mean cost per evaluated request was about
$0.0152 Astra, $0.0071 Sol and $0.0071 Sonnet (not complete voice-turn cost, bill,
tax or production estimate). Tool overhead/tokenization differ; cheapest token
price alone is not cheapest successful task. Precision remains the admission gate.

## Integration evidence and remaining gate

- Added offline-default evaluator plus 11 passing tests. No image, provider body,
  transcript or credential persisted in the repo; private fixture stays in temp.
- VisionAPI purpose + independent manager client routes all three localization
  sites (Realtime, fallback, silent refresh) to Astra. The fallback picker no
  longer changes pointing model. Realtime voice and native AX targets unchanged.
- Worker allows localization only for Astra/Sol, one image and nonstream output.
  Strict function response is validated and normalized; unexpected/multiple tools,
  incomplete/malformed responses, oversized bodies and provider failures reject.
  Computer actions never execute. Initial integration did not provision secrets
  or deploy; the separately authorized deployment is recorded below.
- Detector binds captureID/dimensions from the immutable request's prepared raster,
  not generated echoes. Current Realtime selected window is explicit in locator
  input. Existing cancellation, stale capture, window identity, bounds and scene
  checks remain; no coordinate offset patch or extra scale conversion.
- Worker: 14/14 mock tests pass, Wrangler dry-run bundle passes. Live calls through
  the actual new handleVision adapter (controlled fixture prompt, not native UI)
  return HTTP200 and correct points/null in all four cases: 3410/2695/2308/1703 ms.
- Native module/library compiles via swiftc (excluding only Sparkle entry point);
  65 tests/11 suites pass in 0.700 s, including independent transport selection,
  caller-owned metadata and delayed old-capture/cancelled response rejection.
  No xcodebuild, app launch, microphone, live desktop capture or Keychain use.
- User subsequently accepted the real app result after deployment and requested
  closure; tsk002 is completed. This is explicit user acceptance, not an agent-run
  matrix of every control, absent/ambiguous item, monitor, language or AirPods route.
  Keep these as regression coverage for future changes and release qualification.

## Authorized deployment evidence

User explicitly requested «despliega». CCE Backend/Dispatch verified contracts and
secret names, preserved remote values with --keep-vars, deployed and checked live
routes using only a generated 256×256 image. No private screenshots were resent.
The internal bearer was retrieved from its existing Keychain item into process
memory only; no token, provider response or ephemeral secret was logged or saved.

- Initial version 511129ab-802b-41ad-80dc-c0bf477ca2ce uploaded, but both vision
  paths returned502. Immediately rolled back to da28d78e-f2f9-49a3-9ffd-a124763c8dac
  and verified legacy vision200. Voice mint/auth already passed.
- Actual workerd reproduced a Request-construction failure: redirect:error is
  unsupported in this runtime. Node tests had not detected it. Changed to manual
  redirects; existing non-OK checks reject3xx without following or leaking bodies.
  No compatibility-date expansion, auth bypass or provider/model substitution.
- Added bundled-handler workerd regression with synthetic bindings and mocked
  upstream. npm test now runs both suites:19/19 pass, including auth-before-forward,
  legacy Chat Completions, Astra Responses/original and fail-closed redirect.
- Corrected version **107dd830-4209-4525-aaac-c2075acb310a** deployed successfully.
  Remote smoke10/10: vision/realtime unauthorized401; invalid localizer/stream400;
  Astra present target200 inside declared rectangle (2018 ms); absent target200
  with null (2090 ms); legacy vision200 in text and SSE; Realtime mint200 with
  no-store; retired chat410. No real microphone/capture/overlay test performed.
- Secrets unchanged; native source/build not changed during deployment. This
  proves endpoint availability and contracts, not universal pointing accuracy.

## User acceptance and closure — 2026-09-18

After deployment the user reported «excelente, funciona a la perfección» and asked
to save lessons and close the ticket. Accepted internal delivery, no remaining
implementation blocker identified for this scope. tsk002 moved to
`workflow/03-completed/tsk002-realtime-screen-pointing-completed.md`.
Separate session-core acceptance (tsk003), public-release hardening and exhaustive
cross-application QA are not implied completed. No new tests/provider calls or
application changes were made during this documentation-only closure.
