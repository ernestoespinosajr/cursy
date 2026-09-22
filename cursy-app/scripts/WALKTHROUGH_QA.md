# Walkthrough and step verification acceptance

Status: implementation under validation; tsk009/010 are NOT complete.
Live baseline on2026-09-21 FAILED:7 false advances/60 negatives,20/20 positives.
The hardened prompt was evaluated in a second authorized batch and FAILED too:
2 false advances/60 negatives,20/20 positives. Six of seven exact regressions were
rejected; a foreign workspace still passed, plus a new documentary-example failure.
See `guide-verification-candidate-v2-2026-09-21.json`. Do not declare automatic
progression accepted. Source/scope attribution needs further investigation.
The third structured-evidence batch also FAILED:2 false advances/60 negatives,
15/20 positives. See `guide-verification-candidate-v3-2026-09-22.json` and the
diagnostic limits below. All240 authorized calls have been consumed.
This development checkpoint is being committed to dev at the user's request;
it does not close either ticket or approve automatic progression.
No deployed Worker change or new provider. macOS 14.2 / existing
Swift language mode retained. The signed app has not been rebuilt/run by this turn:
the Xcode computer-use request timed out. Never substitute terminal xcodebuild.

## User experience

1. In Home, write a request or use the latest conversation request, then choose
   **Guiarme paso a paso**. The planner cannot capture a screen. Review goal/count,
   press **Empezar**, and perform the action yourself. Only the current step is shown.
2. **Listo** confirms manually. **Pausar**, **Reanudar**, **Terminar** act on the
   whole guide; no per-shape controls. A draft message can revise unfinished steps.
3. Screen sharing remains a separate existing permission. **Verificar mis pasos
   en pantalla** asks for a separate following lease. Screenshots are sent to the
   existing provider, not stored locally. Hide sensitive information first.
4. Following is visible in Home's header, including compact/settings states. Hiding
   Home pauses it. Voice/new questions, chat switches, sleep/lock and opt-out pause.
5. Completion congratulates the user, optionally introduces the next step. No
   completion is inferred from retiring a mark, a click, or the assistant's text.

## Persistence independent of tsk008

Temporary is default. **Guardar guía** explicitly opts one guide into local storage
until deletion. `Application Support/Cursy/Guides/<UUID>.json`: version 1, max20 files,
max1MB each, private directory/file modes. Saves goal, steps, confirmations, IDs and
bounded per-step verification usage;
never screen images, coordinates, audio, running operations, or consent. No app-level
encryption claim. Corrupt/future checkpoints are preserved and reported, not replaced.
Reopen binds to a fresh temporary Home chat and always restores paused. User must
re-enable following. Delete cancels current guide and blocks late write resurrection;
OS backups/forensic erasure are outside the guarantee. Conversation persistence,
search/archive and full chat history remain tsk008.

## Runtime invariants

- One guide/operation active, <=20 bounded steps; model normally emits1–5 concise
  steps to fit the existing1024-token conversation response budget. A truncated or
  malformed response fails rather than creating guessed steps.
- Step token binds guide/conversation/step/revision. Pause, correction, step change
  and restore revoke old results. Completed steps and original goal survive revisions.
- Up to3 marks resolve from one current capture. A drag route joins independently
  validated source/destination. Missing group member means no group. No verified
  region means precise cursor fallback, not a fabricated paragraph extent.
- Pointer-display capture uses the existing single-flight capture slot. Before
  publication/advance, recheck ownership, permissions, scene revision and pixels.
- Following:300s lease, local loop <=1Hz; remote calls >=3s apart, <=10/step and
  <=30/guide (includes automatic locator calls). User-triggered plan/correction/manual
  localization is distinct from following and may make additional calls. Renewing a
  lease or reopening a saved guide does not replenish spent step/guide quota. For
  saved guides the debit reaches disk before remote dispatch; failed saves stop the
  operation. Temporary guides retain counts only in memory. Exhaustion pauses, no silent retry.
- Secure input/secure focused fields suppress observation. Semantic identification
  of every sensitive page is not claimed. User must hide private content before consent.
- Existing localization provider is unchanged. No local OCR, clipboard, synthetic
  input, tools, automatic clicks or newly deployed endpoints.

### Structured verification candidate (implemented2026-09-21; live gate failed2026-09-22)

`confirmed` now requires versioned evidence bound to the exact step criterion:
expected target/scope, both observed sources/states/regions, and no contradictions.
Missing, unknown, foreign, documentary or non-transitional evidence becomes uncertain.
The existing two-image request also carries bounded captured-window metadata as data,
not instructions. No extra request or provider change is introduced.

Before advancing, the client checks region bounds, window membership/occlusion when
OS metadata exists, and a meaningful pixel change in the target crops themselves.
It rechecks OS window identity/owner/frame/visibility after the provider returns.
No window metadata means image-only validation, not native identity attestation.
ModelClient and Coordinator both enforce the gate; injected bare confirmations fail.
Evidence boxes, observations and window metadata are transient; checkpoints are unchanged.

