# Context workflow

This directory is the project's persistent intelligence layer.

```text
workflow/
├── 00-context/       permanent analyses (`ct###-*`)
├── 01-planned/       implementation-ready tasks (`tsk###-*`)
├── 02-in-progress/   active tasks
├── 03-completed/     completed or failed tasks
├── context-levels.md context scaling reference
├── dependencies.md   dependency and integration registry
└── logbook.md        concise project index
```

## Invariants

- A task has one file and that file moves between lifecycle directories.
- The logbook points to task files; it does not reproduce their full contents.
- IDs are monotonically increasing across all directories.
- Context files remain in `00-context` as long-lived references.
- Completion records contain validation evidence and unresolved follow-ups.
- Secrets and sensitive output never belong in workflow documents.

## Suggested flow

1. `$cce-ask` searches project memory and analyzes the request.
2. `$cce-issue`, `$cce-quick-feature`, or `$cce-feature` creates the plan.
3. `$cce-dispatch` validates the plan and executes it.
4. The task record and logbook are updated as facts change.
5. Successful work moves to `03-completed/*-completed.md`; an attempted task
   that cannot meet its goal moves to `*-failed.md` with evidence. Work that is
   merely paused stays in progress.
