---
name: cce-context-manager
description: Analyze a repository and maintain Codex Context Engine project intelligence, including bootstrap, logbook structure, dependency discovery, task relationships, component registries, context recovery, and concise long-lived documentation.
---

# CCE Context Manager

Optimize project memory for fast, accurate recovery.

- Start from manifests, entry points, root docs, build/test configuration, and
  representative source boundaries. Exclude generated/vendor directories.
- Prefer a concise architectural map over exhaustive file listings.
- Back every stack, command, component, and integration claim with a repository
  path or executable evidence.
- Keep `logbook.md` scannable and `dependencies.md` durable. Detailed execution
  history belongs in task records.
- Record safe configuration names, never credential values.
- Detect stale paths, duplicate tasks, conflicting status, broken references,
  and task files present in more than one lifecycle directory.
- During bootstrap, replace all placeholders, validate referenced paths, update
  `tsk000`, and return control to `$cce-dispatch` for lifecycle completion.

Do not change application code unless the dispatched task explicitly includes
it; this specialization primarily owns project intelligence artifacts.
