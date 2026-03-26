---
name: req-driven
description: "Enforces requirements-driven development workflow. TRIGGER when: implementing features, fixing bugs, or making behaviour changes."
---

# Requirements-Driven Development

*Nothing gets implemented without a requirement. Nothing gets committed without verification against requirements.*

## The Workflow

Every behaviour change follows this sequence:

### 1. Requirements First

Before writing any code, confirm which requirement you're addressing. Open `CLAUDE.md` and check `## Requirements`.

- **Requirement exists** — proceed. State which requirement key you're implementing.
- **Requirement is missing** — update `## Requirements` in CLAUDE.md first, then proceed.
- **Requirement needs changing** — update it first, then proceed.

Never implement something that isn't captured in requirements. If the user asks for something not yet in requirements, add it before implementing.

### 2. Write Tests That Express the Requirement

Before implementing, write tests that express the requirement you identified in step 1. The tests should describe what the system does — they are a specification of the requirement in executable form.

Ask yourself: if someone reads only the test output, can they understand the requirement?

### 3. Implement Against Tests

Write code to make the tests pass. Only build what the tests demand.

### 4. Verify Against Requirements

After implementation, cross-check:

- Re-read the requirement in `## Requirements`.
- Does the implementation satisfy it as stated?
- Do the tests cover the requirement's key behaviours?
- Are there edge cases in the requirement that aren't tested?

If anything is missing, go back to step 2.

### 5. Update Mental Model

If the implementation changes how the system works — new concepts, changed lifecycle, different architecture — update `## Mental Model` in CLAUDE.md. The Stop hook will prompt you for this, but do it proactively if you know it's needed.

## Requirements Format

Requirements in `## Requirements` use short descriptive keys (not numbers) and describe what the system does and how it behaves. They cover both functional requirements (what it does) and cross-functional requirements (how it behaves — performance, security, reliability, etc.).

Example:
```markdown
## Requirements

- **stop-hook-review** — on every stop, prompt Claude to check whether CLAUDE.md sections need updating
- **loop-prevention** — skip the review prompt when `stop_hook_active` is true to prevent infinite recursion
- **jq-dependency** — hook requires `jq` on the host system for JSON parsing
```

## Rules

- Never implement without a requirement. Add it first if missing.
- State which requirement you're addressing before writing code.
- Write tests before implementation.
- Verify against the requirement text after implementation.
- Keep requirements in sync — if implementation reveals the requirement was wrong or incomplete, update it.
