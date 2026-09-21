# Context depth reference

Use only the depth needed by the task.

## 3-layer issue context

1. Problem: current behavior, expected behavior, evidence, reproduction.
2. Solution: root cause, impact, minimal fix, alternatives and risks.
3. Implementation: edits, tests, rollback, documentation.

## 6-layer quick-feature context

1. Goals and requirements: purpose, users, scope, acceptance criteria.
2. User experience: journey, states, accessibility, errors, responsiveness.
3. Technical design: architecture, components, data, APIs, conventions.
4. Dependencies: internal, external, schema, integrations, compatibility.
5. Implementation: phases, tests, security, performance, rollout.
6. Validation: quality gates, metrics, documentation, rollback.

## 11-layer feature context

1. Strategic context and business goal.
2. User and stakeholder needs.
3. Functional requirements and explicit non-goals.
4. Existing-system and historical context.
5. Architecture and component boundaries.
6. Data model, contracts, migrations, and lifecycle.
7. Security, privacy, abuse, and compliance concerns.
8. Reliability, performance, observability, and scale.
9. Dependency and integration map.
10. Phased implementation, testing, rollout, and rollback.
11. Quality gates, measurable success, documentation, and ownership.

Every plan should distinguish verified facts, reasoned inferences, and open
questions. Avoid filler sections when a layer does not apply; say why briefly.
