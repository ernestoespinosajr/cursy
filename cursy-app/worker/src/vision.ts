// App-owned contract. Provider-specific payloads and stream formats stay server-side.
export interface VisionRequest {
  purpose?: "conversation" | "localization";
  model: string;
  stream: boolean;
  instructions: string;
  prompt: string;
  images: { data: string; mimeType: string; label: string }[];
  history: { user: string; assistant: string }[];
}

const conversationModels = new Set(["gpt-4.1", "gpt-4.1-mini"]);
const localizationModels = new Set(["gpt-6-astra", "gpt-5.6-sol"]);
const boundedString = (value: unknown, max: number): value is string =>
  typeof value === "string" && value.length <= max;

export function validVisionRequest(value: any): value is VisionRequest {
  return value !== null && typeof value === "object" &&
    [undefined, "conversation", "localization"].includes(value.purpose) &&
    (value.purpose === "localization"
      ? localizationModels.has(value.model) && value.stream === false && value.images?.length === 1
      : conversationModels.has(value.model)) && typeof value.stream === "boolean" &&
    boundedString(value.instructions, 24000) && boundedString(value.prompt, 16000) &&
    value.prompt.trim().length > 0 &&
    Array.isArray(value.history) && value.history.length <= 10 &&
    value.history.every((item: any) => item && boundedString(item.user, 16000) && boundedString(item.assistant, 16000)) &&
    Array.isArray(value.images) && value.images.length <= 2 &&
    value.images.every((image: any) => image &&
      ["image/jpeg", "image/png"].includes(image.mimeType) &&
      boundedString(image.label, 2000) && boundedString(image.data, 1400000) &&
      image.data.length > 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(image.data));
}

const localizationIntents = ["close_window", "minimize_window", "zoom_window", "dock_application", "other"];
const targetKeys = ["x", "y", "label", "intent", "nativeControlID", "windowID"];

// Only this adapter knows the provider's function schema. A returned tool call is
// data: the Worker has no computer/action executor and never runs model outputs.
export function openAILocalizationRequest(body: VisionRequest) {
  return {
    model: body.model, store: false, stream: false, max_output_tokens: 2048,
    reasoning: { effort: "low" }, instructions: body.instructions,
    parallel_tool_calls: false,
    tool_choice: { type: "function", name: "record_localization" },
    tools: [{
      type: "function", name: "record_localization", strict: true,
      description: "Record a proposed visible UI target in screenshot pixels, or null. Does not execute any action.",
      parameters: {
        type: "object", additionalProperties: false, required: ["target"],
        properties: { target: { anyOf: [
          { type: "null" },
          { type: "object", additionalProperties: false, required: targetKeys,
            properties: {
              x: { type: "number", minimum: 0 }, y: { type: "number", minimum: 0 },
              label: { type: "string", minLength: 1, maxLength: 120 },
              intent: { type: "string", enum: localizationIntents },
              nativeControlID: { type: "string", maxLength: 240 },
              windowID: { type: "string", maxLength: 240 },
            },
          },
        ] } },
      },
    }],
    input: [
      ...body.history.flatMap(item => [
        { role: "user", content: item.user }, { role: "assistant", content: item.assistant },
      ]),
      { role: "user", content: [
        { type: "input_text", text: body.prompt },
        ...body.images.flatMap(image => [
          { type: "input_text", text: image.label },
          { type: "input_image", image_url: `data:${image.mimeType};base64,${image.data}`, detail: "original" },
        ]),
      ] },
    ],
  };
}

export function normalizedLocalizationResponse(result: any): string | null {
  if (result?.status !== "completed" || result.error || result.incomplete_details || !Array.isArray(result.output)) return null;
  const calls = result.output.filter((item: any) => item?.type !== "reasoning");
  if (calls.length !== 1 || calls[0]?.type !== "function_call" || calls[0].name !== "record_localization" ||
      (calls[0].status !== undefined && calls[0].status !== "completed") ||
      !boundedString(calls[0].arguments, 8000)) return null;
  let args: any;
  try { args = JSON.parse(calls[0].arguments); } catch { return null; }
  if (!args || typeof args !== "object" || Array.isArray(args) ||
      Object.keys(args).length !== 1 || !Object.hasOwn(args, "target")) return null;
  const target = args.target;
  if (target === null) return JSON.stringify({ target: null });
  if (!target || typeof target !== "object" || Array.isArray(target) ||
      Object.keys(target).length !== targetKeys.length || !targetKeys.every(key => Object.hasOwn(target, key)) ||
      !Number.isFinite(target.x) || !Number.isFinite(target.y) || target.x < 0 || target.y < 0 ||
      target.x > Number.MAX_SAFE_INTEGER || target.y > Number.MAX_SAFE_INTEGER ||
      !boundedString(target.label, 120) || !target.label.trim() || !localizationIntents.includes(target.intent) ||
      !boundedString(target.nativeControlID, 240) || !boundedString(target.windowID, 240)) return null;
  // Image size/capture identity belong to the native caller; its device/window
  // validators enforce the returned point's upper bounds without model echo.
  return JSON.stringify({ target });
}

