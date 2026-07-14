# contree

**[Read the visual intro →](https://elimydlarz.github.io/claude-code-plugins/contree/)** — a one-page explainer aimed at developers new to TDD.

Test trees as living requirements. Combines test-driven development with automatic requirements synchronisation — your test trees in `TEST_TREES.md` ARE the specification, always up to date.

## Not a software factory

contree does not turn a prompt into shipped software while you watch. **You stay in the loop**, working mainly at the level of test trees — the place where intent lives. You start from a vision, not a spec, and discover the exact requirements iteratively: each tree you write or refine sharpens what the system should do, and the implementation follows from it. The trees are where you think and decide; the code is downstream.

What contree gives you is a **very strong harness, bootstrapped for you**: outside-in testing, the trees-as-contract invariant, the skills that route you through change → sync → tdd → second-opinion, and the hooks that keep everything honest. That harness is a general way of working with AI — not tied to any one stack or domain.

It is a foundation, not the whole house. You are still expected to **build your project-level harness on top** — your own fixtures, runners, conventions, and domain detail. contree gets you a rigorous starting point and keeps you honest as you go; the specifics of your project remain yours to develop. Trees name the observable test kind they contract: Journey, System, Component, Adapter, Use-case, Domain, or Port. Journey, System, Component, and Adapter are the operator-facing test layers; Use-case and Domain identify native Unit seams, while Port identifies a shared contract suite. TDD starts outside-in from the current tree's consumer: write one test, observe RED, implement GREEN, then during REFACTOR notice too much branching in the test or tree. Extract some branching into a new unit with a mock and a stub that throws `NotImplemented`. The mock makes the consumer tests pass; the stub makes running code fail loudly. That is the signal to give the unit its own tree and repeat the TDD process from step 1 for it.

## What it does

**Test trees become requirements.** Instead of separate requirement documents and test code, contree puts `when/then` test trees directly in your project's `TEST_TREES.md` at the project root. Every test you write reifies exactly one tree.

Focused skills:

- **`/contree:setup-test-feedback`** — Configures and verifies normal, journey, and impact-selected test feedback.
- **`/contree:setup-linter`** — Installs strong conventional linting, runs autofix, repairs remaining violations, and adds save-time feedback.
- **`/contree:setup-architecture-linter`** — Maps the project's real hexagonal boundaries, enforces them in CI and Stop hooks, and runs the rules immediately.
- **`/contree:fix-architecture`** — Partitions architecture violations across subagents, reconciles their fixes, and reruns every rule until green.
- **`/contree:setup-mental-model`** — Discovers and reconciles the seven-section project theory with you, then installs project-local SessionStart and Stop steering so later agents work from it and keep it current.
- **`/contree:setup-test-trees`** — Discovers and reconciles the behavioural contract with you, then installs project-local SessionStart and Stop steering without implementing the tests.
- **`/contree:bootstrap-test-trees`** — Composes mental-model and test-tree setup, then uses a fresh TDD subagent wave to implement and run exactly one test file per agreed tree.
- **`/contree:setup-mutation-testing`** — Configures fast Domain- and Use-case-test mutation feedback, installs relevant-change incremental Stop feedback, runs the full quality gate, and strengthens tests until the agreed threshold passes.
- **`/contree:setup`** — The comprehensive setup: dynamically orchestrates every missing feedback loop, engages you at consequential decisions, uses subagents for independent work, and verifies the whole steering system before reporting success.
- **`/contree:change`** — Write or modify test trees in `TEST_TREES.md` before any code is written. Auto-triggers when planning behaviour changes.
- **`/contree:tdd`** — Auto-triggers when implementing behaviour. Runs one observable behaviour through RED, GREEN, and REFACTOR; excessive branching moves behind a passing mock and throwing stub, signalling a new TDD cycle for that unit.
- **`/contree:sync`** — Uses subagents to audit every tree leaf, production code area, and mental-model heading, then proactively resolves drift according to operator intention. Suggests `second-opinion` once everything agrees.
- **`/contree:change-without-me`** — Runs change → sync → tdd → second-opinion end-to-end without pausing.
- **`/contree:second-opinion`** — Sends the selected work, or the current worktree by default, and your test-tree contract to OpenAI's gpt-5.6-sol with high reasoning effort for an independent review of database schemas, API contracts, impacts on other systems, and contract compliance. Requires `OPENAI_API_KEY` and fails loudly rather than fabricating a review.
- **`/contree:diff-for-humans`** — Generates a single image explaining the current change to a human with OpenAI's gpt-image-2 model, foregrounding the technical substance it touches (contracts, databases, behaviour, test trees) and choosing what to depict from the nature of the change, its key details, and its audience, then surfaces those choices for review. Run on demand; requires `OPENAI_API_KEY`.

Plus plugin-wide lifecycle hooks and setup-generated project hooks. Contree progressively expands into a project: every focused setup phase preserves earlier hooks and adds another fast feedback loop, so coding agents receive increasingly complete steering while they work.


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

1. Run the focused setup skill for the feedback you need, or `/contree:setup` for the comprehensive operator-guided workflow across tests, lint, architecture, mental-model steering, test-tree steering and bootstrap, and mutation testing
2. When you plan a behaviour change, `/contree:change` writes or modifies test trees first
3. `/contree:tdd` auto-triggers during implementation — outside-in TDD against test trees
4. The stop hook keeps `CLAUDE.md` and `README.md` current after every response
5. Run `/contree:sync` periodically to verify completeness, then `/contree:second-opinion` for an independent review — or `/contree:change-without-me` for the full cycle

## Standardised architecture

contree imposes one architecture on every project, so the harness it bootstraps is the same regardless of stack or domain. It is **hexagonal**: the domain is pure, all I/O lives in adapters, and dependencies point inward toward the domain. Each outbound dependency is a **Port** that ships two implementations — an in-memory twin and a real adapter — both held to one shared contract suite, so the in-memory substitution used by fast tests stays faithful to the real thing.

The operator-facing test layers are:

- **Journey** (`test/journey/*.journey.test.*`) — broad, production-like test of a curated user arc across capabilities.
- **System** (`test/system/*.system.test.*`) — deep, production-like test of one capability through the whole app.
- **Component** (`test/component/*.component.test.*`) — deep in-process test of one capability through the whole app, with external services replaced by test doubles.
- **Adapter** (`*.adapter.test.*`) — test of one concrete boundary implementation against the real boundary it adapts.

Native tests cover the hexagonal seams directly:

- **Use-case** (`*.use-case.test.*`) — exhaustive application orchestration at its public seam.
- **Domain** (`*.domain.test.*`) — exhaustive substantive pure rules at their public seam.
- **Port** (`*.port-contract.test.*`) — one shared contract that every implementation of an outbound application interface must pass.

Development remains outside-in and consumer-driven: start from the current consumer, make one behaviour pass, then move excessive branching behind a mock and a stub that throws `NotImplemented`. Passing consumer tests prove the mock is consumed correctly; the throwing stub shows the new unit is unfinished and must begin its own TDD cycle.

This is the standardised foundation. Your project's own fixtures, runners, and conventions are layered on top of it.

## Test tree format

Trees in `TEST_TREES.md` look like this:

A bookmarks feature can have trees at the scopes its consumers actually need:

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

Use-case: createBookmark (src: src/features/bookmarks/use-cases/create-bookmark.ts; use-case: src/features/bookmarks/use-cases/create-bookmark.use-case.test.ts)
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

### CreateBookmark (Component)

Component: CreateBookmark (src: src/features/bookmarks/create-bookmark.ts; component: test/component/create-bookmark.component.test.ts)
  when an authenticated user submits a bookmark with a valid URL
    then the bookmark is persisted against their library
    and the canonicalised URL is returned to the caller
  if the caller is not authenticated
    then the request is rejected before the store is touched
```

Every tree is consumer-driven. Journey, System, Component, and Adapter trees use the consumer's vocabulary. Domain, Use-case, and Port trees use their own public functions, types, results, and errors. Even a pure function exists because a caller needs to invoke it and observe its result or error. Causal nesting (the duplicate-URL case under successful persistence) keeps dependent behaviour attached to the outcome it depends on.

Each behavioural subject gets its own tree at the test kind its consumer observes. Every tree starts with `<Test-kind>: <Subject>` and names coverage in parenthesised semicolon-separated labelled pairs on the same line. The categories are `src`, `domain`, `use-case`, `adapter`, `component`, `system`, and `journey`. Gaps are declared explicitly: `none` for expected but missing coverage; inapplicable categories are omitted. Every test file's describe/it hierarchy mirrors its tree verbatim.

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

The functional journey suite and two skills call external APIs and read their credentials from the environment where the coding agent runs (export them in your shell, or whatever launches the agent, so its tools inherit them):

- **`OPENAI_API_KEY`** — required by the functional journey suite to run both coding-agent harnesses with OpenAI's gpt-5.6-luna at medium reasoning effort, by `/contree:second-opinion` to call OpenAI's gpt-5.6-sol through the Responses API, and by `/contree:diff-for-humans` to call OpenAI's gpt-image-2. Standard Claude Code journey turns have a $5 budget ceiling.

The key is only needed when you run the functional journey suite or invoke either external-API skill; the rest of contree works without it. Journey launchers inherit an exported key or load it from `contree/test/journey/.env` or the repository-root `.env`.

## Dependencies

- `jq` on the host system (for the stop hook)
