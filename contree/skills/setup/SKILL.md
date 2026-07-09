---
name: setup
description: "Prepare a project for ongoing test-tree-driven development by configuring the test framework and creating TEST_TREES.md. TRIGGER when: a project has no test framework configured, no TEST_TREES.md at the project root, no mental model, or the user is starting a new project."
---

# Setup Contree

Prepares the project for ongoing test-tree-driven development. Configures the test framework and creates `TEST_TREES.md` when needed.

## Critical Rules

1. **Read before write.** Always read existing config files before modifying them. Never overwrite — merge surgically.
2. **Tree output is non-negotiable.** If a framework can produce nested output, configure it. If it can only produce flat output, use it and be honest.
3. **SessionStart test kinds, always.** Configure the kinds named by the SessionStart hook where the project has that surface:
   - **Journey** — broad, production-like test of a curated user arc across capabilities. `test/journey/`. `*.journey.test.*`.
   - **System** — deep, production-like test of one capability through the whole app. `test/system/`. `*.system.test.*`.
   - **Component** — deep in-process test of one capability through the whole app, with external services replaced by test doubles such as stubbed outbound HTTP. `test/component/`. `*.component.test.*`.
   - **Adapter** — one concrete boundary implementation against the real boundary it adapts. Colocated. `*.adapter.test.*`.
   - **Port contract** — shared contract suite for an application interface; every implementation passes it. Colocated with the port. `*.contract.ts`.
   - **Unit** — one public surface on one subject. Domain units use `*.domain.test.*`; Use-case units use `*.use-case.test.*`.

   See `skills/tdd/SKILL.md` for the full mapping, the in-memory adapter pattern, and the shared port contract suite.
4. **CI dual reporters.** Configure tree output for local dev AND structured output (JUnit XML) for CI. Both, not either/or.
5. **Verify after configuring.** Run the tests and confirm tree-shaped output before moving on.
6. **No test files.** Setup configures the framework and creates the test-tree home. Do NOT create any test files (`*.test.*`, `*.spec.*`). Trees and tests happen after setup.

## Process

### 1. REVIEW

Read project files — source code, existing tests, configs, CLAUDE.md. Understand:

- Language and ecosystem
- Existing test framework and config (if any)
- What behaviours the system implements today
- Whether `TEST_TREES.md` already exists at the project root
- Whether this is a monorepo (check for workspace configs, turborepo.json, nx.json, pnpm-workspace.yaml, Cargo.toml workspaces)

**Detect existing test config.** Check for these files before creating or modifying anything:

| Ecosystem | Config files to check |
|---|---|
| Vitest | `vitest.config.*`, `test` key in `vite.config.*` |
| Jest | `jest.config.*`, `jest` key in `package.json` |
| Mocha | `.mocharc.*`, `mocha` key in `package.json` |
| pytest | `conftest.py`, `pytest.ini`, `[tool.pytest.ini_options]` in `pyproject.toml`, `[tool:pytest]` in `setup.cfg` |
| RSpec | `.rspec`, `spec/spec_helper.rb` |
| Minitest | `test/test_helper.rb` |
| PHPUnit | `phpunit.xml`, `phpunit.xml.dist` |
| Pest | `pest` in `composer.json` |
| JUnit/Gradle | `build.gradle(.kts)` for `testLogging` or test-logger plugin |
| JUnit/Maven | `pom.xml` for surefire/failsafe config |
| Go | Makefile/scripts for `gotestsum` |
| Rust | `.config/nextest.toml` |
| Elixir | `test/test_helper.exs` |
| .NET | `.csproj` for test SDK references |
| Bats | `test/*.bats`, `bats` in `package.json` |

If config exists, **merge into it** — add the reporter setting alongside existing keys. Never replace the file.

### 2. IDENTIFY FRAMEWORKS

Detect existing test framework from project manifests. If none exists, identify the most suitable for the project's language.

When multiple test frameworks are detected, choose the test framework from project evidence and tree-output quality. Ask before choosing the main application framework for a project.

### 3. SUGGEST

Present the chosen test framework with the evidence and tree-output quality behind the choice. If setup would choose the main application framework, ask before proceeding.

### 4. DETERMINE TEST STRATEGY

Confirm how conventions apply to this project:

- Domain tests: colocated with source, `*.domain.test.*`
- Use-case tests: colocated with source, `*.use-case.test.*`
- Adapter tests: colocated with the adapter (driving or driven), `*.adapter.test.*`
- System tests: `test/system/` at project root, `*.system.test.*`
- Journey tests: `test/journey/` at project root, `*.journey.test.*`
- Shared port contract suites: colocated with the port interface, `*.contract.ts` (not a test file — a suite imported by both the in-memory and real adapter tests)
- Tree-style output at every layer

**Language-specific conventions that override defaults:**
- **Rust**: Domain and Use-case tests live inside source (`#[cfg(test)] mod tests`); Adapter (driven), System, and Journey tests live in `tests/` at crate root — this is the language convention
- **Go**: tests are always colocated (`foo_test.go` next to `foo.go`); Adapter (driven) tests use `*_integration_test.go` with `//go:build integration` tags; System and Journey tests live in `test/system/` and `test/journey/` (or `tests/...`) per convention
- **Ruby/RSpec**: separated `spec/` directory is the overwhelming convention — follow it, subdivide by layer (`spec/domain/`, `spec/use_case/`, `spec/adapter/`, `spec/system/`, `spec/journey/`)
- **Python**, **JS/TS**, **PHP**: both colocated and separated patterns work; prefer colocated for Domain, Use-case, Adapter

**Monorepo strategy:**
- Colocated test layers (Domain, Use-case, Adapter): stay with source in each package
- System tests: at monorepo root `test/system/` if they exercise cross-package behaviour, or per-package if they test a single package
- Journey tests: at monorepo root `test/journey/` — they span packages and capabilities by nature
- Never create a single root-level test config that reaches into all packages — follow the monorepo tool's conventions (Turborepo tasks, Nx project graph, pnpm workspace scripts)
- Prefer composed, direct per-package config over inherited base config.

### 5. CONFIGURE INNER TEST RUNNERS

Configure the Domain, Use-case, and Adapter layers as separate projects/configurations in the test runner. See the Framework Reference below for the Vitest projects example.

**Do NOT skip. Do NOT rely on defaults. Do NOT overwrite existing config — merge into it.**

If the config already has a `reporters` or `verbose` key, check whether changing it would break CI (e.g., removing a JUnit XML reporter). Present the conflict to the user rather than silently overwriting.

