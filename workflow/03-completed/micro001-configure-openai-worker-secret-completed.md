# Configure OpenAI Worker secret

- **ID:** micro001-configure-openai-worker-secret
- **Status:** completed
- **Created:** 2026-09-18
- **Related context:** `ct001-capability-roadmap`

## Request

Complete the OpenAI API-key setup after the user added `OPENAI_API_KEY` to the
Worker's local `.dev.vars` file and a root-level Wrangler invocation failed to
find the Worker name.

## Scope

- Verify the local secret exists without exposing its value.
- Ensure `.dev.vars` is excluded from Git.
- Declare `OPENAI_API_KEY` in the Worker's environment contract.
- Upload the secret to the configured `cursy-proxy` Cloudflare Worker from the
  Worker directory.
- Do not add an OpenAI endpoint or modify the macOS client in this micro-task.

## Approach

Use the existing `wrangler.toml` and source the local `.dev.vars` only inside a
non-verbose shell process that pipes the value to Wrangler. Never include the
credential in commands, logs, diffs, or workflow records.

## Affected areas

- `cursy-app/worker/src/index.ts`
- Cloudflare Worker secret configuration for `cursy-proxy`
- `workflow/logbook.md`

## Acceptance criteria

- [x] Local `.dev.vars` contains a non-empty `OPENAI_API_KEY`.
- [x] `.dev.vars` is ignored by Git.
- [x] Worker `Env` declares `OPENAI_API_KEY`.
- [x] Wrangler confirms the secret was uploaded to `cursy-proxy`.
- [x] Worker TypeScript validation succeeds.

## Execution log

- Confirmed `wrangler.toml` names the Worker `cursy-proxy`.
- Confirmed the original failure was caused by invoking Wrangler from the
  repository root rather than `cursy-app/worker`.
- Confirmed the local secret exists and is ignored without reading its value.
- Added `OPENAI_API_KEY` to the Worker's typed `Env` contract.
- Ran a standalone TypeScript check for `src/index.ts`; it completed without
  diagnostics.
- The first secret upload attempt reached Wrangler but was rejected because the
  automated shell has no Cloudflare API token. Started `wrangler login` and left
  its Cloudflare authorization page open for the user; upload remains pending
  until that account login completes.
- The user completed Cloudflare OAuth and Wrangler confirmed the login.
- Wrangler found no existing remote Worker named `cursy-proxy`, created it, and
  uploaded `OPENAI_API_KEY` successfully.
- `wrangler secret list` returned exactly `OPENAI_API_KEY` as `secret_text`; no
  secret value was displayed.
