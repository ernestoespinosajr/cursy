---
name: cce-ask
description: Analyze a proposed bug, feature, or improvement using the Codex Context Engine; inspect project memory, detect related work and reuse opportunities, assess complexity, create a permanent context analysis, and recommend cce-issue, cce-quick-feature, or cce-feature. Use when the user invokes $cce-ask or asks for context-aware task triage before planning.
---

# CCE Ask

Analyze and route work; do not implement it.

## Procedure

1. Locate the project root from `AGENTS.md`. Read `workflow/logbook.md`, then
   `workflow/dependencies.md` if relationships may matter.
2. Search the repository and relevant task records for existing implementations,
   overlapping work, reusable components, constraints, and prior lessons.
3. Separate verified facts from inferences and open questions. Ask a blocking
   question only when different answers would materially change the route.
4. Score technical, integration, testing, and rollout complexity from 1-10.
5. Choose the route:
   - 1-3: `$cce-issue`
   - 4-6: `$cce-quick-feature`
   - 7-10: `$cce-feature`
6. Read
   [`../cce-dispatch/references/specialist-skill-routing.md`](../cce-dispatch/references/specialist-skill-routing.md)
   and recommend one CCE owner plus only the companion skills supported by the
   verified workstreams.
7. Determine the next unused `ct###` across `workflow/00-context/`; create
   `ct###-slug.md`. Use a stable lowercase kebab-case slug.
8. Register the context file in the logbook without changing task counters.

## Context file contents

Include: request summary, evidence inspected, related tasks, reusable code,
affected areas, complexity breakdown, assumptions, risks, 2-3 viable approaches
when useful, recommended route, recommended specialist skill, available tool
categories, and a ready-to-run next prompt.

Do not assume a plugin, MCP server, or collaboration tool is installed. Refer
to capabilities by purpose and mention a specific tool only when it is actually
available in the session.

End with a concise recommendation and the exact `$cce-*` invocation to use.
