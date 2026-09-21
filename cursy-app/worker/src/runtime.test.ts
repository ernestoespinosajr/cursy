import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";

// Exercise the deployed runtime, not Node's more permissive Request/fetch options.
// All outbound requests terminate in this in-process mock; no credentials/files
// from the developer environment or provider network are used.
test("workerd vision integration at the deployed compatibility date", { timeout: 30_000 }, async context => {
  const configuration = await readFile(new URL("../wrangler.toml", import.meta.url), "utf8");
  const compatibilityDate = configuration.match(/^compatibility_date\s*=\s*"([^"]+)"/m)?.[1];
  assert.ok(compatibilityDate);
  const bundle = await build({
    entryPoints: [fileURLToPath(new URL("./index.ts", import.meta.url))],
    bundle: true, write: false, format: "esm", platform: "browser", target: "es2022",
  });
  const calls: { path: string; body: any }[] = [];
  let outboundRequestCount = 0;
  let redirectUpstream = false;
  const target = { x: 24, y: 17, label: "Synthetic control", intent: "other", nativeControlID: "", windowID: "window-1" };
  const runtime = new Miniflare(convertV4MiniflareOptions({
    modules: true, compatibilityDate, script: bundle.outputFiles[0].text,
    bindings: { OPENAI_API_KEY: "synthetic-provider", CURSY_INTERNAL_API_TOKEN: "synthetic-internal" },
    outboundService: async request => {
      outboundRequestCount++;
      const url = new URL(request.url);
      assert.equal(url.origin, "https://api.openai.com");
      assert.equal(request.method, "POST");
      assert.equal(request.headers.get("authorization"), "Bearer synthetic-provider");
      calls.push({ path: url.pathname, body: await request.json() });
      if (redirectUpstream) return new Response("private redirect body", {
        status: 307, headers: { location: "https://redirect-must-not-be-followed.invalid" },
      });
      if (url.pathname === "/v1/responses") return Response.json({
        status: "completed", output: [{ type: "function_call", status: "completed", name: "record_localization", arguments: JSON.stringify({ target }) }],
      });
      assert.equal(url.pathname, "/v1/chat/completions");
      return Response.json({ choices: [{ finish_reason: "stop", message: { content: "Synthetic answer" } }] });
    },
  }));
  const payload = {
    model: "gpt-4.1-mini", stream: false, instructions: "Explain", prompt: "Synthetic question",
    images: [{ data: "YWJj", mimeType: "image/jpeg", label: "Synthetic image" }], history: [],
  };
  const request = (body: unknown, token = "synthetic-internal") => runtime.dispatchFetch("https://runtime.invalid/vision", {
    method: "POST", headers: { authorization: `Bearer ${token}` }, body: JSON.stringify(body),
  });
  try {
    await context.test("authorization rejects before any upstream request", async () => {
      assert.equal((await request(payload, "wrong")).status, 401);
      assert.equal(outboundRequestCount, 0);
    });
    await context.test("legacy conversation reaches mocked Chat Completions", async () => {
      const response = await request(payload);
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), { text: "Synthetic answer" });
      assert.equal(calls.at(-1)?.path, "/v1/chat/completions");
    });
    await context.test("localization reaches mocked Responses using original detail", async () => {
      const response = await request({ ...payload, purpose: "localization", model: "gpt-6-astra" });
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), { text: JSON.stringify({ target }) });
      assert.equal(calls.at(-1)?.path, "/v1/responses");
      assert.match(JSON.stringify(calls.at(-1)?.body), /"detail":"original"/);
    });
    await context.test("provider redirects fail closed without following or exposing body", async () => {
      redirectUpstream = true;
      const before = outboundRequestCount;
      const response = await request(payload);
      assert.equal(response.status, 502);
      assert.equal(outboundRequestCount, before + 1);
      assert.deepEqual(await response.json(), { error: "Vision provider unavailable" });
    });
  } finally {
    await runtime.dispose();
  }
});
