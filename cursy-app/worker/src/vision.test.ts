import test from "node:test";
import assert from "node:assert/strict";
import worker from "./index.ts";
import { validVisionRequest, openAIRequest, normalizedOpenAIStream,
  openAILocalizationRequest, normalizedLocalizationResponse } from "./vision.ts";

const payload = {
  model: "gpt-4.1", stream: false, instructions: "Explain", prompt: "Where is close?",
  images: [{ data: "YWJj", mimeType: "image/jpeg", label: "Screen" }],
  history: [{ user: "Hello", assistant: "Hi" }],
};
const env = {
  OPENAI_API_KEY: "test-provider-only", CURSY_INTERNAL_API_TOKEN: "test-internal",
  ELEVENLABS_API_KEY: "", ELEVENLABS_VOICE_ID: "", ASSEMBLYAI_API_KEY: "",
};
const request = (body: unknown = payload, token = "test-internal") =>
  new Request("https://unit.test/vision", {
    method: "POST", headers: { authorization: `Bearer ${token}` }, body: JSON.stringify(body),
  });

test("contract maps image/history to OpenAI, rejects unsupported providers", () => {
  assert.equal(validVisionRequest(payload), true);
  assert.equal(validVisionRequest({ ...payload, model: "claude-sonnet-4-6" }), false);
  assert.equal(validVisionRequest({ ...payload, images: [{ data: "https://external.test" }] }), false);
  assert.equal(validVisionRequest({ ...payload, history: Array(11).fill(payload.history[0]) }), false);
  const upstream = openAIRequest(payload);
  assert.equal(upstream.store, false);
  assert.equal(upstream.messages.length, 4);
  assert.match(JSON.stringify(upstream), /data:image\/jpeg;base64,YWJj/);
});

test("broker authenticates before forwarding and disables legacy Anthropic route", async () => {
  assert.equal((await worker.fetch(request(payload, "wrong"), env)).status, 401);
  assert.equal((await worker.fetch(request(), { ...env, OPENAI_API_KEY: "" })).status, 503);
  assert.equal((await worker.fetch(request({ ...payload, model: "claude" }), env)).status, 400);
  assert.equal((await worker.fetch(new Request("https://unit.test/chat", { method: "POST" }), env)).status, 410);
});

test("nonstream vision goes only to OpenAI and returns neutral response", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, options) => {
    assert.equal(url, "https://api.openai.com/v1/chat/completions");
    assert.equal(new Headers(options?.headers).get("authorization"), "Bearer test-provider-only");
    assert.equal(JSON.parse(options!.body as string).model, "gpt-4.1");
    return Response.json({ choices: [{ finish_reason: "stop", message: { content: "Use the red button." } }] });
  };
  try {
    const result = await worker.fetch(request(), env);
    assert.equal(result.status, 200);
    assert.equal(result.headers.get("cache-control"), "no-store");
    assert.deepEqual(await result.json(), { text: "Use the red button." });
  } finally { globalThis.fetch = originalFetch; }
});

test("upstream errors do not expose provider payloads", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response("sensitive upstream message", { status: 401 });
  try {
    const result = await worker.fetch(request(), env);
    assert.equal(result.status, 502);
    assert.doesNotMatch(await result.text(), /sensitive/);
  } finally { globalThis.fetch = originalFetch; }
});

async function streamResult(text: string) {
  const encoded = new TextEncoder().encode(text);
  const source = new ReadableStream<Uint8Array>({
    start(controller) {
      // Split every byte, including UTF-8 and JSON/event boundaries.
      for (const byte of encoded) controller.enqueue(new Uint8Array([byte]));
      controller.close();
    },
  });
  return new Response(normalizedOpenAIStream(source)).text();
}

test("SSE handles fragmented UTF-8 and requires successful completion", async () => {
  const delta = 'data: {"choices":[{"delta":{"content":"Sí"}}]}\n\n';
  const stop = 'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\n';
  const valid = await streamResult(delta + stop + "data: [DONE]\n\n");
  assert.match(valid, /"text":"Sí"/);
  assert.match(valid, /"type":"done"/);
  const truncated = await streamResult(delta);
  assert.match(truncated, /"type":"error"/);
  assert.doesNotMatch(truncated, /"type":"done"/);
  assert.match(await streamResult('data: {"error":{}}\n\n'), /"type":"error"/);
});

