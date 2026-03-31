---
name: setup
description: "Prepare the project for ongoing test-tree-driven development — configures test framework with tree reporters and generates initial test trees in CLAUDE.md. TRIGGER when: project has no test framework configured, no ## Requirements section in CLAUDE.md, or user is starting a new project. Run once per project."
---

# Setup Contree

Prepares the project for ongoing test-tree-driven development. Configures the test framework, generates initial test trees in CLAUDE.md, and establishes the contract between intent and implementation that the other skills maintain.

## Critical Rules

1. **Read before write.** Always read existing config files before modifying them. Never overwrite — merge surgically.
2. **Tree output is non-negotiable.** If a framework can produce nested output, configure it. If it can only produce flat output, use it and be honest.
3. **Two test layers, always.** Unit (colocated, mocked, fast) and functional (separated, real system, no mocks).
4. **CI dual reporters.** Configure tree output for local dev AND structured output (JUnit XML) for CI. Both, not either/or.
5. **Verify after configuring.** Run the tests and confirm tree-shaped output before moving on.

## Process

### 1. REVIEW

Read project files — source code, existing tests, configs, CLAUDE.md. Understand:

- Language and ecosystem
- Existing test framework and config (if any)
- What behaviours the system implements today
- Whether `## Requirements` already exists in CLAUDE.md
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

When multiple frameworks are detected (e.g., both Jest and Vitest deps exist during a migration), present both and ask the user which to use.

### 3. SUGGEST

Present identified frameworks with trade-offs and recommendation. Include tree output quality in the comparison. Let the user choose before proceeding.

### 4. DETERMINE TEST STRATEGY

Confirm how conventions apply to this project:

- Unit tests: colocated with source, `*.unit.test.*`
- Functional tests: `test/functional/` at project root, `*.functional.test.*`
- Tree-style output at both layers

**Language-specific conventions that override defaults:**
- **Rust**: unit tests live inside the source file (`#[cfg(test)] mod tests`), integration tests in `tests/` at crate root — this is the language convention, not a choice
- **Go**: tests are always colocated (`foo_test.go` next to `foo.go`) — this is the language convention
- **Ruby/RSpec**: separated `spec/` directory is the overwhelming convention — follow it
- **Python**, **JS/TS**, **PHP**: both colocated and separated patterns work; prefer colocated for unit tests

**Monorepo strategy:**
- Unit tests: colocated with source in each package
- Functional tests: at monorepo root `test/functional/` if they exercise cross-package behaviour, or per-package if they test a single package
- Never create a single root-level test config that reaches into all packages — follow the monorepo tool's conventions (Turborepo tasks, Nx project graph, pnpm workspace scripts)
- Use shared base config that each package extends

### 5. CONFIGURE UNIT TEST RUNNER

Write tree-style reporter config into the project's test configuration. Use the Framework Reference below.

**Do NOT skip. Do NOT rely on defaults. Do NOT overwrite existing config — merge into it.**

If the config already has a `reporters` or `verbose` key, check whether changing it would break CI (e.g., removing a JUnit XML reporter). Present the conflict to the user rather than silently overwriting.

### 6. CONFIGURE FUNCTIONAL TEST RUNNER

Separate test command/config:

- `test/functional/` at project root
- Tree-style output
- Runnable independently from unit tests
- Same framework where possible
- Higher timeouts (functional tests hit real systems)

**Determine whether a Docker harness is needed.** See the Docker Harness Reference below. The key question: does this software need external processes (databases, queues, HTTP servers, other services) to exercise its real behaviour? If yes, set up a Docker Compose harness alongside the functional test runner. If the software is a pure library or CLI that only touches the filesystem, Docker is unnecessary overhead — run functional tests directly on the host.

When configuring Docker:
- `docker-compose.yml` lives at project root (or `test/functional/docker-compose.yml` if the project root is already crowded)
- Functional test scripts start compose, wait for readiness, run tests, tear down
- Add a `test:functional` script that orchestrates the full lifecycle
- Never assume Docker services are already running — the harness must be self-contained

