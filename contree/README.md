# contree

Test trees as living requirements. Combines test-driven development with automatic requirements synchronisation — your test trees in `CLAUDE.md` ARE the specification, always up to date.

## What it does

**Test trees become requirements.** Instead of separate requirement documents and test code, contree puts `when/then` test trees directly in your project's `## Requirements` section in `CLAUDE.md`. Every test you write traces back to a test tree. Every test tree is verified by tests.

Five skills:

- **`/contree:setup`** — Configures your test framework with tree reporters and generates initial test trees from your existing codebase (or plans). Run once per project.
- **`/contree:change`** — Write or modify test trees in `CLAUDE.md` before any code is written. Auto-triggers when planning behaviour changes.
- **`/contree:tdd`** — Auto-triggers when implementing behaviour. Enforces outside-in TDD: confirms test tree exists → failing functional test → unit TDD inward → functional passes.
- **`/contree:sync`** — Audits test trees against implementation, finds gaps and drift, then TDDs any gaps closed.
- **`/contree:workflow`** — Runs change → sync → tdd end-to-end without pausing.

Plus a **stop hook** that prompts Claude to keep test trees, mental model, CLAUDE.md, and README.md current after every response. And a **self-care hook** that reminds you to look at something 20 feet away for 20 seconds every 20 minutes (20-20-20 rule).

## Install

```sh
claude plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install contree@susu-eng --scope project
```

## How it works

1. Run `/contree:setup` — sets up test framework, generates test trees in `CLAUDE.md`
2. When you plan a behaviour change, `/contree:change` writes or modifies test trees first
3. `/contree:tdd` auto-triggers during implementation — outside-in TDD against test trees
4. The stop hook keeps `CLAUDE.md` and `README.md` current after every response
5. Run `/contree:sync` periodically to verify completeness, or `/contree:workflow` for the full cycle

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

## Supported languages

Setup configures tree reporters, test runners, and mutation testing for:

| Language | Tree reporter | Mutation testing |
|---|---|---|
| JavaScript/TypeScript | Vitest, Jest, Mocha | Stryker |
| Python | pytest + pytest-spec | mutmut |
| Ruby | RSpec | mutant |
| Java/Kotlin | JUnit 5 + Gradle/Maven | PIT (pitest) |
| PHP | PHPUnit | Infection |
| C#/.NET | dotnet test | Stryker.NET |
| Go | gotestsum (flat) | go-mutesting (experimental) |
| Rust | cargo nextest (flat) | cargo-mutants |
| Elixir | ExUnit (flat) | — |
| Shell/Bash | Bats (flat) | — |
| Swift | Swift Testing (flat) | — |

Languages marked "flat" don't support nested test output natively — contree uses the best available option and is honest about the limitation.

## Dependencies

- `jq` on the host system (for the stop hook)
