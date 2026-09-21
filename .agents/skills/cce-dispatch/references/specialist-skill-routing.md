# Cursy specialist skill routing

Use this matrix after identifying the task's actual workstreams. Choose one CCE
owner and only the companion skills that change implementation or review
decisions. The agent performing a workstream must read each selected skill's
complete `SKILL.md` before acting.

| Workstream | CCE owner | Companion skills |
| --- | --- | --- |
| Model APIs, routing, voice AI, evaluations, latency or cost | `cce-ai-engineer` | `openai-docs` for OpenAI behavior requiring current official documentation |
| Swift, SwiftUI, AppKit, macOS permissions, lifecycle or concurrency | `cce-mobile` | `write-swift`; add `apple-design` for interaction or platform-design decisions |
| Web landing page or client UI | `cce-frontend` | `emil-design-eng`; add `mobile-native` for mobile-web behavior |
| Backend, proxy, auth, storage or integrations | `cce-backend` | Add `cce-ai-engineer` only when model behavior is part of the boundary |
| End-to-end client, backend and model flow | `cce-full-stack` | Combine only the domain skills owned by each verified workstream |
| New bitmap illustration, texture, mockup or image edit | Relevant CCE owner | `imagegen` |
| Cohesive batch photo edits | Relevant CCE owner | `app-69312da8e4dc81919370cb86fd172b6c:adobe-batch-edit-photos` |
| Product or scene mockups | Relevant CCE owner | `app-69312da8e4dc81919370cb86fd172b6c:adobe-create-mockups` |
| Social-media exports and variants | Relevant CCE owner | `app-69312da8e4dc81919370cb86fd172b6c:adobe-create-social-variations` |
| Template-based marketing design | Relevant CCE owner | `app-69312da8e4dc81919370cb86fd172b6c:adobe-design-from-template` |
| Video highlight or sizzle reel | Relevant CCE owner | `app-69312da8e4dc81919370cb86fd172b6c:adobe-edit-quick-cut` |
| Portrait retouching | Relevant CCE owner | `app-69312da8e4dc81919370cb86fd172b6c:adobe-retouch-portraits` |
| Implement a purposeful UI animation | `cce-frontend` or `cce-mobile` | `animate`; add `apple-design` for Apple-platform motion |
| Discover missing motion opportunities | Appropriate UI CCE owner | `find-animation-opportunities` |
| Audit and plan motion improvements | Appropriate UI CCE owner | `improve-animations` |
| Review existing animation code | Appropriate UI CCE owner | `review-animations` |
| Identify an unknown motion pattern by description | Appropriate UI CCE owner | `animation-vocabulary` |
| Broad interaction polish and microinteractions | Appropriate UI CCE owner | `emil-design-eng`; add `animate` only when implementing motion |
| Compare several UI directions before choosing | `cce-frontend` or `cce-mobile` | `prototype` |

## Selection boundaries

- A mention of an image does not automatically require image generation or an
  Adobe workflow. Use those skills only when producing or editing media.
- A Swift file does not automatically require animation or Apple design. Use
  `write-swift` for native implementation; add design skills only when the task
  includes relevant interaction decisions.
- Use one motion workflow for the requested outcome: discovery, audit,
  implementation, or review. Combine them only when the request genuinely spans
  those phases.
- Planning skills record the recommended CCE owner and companion skills in the
  task file. Dispatch revalidates that selection against the current repository.
- For delegated work, the coordinator includes exact skill names, paths when
  needed, task boundaries, and acceptance criteria in the assignment.