### 6. CONFIGURE SYSTEM AND JOURNEY TEST RUNNERS

Two functional layers, each its own command/config:

- **System** — `test/system/`, `*.system.test.*` — whole app for a single capability
- **Journey** — `test/journey/`, `*.journey.test.*` — the multi-capability user arc, the outside-in entry point
- **Component** — `test/component/`, `*.component.test.*` — one capability in-process with real driving and driven adapters; needs no external services because externals are doubled at the edge, such as an in-memory database and stubbed outbound HTTP.
- Both wire **real driven adapters** at the highest tolerable realism — never in-memory at these layers. Speed for combinatorial breadth comes from the cheap Use-case and Component layers, not from diluting these into in-memory tests.
- Journey tests exercise real everything across the multi-capability arc at max realism.
- exhaustive single-capability breadth belongs at the Use-case and Component layers.
- Tree-style output; runnable independently from the inner layers and from each other
- Higher timeouts — they assemble the whole app; the Journey is the slowest
- Where real infrastructure is heavy, gate the heaviest runs behind a separate command (pre-release, not per-push) — but keep them real; do not substitute in-memory wiring to make them cheap

**Determine whether a Docker harness is needed.** See the Docker Harness Reference below. Key question: do Adapter (driven), System, or Journey tests need external processes — databases, queues, HTTP servers? If yes, set up a Docker Compose harness. If the software is pure in-process, Docker is unnecessary.

When configuring Docker:
- `docker-compose.yml` lives at project root (or `test/system/docker-compose.yml` if the project root is already crowded)
- Real-infra test scripts start compose, wait for readiness, run tests, tear down
- Add a `test:system:real` script (or `test:adapter:real`) that orchestrates the full lifecycle
- Never assume Docker services are already running — the harness must be self-contained

### 7. CONFIGURE MUTATION TESTING

Install appropriate mutation testing tool (see Mutation Testing Reference below). Configure with:

- Mutator targeting source files, **explicitly excluding test files** — if tests are colocated, the exclusion globs must match the naming convention exactly (e.g., `!src/**/*.domain.test.*`, `!src/**/*.use-case.test.*`, `!src/**/*.adapter.test.*`, `!src/**/*.contract.ts`). For TypeScript projects, include the precise layer suffixes: `!src/**/*.domain.test.ts`, `!src/**/*.use-case.test.ts`, `!src/**/*.adapter.test.ts`, `!src/**/*.component.test.ts`, `!src/**/*.system.test.ts`, `!src/**/*.journey.test.ts`, `!test/**/*.component.test.ts`, `!test/**/*.system.test.ts`, `!test/**/*.journey.test.ts`, and `!src/**/*.contract.ts`.
- Domain and Use-case test runners only (Adapter and System tests are too slow for mutation testing)
- Thresholds: `high: 80, low: 60, break: 50`
- Incremental mode where available (stores state between runs for speed)
- Add script/command (e.g., `npm run test:mutate`)

### 8. CONFIGURE ARCHITECTURAL LINTER

Contree prescribes hexagonal architecture: domain is pure, I/O lives in adapters, dependencies point inward. Install a linter that enforces this so boundary violations break the build rather than the review.

The enforced rules are: Domain has no I/O, use-cases depend on ports/interfaces and not concrete adapters, and circular dependencies are rejected.

**For JS/TS projects** — install dependency-cruiser:

```bash
pnpm add -D dependency-cruiser
```

Write `.dependency-cruiser.cjs` at the project root:

```javascript
module.exports = {
  forbidden: [
    {
      name: 'domain-pure',
      severity: 'error',
      from: { path: 'src/.+/domain/' },
      to: { path: 'src/.+/(adapters|application)/' },
    },
    {
      name: 'use-case-no-adapter',
      severity: 'error',
      from: { path: 'src/.+/application/' },
      to: { path: 'src/.+/adapters/' },
    },
    {
      name: 'no-circular',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
  ],
  options: {
    tsConfig: { fileName: 'tsconfig.json' },
  },
};
```

Add a script and wire it into the project's lint command:

```json
{
  "scripts": {
    "lint:arch": "depcruise src --config .dependency-cruiser.cjs",
    "lint": "... && pnpm lint:arch"
  }
}
```

Ensure CI runs `pnpm lint` (or `pnpm lint:arch` directly) so architectural violations fail builds.

**For non-JS/TS projects** — recommend the language-native equivalent. Don't attempt to install without a template; tell the user the rules they need to enforce (no imports from domain into adapters; no imports from application into adapters) and name the tool:

| Language | Tool |
|---|---|
| Java / Kotlin | ArchUnit |
| Go | `go list` + `depguard` |
| Python | `import-linter` |
| Rust | `cargo-modules` with CI assertions |

State the limitation honestly: without contree-provided config, the user wires the rules themselves.

### 9. SET UP CHANGED-TEST RUNNERS

Configure commands to run only tests affected by recent changes. Be aware of the gotchas — several "changed" flags silently run zero tests in common situations.

**Framework-native support:**

| Framework | Command | Gotcha |
|---|---|---|
| Vitest | `--changed` | Only tracks changed source files, NOT changed test files. If you edit a test without changing source, zero tests run. Use `--watch` for local TDD instead. |
| Jest | `--onlyChanged` / `-o` | Uses `git status` — after committing, nothing is "changed" and zero tests run. Useless in CI. |
| Jest | `--changedSince=main` | CI-appropriate. Requires `git fetch origin main` first (shallow clones break it). Use `origin/main` not `main`. |
| pytest | `pytest-testmon` | Tracks dependencies via coverage.py. First run builds the map (slower). `.testmondata` goes in `.gitignore`. |
| pytest | `--last-failed` | Built-in. Re-runs failures from previous run. Good complement to testmon. |
| RSpec | `--only-failures` | Requires `example_status_persistence_file_path` in spec_helper. |
| Go | `gotestsum --watch` | File watcher, re-runs on save. No git-aware mode. |
| Rust | `cargo nextest run` + watchexec | No built-in changed mode. Use `watchexec -e rs -- cargo nextest run`. |

**For local TDD**: prefer file watchers (`vitest --watch`, `gotestsum --watch`, `guard-rspec`, `watchexec`) over git-based `--changed` flags. Watchers are more reliable during rapid red-green cycles.

**For CI**: use branch-comparison flags (`--changedSince=origin/main`, `nx affected:test`, `turbo run test --filter=...[origin/main]`). Ensure adequate git fetch depth.

