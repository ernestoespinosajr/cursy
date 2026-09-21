---
name: cce-feature
description: Create a comprehensive 11-layer Codex Context Engine plan for complex features, architectural changes, new subsystems, migrations, or high-risk integrations. Use when the user invokes $cce-feature or asks for formal planning of high-complexity work.
---

# CCE Feature

Produce a decision-ready plan; do not implement unless explicitly asked.

1. Read project memory first, then inspect relevant architecture, history,
   tests, and external contracts. Use current official documentation when
   volatile external behavior materially affects the plan.
2. Confirm complexity 7-10. Identify assumptions and meaningful decisions that
   require the user rather than silently choosing them.
3. Allocate the next unused `tsk###` across all workflow directories.
4. Create one file in `workflow/01-planned/`; update logbook and dependency
   relationships.
5. Address the 11 layers in `workflow/context-levels.md` with evidence and
   explicit non-goals.

The plan needs phased deliverables, file-level impact where discoverable,
interfaces and migrations, security/privacy, reliability/observability,
performance budgets, compatibility, test matrix, rollout and rollback,
quality gates, success metrics, ownership, documentation, risks, and open
decisions. Make phases independently verifiable.

Recommend a primary specialist and parallel work only when units are genuinely
independent and non-overlapping. Read
[`../cce-dispatch/references/specialist-skill-routing.md`](../cce-dispatch/references/specialist-skill-routing.md)
and record the CCE owner and applicable companion skills per phase. Finish with
the exact dispatch prompt.
