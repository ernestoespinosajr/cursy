---
name: cce-multi-agent-coordinator
description: Coordinate an explicitly authorized Codex Context Engine task across multiple agents when independent bounded workstreams can run in parallel, with clear ownership, integration, and validation.
---

# CCE Multi-Agent Coordinator

Use only when collaboration tools are available and the user has authorized
delegation or parallel agent work.

1. Split work into independent deliverables with non-overlapping file ownership.
2. Give each agent the task goal, relevant paths, constraints, acceptance
   criteria, expected return format, and exact required skill names. Each agent
   must read those skills itself before acting. Do not delegate interpretation
   of repository instructions or required skill instructions.
3. The coordinator alone owns the task file, logbook, shared contracts, and
   final integration unless ownership is explicitly reassigned.
4. Track dependencies and wait on the critical path. Stop or redirect agents
   promptly when assumptions change.
5. Review every result, integrate it, resolve conflicts, and run end-to-end
   validation. Agent completion is evidence, not proof of system completion.

If the task cannot be divided safely, execute it serially with the most relevant
specialist instead.

Use
[`../cce-dispatch/references/specialist-skill-routing.md`](../cce-dispatch/references/specialist-skill-routing.md)
to match each bounded workstream to its CCE owner and companion skills.