Commands should be simple to invoke — package.json scripts, Makefile targets, or mix aliases.

### 10. CREATE TEST_TREES.md

Create `TEST_TREES.md` at the project root if it does not already exist, containing a short header noting that the file holds the project's test trees and that new trees should be added as `###` subsections using EARS patterns.

**Do not compose the trees yourself in this step.** Setup prepares the project. It does not define requirements.

**Do not create any `*.test.*` or `*.spec.*` files in this step**, not even with `.todo`/`.skip` stubs. Tests are the `tdd` skill's output.

### 11. UPDATE CLAUDE.md

Add or update the following sections:

- A pointer line identifying `TEST_TREES.md` as the definition of the project's test trees. If `CLAUDE.md` already references `TEST_TREES.md`, do not duplicate the pointer.
- Testing commands section with:
  - Command to run Domain tests with tree output
  - Command to run Use-case tests with tree output
  - Command to run Adapter tests with tree output (driving and driven)
  - Command to run System tests with tree output (real driven adapters at the highest tolerable realism)
  - Command to run Journey tests with tree output (the full multi-capability arc at max realism)
  - Command to run only changed tests at each layer
  - Command to run mutation testing (Domain + Use-case only)
  - Outside-in TDD workflow summary
  - Example tree structure for this project

Configured examples must follow the SessionStart rules: no copied comments, no env-var behaviour switches, and strong preference for composition over inheritance. Environment variables remain appropriate for secrets and external connection details because they configure boundaries rather than changing test/runtime behaviour.

### 12. SCAFFOLD MENTAL_MODEL.md

**This step is mandatory. Do not skip it.** If `MENTAL_MODEL.md` does not exist at the project root, create it now — before VERIFY — with exactly seven H2 sections.

If `MENTAL_MODEL.md` already exists, leave it alone — its content is authoritative and must not be modified.

The seven H2 sections, in order, each followed by a one-line placeholder describing what belongs there:

1. `## Core Domain Identity`
2. `## World-to-Code Mapping`
3. `## Ubiquitous Language`
4. `## Bounded Contexts`
5. `## Invariants`
6. `## Decision Rationale`
7. `## Temporal View`

The placeholders are replaced as the project accrues real content; their purpose is to make the expected contents of each section legible without content yet.

Then add a pointer line to `CLAUDE.md` identifying `MENTAL_MODEL.md` as the definition of the project's mental model. If `CLAUDE.md` already references `MENTAL_MODEL.md`, do not duplicate the pointer.

### 13. VERIFY

Run each layer's test suite and confirm tree-shaped output at each layer:

- Domain (`*.domain.test.*`) — tree-shaped (or best available for the language)
- Use-case (`*.use-case.test.*`) — tree-shaped
- Adapter (`*.adapter.test.*`) — tree-shaped
- System (`*.system.test.*`) — tree-shaped
- Journey (`*.journey.test.*`) — tree-shaped
- Mutation testing runs and produces a score report

**Do NOT create test files to verify the reporter.** If no tests exist yet, the empty suite's output (no tests found, reporter-formatted) is sufficient evidence that the reporter is wired correctly. Writing smoke tests or stubs violates rule #6 and rule #3 above (No fake code). The `tdd` skill writes tests later, from the trees.

---

## EARS Patterns

Test trees use EARS (Easy Approach to Requirements Syntax) to choose the right keyword for each requirement. Match the pattern to the requirement's nature — don't force everything into `when/then`.

**Ubiquitous** — always true, no condition:
```
then <outcome>
```

**State-driven** — active while a condition holds:
```
while <precondition>
  then <outcome>
```

**Event-driven** — response to a trigger:
```
when <trigger>
  then <outcome>
```

**Optional feature** — applies only when a feature is present:
```
where <feature>
  then <outcome>
```

**Unwanted behaviour** — response to error or undesired situation:
```
if <condition>
  then <outcome>
```

**Complex** — state + event combined:
```
while <precondition>
  when <trigger>
    then <outcome>
```

**Causal nesting** — when a trigger can only occur as a consequence of a prior outcome, nest it under that outcome:
```
when <trigger>
  then <outcome>
    when <consequence of outcome>
      then <next outcome>
```

A `when` that depends on a preceding `then` is not a sibling — it is a child. If "refresh fails" can only happen because "refresh was attempted", nest it under the `then` that attempts the refresh.

Choose the pattern that fits: a system constraint is ubiquitous; a precondition that must hold is state-driven; a discrete trigger is event-driven; an error case is unwanted behaviour; a feature flag is optional. Combine when needed. Nest when one behaviour depends on another's outcome.

---

## Framework Reference

### Tree Output Support

**True tree output** (nested indentation): Vitest, Jest, Mocha, RSpec, Gradle test-logger-plugin (mocha theme), Maven tree-reporter
**Partial tree** (one level grouping): pytest-spec, PHPUnit testdox, Pest testdox, Minitest SpecReporter
**Flat only** (no nesting model): Go, Rust, Elixir (ExUnit), Bats, Swift, .NET CLI

---

### JavaScript/TypeScript — Vitest

**Tree reporter:**
```ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    reporters: ['tree', 'junit'],
    outputFile: { junit: './reports/junit.xml' },
  },
})
```

**Separating the six test layers** — use Vitest projects (replaces deprecated `vitest.workspace.ts` in v3.2+). One project per layer: `domain`, `use-case`, `component`, `adapter`, `system`, `journey`. Same pattern shown below — adjust `include` globs and timeouts per layer. Adapter (driven), System, and Journey (real infra) may need much higher timeouts than Domain/Use-case/Component:
```ts
export default defineConfig({
  test: {
    reporters: ['tree', 'junit'],
    outputFile: { junit: './reports/junit.xml' },
    projects: [
      {
        test: {
          name: 'domain',
          include: ['src/**/*.domain.test.{ts,js}'],
        },
      },
      {
        test: {
          name: 'use-case',
          include: ['src/**/*.use-case.test.{ts,js}'],
        },
      },
      {
        test: {
          name: 'adapter',
          include: ['src/**/*.adapter.test.{ts,js}'],
          testTimeout: 30_000,
          hookTimeout: 30_000,
        },
      },
      {
        test: {
          name: 'component',
          include: ['test/component/**/*.component.test.{ts,js}'],
        },
      },
      {
        test: {
          name: 'system',
          include: ['test/system/**/*.system.test.{ts,js}'],
          testTimeout: 30_000,
          hookTimeout: 30_000,
        },
      },
      {
        test: {
          name: 'journey',
          include: ['test/journey/**/*.journey.test.{ts,js}'],
          testTimeout: 60_000,
          hookTimeout: 60_000,
        },
      },
    ],
  },
})
```

