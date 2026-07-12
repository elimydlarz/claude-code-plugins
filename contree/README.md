# contree

**[Read the visual intro →](https://elimydlarz.github.io/claude-code-plugins/contree/)** — a one-page explainer aimed at developers new to TDD.

Test trees as living requirements. Combines test-driven development with automatic requirements synchronisation — your test trees in `TEST_TREES.md` ARE the specification, always up to date.

## Not a software factory

contree does not turn a prompt into shipped software while you watch. **You stay in the loop**, working mainly at the level of test trees — the place where intent lives. You start from a vision, not a spec, and discover the exact requirements iteratively: each tree you write or refine sharpens what the system should do, and the implementation follows from it. The trees are where you think and decide; the code is downstream.

What contree gives you is a **very strong harness, bootstrapped for you**: the outside-in layered testing discipline, the trees-as-contract invariant, the skills that route you through change → sync → tdd → second-opinion, and the hooks that keep everything honest. That harness is a general way of working with AI — not tied to any one stack or domain.

It is a foundation, not the whole house. You are still expected to **build your project-level harness on top** — your own fixtures, runners, conventions, and domain detail. contree gets you a rigorous starting point and keeps you honest as you go; the specifics of your project remain yours to develop. Tests are layered — Journey, System, Component, Adapter, Port contract, Unit — but those kinds are not a prescribed implementation order. TDD starts outside-in from the current tree's consumer: write one test, observe RED, implement GREEN, then during REFACTOR notice too much branching in the test or tree. Extract some branching into a new unit with a mock and a stub that throws `NotImplemented`. The mock makes the consumer tests pass; the stub makes running code fail loudly. That is the signal to give the unit its own tree and repeat the TDD process from step 1 for it.

## What it does

**Test trees become requirements.** Instead of separate requirement documents and test code, contree puts `when/then` test trees directly in your project's `TEST_TREES.md` at the project root. Every test you write reifies exactly one tree.

Seven skills:

- **`/contree:setup`** — Configures your test framework with tree reporters, normal and functional test commands, an impact-selected `test-changed` command and Stop hook, a conventional linter with strong rules, save-time autofix and architecture enforcement through project-level hooks, and creates `TEST_TREES.md` when needed. Run once per project.
- **`/contree:change`** — Write or modify test trees in `TEST_TREES.md` before any code is written. Auto-triggers when planning behaviour changes.
- **`/contree:tdd`** — Auto-triggers when implementing behaviour. Runs one observable behaviour through RED, GREEN, and REFACTOR; excessive branching moves behind a passing mock and throwing stub, signalling a new TDD cycle for that unit.
- **`/contree:sync`** — Uses subagents to audit every tree leaf, production code area, and mental-model heading, then proactively resolves drift according to operator intention. Suggests `second-opinion` once everything agrees.
- **`/contree:workflow`** — Runs change → sync → tdd → second-opinion end-to-end without pausing.
- **`/contree:second-opinion`** — Sends the current change and your test-tree contract to Z.AI's GLM 5.2 with `ZAI_API_KEY`, or to DeepSeek with `DEEPSEEK_API_KEY`, for an independent review of completed work, then surfaces its critique. Fails loudly rather than fabricating a review.
- **`/contree:diff-for-humans`** — Generates a single image explaining the current change to a human with OpenAI's gpt-image-2 model, foregrounding the technical substance it touches (contracts, databases, behaviour, test trees) and choosing what to depict from the nature of the change, its key details, and its audience, then surfaces those choices for review. Run on demand; requires `OPENAI_API_KEY`.

Plus a **stop hook** that prompts Claude to keep test trees, mental model, CLAUDE.md, and README.md current after every response. A **session-start header** with skill directions and coding rules, so the agent starts every session knowing when to reach for each skill.


**Codex CLI:**

1. **Enable hooks** — contree ships with hook scripts (session-start, stop-drift-check, etc.) that only fire if you opt in. Add to `~/.codex/config.toml`:
   ```toml
   [features]
   hooks = true
   plugin_hooks = true

   [shell_environment_policy]
   inherit = "all"

   [plugins."contree@local-marketplace"]
   enabled = true
   ```
2. **Install the plugin** — copy it into Codex's local marketplace cache:
   ```sh
   VERSION=$(jq -r .version contree/.codex-plugin/plugin.json)
   mkdir -p ~/.codex/plugins/cache/local-marketplace/contree/$VERSION
   rsync -a --exclude='.git' contree/ ~/.codex/plugins/cache/local-marketplace/contree/$VERSION/
   ```

Skills run automatically once installed. Hooks require the feature flags above. Codex sets `CLAUDE_PLUGIN_ROOT` in hook command environment so shared scripts run in the same plugin root as Claude Code.

## How it works

1. Run `/contree:setup` — sets up the test framework, normal and functional test commands, impact-selected tests after agent changes, strong linting with project-level autofix and architecture hooks, and creates `TEST_TREES.md` when needed
2. When you plan a behaviour change, `/contree:change` writes or modifies test trees first
3. `/contree:tdd` auto-triggers during implementation — outside-in TDD against test trees
4. The stop hook keeps `CLAUDE.md` and `README.md` current after every response
5. Run `/contree:sync` periodically to verify completeness, then `/contree:second-opinion` for an independent review — or `/contree:workflow` for the full cycle

## Standardised architecture

contree imposes one architecture on every project, so the harness it bootstraps is the same regardless of stack or domain. It is **hexagonal**: the domain is pure, all I/O lives in adapters, and dependencies point inward toward the domain. Each outbound dependency is a **Port** that ships two implementations — an in-memory twin and a real adapter — both held to one shared `*.contract.ts` suite, so the in-memory substitution used by fast tests stays faithful to the real thing.

Tests are **layered outside-in**, each layer owning complete coverage of its own seam:

- **Journey** (`test/journey/*.journey.test.*`) — the outermost layer and outside-in entry point: a curated, max-realism user arc spanning multiple capabilities, kept under 5 minutes.
- **System** (`test/system/*.system.test.*`) — one capability wired whole-app with real infrastructure, interior to the Journey. The same single-capability surface a Component test covers, validated for real; selective, not exhaustive.
- **Component** (`test/component/*.component.test.*`) — one capability wired whole-app with real driving and driven adapters, externals doubled only at the edge — an in-memory database and stubbed outbound HTTP. Runs in-process; carries the exhaustive single-capability behaviour coverage.
- **Adapter** (`*.adapter.test.*`) — one adapter against the real infrastructure it fronts.
- **Use-case** (`*.use-case.test.*`) — orchestration over in-memory ports.
- **Domain** (`*.domain.test.*`) — the pure core, no I/O.

The test kinds define what each test exercises, not an implementation sequence. Development remains outside-in and consumer-driven: start from the current consumer, make one behaviour pass, then move excessive branching behind a mock and a stub that throws `NotImplemented`. Passing consumer tests prove the mock is consumed correctly; the throwing stub shows the new unit is unfinished and must begin its own TDD cycle.

This is the standardised foundation. Your project's own fixtures, runners, and conventions are layered on top of it.

## Test tree format

Trees in `TEST_TREES.md` look like this:

A slice is described by a few small trees, one per hexagonal seam. For a bookmarks feature:

```markdown
### canonicaliseUrl (Domain)

Domain: canonicaliseUrl (src: src/features/bookmarks/domain/canonicalise-url.ts; domain: src/features/bookmarks/domain/canonicalise-url.domain.test.ts)
  canonicaliseUrl
    when the host contains mixed case
      then the host is lower-cased
    when the path has a trailing slash
      then the trailing slash is stripped
    when the URL uses the scheme's default port
      then the port is removed
    if the input cannot be parsed as a URL
      then a ParseError is thrown

### createBookmark (Use-case)

Use-case: createBookmark (src: src/features/bookmarks/use-cases/create-bookmark.ts; use-case: src/features/bookmarks/use-cases/create-bookmark.usecase.test.ts)
  createBookmark
    when called with a valid URL for an authenticated user
      then the URL is canonicalised via the Domain
      and the bookmark is saved through the BookmarkStore port
      and the saved bookmark is returned
      when a bookmark with the same canonical URL already exists for the user
        then the existing bookmark is returned
        and the store is not written to
    if canonicalisation fails
      then a ValidationError is raised before the store is touched

### CreateBookmark (System)

System: CreateBookmark (src: src/features/bookmarks/system/create-bookmark.ts; system: test/system/create-bookmark.system.test.ts)
  when an authenticated user submits a bookmark with a valid URL
    then the bookmark is persisted against their library
    and the canonicalised URL is returned to the caller
  if the caller is not authenticated
    then the request is rejected before the store is touched
```

Every tree is consumer-driven. Outer trees describe what users, API clients, hooks, queues, or other boundary callers observe. Inner trees describe what the outer consumer needs from the unit it forced into existence; even a pure function is introduced because a caller needs to invoke it and observe its result or error. Causal nesting (the duplicate-URL case under successful persistence) keeps dependent behaviour attached to the outcome it depends on.

Each behavioural unit gets its own tree — arc (Journey), slice (System), use-case, port contract, adapter, domain object. Every tree name starts with `<Layer>: <Subject>` and names coverage in parenthesised semicolon-separated labelled pairs on the same line. The categories are `src`, `domain`, `use-case`, `adapter`, `component`, `system`, `journey`. Gaps are declared explicitly: `none` for a category that is expected but uncovered (so readers and `sync` spot it); categories that are genuinely not applicable are omitted. At Journey, System, Component, and Adapter layers, trees describe principles rather than enumerated cases. At Use-case, Domain, and Port layers, trees describe what the outer consumer needs to observe from the unit it has forced into existence. Every test file's describe/it hierarchy mirrors its tree verbatim.

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

## Configuration

Two skills call external APIs and read their credentials from the environment where Claude Code runs (export them in your shell, or whatever launches Claude Code, so its tools inherit them):

- **`ZAI_API_KEY`** or **`DEEPSEEK_API_KEY`** — required by `/contree:second-opinion`; `ZAI_API_KEY` calls Z.AI's GLM 5.2, while `DEEPSEEK_API_KEY` calls DeepSeek. Without either key the skill fails loudly rather than fabricating a review.
- **`OPENAI_API_KEY`** — required by `/contree:diff-for-humans` to call OpenAI's gpt-image-2.

Both are only needed when you invoke the skill that uses them; the rest of contree works without any keys.

## Dependencies

- `jq` on the host system (for the stop hook)
