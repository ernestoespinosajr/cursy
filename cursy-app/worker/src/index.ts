/**
 * Cursy Proxy Worker
 *
 * Proxies requests to OpenAI and ElevenLabs APIs so the app never
 * ships with raw API keys. Keys are stored as Cloudflare secrets.
 *
 * Routes:
 *   POST /vision → protected provider-neutral vision/chat (OpenAI adapter)
 *   POST /tts   → ElevenLabs TTS API
 *   POST /openai/realtime/session → short-lived OpenAI Realtime client secret
 */

import { handleVision } from "./vision.ts";

interface Env {
  OPENAI_API_KEY: string;
  CURSY_INTERNAL_API_TOKEN: string;
  ELEVENLABS_API_KEY: string;
  ELEVENLABS_VOICE_ID: string;
  ASSEMBLYAI_API_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    try {
      if (url.pathname === "/chat") {
        return jsonResponse({ error: "Legacy chat retired; update the app to use /vision" }, 410);
      }

      if (url.pathname === "/vision") {
        if (!env.OPENAI_API_KEY || !env.CURSY_INTERNAL_API_TOKEN) {
          return jsonResponse({ error: "Vision service not configured" }, 503);
        }
        if (!(await hasValidInternalAuthorization(request, env.CURSY_INTERNAL_API_TOKEN))) {
          return jsonResponse({ error: "Unauthorized" }, 401);
        }
        return await handleVision(request, env.OPENAI_API_KEY);
      }

      if (url.pathname === "/tts") {
        return await handleTTS(request, env);
      }

      if (url.pathname === "/transcribe-token") {
        return await handleTranscribeToken(env);
      }

      if (url.pathname === "/openai/realtime/session") {
        return await handleOpenAIRealtimeSession(request, env);
      }
    } catch (error) {
      console.error(`[${url.pathname}] Unhandled error:`, error);
      return jsonResponse({ error: "Unexpected proxy error" }, 500);
    }

    return new Response("Not found", { status: 404 });
  },
};

async function handleOpenAIRealtimeSession(request: Request, env: Env): Promise<Response> {
  if (!env.OPENAI_API_KEY || !env.CURSY_INTERNAL_API_TOKEN) {
    console.error("[/openai/realtime/session] Required Worker secrets are not configured");
    return jsonResponse({ error: "Realtime sessions are not configured" }, 503);
  }

  if (!(await hasValidInternalAuthorization(request, env.CURSY_INTERNAL_API_TOKEN))) {
    return jsonResponse({ error: "Unauthorized" }, 401, {
      "www-authenticate": "Bearer",
    });
  }

  const response = await fetch("https://api.openai.com/v1/realtime/client_secrets", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      expires_after: {
        anchor: "created_at",
        seconds: 60,
      },
      session: {
        type: "realtime",
        model: "gpt-realtime-2.1",
        output_modalities: ["audio"],
        audio: {
          input: {
            turn_detection: {
              type: "server_vad",
            },
          },
          output: {
            voice: "marin",
          },
        },
      },
    }),
  });

  if (!response.ok) {
    console.error(
      `[/openai/realtime/session] OpenAI request failed with status ${response.status}`
    );
    return jsonResponse(
      { error: "Unable to create a Realtime session" },
      response.status >= 400 && response.status < 500 ? 502 : 503
    );
  }

  return new Response(response.body, {
    status: 200,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}

async function hasValidInternalAuthorization(
  request: Request,
  expectedToken: string
): Promise<boolean> {
  const authorizationHeader = request.headers.get("authorization");
  const bearerPrefix = "Bearer ";

  if (!authorizationHeader?.startsWith(bearerPrefix)) {
    return false;
  }

  const providedToken = authorizationHeader.slice(bearerPrefix.length);
  const textEncoder = new TextEncoder();
  const [providedDigest, expectedDigest] = await Promise.all([
    crypto.subtle.digest("SHA-256", textEncoder.encode(providedToken)),
    crypto.subtle.digest("SHA-256", textEncoder.encode(expectedToken)),
  ]);

  const providedBytes = new Uint8Array(providedDigest);
  const expectedBytes = new Uint8Array(expectedDigest);
  let difference = providedBytes.length ^ expectedBytes.length;

  for (let byteIndex = 0; byteIndex < providedBytes.length; byteIndex += 1) {
    difference |= providedBytes[byteIndex] ^ expectedBytes[byteIndex];
  }

  return difference === 0;
}

function jsonResponse(
  body: Record<string, unknown>,
  status: number,
  additionalHeaders: Record<string, string> = {}
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
      ...additionalHeaders,
    },
  });
}

async function handleTranscribeToken(env: Env): Promise<Response> {
  const response = await fetch(
    "https://streaming.assemblyai.com/v3/token?expires_in_seconds=480",
    {
      method: "GET",
      headers: {
        authorization: env.ASSEMBLYAI_API_KEY,
      },
    }
  );

  if (!response.ok) {
    const errorBody = await response.text();
    console.error(`[/transcribe-token] AssemblyAI token error ${response.status}: ${errorBody}`);
    return new Response(errorBody, {
      status: response.status,
      headers: { "content-type": "application/json" },
    });
  }

  const data = await response.text();
  return new Response(data, {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

async function handleTTS(request: Request, env: Env): Promise<Response> {
  const body = await request.text();
  const voiceId = env.ELEVENLABS_VOICE_ID;

  const response = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    {
      method: "POST",
      headers: {
        "xi-api-key": env.ELEVENLABS_API_KEY,
        "content-type": "application/json",
        accept: "audio/mpeg",
      },
      body,
    }
  );

  if (!response.ok) {
    const errorBody = await response.text();
    console.error(`[/tts] ElevenLabs API error ${response.status}: ${errorBody}`);
    return new Response(errorBody, {
      status: response.status,
      headers: { "content-type": "application/json" },
    });
  }

  return new Response(response.body, {
    status: response.status,
    headers: {
      "content-type": response.headers.get("content-type") || "audio/mpeg",
    },
  });
}