**Scripts:**
```json
{
  "test": "vitest run",
  "test:domain": "vitest run --project domain",
  "test:use-case": "vitest run --project use-case",
  "test:adapter": "vitest run --project adapter",
  "test:component": "vitest run --project component",
  "test:system": "vitest run --project system",
  "test:journey": "vitest run --project journey",
  "test:changed": "vitest run --changed",
  "test:watch": "vitest",
  "test:mutate": "stryker run"
}
```

**Gotchas:**
- `reporters` is root-level only — setting it inside a `projects[*].test` block is silently ignored
- `--changed` uses the import graph but only tracks changed source files, not changed test files — use `--watch` for local TDD
- `vitest.workspace.ts` is deprecated since v3.2 — use the `projects` array inside `vitest.config.ts`

---

### JavaScript/TypeScript — Jest

**Tree reporter:**
```ts
import type { Config } from 'jest'

const config: Config = {
  verbose: true,
  reporters: [
    'default',
    ['jest-junit', {
      outputDirectory: 'reports',
      outputName: 'junit.xml',
    }],
  ],
  projects: [
    {
      displayName: 'domain',
      testMatch: ['<rootDir>/src/**/*.domain.test.{ts,js}'],
      transform: { '^.+\\.tsx?$': 'ts-jest' },
      testEnvironment: 'node',
    },
    {
      displayName: 'system',
      testMatch: ['<rootDir>/test/system/**/*.system.test.{ts,js}'],
      transform: { '^.+\\.tsx?$': 'ts-jest' },
      testEnvironment: 'node',
      testTimeout: 30_000,
    },
  ],
}

export default config
```

**Scripts:**
```json
{
  "test": "jest",
  "test:domain": "jest --selectProjects domain",
  "test:system": "jest --selectProjects system",
  "test:changed": "jest --changedSince=origin/main",
  "test:mutate": "stryker run"
}
```

Add one project per layer — domain, use-case, component, adapter, system, journey — as shown for Vitest above.

**Gotchas:**
- `verbose` and `reporters` are shared across all projects — you cannot set them per-project
- `displayName` is required for `--selectProjects` and `--ignoreProjects` to work
- `--onlyChanged` uses `git status` — after committing, zero tests run; use `--changedSince=origin/main` for CI
- `--changedSince` requires the base branch to be fetchable — in CI run `git fetch --no-tags --depth=1 origin main` first, then use `origin/main` (not `main`)
- Stryker's Jest runner crashes when Jest `projects` is configured — if using Stryker with Jest projects, you may need a separate jest.config for Stryker that targets Domain + Use-case tests only without the projects array
- Do NOT install `ts-jest` if the project uses Vitest (which handles TypeScript natively)

---

### JavaScript/TypeScript — Mocha

**Tree reporter:**
```yaml
reporter: spec
require:
  - tsx
recursive: true
timeout: 5000
extension:
  - ts
  - js
```

**Separating test suites** — use separate config files:

`.mocharc.domain.yml`:
```yaml
require: [tsx]
spec: 'src/**/*.domain.test.{ts,js}'
reporter: spec
parallel: true
jobs: 4
timeout: 5000
```

`.mocharc.system.yml`:
```yaml
require: [tsx]
spec: 'test/system/**/*.system.test.{ts,js}'
reporter: spec
parallel: false
timeout: 30000
```

**Scripts:**
```json
{
  "test:domain": "mocha --config .mocharc.domain.yml",
  "test:system": "mocha --config .mocharc.system.yml",
  "test:mutate": "stryker run"
}
```

Add one project per layer — domain, use-case, component, adapter, system, journey — as shown for Vitest above.

**Gotchas:**
- No built-in `--changed` flag — use file watcher or script: `mocha $(git diff --name-only -- '*.test.ts')`
- Parallel mode: root hooks from one test file are NOT available in another worker — use `--require` with a root hook plugin file
- `spec` reporter works correctly in parallel mode

---

### JavaScript/TypeScript — Stryker Mutation Testing

**Install** (pick the runner matching your test framework):
```bash
pnpm add -D @stryker-mutator/core @stryker-mutator/vitest-runner
pnpm add -D @stryker-mutator/jest-runner
pnpm add -D @stryker-mutator/mocha-runner
pnpm add -D @stryker-mutator/typescript-checker
```

**Vitest runner config:**
```js
export default {
  testRunner: 'vitest',
  vitest: {
    configFile: 'vitest.config.ts',
    dir: '.',
    related: true,
  },

  mutate: [
    'src/**/*.ts',
    '!src/**/*.test.ts',
    '!src/**/*.spec.ts',
    '!src/**/*.domain.test.ts',
    '!src/**/*.use-case.test.ts',
    '!src/**/*.adapter.test.ts',
    '!src/**/*.component.test.ts',
    '!src/**/*.system.test.ts',
    '!src/**/*.journey.test.ts',
    '!test/**/*.component.test.ts',
    '!test/**/*.system.test.ts',
    '!test/**/*.journey.test.ts',
    '!src/**/*.contract.ts',
    '!src/**/*.d.ts',
  ],

  coverageAnalysis: 'perTest',

  reporters: ['clear-text', 'progress', 'html'],
  htmlReporter: { fileName: 'reports/mutation/index.html' },

  thresholds: { high: 80, low: 60, break: 50 },

  incremental: true,
  incrementalFile: 'reports/stryker-incremental.json',

  checkers: ['typescript'],
  tsconfigFile: 'tsconfig.json',

  concurrency: 4,
  timeoutMS: 10_000,
  timeoutFactor: 1.5,
  ignoreStatic: true,
}
```

**Jest runner config** — same structure but:
```js
  testRunner: 'jest',
  jest: {
    projectType: 'custom',
    configFile: 'jest.config.ts',
    enableFindRelatedTests: true,
  },
```

**Mocha runner config** — same structure but:
```js
  testRunner: 'mocha',
  mochaOptions: {
    spec: ['src/**/*.domain.test.ts'],
    config: '.mocharc.domain.yml',
    require: ['tsx'],
    timeout: 10_000,
    ui: 'bdd',
  },
```
Note: Mocha runner does NOT reliably support `coverageAnalysis: 'perTest'` — use `'all'` when `perTest` errors in this runner.

