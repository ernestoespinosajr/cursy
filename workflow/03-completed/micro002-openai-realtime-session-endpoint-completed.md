# OpenAI Realtime session endpoint

- **ID:** micro002-openai-realtime-session-endpoint
- **Status:** completed
- **Created:** 2026-09-18
- **Related context:** `ct001-capability-roadmap`

## Request

Implement the first four backend steps for OpenAI Realtime: create a protected
ephemeral-session endpoint, validate and test it locally, deploy the Worker, and
capture its public URL before starting the macOS audio integration.

## Scope

- Add `POST /openai/realtime/session` to `cursy-proxy`.
- Request a short-lived Realtime client secret from OpenAI using the server-side
  `OPENAI_API_KEY`.
- Require an internal bearer token so the public Worker cannot mint sessions for
  arbitrary callers during development.
- Return stable JSON errors without leaking credentials or upstream bodies.
- Validate locally, deploy, and smoke-test the public endpoint.
- Do not modify the Swift app or its audio pipeline.

## Approach

Use the official `POST /v1/realtime/client_secrets` endpoint with a server-owned
session configuration for `gpt-realtime`. Forward the successful JSON response
without logging it and use `Cache-Control: no-store`. Keep both the OpenAI key
and the internal development bearer token as Worker secrets.

## Affected areas

- `cursy-app/worker/src/index.ts`
- `.gitignore`
- Cloudflare Worker `cursy-proxy`
- `workflow/logbook.md`

## Acceptance criteria

- [x] Unauthorized requests receive `401` and never call OpenAI.
- [x] Authorized requests call OpenAI's Realtime client-secret endpoint.
- [x] Upstream failures return stable, non-sensitive JSON.
- [x] Local TypeScript and Wrangler validation pass.
- [x] Local smoke tests cover method, authorization, and successful schema.
- [x] Worker deploy succeeds and its public URL is recorded.
- [x] Public smoke test verifies authorization and successful session creation
      without printing the ephemeral credential.

## Execution log

- Verified against the official OpenAI API reference that
  `POST /v1/realtime/client_secrets` returns `value`, `expires_at`, and a session,
  and is intended to avoid exposing the main API key to a client application.
- Added constant-time bearer-token verification, a 60-second OpenAI client-secret
  TTL, fixed server-owned `gpt-realtime` configuration, `no-store` responses, and
  stable error bodies.
- Updated Wrangler from 3.x to 4.135.0; `npm audit` reports zero vulnerabilities.
- Local tests returned `405` for GET, `401` for an unauthorized POST, and `200`
  with the expected ephemeral-secret schema for an authorized POST.
- Uploaded a fresh `CURSY_INTERNAL_API_TOKEN` as a Cloudflare secret.
- Enabled the stable workers.dev route and disabled per-deployment preview URLs.
- Deployed final version `94e52d18-8c28-4cab-b4a0-b255f633593c` at
  `https://cursy-proxy.ernestoespinosajr.workers.dev`.
- Public smoke tests returned `405`, `401`, and `200` respectively and confirmed
  `gpt-realtime` without printing the ephemeral credential.
- Removed all temporary local token and response files after validation. The
  production bearer token remains only as an encrypted Cloudflare secret and
  should be rotated when the Swift client authentication flow is implemented.
