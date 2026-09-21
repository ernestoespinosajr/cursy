# Isolated localization evaluation

`evaluate-localization.mjs` is offline by default. It compares proposed points,
never executes computer tools, captures the desktop or deploys an app/Worker.
Keep screenshots, labels and fixture JSON outside the repository. Obtain consent
for each provider receiving private images. API keys stay in ignored
`worker/.dev.vars`; never put them in fixtures or command-line arguments.

Example fixture (one PNG/JPEG, dimensions must match the actual file):

```json
{
  "cases": [{
    "caseID": "case-01",
    "image": "sample.png",
    "width": 1200,
    "height": 800,
    "label": "The visible Export button",
    "acceptanceRect": {"x": 0.7, "y": 0.1, "width": 0.1, "height": 0.06}
  }]
}
```

Rectangles use normalized top-left coordinates. Fix them before inference;
`acceptanceRect: null` means the requested target is absent and must yield no
point. IDs must be opaque `case-01` style. Image paths resolve relative to fixture.

From `cursy-app`:

```sh
node --test scripts/evaluate-localization.test.mjs
node scripts/evaluate-localization.mjs --fixtures /private/tmp/qa/fixtures.json
```

After authorizing upload and API usage, add `--run`. `--models` is an explicit
comma-separated allowlist, `--repeat` is 1–5 and `--max-calls` caps each invocation
at 20. Defaults compare GPT-4.1, GPT-5.6 Sol, Claude Sonnet 5 and DeepSeek Flash;
GPT-6 Astra/Claude Opus 5 are also supported. No fallback or automatic retries.

Output contains opaque case ID, model, point, acceptance hit, time, token counts
and sanitized status only. `billing_unavailable` is not a precision failure.
Missing/refused/malformed output is distinct from a wrong visible point. The
program never executes mouse_move, click, type, or other provider suggestions.

This compares model **and adapter**, on the supplied image. It is not a replay
of the full native prompt, window metadata, Realtime history or observation loop.
Repeated success on one screenshot is not independent evidence across apps.
Require broader fixtures plus in-app multi-monitor/scroll QA before promotion.
Never interpret 100% in a finite sample as a guarantee of 100% future accuracy.