**Gotchas:**
- The runner plugin MUST match the test framework — `@stryker-mutator/vitest-runner` for Vitest, `jest-runner` for Jest, etc. Mismatching silently fails or crashes.
- `vitest.related: true` and `jest.enableFindRelatedTests: true` are critical for performance — without them Stryker runs ALL tests for every mutant
- `coverageAnalysis: 'perTest'` is the most efficient option — `'all'` re-runs the full suite per mutant
- `ignoreStatic: true` skips mutants in `const x = 'hello'` at module scope — these are killed by every importing test, slow and low value
- `thresholds.break` has no CI gate by default — set it to enforce one
- For the TypeScript checker, install `@stryker-mutator/typescript-checker`

---

### Python

**Tree reporter — pytest-spec + pytest-describe:**
```bash
pip install pytest-spec pytest-describe
```

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--spec --strict-markers"

describe_prefixes = ["describe_", "context_", "when_"]

spec_header_format = "{module_path}:"
spec_test_format = "{result} {name}"
spec_success_indicator = "+"
spec_failure_indicator = "-"
spec_skipped_indicator = "?"

markers = [
    "domain: Fast isolated domain-layer tests",
    "system: Whole-app system tests against real infra",
    "slow: Tests taking >5s",
]
strict_markers = true
```

**pytest-describe** enables nested describe/context blocks:
```python
def describe_wallet():
    def describe_after_deposit():
        def it_has_the_deposited_amount(wallet):
            assert wallet.balance == 100
```

**pytest-spec** formats the output as indented tree. They compose — use both together for best results.

**Separating domain and system tests:**
```
tests/
  domain/
    conftest.py
    test_models.py
  system/
    conftest.py
    test_api.py
  conftest.py
```

Auto-mark by directory in `tests/domain/conftest.py`:
```python
import pytest
def pytest_collection_modifyitems(items):
    for item in items:
        item.add_marker(pytest.mark.domain)
```

Run independently:
```bash
pytest tests/domain/
pytest tests/system/
```

**Changed-test runner — pytest-testmon:**
```bash
pip install pytest-testmon
```
```bash
pytest --testmon
pytest --last-failed
```
`.testmondata` goes in `.gitignore` — it is machine-specific.

**Mutation testing — mutmut:**
```bash
pip install mutmut
```

```toml
[tool.mutmut]
paths_to_mutate = ["src/"]
tests_dir = ["tests/"]
runner = "python -m pytest -x --tb=short -q"
do_not_mutate = [
    "src/*/migrations/*",
    "src/*/config.py",
]
mutate_only_covered_lines = true
```

```bash
mutmut run
mutmut run "src/myapp/models*"
mutmut browse
```

**Gotchas:**
- pytest-spec conflicts with `-v`/`--verbose` — use `--spec` instead, not both
- mutmut v3 was a major rewrite — `mutmut html` is gone, use `mutmut browse` (TUI)
- mutmut has no built-in threshold enforcement — parse results in CI script
- `mutate_only_covered_lines = true` is critical for speed on large codebases
- For unittest-based projects: pytest discovers and runs `unittest.TestCase` natively — get tree output by running unittest tests through pytest with pytest-spec

---

### Ruby

**Tree reporter — RSpec:**
```
--format documentation
--color
--order random
--require spec_helper
```

The `documentation` formatter prints nested `describe`/`context`/`it` blocks as indented text.

**Separating spec directories:**
```ruby
RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/system/}) do |metadata|
    metadata[:system] = true
  end
  config.define_derived_metadata(file_path: %r{/spec/domain/}) do |metadata|
    metadata[:domain] = true
  end
  config.example_status_persistence_file_path = "spec/examples.txt"
end
```

Run by tag:
```bash
rspec --tag domain
rspec --tag system
rspec --only-failures
rspec --next-failure
```

**File watching** — guard-rspec:
```ruby
gem 'guard-rspec', require: false
```

**Mutation testing — mutant:**
```ruby
group :development, :test do
  gem 'mutant'
  gem 'mutant-rspec'
end
```

```bash
bundle exec mutant run --include lib --require my_project --integration rspec -- 'MyApp::User'
bundle exec mutant run --include lib --require my_project --integration rspec -- 'MyApp::User#valid?'
```

Mutant is the gold standard for Ruby mutation testing — mature, actively maintained (v0.14+). Works best on focused classes/modules rather than entire codebases at once. Test selection uses longest RSpec example group description prefix match.

**Minitest note:** If the project uses Minitest, `minitest-reporters` with `SpecReporter` gives one level of grouping (class > test) but not true nesting. If tree output matters, recommend RSpec.

---

### Go

**Best available output — gotestsum:**
```bash
go install gotest.tools/gotestsum@latest
```

```bash
gotestsum --format testdox ./...
gotestsum --format testname ./...
gotestsum --format testdox --watch ./...
gotestsum --junitfile results.xml ./...
```

`testdox` output groups by package, then lists tests as sentences — one level deep. Go's test model has no describe/context nesting, so no tool can produce a deep tree. Be honest about this.

**Separating unit and integration tests — build tags:**
```go

package myapp
```

```bash
go test ./...
go test -tags=integration ./...
```

Critical: `-tags=integration` runs tagged AND untagged files. To run ONLY integration tests, also tag unit tests with `//go:build !integration`, or use the `-short` convention:

```go
func TestSlowIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }
}
```

```bash
go test -short ./...
go test ./...
```

**Mutation testing — gremlins:**
```bash
go install github.com/go-gremlins/gremlins/cmd/gremlins@latest
```

```bash
gremlins unleash
gremlins unleash --tags=unit
```

Gremlins (v0.6+, actively maintained) is the best Go mutation tool available. Supports arithmetic, conditionals, increment/decrement mutations. Limitation: runs full test suite per mutation, so impractical for large monolithic modules. Works well for microservice-sized modules (which is most Go code).

**Alternatives:** `go-mutesting` (original abandoned; Avito fork has sporadic maintenance) — prefer gremlins.

---

### Rust

**Best available output — cargo nextest:**
```bash
cargo install cargo-nextest --locked
```

```toml
[profile.default]
test-threads = "num-cpus"
fail-fast = true
slow-timeout = { period = "60s", terminate-after = 2 }
status-level = "pass"
failure-output = "immediate"
success-output = "never"

[profile.ci]
fail-fast = false
failure-output = "immediate-final"

[profile.ci.junit]
path = "target/nextest/ci/junit.xml"
```

