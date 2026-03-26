# contree

Test trees as living requirements. Combines test-driven development with automatic requirements synchronisation — your test trees in `CLAUDE.md` ARE the specification, always up to date.

## What it does

**Test trees become requirements.** Instead of separate requirement documents and test code, contree puts `when/then` test trees directly in your project's `## Requirements` section in `CLAUDE.md`. Every test you write traces back to a requirement tree. Every requirement tree is verified by tests.

Three skills:

- **`/setup-contree`** — Configures your test framework with tree reporters and generates initial requirement trees from your existing codebase (or plans). Run once per project.
- **`tdd`** — Auto-triggers on behaviour changes. Enforces outside-in TDD: confirms requirement tree exists → failing functional test → unit TDD inward → functional passes → updates requirements if needed.
- **`/sync-to-requirements`** — Completes requirement trees to match implementation, then TDDs any gaps closed.

Plus a **stop hook** that prompts Claude to keep requirement trees, mental model, and repo map in `CLAUDE.md` current after every response.

## Install

```sh
claude plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install contree@susu-eng --scope project
```

## How it works

1. Run `/setup-contree` — sets up test framework, generates requirement trees in `CLAUDE.md`
2. When you change behaviour, the `tdd` skill auto-triggers and implements against requirement trees
3. The stop hook keeps `CLAUDE.md` current after every response
4. Run `/sync-to-requirements` periodically to verify completeness

## Requirements format

Requirements in `CLAUDE.md` look like this:

```markdown
## Requirements

### UserRegistration

UserRegistration
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  when the email is already registered
    then registration is rejected
```

Each capability gets its own subsection. Trees describe operating principles (not case enumerations).

## Dependencies

- `jq` on the host system (for the stop hook)