async function boundedProviderJSON(response: Response): Promise<unknown> {
  if (!response.body) throw new Error("Missing provider body");
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const part = await reader.read();
    if (part.done) break;
    size += part.value.byteLength;
    if (size > 1_000_000) {
      await reader.cancel().catch(() => {});
      throw new Error("Oversized provider body");
    }
    chunks.push(part.value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return JSON.parse(new TextDecoder().decode(bytes));
}

export function openAIRequest(body: VisionRequest) {
  const content: unknown[] = [];
  for (const image of body.images) {
    content.push({ type: "text", text: image.label });
    content.push({ type: "image_url", image_url: { url: `data:${image.mimeType};base64,${image.data}`, detail: "high" } });
  }
  content.push({ type: "text", text: body.prompt });
  return {
    model: body.model, stream: body.stream, store: false, max_completion_tokens: 1024,
    messages: [
      { role: "system", content: body.instructions },
      ...body.history.flatMap(item => [
        { role: "user", content: item.user }, { role: "assistant", content: item.assistant },
      ]),
      { role: "user", content },
    ],
  };
}

// A future provider adapter must return this same delta/done/error contract.
export function normalizedOpenAIStream(upstream: ReadableStream<Uint8Array>): ReadableStream<Uint8Array> {
  const reader = upstream.getReader();
  const decoder = new TextDecoder();
  const encoder = new TextEncoder();
  let cancelled = false;
  return new ReadableStream({
    async start(controller) {
      let pending = "";
      let completed = false;
      const emit = (event: object) => controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
      try {
        while (!completed && !cancelled) {
          const part = await reader.read();
          if (part.done) break;
          pending += decoder.decode(part.value, { stream: true });
          if (pending.length > 1_000_000) throw new Error("Oversized stream event");
          let newline: number;
          while ((newline = pending.indexOf("\n")) >= 0) {
            const line = pending.slice(0, newline).trimEnd();
            pending = pending.slice(newline + 1);
            if (!line.startsWith("data: ")) continue;
            const payload = line.slice(6);
            if (payload === "[DONE]") break;
            const event = JSON.parse(payload);
            if (event.error) throw new Error("Provider error");
            const choice = event.choices?.[0];
            if (typeof choice?.delta?.content === "string") emit({ type: "delta", text: choice.delta.content });
            if (choice?.finish_reason) {
              if (choice.finish_reason !== "stop") throw new Error("Incomplete response");
              completed = true;
              emit({ type: "done" });
              break;
            }
          }
        }
        if (!completed && !cancelled) throw new Error("Incomplete stream");
      } catch {
        if (!cancelled) emit({ type: "error" });
      } finally {
        await reader.cancel().catch(() => {});
        if (!cancelled) controller.close();
      }
    },
    cancel() { cancelled = true; return reader.cancel(); },
  });
}

export async function handleVision(request: Request, apiKey: string): Promise<Response> {
  const json = (body: object, status = 200) => new Response(JSON.stringify(body), {
    status, headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
  // Bound actual bytes, not only an untrusted Content-Length header.
  if (!request.body) return json({ error: "Missing request" }, 400);
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const part = await reader.read();
    if (part.done) break;
    size += part.value.byteLength;
    if (size > 3_000_000) { await reader.cancel(); return json({ error: "Request too large" }, 413); }
    chunks.push(part.value);
  }
  const data = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { data.set(chunk, offset); offset += chunk.byteLength; }
  let body: unknown;
  try { body = JSON.parse(new TextDecoder().decode(data)); }
  catch { return json({ error: "Invalid JSON" }, 400); }
  if (!validVisionRequest(body)) return json({ error: "Unsupported model or invalid vision request" }, 400);
  const localization = body.purpose === "localization";
  try {
    const response = await fetch(localization ? "https://api.openai.com/v1/responses" : "https://api.openai.com/v1/chat/completions", {
      // workerd supports manual/follow, not Node's redirect:error. A redirect
      // stays non-OK below and is never followed with the provider credential.
      method: "POST", redirect: "manual",
      headers: { authorization: `Bearer ${apiKey}`, "content-type": "application/json" },
      body: JSON.stringify(localization ? openAILocalizationRequest(body) : openAIRequest(body)),
      signal: AbortSignal.any([request.signal, AbortSignal.timeout(60_000)]),
    });
    if (!response.ok || !response.body) {
      await response.body?.cancel().catch(() => {});
      return json({ error: "Vision provider unavailable" }, 502);
    }
    if (body.stream) return new Response(normalizedOpenAIStream(response.body), {
      headers: { "content-type": "text/event-stream", "cache-control": "no-store" },
    });
    const result: any = await boundedProviderJSON(response);
    if (localization) {
      const text = normalizedLocalizationResponse(result);
      return text === null ? json({ error: "Invalid localization response" }, 502) : json({ text });
    }
    const choice = result?.choices?.[0];
    if (choice?.finish_reason !== "stop" || typeof choice.message?.content !== "string" || !choice.message.content.trim()) {
      return json({ error: "Incomplete vision response" }, 502);
    }
    return json({ text: choice.message.content });
  } catch {
    // Do not forward/log raw provider/network exceptions via index.ts's catch.
    return json({ error: "Vision provider unavailable" }, 502);
  }
}