```bash
cargo nextest run
cargo nextest run --lib
cargo nextest run -E 'kind(test)'
cargo nextest run --profile ci
```

cargo nextest is a strict upgrade over `cargo test` — each test runs in its own process (better isolation), parallel by default, better failure output. Only limitation: cannot run doctests (use `cargo test --doc` separately).

Output is flat — module paths, not nested indentation. Rust's `#[test]` model has no describe/context hierarchy. Be honest about this.

**Test separation** follows Rust conventions:
- Unit tests: `#[cfg(test)] mod tests` inside source files — access private items
- Integration tests: `tests/` directory at crate root — separate crates, public API only

```bash
cargo nextest run --lib
cargo nextest run -E 'kind(test)'
```

**Mutation testing — cargo-mutants:**
```bash
cargo install --locked cargo-mutants
```

```toml
test_tool = "nextest"
```

Add an explicit speed-optimised profile in `Cargo.toml`:
```toml
[profile.mutants]
debug = false
```

```bash
cargo mutants
cargo mutants -f "src/user.rs"
cargo mutants -F "validate"
cargo mutants --shard 1/4
cargo mutants --profile=mutants
```

cargo-mutants (v1.1+, actively maintained) is the most mature Rust mutation tool. Replaces function bodies with default return values, deletes match arms, replaces operators. Works on any stable compiler (no nightly required).

---

### Elixir

**Best available output — ExUnit trace mode:**
```elixir
ExUnit.start(trace: true)
```

Or: `mix test --trace`

Trace mode sets `max_cases: 1` (serial), prints each module and test name. Output is flat — describe block names are prepended to test names as string prefixes, no visual indentation.

**Describe blocks** are limited to ONE level of nesting — ExUnit forbids nested describe by design. Composition happens through named setup functions:
```elixir
describe "when empty" do
  setup [:create_empty_order]
  test "is not ready", %{order: order} do
    refute Order.ready?(order)
  end
end
```

**Test separation — tags:**
```elixir
ExUnit.start(trace: true, exclude: [:integration])
```

```elixir
@moduletag :integration
```

```bash
mix test
mix test --include integration
mix test --only integration
```

**Mix aliases** for convenience in `mix.exs`:
```elixir
defp aliases do
  [
    "test.unit": ["test --exclude integration"],
    "test.integration": ["test --only integration"],
  ]
end
```

**Mutation testing:** No mature tool exists. Muzak and Exavier are both unmaintained. For similar confidence, use property-based tests with StreamData instead. Be honest about this limitation.

---

### PHP

**PHPUnit — testdox config:**
```xml
<phpunit testdox="true" colors="true">
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Functional">
            <directory>tests/Functional</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory>src</directory>
        </include>
    </source>
</phpunit>
```

Testdox groups by class and converts camelCase to sentences — one level deep (class > test). No nested describe in PHPUnit.

```bash
vendor/bin/phpunit --testsuite=Unit
vendor/bin/phpunit --testsuite=Functional
```

**Pest PHP alternative:** If the project uses Pest (v3+), it supports `describe`/`it` blocks and has built-in mutation testing:
```bash
./vendor/bin/pest
./vendor/bin/pest --mutate
./vendor/bin/pest --mutate --min=80
```

Pest v3's built-in mutation testing is a significant advantage over managing Infection separately.

**Infection** (if not using Pest):
```json5
{
    "source": {
        "directories": ["src"],
        "excludes": ["Config", "Migrations"]
    },
    "timeout": 10,
    "threads": "max",
    "logs": {
        "text": "infection.log",
        "html": "infection.html",
        "summary": "summary.log"
    },
    "minMsi": 50,
    "minCoveredMsi": 80,
    "testFramework": "phpunit",
    "testFrameworkOptions": "--testsuite=Unit"
}
```

```bash
vendor/bin/infection --threads=max --show-mutations
vendor/bin/infection --git-diff-lines
```

---

### Java/Kotlin — Gradle

**Tree reporter — gradle-test-logger-plugin:**
```kotlin
plugins {
    id("com.adarshr.test-logger") version "4.0.0"
}

testlogger {
    theme = com.adarshr.gradle.testlogger.theme.ThemeType.MOCHA
    showExceptions = true
    showStackTraces = true
    showPassed = true
    showSkipped = true
    showFailed = true
    slowThreshold = 2000
}
```

The `MOCHA` theme produces nested tree output from `@Nested` JUnit 5 test classes. Use `MOCHA_PARALLEL` when `maxParallelForks > 1`.

**Separating test source sets** — JVM Test Suite Plugin (built-in since Gradle 7.3):
```kotlin
testing {
    suites {
        val test by getting(JvmTestSuite::class) {
            useJUnitJupiter()
        }
        val systemTest by registering(JvmTestSuite::class) {
            useJUnitJupiter()
            dependencies {
                implementation(project())
            }
            targets {
                all {
                    testTask.configure { shouldRunAfter(test) }
                }
            }
        }
    }
}

tasks.named("check") {
    dependsOn(testing.suites.named("systemTest"))
}
```

Run: `./gradlew test` (the fast colocated layers) vs `./gradlew systemTest`.

**JUnit 5 @Nested for tree structure:**
```java
class OrderTest {
    @Nested class WhenEmpty {
        @Test void isNotReady() { }
        @Nested class AfterAddingItem {
            @Test void isReady() { }
        }
    }
}
```

**Mutation testing — PIT (pitest):**
```kotlin
plugins {
    id("info.solidsoft.pitest") version "1.19.0-rc.3"
}

pitest {
    pitestVersion.set("1.19.1")
    junit5PluginVersion.set("1.2.3")
    targetClasses.set(setOf("com.example.*"))
    targetTests.set(setOf("com.example.*Test"))
    threads.set(4)
    outputFormats.set(setOf("HTML", "XML"))
    timestampedReports.set(false)
    mutationThreshold.set(50)
}
```

Run: `./gradlew pitest`. Incremental: `./gradlew pitest` caches results between runs.

**Kotest note (Kotlin):** Kotest has expressive spec DSLs (DescribeSpec, BehaviorSpec) but when run via Gradle's JUnit Platform runner, output is flat paths, not indented tree. JUnit 5 `@Nested` + gradle-test-logger-plugin gives better CLI tree output.

---

### Java/Kotlin — Maven

