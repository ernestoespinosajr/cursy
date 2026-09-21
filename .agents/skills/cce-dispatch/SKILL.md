---
name: cce-dispatch
description: Execute a planned Codex Context Engine task, including bootstrap; move its single task file through the workflow, apply an appropriate specialist, implement and validate the work, update project memory and dependencies, and archive the final record. Use when the user invokes $cce-dispatch or asks to execute a specific CCE tsk### task.
---

# CCE Dispatch

Execute a named task to a truthful terminal state.

## Preflight

1. Read `workflow/logbook.md`, relevant dependencies, the named task, linked
   context, repository instructions, and working-tree status.
2. Reject ambiguous task matches. If the task is already completed, report its
   result rather than executing it again unless the user explicitly requests a
   follow-up.
3. Verify the plan against current code. Amend its assumptions and record why
   when the repository has changed.
4. Read [references/specialist-skill-routing.md](references/specialist-skill-routing.md).
   Select the closest CCE owner plus the smallest relevant set of companion
   skills. Read every selected skill before implementation. For bootstrap, use
   `$cce-context-manager`.

## Lifecycle

1. Move the task file from `01-planned` to `02-in-progress` before edits. Update
   its metadata and logbook status in the same change.
2. Implement phase by phase. Keep a compact execution log with changed files,
   decisions, discovered dependencies, issues, and validation evidence.
   Record which specialist and companion skills materially guided the work.
3. Run the strongest relevant checks that are practical in the environment.
   Never describe a check as passing unless it ran successfully.
4. Pause for the user only at a decision or manual acceptance gate defined by
   the plan, or when new authority is required. Routine phases do not require
   ceremonial approval.
5. Update `dependencies.md` only for durable discoveries or task relationships.

## Completion

- Success: satisfy acceptance criteria, record residual risks and follow-ups,
  move to `03-completed/tsk###-slug-completed.md`, and update logbook metrics.
- Failed attempt: record evidence and recovery advice, move to
  `*-failed.md`, and update metrics.
- Blocked or paused: leave in `02-in-progress`; do not mislabel it failed.

Use filesystem moves so only one task file exists. Preserve unrelated user
changes. Never commit, push, deploy, message external systems, or perform a
destructive action unless that action is within the user's authorization.
