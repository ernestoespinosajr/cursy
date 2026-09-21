# Codex Context Engine

This repository uses a persistent context workflow. These instructions apply
from the repository root downward.

## Project root and memory

- Treat the directory containing this file as `<project-root>`.
- The only workflow directory is `<project-root>/workflow/`. Never create one
  under `src/`, `frontend/`, `backend/`, or another subdirectory.
- At the start of repository work, read `workflow/logbook.md`. Read
  `workflow/dependencies.md` when relationships, integrations, or blockers are
  relevant. Open individual task files only when the logbook indicates they
  matter.
- Search for existing components and related tasks before creating new ones.
- Keep the logbook concise: it is an index and current-state summary, not a
  transcript.

## Request modes

1. A request naming `$cce-ask`, `$cce-issue`, `$cce-quick-feature`,
   `$cce-feature`, or `$cce-dispatch` follows that skill exactly.
2. A direct implementation request should be completed normally. Track it as
   a micro-task only when it is substantial enough that cross-session memory
   adds value; trivial questions and tiny edits do not need workflow files.
3. Never create both a formal task and a micro-task for the same request.

## Task lifecycle

- Context analysis: `workflow/00-context/ct###-slug.md`.
- Planning: `workflow/01-planned/tsk###-slug.md`.
- Execution: move the same file to `workflow/02-in-progress/`.
- Completion: move it to `workflow/03-completed/` and append `-completed` or
  `-failed` before `.md`.
- Determine the next numeric ID by scanning every workflow directory, not only
  the planned directory. Do not reuse IDs.
- Update status, dates, decisions, validation evidence, affected files, newly
  discovered dependencies, and lessons in the task record.
- Do not mark a task complete while required work remains. Explicit user
  approval is required only when the plan identifies a user decision or manual
  acceptance gate; automated evidence is sufficient for routine code phases.

## Engineering behavior

- Treat user-reported scenarios as QA cases, not application-specific product
  rules. Fix the general cause and keep runtime instructions and implementation
  independent of example app names, people, files, or workflows. Preserve concrete
  examples as regression fixtures and validate other representative cases where
  practical. Add special-case behavior only when explicitly required by the product.
- Preserve user changes and inspect the working tree before editing.
- Prefer evidence from repository files and executable checks over assumptions.
- Make the smallest coherent change that satisfies the request.
- Validate in proportion to risk and report commands and outcomes truthfully.
- Never commit secrets, tokens, private URLs, or credentials to workflow files.
- External writes, deployments, messages, purchases, and destructive actions
  require the same authorization they would outside this workflow.

## Context scaling

- Issue (complexity 1-3): problem, solution, implementation.
- Quick feature (complexity 4-6): goals, UX, technical design, dependencies,
  implementation, validation.
- Feature (complexity 7-10): use the 11 layers in
  `workflow/context-levels.md`.

## Collaboration

Use parallel agents only when Codex exposes collaboration tools, the user has
authorized delegation, and the work splits into independent, bounded tasks.
One coordinator owns shared files and integration. Agents must not make
overlapping edits. If these conditions are absent, work serially.

## Skill routing

Every agent working in this repository must consider the installed specialist
skills before planning or editing. Select the smallest set that materially
improves the task; do not load every skill by default. Read the complete
`SKILL.md` for every selected skill before acting, and follow its referenced
resources only when the current task needs them.

- Use the appropriate `cce-*` skill to own project context, planning, lifecycle,
  or implementation. CCE remains the orchestration layer; companion skills add
  domain expertise rather than replacing the CCE workflow.
- For Swift, SwiftUI, AppKit, macOS lifecycle, concurrency, permissions, or
  native tests, pair the CCE owner with `write-swift`. Add `apple-design` when
  interaction design, platform conventions, gestures, or native motion matter.
- For motion implementation use `animate`; use `find-animation-opportunities`
  for discovery, `improve-animations` for an audit and plan, and
  `review-animations` for review. Add `emil-design-eng` when the task calls for
  broader interface polish. Do not stack all motion skills for an ordinary
  animation change.
- Use `imagegen` for new or edited bitmap assets. Use the matching Adobe skill
  for batch photo styling, product mockups, social variants, template-based
  designs, quick-cut video, or portrait retouching when that workflow is
  actually requested or required.
- When delegating, name the required skills in the subagent assignment. Each
  subagent must read those skills itself; never delegate interpretation of
  repository or skill instructions.

CCE planning and execution skills use the maintained routing matrix at
`.agents/skills/cce-dispatch/references/specialist-skill-routing.md`.