const localizationPayload = { ...payload, purpose: "localization" as const, model: "gpt-6-astra" };
const localizationTarget = { x: 240, y: 170, label: "Synthetic control", intent: "other", nativeControlID: "", windowID: "window-1" };
const localizationResponse = (args: unknown = { target: localizationTarget }) => ({
  status: "completed", output: [{ type: "function_call", status: "completed", name: "record_localization", arguments: JSON.stringify(args) }],
});

test("purpose/model allowlists keep conversation and localization separate", () => {
  assert.equal(validVisionRequest({ ...payload, purpose: "conversation" }), true);
  assert.equal(validVisionRequest(localizationPayload), true);
  assert.equal(validVisionRequest({ ...localizationPayload, model: "gpt-5.6-sol" }), true);
  for (const update of [
    { purpose: "anything" }, { purpose: null }, { purpose: "localization" }, { model: "gpt-6-astra" },
  ]) assert.equal(validVisionRequest({ ...payload, ...update }), false);
  for (const update of [
    { model: "gpt-4.1" }, { model: "gpt-4.1-mini" }, { model: "claude-sonnet-5" }, { model: "deepseek-flash" },
    { stream: true }, { images: [] }, { images: [payload.images[0], payload.images[0]] },
    { purpose: undefined }, { purpose: "conversation" },
  ]) assert.equal(validVisionRequest({ ...localizationPayload, ...update }), false);
});

test("localization uses original raster and one forced strict record-only function", () => {
  const upstream = openAILocalizationRequest(localizationPayload);
  assert.equal(upstream.model, "gpt-6-astra");
  assert.equal(upstream.store, false);
  assert.equal(upstream.stream, false);
  assert.equal(upstream.max_output_tokens, 2048);
  assert.deepEqual(upstream.reasoning, { effort: "low" });
  assert.equal(upstream.parallel_tool_calls, false);
  assert.deepEqual(upstream.tool_choice, { type: "function", name: "record_localization" });
  assert.equal(upstream.tools.length, 1);
  assert.equal(upstream.tools[0].strict, true);
  assert.equal(upstream.tools[0].type, "function");
  assert.deepEqual(upstream.tools[0].parameters.required, ["target"]);
  assert.equal(upstream.tools[0].parameters.additionalProperties, false);
  const encoded = JSON.stringify(upstream);
  assert.match(encoded, /"detail":"original"/);
  assert.match(encoded, /data:image\/jpeg;base64,YWJj/);
  assert.doesNotMatch(encoded, /captureID|imageWidth|imageHeight|computer_call|left_click/);
  assert.equal(upstream.input.length, 3);
});

test("localization normalizes target/null without inventing metadata", () => {
  assert.equal(normalizedLocalizationResponse(localizationResponse()), JSON.stringify({ target: localizationTarget }));
  assert.equal(normalizedLocalizationResponse(localizationResponse({ target: null })), '{"target":null}');
  const withReasoning = localizationResponse();
  withReasoning.output.unshift({ type: "reasoning" } as any);
  assert.equal(normalizedLocalizationResponse(withReasoning), JSON.stringify({ target: localizationTarget }));
});

test("localization rejects incomplete, refusal, extra/unexpected tool and malformed provider output", () => {
  const valid = localizationResponse();
  for (const value of [
    null, {}, { ...valid, status: "incomplete" }, { ...valid, error: { message: "private" } },
    { ...valid, incomplete_details: { reason: "max_output_tokens" } },
    { ...valid, output: [] }, { ...valid, output: [...valid.output, ...valid.output] },
    { ...valid, output: [{ ...valid.output[0], name: "click" }] },
    { ...valid, output: [{ ...valid.output[0], status: "in_progress" }] },
    { ...valid, output: [{ ...valid.output[0], arguments: "not JSON" }] },
    { ...valid, output: [{ ...valid.output[0], arguments: "x".repeat(8001) }] },
    { ...valid, output: [{ type: "message", content: [{ type: "refusal", refusal: "private" }] }] },
    { ...valid, output: [{ type: "computer_call", actions: [] }] },
    localizationResponse({}), localizationResponse({ target: localizationTarget, captureID: "wrong" }),
  ]) assert.equal(normalizedLocalizationResponse(value), null);
});