**Tree reporter — maven-surefire-junit5-tree-reporter:**
```xml
<plugin>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.5.3</version>
    <dependencies>
        <dependency>
            <groupId>me.fabriciorby</groupId>
            <artifactId>maven-surefire-junit5-tree-reporter</artifactId>
            <version>1.5.1</version>
        </dependency>
    </dependencies>
    <configuration>
        <reportFormat>plain</reportFormat>
        <consoleOutputReporter>
            <disable>true</disable>
        </consoleOutputReporter>
        <statelessTestsetInfoReporter
            implementation="org.apache.maven.plugin.surefire.extensions.junit5.JUnit5StatelessTestsetInfoTreeReporter">
            <theme>UNICODE</theme>
        </statelessTestsetInfoReporter>
    </configuration>
</plugin>
```

**Critical:** Pin surefire to 3.5.3 — the tree reporter v1.5.1 is incompatible with surefire 3.5.4+.

Use `maven-failsafe-plugin` (same config pattern) for functional/integration tests (`*IT.java`).

**PIT for Maven:**
```xml
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <version>1.19.1</version>
    <dependencies>
        <dependency>
            <groupId>org.pitest</groupId>
            <artifactId>pitest-junit5-plugin</artifactId>
            <version>1.2.3</version>
        </dependency>
    </dependencies>
    <configuration>
        <targetClasses><param>com.example.*</param></targetClasses>
        <targetTests><param>com.example.*Test</param></targetTests>
        <threads>4</threads>
        <mutationThreshold>50</mutationThreshold>
        <timestampedReports>false</timestampedReports>
    </configuration>
</plugin>
```

Run: `mvn org.pitest:pitest-maven:mutationCoverage`
Incremental (only changed code): `mvn org.pitest:pitest-maven:scmMutationCoverage`

---

### C# / .NET

**Output:** `dotnet test` output is flat in ALL verbosity modes — it lists `Namespace.Class.Method PASSED` one per line. There is no nested indentation in the CLI. True tree output only exists in Visual Studio/Rider GUIs.

```bash
dotnet test --logger "console;verbosity=detailed"
dotnet test --logger "trx"
```

**Test separation** — separate `.csproj` projects:
```
tests/
  MyApp.UnitTests/MyApp.UnitTests.csproj
  MyApp.FunctionalTests/MyApp.FunctionalTests.csproj
```

```bash
dotnet test tests/MyApp.UnitTests/
dotnet test tests/MyApp.FunctionalTests/
```

**Mutation testing — Stryker.NET:**
```bash
dotnet tool install -g dotnet-stryker
```

```json
{
    "stryker-config": {
        "solution": "MyApp.sln",
        "test-projects": ["tests/MyApp.UnitTests/MyApp.UnitTests.csproj"],
        "mutate": ["**/*.cs", "!**/obj/**", "!**/bin/**", "!**/Migrations/**"],
        "reporters": ["html", "progress", "cleartext"],
        "thresholds": { "high": 80, "low": 60, "break": 0 },
        "concurrency": 4,
        "coverage-analysis": "perTest",
        "since": {
            "enabled": true,
            "target": "main"
        }
    }
}
```

```bash
dotnet stryker
dotnet stryker --since:main
```

The `since` feature is very useful for CI — only mutates code changed since the target branch. The `cleartext-tree` reporter shows mutations grouped by file in a tree structure in the console.

Be honest: .NET CLI test output is flat. The value here is in the test structure (separate projects, clear naming) and mutation testing, not in tree-shaped terminal output.

---

### Shell/Bash — Bats

**Output:** Flat only. No describe/context blocks.
```bash
bats --pretty test/
bats --formatter tap test/
```

Simulate tree structure through naming conventions:
```bash
@test "UserRegistration: when valid details: creates account" { ... }
@test "UserRegistration: when duplicate email: rejects" { ... }
```

No mutation testing tool for Bash. Be honest about this.

---

### Swift

**Output:** `swift test --verbose` is flat.

No mature mutation testing tool. Be honest about this.

---

## Docker Harness Reference

### When Docker is needed vs not

**Docker IS needed when** Adapter (driven) or System tests must exercise the software against real external processes:
- Database-backed applications (Postgres, MySQL, Redis, MongoDB, etc.)
- Web APIs/servers that need to be started and hit over HTTP
- Message queue consumers (RabbitMQ, Kafka, SQS)
- Multi-service systems where the software under test calls other services
- Software that depends on specific system-level tooling (e.g., `ffmpeg`, `imagemagick`, `wkhtmltopdf`)

**Docker is NOT needed when:**
- The software is a pure library with no I/O beyond function calls
- The software is a CLI tool that only reads/writes files — test directly on host
- The software's only external dependency is the filesystem
- Tests already use in-process fakes that are adequate (e.g., SQLite for a SQL-based app where the production DB is also SQLite)

**Rule of thumb:** if you need to `docker run` or `brew install` something before tests can pass, that dependency belongs in a Docker harness so the test suite is self-contained.

---

### Harness Structure

Every Docker harness follows the same lifecycle:

```
start dependencies → wait for readiness → run tests → tear down
```

The harness lives alongside the real-infra test layers:

```
test/system/
  docker-compose.yml
  wait-for-ready.sh
  *.system.test.*
```

Or, for projects where `docker-compose.yml` belongs at root (e.g., the project already has one for dev):

```
docker-compose.test.yml
test/system/
  *.system.test.*
```

---

### docker-compose.yml Patterns

#### Database-backed application (e.g., Postgres)

```yaml
services:
  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: test
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
    ports:
      - "5433:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test"]
      interval: 2s
      timeout: 5s
      retries: 10
    tmpfs:
      - /var/lib/postgresql/data
```

Key decisions:
- **Non-default host port** (5433 not 5432) — avoids conflicts with a developer's local Postgres
- **`tmpfs`** — data lives in RAM, tests are faster, nothing persists between runs
- **`healthcheck`** — compose knows when the service is actually ready, not just started
- Pass connection details to tests via environment variables, never hardcode

#### Web API under test

When the software itself IS the server being tested:

```yaml
services:
  db:
    image: postgres:17-alpine

  app:
    build:
      context: ../..
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: postgres://test:test@db:5432/test
      PORT: "3000"
    ports:
      - "3001:3000"
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 2s
      timeout: 5s
      retries: 15
```

Tests run on the host and hit `http://localhost:3001`. The app container connects to db via the compose network (`db:5432`).