### 7. CONFIGURE MUTATION TESTING

Install appropriate mutation testing tool (see Mutation Testing Reference below). Configure with:

- Mutator targeting source files, **explicitly excluding test files** — if tests are colocated, the exclusion globs must match the naming convention exactly (e.g., `!src/**/*.unit.test.*`, `!src/**/*.functional.test.*`)
- Unit test runner only (functional tests are too slow for mutation testing)
- Thresholds: `high: 80, low: 60, break: 50`
- Incremental mode where available (stores state between runs for speed)
- Add script/command (e.g., `npm run test:mutate`)

### 8. SET UP CHANGED-TEST RUNNERS

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

### 9. GENERATE INITIAL REQUIREMENT TREES

This is the key step that distinguishes contree from a plain test framework setup.

**Read the codebase and generate test trees that describe what the system does today.** These become the `## Requirements` section in CLAUDE.md.

Process:
1. Identify the system's capabilities — what does it do from the consumer's perspective?
2. For each capability, write a functional-level test tree using EARS patterns (see the `ears` rule) — choose the right keyword for each requirement's nature
3. Describe operating principles, not implementation details
4. Include positive paths and unwanted behaviour (`if/then` for error cases)
5. If existing tests exist, use them as input — but rewrite as principle-describing trees, don't copy test names verbatim
6. If the system is new/empty, write requirement trees for the planned capabilities based on what the user describes

**Do NOT implement the test trees** — they are requirements only at this stage. The `tdd` skill handles implementation later.

Write the trees into `## Requirements` in CLAUDE.md. Each capability gets its own subsection:

```markdown
## Requirements

### UserRegistration

UserRegistration
  then passwords are stored hashed, never in plain text
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  if the email is already registered
    then registration is rejected

### InvoiceGeneration

InvoiceGeneration
  when a completed order is submitted for invoicing
    then a PDF invoice is generated with line items
    and the invoice is emailed to the customer
  if the order has no line items
    then invoicing is rejected
  where the customer has a tax exemption
    then the invoice omits VAT
```

### 10. UPDATE CLAUDE.md

Add or update the following sections:

- `## Requirements` — the test trees from step 9
- Testing commands section with:
  - Command to run all unit tests with tree output
  - Command to run all functional tests with tree output
  - Command to run only changed unit/functional tests
  - Command to run mutation testing
  - Outside-in TDD workflow summary
  - Example test tree structure for this project

### 11. VERIFY

Run each layer's test suite and confirm:

- Unit test output is tree-shaped (or best available for the language)
- Functional test output is tree-shaped
- Mutation testing runs and produces a score report
- If no tests exist yet, create minimal smoke tests at both layers with nested describe/it blocks, run to confirm tree-shaped output

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
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // 'tree' gives nested describe/it output.
    // CRITICAL: Do NOT use 'verbose' — in Vitest v3+ it switched to flat output.
    // 'tree' is the correct reporter for nested indentation.
    reporters: [
      'tree',
      // Add JUnit XML for CI alongside tree for local dev:
      ...(process.env.CI ? ['junit'] : []),
    ],
    outputFile: process.env.CI ? { junit: './reports/junit.xml' } : undefined,
  },
})
```

**Separating unit and functional tests** — use Vitest projects (replaces deprecated `vitest.workspace.ts` in v3.2+):
```ts
// vitest.config.ts
export default defineConfig({
  test: {
    reporters: ['tree'],  // reporters are root-level only — silently ignored inside projects
    projects: [
      {
        extends: true,  // inherit root config (plugins, resolve.alias, etc.)
        test: {
          name: 'unit',
          include: ['src/**/*.unit.test.{ts,js}'],
        },
      },
      {
        extends: true,
        test: {
          name: 'functional',
          include: ['test/functional/**/*.functional.test.{ts,js}'],
          testTimeout: 30_000,
          hookTimeout: 30_000,
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
  "test:unit": "vitest run --project unit",
  "test:functional": "vitest run --project functional",
  "test:changed": "vitest run --changed",
  "test:watch": "vitest",
  "test:mutate": "stryker run"
}
```

**Gotchas:**
- `reporters` is root-level only — setting it inside a `projects[*].test` block is silently ignored
- `extends: true` in a project block is required to inherit root-level config — without it you get a bare Vite config
- `--changed` uses the import graph but only tracks changed source files, not changed test files — use `--watch` for local TDD
- `vitest.workspace.ts` is deprecated since v3.2 — use the `projects` array inside `vitest.config.ts`

---

### JavaScript/TypeScript — Jest

**Tree reporter:**
```ts
// jest.config.ts
import type { Config } from 'jest'

const config: Config = {
  // verbose: true IS Jest's tree output — it nests test names under describe blocks.
  // There is no separate 'tree' reporter in Jest.
  verbose: true,

  // Add JUnit XML for CI:
  reporters: [
    'default',
    ...(process.env.CI ? [['jest-junit', {
      outputDirectory: 'reports',
      outputName: 'junit.xml',
    }]] : []),
  ],

  // Separate unit and functional via projects:
  projects: [
    {
      displayName: 'unit',  // required for --selectProjects to work
      testMatch: ['<rootDir>/src/**/*.unit.test.{ts,js}'],
      transform: { '^.+\\.tsx?$': 'ts-jest' },
      testEnvironment: 'node',
    },
    {
      displayName: 'functional',
      testMatch: ['<rootDir>/test/functional/**/*.functional.test.{ts,js}'],
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
  "test:unit": "jest --selectProjects unit",
  "test:functional": "jest --selectProjects functional",
  "test:changed": "jest --changedSince=origin/main",
  "test:mutate": "stryker run"
}
```

**Gotchas:**
- `verbose` and `reporters` are shared across all projects — you cannot set them per-project
- `displayName` is required for `--selectProjects` and `--ignoreProjects` to work
- `--onlyChanged` uses `git status` — after committing, zero tests run; use `--changedSince=origin/main` for CI
- `--changedSince` requires the base branch to be fetchable — in CI run `git fetch --no-tags --depth=1 origin main` first, then use `origin/main` (not `main`)
- Stryker's Jest runner crashes when Jest `projects` is configured — if using Stryker with Jest projects, you may need a separate jest.config for Stryker that targets unit tests only without the projects array
- Do NOT install `ts-jest` if the project uses Vitest (which handles TypeScript natively)

---

### JavaScript/TypeScript — Mocha

**Tree reporter:**
```yaml
# .mocharc.yml
# 'spec' is the tree-style reporter (nested describe/it). It is also the default.
reporter: spec
require:
  - tsx  # TypeScript support
recursive: true
timeout: 5000
extension:
  - ts
  - js
```

**Separating test suites** — use separate config files:

`.mocharc.unit.yml`:
```yaml
require: [tsx]
spec: 'src/**/*.unit.test.{ts,js}'
reporter: spec
parallel: true
jobs: 4
timeout: 5000
```

`.mocharc.functional.yml`:
```yaml
require: [tsx]
spec: 'test/functional/**/*.functional.test.{ts,js}'
reporter: spec
parallel: false  # functional tests often need serial execution
timeout: 30000
```

**Scripts:**
```json
{
  "test:unit": "mocha --config .mocharc.unit.yml",
  "test:functional": "mocha --config .mocharc.functional.yml",
  "test:mutate": "stryker run"
}
```

**Gotchas:**
- No built-in `--changed` flag — use file watcher or script: `mocha $(git diff --name-only -- '*.test.ts')`
- Parallel mode: root hooks from one test file are NOT available in another worker — use `--require` with a root hook plugin file
- `spec` reporter works correctly in parallel mode

---

### JavaScript/TypeScript — Stryker Mutation Testing

**Install** (pick the runner matching your test framework):
```bash
pnpm add -D @stryker-mutator/core @stryker-mutator/vitest-runner
# OR: @stryker-mutator/jest-runner
# OR: @stryker-mutator/mocha-runner
# Optional: @stryker-mutator/typescript-checker
```

**Vitest runner config:**
```js
// stryker.config.mjs
/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  testRunner: 'vitest',
  vitest: {
    configFile: 'vitest.config.ts',
    dir: '.',
    // Only run tests related to mutated files — MUCH faster:
    related: true,
  },

  mutate: [
    'src/**/*.ts',
    // Exclude test files — critical when tests are colocated with source:
    '!src/**/*.test.ts',
    '!src/**/*.spec.ts',
    '!src/**/*.unit.test.ts',
    '!src/**/*.functional.test.ts',
    '!src/**/*.d.ts',
  ],

  coverageAnalysis: 'perTest',  // most efficient — always use this

  reporters: ['clear-text', 'progress', 'html'],
  htmlReporter: { fileName: 'reports/mutation/index.html' },

  thresholds: { high: 80, low: 60, break: 50 },

  // Incremental mode — stores state between runs for speed.
  // Commit the file or store as CI artifact for cross-run benefits.
  incremental: true,
  incrementalFile: 'reports/stryker-incremental.json',

  // TypeScript checker prunes non-compiling mutants early (faster):
  checkers: ['typescript'],
  tsconfigFile: 'tsconfig.json',

  concurrency: 4,
  timeoutMS: 10_000,
  timeoutFactor: 1.5,
  ignoreStatic: true,  // skip mutants in static initializers (low value, slow)
}
```

**Jest runner config** — same structure but:
```js
  testRunner: 'jest',
  jest: {
    projectType: 'custom',
    configFile: 'jest.config.ts',
    enableFindRelatedTests: true,  // equivalent of vitest.related
  },
```

**Mocha runner config** — same structure but:
```js
  testRunner: 'mocha',
  mochaOptions: {
    spec: ['src/**/*.unit.test.ts'],
    config: '.mocharc.unit.yml',
    require: ['tsx'],
    timeout: 10_000,
    ui: 'bdd',
  },
```
Note: Mocha runner does NOT reliably support `coverageAnalysis: 'perTest'` — fall back to `'all'` if you see errors.

**Gotchas:**
- The runner plugin MUST match the test framework — `@stryker-mutator/vitest-runner` for Vitest, `jest-runner` for Jest, etc. Mismatching silently fails or crashes.
- `vitest.related: true` and `jest.enableFindRelatedTests: true` are critical for performance — without them Stryker runs ALL tests for every mutant
- `coverageAnalysis: 'perTest'` is the most efficient option — `'all'` re-runs the full suite per mutant
- `ignoreStatic: true` skips mutants in `const x = 'hello'` at module scope — these are killed by every importing test, slow and low value
- `thresholds.break` is `null` by default (no CI failure) — set it to enforce the gate
- For the TypeScript checker, install `@stryker-mutator/typescript-checker`

---

### Python

**Tree reporter — pytest-spec + pytest-describe:**
```bash
pip install pytest-spec pytest-describe
# or: uv add --dev pytest-spec pytest-describe
```

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--spec --strict-markers"

# pytest-describe: enable when/context prefixes for nested blocks
describe_prefixes = ["describe_", "context_", "when_"]

# pytest-spec: configure output format
spec_header_format = "{module_path}:"
spec_test_format = "{result} {name}"
spec_success_indicator = "+"
spec_failure_indicator = "-"
spec_skipped_indicator = "?"

# Markers for test categorisation
markers = [
    "unit: Fast isolated unit tests",
    "functional: End-to-end functional tests",
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

**Separating unit and functional tests:**
```
tests/
  unit/
    conftest.py       # auto-marks all tests as @pytest.mark.unit
    test_models.py
  functional/
    conftest.py       # auto-marks all tests as @pytest.mark.functional
    test_api.py
  conftest.py         # shared fixtures
```

Auto-mark by directory in `tests/unit/conftest.py`:
```python
import pytest
def pytest_collection_modifyitems(items):
    for item in items:
        item.add_marker(pytest.mark.unit)
```

Run independently:
```bash
pytest tests/unit/            # or: pytest -m unit
pytest tests/functional/      # or: pytest -m functional
```

**Changed-test runner — pytest-testmon:**
```bash
pip install pytest-testmon
```
```bash
pytest --testmon              # first run builds dependency map; subsequent runs only affected tests
pytest --last-failed          # built-in: re-run failures from previous run
```
`.testmondata` goes in `.gitignore` — it is machine-specific.

**Mutation testing — mutmut:**
```bash
pip install mutmut
```

```toml
# pyproject.toml
[tool.mutmut]
paths_to_mutate = ["src/"]
tests_dir = ["tests/"]
runner = "python -m pytest -x --tb=short -q"
do_not_mutate = [
    "src/*/migrations/*",
    "src/*/config.py",
]
mutate_only_covered_lines = true  # huge speed improvement — always enable
```

```bash
mutmut run                    # run all mutations
mutmut run "src/myapp/models*"  # target specific modules
mutmut browse                 # TUI to inspect results (replaces mutmut html in v3)
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
# .rspec
--format documentation
--color
--order random
--require spec_helper
```

The `documentation` formatter prints nested `describe`/`context`/`it` blocks as indented text.

**Separating spec directories:**
```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/functional/}) do |metadata|
    metadata[:functional] = true
  end
  config.define_derived_metadata(file_path: %r{/spec/unit/}) do |metadata|
    metadata[:unit] = true
  end
  # Persistence file for --only-failures:
  config.example_status_persistence_file_path = "spec/examples.txt"
end
```

Run by tag:
```bash
rspec --tag unit
rspec --tag functional
rspec --only-failures         # re-run previous failures
rspec --next-failure          # stop at first failure
```

**File watching** — guard-rspec:
```ruby
# Gemfile
gem 'guard-rspec', require: false
```

**Mutation testing — mutant:**
```ruby
# Gemfile
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
gotestsum --format testdox ./...          # BDD-style sentences, grouped by package
gotestsum --format testname ./...         # one line per test with package prefix
gotestsum --format testdox --watch ./...  # file watcher for TDD
gotestsum --junitfile results.xml ./...   # JUnit XML for CI
```

`testdox` output groups by package, then lists tests as sentences — one level deep. Go's test model has no describe/context nesting, so no tool can produce a deep tree. Be honest about this.

**Separating unit and integration tests — build tags:**
```go
// integration_test.go
//go:build integration

package myapp
// ...
```

```bash
go test ./...                          # unit tests only (no tag)
go test -tags=integration ./...        # both unit AND integration
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
go test -short ./...    # skip integration
go test ./...           # run everything
```

**Mutation testing — gremlins:**
```bash
go install github.com/go-gremlins/gremlins/cmd/gremlins@latest
```

```bash
gremlins unleash                       # run from module root
gremlins unleash --tags=unit           # with build tags
```

Gremlins (v0.6+, actively maintained) is the best Go mutation tool available. Supports arithmetic, conditionals, increment/decrement mutations. Limitation: runs full test suite per mutation, so impractical for large monolithic modules. Works well for microservice-sized modules (which is most Go code).

**Alternatives:** `go-mutesting` (original abandoned; Avito fork has sporadic maintenance) — prefer gremlins.

---

### Rust

**Best available output — cargo nextest:**
```bash
cargo install cargo-nextest --locked
# or: cargo binstall cargo-nextest
```

```toml
# .config/nextest.toml
[profile.default]
test-threads = "num-cpus"
fail-fast = true
slow-timeout = { period = "60s", terminate-after = 2 }
status-level = "pass"
failure-output = "immediate"
success-output = "never"

[profile.ci]
retries = 3
fail-fast = false
failure-output = "immediate-final"

[profile.ci.junit]
path = "target/nextest/ci/junit.xml"
```

```bash
cargo nextest run                           # all tests
cargo nextest run --lib                     # unit tests only (inline #[cfg(test)])
cargo nextest run -E 'kind(test)'           # integration tests only (tests/ dir)
cargo nextest run --profile ci              # CI profile with retries + JUnit
```

cargo nextest is a strict upgrade over `cargo test` — each test runs in its own process (better isolation), parallel by default, better failure output. Only limitation: cannot run doctests (use `cargo test --doc` separately).

Output is flat — module paths, not nested indentation. Rust's `#[test]` model has no describe/context hierarchy. Be honest about this.

**Test separation** follows Rust conventions:
- Unit tests: `#[cfg(test)] mod tests` inside source files — access private items
- Integration tests: `tests/` directory at crate root — separate crates, public API only

```bash
cargo nextest run --lib                    # unit only
cargo nextest run -E 'kind(test)'          # integration only
```

**Mutation testing — cargo-mutants:**
```bash
cargo install --locked cargo-mutants
# or: cargo binstall cargo-mutants
```

```toml
# .cargo/mutants.toml
test_tool = "nextest"  # use nextest instead of cargo test
```

Add a speed-optimised profile in `Cargo.toml`:
```toml
[profile.mutants]
inherits = "test"
debug = false          # skip debug symbols — faster builds
```

```bash
cargo mutants                              # all mutations
cargo mutants -f "src/user.rs"             # specific file
cargo mutants -F "validate"                # specific function regex
cargo mutants --shard 1/4                  # CI sharding (parallel)
cargo mutants --profile=mutants            # use speed-optimised profile
```

cargo-mutants (v1.1+, actively maintained) is the most mature Rust mutation tool. Replaces function bodies with default return values, deletes match arms, replaces operators. Works on any stable compiler (no nightly required).

---

### Elixir

**Best available output — ExUnit trace mode:**
```elixir
# test/test_helper.exs
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
# test/test_helper.exs
ExUnit.start(trace: true, exclude: [:integration])
```

```elixir
# In integration test files:
@moduletag :integration
```

```bash
mix test                          # unit only (integration excluded)
mix test --include integration    # everything
mix test --only integration       # integration only
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
<!-- phpunit.xml -->
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
./vendor/bin/pest                      # run tests
./vendor/bin/pest --mutate             # mutation testing
./vendor/bin/pest --mutate --min=80    # fail if MSI below 80%
```

Pest v3's built-in mutation testing is a significant advantage over managing Infection separately.

**Infection** (if not using Pest):
```json5
// infection.json5
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
vendor/bin/infection --git-diff-lines                # only changed lines — great for CI
```

---

### Java/Kotlin — Gradle

**Tree reporter — gradle-test-logger-plugin:**
```kotlin
// build.gradle.kts
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
            // src/test/java — unit tests
        }
        val functionalTest by registering(JvmTestSuite::class) {
            useJUnitJupiter()
            // src/functionalTest/java — functional tests
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
    dependsOn(testing.suites.named("functionalTest"))
}
```

Run: `./gradlew test` (unit) vs `./gradlew functionalTest`.

**JUnit 5 @Nested for tree structure:**
```java
class OrderTest {
    @Nested class WhenEmpty {
        @Test void isNotReady() { /* ... */ }
        @Nested class AfterAddingItem {
            @Test void isReady() { /* ... */ }
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
<!-- pom.xml -->
<plugin>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.5.3</version> <!-- MUST be <= 3.5.3; breaks on 3.5.4+ -->
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
dotnet test --logger "console;verbosity=detailed"   # most verbose, still flat
dotnet test --logger "trx"                           # structured output for CI
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
// stryker-config.json
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
dotnet stryker                    # full run
dotnet stryker --since:main       # only mutate changes since main branch
```

The `since` feature is very useful for CI — only mutates code changed since the target branch. The `cleartext-tree` reporter shows mutations grouped by file in a tree structure in the console.

Be honest: .NET CLI test output is flat. The value here is in the test structure (separate projects, clear naming) and mutation testing, not in tree-shaped terminal output.

---

### Shell/Bash — Bats

**Output:** Flat only. No describe/context blocks.
```bash
bats --pretty test/             # coloured pass/fail
bats --formatter tap test/      # TAP format for CI
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

**Docker IS needed when** functional tests must exercise the software against real external processes:
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

The harness lives alongside the functional tests:

```
test/functional/
  docker-compose.yml      # service definitions
  wait-for-ready.sh       # readiness checks (or use healthchecks in compose)
  *.functional.test.*     # test files
```

Or, for projects where `docker-compose.yml` belongs at root (e.g., the project already has one for dev):

```
docker-compose.test.yml   # test-specific overrides
test/functional/
  *.functional.test.*
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
      - "5433:5432"   # non-default port to avoid clashing with local Postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test"]
      interval: 2s
      timeout: 5s
      retries: 10
    tmpfs:
      - /var/lib/postgresql/data   # RAM-backed storage — fast, disposable
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
    # ... same as above ...

  app:
    build:
      context: ../..           # project root
      dockerfile: Dockerfile   # or Dockerfile.test if different from prod
    environment:
      DATABASE_URL: postgres://test:test@db:5432/test
      PORT: "3000"
    ports:
      - "3001:3000"            # non-default host port
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
      - "5673:5672"    # AMQP
      - "15673:15672"  # management UI (useful for debugging)
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
    # ...
  redis:
    image: redis:7-alpine
    # ...
  app:
    build: ../..
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }
    # ...
  worker:
    build: ../..
    command: ["node", "worker.js"]
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }
    # ...
```

---

### Orchestrating the Test Lifecycle

#### Shell wrapper (works with any test framework)

```bash
#!/usr/bin/env bash
# test/functional/run-docker.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

cleanup() {
  docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

# Start services and wait for health
docker compose -f "$COMPOSE_FILE" up -d --wait

# Export connection details for tests
export DATABASE_URL="postgres://test:test@localhost:5433/test"
export REDIS_URL="redis://localhost:6380"

# Run migrations if needed
# npm run db:migrate  (or equivalent)

# Run functional tests
npm run test:functional
```

#### package.json scripts (Node.js)

```json
{
  "test:functional": "vitest run --project functional",
  "test:functional:docker": "bash test/functional/run-docker.sh",
  "test:functional:ci": "bash test/functional/run-docker.sh"
}
```

#### Makefile (language-agnostic)

```makefile
.PHONY: test-functional
test-functional:
	docker compose -f test/functional/docker-compose.yml up -d --wait
	DATABASE_URL=postgres://test:test@localhost:5433/test \
	  pytest tests/functional/ || (docker compose -f test/functional/docker-compose.yml down -v; exit 1)
	docker compose -f test/functional/docker-compose.yml down -v
```

---

### Writing Functional Tests Against Docker Services

The tests themselves should not know about Docker — they connect to services via environment variables or config, same as they would in production.

**Node.js/TypeScript example:**
```typescript
// test/functional/user-registration.functional.test.ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { createApp } from '../../src/app'

describe('UserRegistration', () => {
  let app: ReturnType<typeof createApp>

  beforeAll(async () => {
    // Uses DATABASE_URL from environment (set by run-docker.sh)
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
# tests/functional/test_user_registration.py
import os
import pytest
import httpx

BASE_URL = os.environ.get("APP_URL", "http://localhost:3001")

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
// test/functional/user_test.go
//go:build integration

package functional

import (
    "net/http"
    "os"
    "testing"
)

func TestUserRegistration_ValidDetails_CreatesAccount(t *testing.T) {
    baseURL := os.Getenv("APP_URL")
    if baseURL == "" {
        baseURL = "http://localhost:3001"
    }
    // ...
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
# Bats example for a CLI that talks to a database
@test "import command loads CSV into database" {
  run ./mycli import --file fixtures/data.csv --db "$DATABASE_URL"
  [ "$status" -eq 0 ]
  # Verify data landed in the database
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
1. Mock the mobile client's requests using recorded fixtures
2. Test push notification delivery to a mock push service (add it to compose)

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