These vetoes are not independent semantic recognition: a model can still invent a
consistent identity or choose the wrong changed crop. Small/color-only changes may
also be rejected by the grayscale threshold; uncertain falls back to user confirmation.
Authored JSON + synthetic pixel tests are not proof that the model reads the two
failed screenshots correctly. The third live batch below failed. Any future authorized
batch must measure both false advances and retained positives, including moved/resized
surfaces and unknown scope; do not infer correctness from the offline suite.
Final offline run:271 tests/34 suites pass in1.693s; artifacts
`/private/tmp/cursy-native-regression.Rkn64T`. No live API requests were made during
that implementation phase; the separately authorized third batch is documented below.

## Offline evidence and commands

`bash cursy-app/scripts/test-native-regressions.sh` compiles app sources except the
Sparkle entry and runs Swift Testing. It is NOT signed Build/Run or physical QA.
Tests include session/correction/late-result isolation,100 serialized checkpoint
reopens, corrupt/stale/deleted-file handling, mocked transport, synthetic coordinator
decisions, multi-display group geometry and lease quotas. Sixty parametrized negative
ownership cases are NOT sixty model-perception trials.
Non-cooperative cancelled observations cannot pause replacement guides; revoking
observation during sleep/capture/localization/verification pauses only the current
owner and prevents subsequent capture. Checkpoint usage rejects invalid counts and
same-revision writes that would replenish quota; restoring never restores a lease.

Prepare provider fixtures without network or credentials:

```
bash cursy-app/scripts/evaluate-guide-verification.sh NATIVE_TEST_ARTIFACT_DIRECTORY EXISTING_OUTPUT_DIRECTORY
```

After explicit approval for up to80 paid provider calls, add
`--live-80-authorized`. Existing internal credentials are used, never printed.
Four synthetic families cover settings, file destination, draft preview and list
filter.60 negatives include unchanged state, hover, other workspace, stale preview,
failure, permissions, tips, injection text, button labels, drag ghosts and occlusion;
20 positives vary appearance/noise. This deliberately simple synthetic gate must be
supplemented by three real guide flows; it is not universal screen accuracy.
Results contain only case ID, expected class, outcome and latency. Fail-fast on
transport errors; no automatic retries. Require0 false advances and >=18/20 positives.

The first authorized80 calls are exhausted. Do not rerun live without additional
explicit authorization. Full baseline and evaluated/candidate hashes are recorded
in `guide-verification-baseline-2026-09-21.json`. Request p50=1.153s/p95=1.662s;
not end-to-end guide latency. Exact billing/token usage is not returned by this route.
The baseline has72 unique image pairs (12 unique positives); later evaluation must
include distinct positive variations and unseen negatives as well as the7 regressions.

Second batch used `--candidate-v2` with80 unique pairs/20 unique positives, retaining
the7 regressions exactly. Its80 additional authorized calls are also exhausted.
The runner refuses a live directory with existing results and exits cleanly on a
failed gate. p50=1.369s/p95=1.820s; first call includes137.317s of Keychain approval
wait, remaining maximum13.965s. Synthetic request timings do not close hardware QA.

Third authorized batch (2026-09-22) used the structured-evidence candidate and the
exact same80 image pairs as v2. Failed:2/60 false advances (hover/historical reference),
15/20 positives confirmed. Both v2 failures were rejected, but two other negatives
regressed; no overall improvement. Report: `guide-verification-candidate-v3-2026-09-22.json`.
All80 additional calls are consumed (240 total across authorizations), no retries.
p50=1.309s/p95=7.632s; first16.349s sample includes Keychain approval. Runner records
only final decisions, not raw output/local rejection reasons: diagnose that separation
before another paid trial. No further calls are authorized. No native signed build.

## Remaining acceptance gates (do not check without evidence)

- [ ] Signed Xcode Build/Run; actual Home layout, keyboard/VoiceOver, reduced motion,
  reduced transparency and two-monitor placement.
- [ ] Three distinct user-accepted flows of >=3 steps: settings, file organization,
  form/draft. Preserve goal across app changes; no automatic action.
- [ ] Save/reopen/delete an explicitly opted-in guide; temporary guide leaves no file.
- [ ] Real model evaluation:60 negatives with0 false advances and >=90% of clear
  positives detected; uncertain cases ask for confirmation. Three live synthetic batches
  failed; structured evidence alone has not met the quality gate.
- [ ] Real following cancellation on screen permission revocation, sleep/lock,
  hide, PTT and chat change; no stale marks/publication after async provider returns.
- [ ] Hardware measurements: local cancellation<=250ms;30 interactions for change
  to decision p50/p95 (target p95<=5s), actual call count/cost. Fake clock tests are
  not a performance benchmark.

## Rollback

Do not start a guide, or terminate the active one; ordinary question/answer stays
available. Do not delete saved files to roll back. Following off keeps manual steps.
No feature enables at app startup, no resumed guide starts observation automatically.