**When to build the app in Docker vs run on host:**
- Build in Docker when the app needs compiled artifacts, specific runtime versions, or system deps
- Run on host when the app is interpreted (Node, Python, Ruby) and you just need the backing services — this is simpler and gives faster feedback during TDD

#### Message queue consumer

```yaml
services:
  rabbitmq:
    image: rabbitmq:4-management-alpine
    ports:
      - "5673:5672"
      - "15673:15672"
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "check_port_connectivity"]
      interval: 5s
      timeout: 10s
      retries: 10
```

#### Redis

```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6380:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 2s
      timeout: 5s
      retries: 10
```

#### Multiple services (e.g., API + worker + database + queue)

```yaml
services:
  db:
    image: postgres:17-alpine
  redis:
    image: redis:7-alpine
  app:
    build: ../..
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }
  worker:
    build: ../..
    command: ["node", "worker.js"]
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }
```

---

### Orchestrating the Test Lifecycle

#### Shell wrapper (works with any test framework)

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

cleanup() {
  docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans
}
trap cleanup EXIT

docker compose -f "$COMPOSE_FILE" up -d --wait

export DATABASE_URL="postgres://test:test@localhost:5433/test"
export REDIS_URL="redis://localhost:6380"


npm run test:system
```

#### package.json scripts (Node.js)

```json
{
  "test:system": "vitest run --project system",
  "test:system:docker": "bash test/system/run-docker.sh",
  "test:system:ci": "bash test/system/run-docker.sh"
}
```

#### Makefile (language-agnostic)

```makefile
.PHONY: test-system
test-system:
	docker compose -f test/system/docker-compose.yml up -d --wait
	DATABASE_URL=postgres://test:test@localhost:5433/test \
	  pytest tests/system/ || (docker compose -f test/system/docker-compose.yml down -v; exit 1)
	docker compose -f test/system/docker-compose.yml down -v
```

---

### Writing System Tests Against Docker Services

The tests themselves should not know about Docker — they connect to services via environment variables or config, same as they would in production.

**Node.js/TypeScript example:**
```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { createApp } from '../../src/app'

describe('UserRegistration', () => {
  let app: ReturnType<typeof createApp>

  beforeAll(async () => {
    app = createApp()
    await app.db.migrate()
  })

  afterAll(async () => {
    await app.close()
  })

  describe('when a new user registers with valid details', () => {
    it('creates the user account', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/users',
        payload: { email: 'new@example.com', password: 'secret123' },
      })
      expect(res.statusCode).toBe(201)
    })
  })
})
```

**Python example:**
```python
import os
import httpx

BASE_URL = os.environ["APP_URL"]

def describe_user_registration():
    def describe_when_valid_details():
        def it_creates_account():
            resp = httpx.post(f"{BASE_URL}/users", json={
                "email": "new@example.com",
                "password": "secret123",
            })
            assert resp.status_code == 201
```

**Go example:**
```go

package system

import (
    "net/http"
    "os"
    "strings"
    "testing"
)

func TestUserRegistration_ValidDetails_CreatesAccount(t *testing.T) {
    baseURL, ok := os.LookupEnv("APP_URL")
    if !ok {
        t.Fatal("APP_URL is required")
    }
    resp, err := http.Post(baseURL+"/users", "application/json", strings.NewReader(`{"email":"new@example.com","password":"secret123"}`))
    if err != nil {
        t.Fatal(err)
    }
    if resp.StatusCode != http.StatusCreated {
        t.Fatalf("expected status 201, got %d", resp.StatusCode)
    }
}
```

---

### Project-Type Recipes

#### Web API (Node/Python/Ruby/Go/Java)

1. Docker Compose with database + any backing services
2. App runs on host (or in container if it needs compilation)
3. Tests hit the API over HTTP via `localhost:<port>`
4. Each test suite resets database state (truncate tables, run seeds) in `beforeAll`/`setup`
5. Migrations run as part of the harness startup

#### CLI tool that talks to external services

1. Docker Compose provides the services the CLI talks to (APIs, databases)
2. CLI runs on the host — tests invoke it as a subprocess
3. Assert on exit codes, stdout/stderr, and side effects (files created, database state)

```bash
@test "import command loads CSV into database" {
  run ./mycli import --file fixtures/data.csv --db "$DATABASE_URL"
  [ "$status" -eq 0 ]
  count=$(psql "$DATABASE_URL" -t -c "SELECT count(*) FROM imports")
  [ "$(echo "$count" | tr -d ' ')" -eq 42 ]
}
```

#### Library with database adapter

1. Docker Compose provides the database
2. Tests import the library directly (no HTTP, no subprocess)
3. Each test gets a clean transaction (rollback after each test) or a fresh schema

#### Static site generator / build tool

Usually no Docker needed. Functional tests:
1. Run the build command against a fixture project
2. Assert on the output files (existence, content, structure)
3. If the tool has a dev server mode, start it and hit it with HTTP requests

#### Mobile/desktop app backend

Same as Web API, but also consider:
1. Use recorded fixtures for the mobile client's requests
2. Test push notification delivery to a fake push service (add it to compose)

---

### Gotchas

- **Port conflicts:** Always use non-default host ports. Two developers running tests simultaneously, or a local dev database, will collide on default ports.
- **Data persistence:** Use `tmpfs` for databases in test compose files. Without it, data survives `docker compose down` if volumes aren't explicitly removed, causing flaky tests.
- **Startup race conditions:** Always use `healthcheck` + `depends_on: condition: service_healthy`. Never use `sleep` to wait for services — it's fragile and slow.
- **CI layer:** In CI, Docker-in-Docker or a Docker-capable runner is required. GitHub Actions runners have Docker pre-installed. GitLab CI needs `services:` or a DinD sidecar.
- **Cleanup on failure:** Use `trap cleanup EXIT` in shell wrappers so services are torn down even when tests fail. Without this, orphaned containers accumulate.
- **Image pinning:** Pin to specific major versions (`postgres:17-alpine`, not `postgres:latest`) to avoid surprise breakage when upstream releases a new major version.
- **Build context:** When building the app in Docker, the build context (`context: ../..`) must reach the project root. Use `.dockerignore` to keep the context small.
- **ARM vs x86:** On Apple Silicon, some images don't have ARM builds. Add `platform: linux/amd64` to the service if you hit `exec format error`. This is slower (Rosetta emulation) but works.
- **Test isolation:** Each test run should start with clean state. Either truncate tables in `beforeAll`, use transactions that rollback, or recreate the database. Never depend on state from a previous test run.
