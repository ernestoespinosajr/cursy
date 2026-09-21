---
name: cce-issue
description: Create an implementation-ready 3-layer Codex Context Engine plan for a bug, regression, maintenance item, or small scoped change. Use when the user invokes $cce-issue or asks to formally plan low-complexity work in the CCE workflow.
---

# CCE Issue

Plan only; do not implement unless the user explicitly asks to plan and execute.

1. Read the logbook, relevant dependencies, matching `ct###` analysis, related
   task records, and the code needed to establish the root cause.
2. Confirm the request fits complexity 1-3. If evidence shows otherwise, explain
   and route to the appropriate feature skill.
3. Allocate the next unused `tsk###` by scanning every workflow directory.
4. Create `workflow/01-planned/tsk###-slug.md` and register it in the logbook.
5. Use the 3-layer reference in `workflow/context-levels.md`.

The plan must include status metadata, context link, evidence, current versus
expected behavior, reproduction when applicable, root cause or investigation
steps, minimal solution, affected files, implementation checklist, tests,
regression risks, rollback, acceptance criteria, and a recommended specialist.
Use
[`../cce-dispatch/references/specialist-skill-routing.md`](../cce-dispatch/references/specialist-skill-routing.md)
to name the CCE owner and any companion skill that materially applies.

Do not claim a root cause without evidence. Mark hypotheses as hypotheses.
Finish with the exact `$cce-dispatch execute tsk###-slug` prompt.