test("localization rejects bad fields, negative/nonfinite points and oversized labels", () => {
  for (const change of [
    { x: -1 }, { x: "240" }, { x: Number.MAX_VALUE }, { y: Infinity },
    { label: "" }, { label: " " }, { label: "x".repeat(121) }, { intent: "click" },
    { nativeControlID: "x".repeat(241) }, { nativeControlID: null }, { windowID: "x".repeat(241) },
    { captureID: "not-a-model-field" }, { imageWidth: 1024 },
  ]) assert.equal(normalizedLocalizationResponse(localizationResponse({ target: { ...localizationTarget, ...change } })), null);
  const missing = { ...localizationTarget } as any;
  delete missing.windowID;
  assert.equal(normalizedLocalizationResponse(localizationResponse({ target: missing })), null);
});

test("localization broker routes to Responses and preserves neutral protected response", async () => {
  const originalFetch = globalThis.fetch;
  let count = 0;
  globalThis.fetch = async (url, options) => {
    count++;
    assert.equal(url, "https://api.openai.com/v1/responses");
    assert.equal(new Headers(options?.headers).get("authorization"), "Bearer test-provider-only");
    assert.equal(options?.redirect, "manual");
    assert.ok(options?.signal instanceof AbortSignal);
    const body = JSON.parse(options!.body as string);
    assert.equal(body.model, "gpt-6-astra");
    assert.equal(body.tools[0].name, "record_localization");
    return Response.json(localizationResponse());
  };
  try {
    assert.equal((await worker.fetch(request(localizationPayload, "wrong"), env)).status, 401);
    assert.equal(count, 0);
    const result = await worker.fetch(request(localizationPayload), env);
    assert.equal(result.status, 200);
    assert.equal(result.headers.get("cache-control"), "no-store");
    assert.deepEqual(await result.json(), { text: JSON.stringify({ target: localizationTarget }) });
    assert.equal(count, 1);
  } finally { globalThis.fetch = originalFetch; }
});

test("localization rejects invalid upstream shape without exposing bodies or silently falling back", async () => {
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async () => {
    calls++;
    return Response.json({ status: "completed", output: [{ type: "message", content: "private provider response" }] });
  };
  try {
    const result = await worker.fetch(request(localizationPayload), env);
    assert.equal(result.status, 502);
    assert.doesNotMatch(await result.text(), /private/);
    assert.equal(calls, 1);
  } finally { globalThis.fetch = originalFetch; }
});

test("provider body limits and malformed JSON are sanitized", async () => {
  const originalFetch = globalThis.fetch;
  try {
    for (const response of [new Response("private invalid JSON"), new Response("x".repeat(1_000_001))]) {
      globalThis.fetch = async () => response;
      const result = await worker.fetch(request(localizationPayload), env);
      assert.equal(result.status, 502);
      assert.equal(result.headers.get("cache-control"), "no-store");
      assert.doesNotMatch(await result.text(), /private|xxxxx/);
    }
  } finally { globalThis.fetch = originalFetch; }
});

test("network/cancellation failures never leak raw exceptions or retry", async () => {
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async (_url, options) => {
    calls++;
    assert.equal(options?.signal?.aborted, true);
    throw new Error("private credential and provider context");
  };
  try {
    const controller = new AbortController();
    const cancelled = new Request(request(localizationPayload), { signal: controller.signal });
    controller.abort();
    const result = await worker.fetch(cancelled, env);
    assert.equal(result.status, 502);
    assert.doesNotMatch(await result.text(), /private|credential/);
    assert.equal(calls, 1);
  } finally { globalThis.fetch = originalFetch; }
});
