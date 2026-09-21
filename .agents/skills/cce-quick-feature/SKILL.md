---
name: cce-quick-feature
description: Create an implementation-ready 6-layer Codex Context Engine plan for a medium feature, UI/UX change, focused integration, or multi-file enhancement. Use when the user invokes $cce-quick-feature or asks to formally plan medium-complexity work.
---

# CCE Quick Feature

Plan only unless execution is explicitly requested in the same request.

1. Read project memory, matching context analysis, related tasks, and relevant
   source files. Identify reuse before proposing new components.
2. Confirm complexity 4-6 and reroute if repository evidence contradicts it.
3. Allocate the next unused `tsk###` across the whole workflow tree.
4. Create one task in `workflow/01-planned/` and update the logbook and any
   known task relationships in `dependencies.md`.
5. Cover all six layers in `workflow/context-levels.md` without padding.

Include user stories or actor goals, scope and non-goals, measurable acceptance
criteria, UX states and accessibility where relevant, architecture and data
flow, affected files, dependencies, phased implementation, testing, security,
performance, rollout/rollback, risks, documentation, and specialist choice.
Use
[`../cce-dispatch/references/specialist-skill-routing.md`](../cce-dispatch/references/specialist-skill-routing.md)
to name one CCE owner and the smallest relevant companion skill set.

End with `$cce-dispatch execute tsk###-slug`.
