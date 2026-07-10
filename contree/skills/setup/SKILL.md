---
name: setup
description: "Prepare a project for ongoing test-tree-driven development by configuring the test framework and creating TEST_TREES.md. TRIGGER when: a project has no test framework configured, no TEST_TREES.md at the project root, no mental model, or the user is starting a new project."
---

# Setup Contree

Prepares the project for ongoing test-tree-driven development. Configures the test framework and creates `TEST_TREES.md` when needed.

## Critical Rules

1. **Tree output is non-negotiable.** If a framework can produce nested output, configure it. If it can only produce flat output, use it and be honest.
2. **Use the fixed Contree test strategy.** The normal test command runs Unit, Port contract, Adapter, and Component tests. The functional test command runs System and Journey tests. System and Journey do not run automatically from the normal command.
3. **Verify after configuring.** Run the tests and confirm tree-shaped output before moving on.
4. **No test files.** Setup configures the framework and creates the test-tree home. Do NOT create any test files (`*.test.*`, `*.spec.*`). Trees and tests happen after setup.

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

The fixed Contree test strategy is set by the harness rules. Setup maps it to the project's framework conventions:

- **Normal tests** run automatically from the project's default test command. They include Unit, Port contract, Adapter, and Component tests.
- **Functional tests** run from a separate command. They include System and Journey tests and are not part of the default test command.
- **JS/TS, Python, PHP, Ruby** usually map this with filename globs or suites.
- **JVM and .NET** usually map this with source sets, suites, or test projects.
- **Go, Rust, Elixir, Bash, Swift** use native tags, directories, module filters, or wrapper scripts because their CLI output is flatter.
- **Monorepos** expose the same two commands through workspace tasks and keep per-package configuration local.

Default naming when the ecosystem does not force another convention:

- Domain tests are colocated with source as `*.domain.test.*`.
- Use-case tests are colocated with the use-case as `*.use-case.test.*`.
- Adapter tests are colocated with the driving or driven adapter as `*.adapter.test.*`.
- Component tests live under `test/component/` as `*.component.test.*`.
- System tests live under `test/system/` as `*.system.test.*`.
- Journey tests live under `test/journey/` as `*.journey.test.*`.

Journey tests exercise real everything across the multi-capability arc at max realism. Component tests exercise one capability in-process with real driving and driven adapters, an in-memory database, and stubbed outbound HTTP. The exhaustive single-capability breadth belongs at the Use-case and Component layers.

### 5. CONFIGURE TEST COMMANDS

Configure one normal test command and one functional test command using native project commands: package.json scripts, Makefile targets, mix aliases, cargo aliases, Gradle tasks, composer scripts, or the ecosystem equivalent.

- `test` or the language's default test command runs Unit, Port contract, Adapter, and Component tests.
- `test:functional` or the closest native equivalent runs System and Journey tests.
- System and Journey tests do not run automatically from the normal test command.
- Component tests run in-process with real driving and driven adapters, with external services doubled only at the edge; they need no external services.
- System and Journey wire real driven adapters at the highest tolerable realism.
- Tree-style output is configured for both commands where the framework can produce it.
- If no tests exist yet, the empty suite output is enough to verify command wiring.

Create a native `test-changed` command for fast agent feedback. The normal test command and `test-changed` share machine-local state recording the project files present at the end of the last completed normal test run. Keep that state out of version control.

When `test-changed` runs, it compares the current project files with that state, identifies added, modified, and deleted files, and passes those files to the test framework's dependency or impact selector. It runs only the normal tests impacted by those files; System and Journey tests remain exclusive to the functional test command. A changed test file is itself impacted. Changes to shared test configuration or dependencies impact every normal test.

Use the framework's native related-test or dependency-tracking capability. Install its maintained changed-test plugin when that capability is not built in. Do not substitute last-failed selection, watch mode, mutation-test selection, or a full suite for impact analysis: each answers a different question.

If no completed normal test run exists, `test-changed` runs the normal test command to establish its baseline. After either command completes, record the current project-file state so the next `test-changed` invocation measures changes from that run.

Create one project-level `Stop` hook for each supported coding harness and merge it into existing project hook configuration without replacing other settings or hooks:

- Claude Code: `.claude/settings.json`
- Codex: `.codex/hooks.json`

The project-level `Stop` hook runs `test-changed` through executable `.contree/hooks/test-changed.sh` after the turn's file changes and after synchronous `PostToolUse` save hooks have completed. Generate that script with `set -euo pipefail`, change to the project root returned by `git rev-parse --show-toplevel`, and invoke the ecosystem's exact native `test-changed` command. Keep the hook synchronous so its result reaches the coding agent before the turn finishes.

Require the coding harness to load and trust the project hook, then verify it with an actual file edit and Stop turn. Presence on disk alone is not verification.

If an impacted test fails, `.contree/hooks/test-changed.sh` writes the complete test output to stderr and exits 2. Preserve the native test command's output while translating its non-zero status into the hook failure status; never swallow the failure or report success.

If the config already has a `reporters` or `verbose` key, check whether changing it would break CI, such as removing a JUnit XML reporter. Present the conflict to the user rather than silently overwriting.

**Determine whether a Docker harness is needed.** See the Docker Harness Reference below. Key question: do Adapter, System, or Journey tests need external processes — databases, queues, HTTP servers? If yes, set up a Docker Compose harness behind the normal or functional command that needs it. If the software is pure in-process, Docker is unnecessary.

When configuring Docker:
- `docker-compose.yml` lives at project root, or `test/system/docker-compose.yml` if the project root is already crowded
- Real-infra test scripts start compose, wait for readiness, run tests, tear down
- Functional scripts orchestrate the full lifecycle before running System and Journey tests
- Normal scripts orchestrate the full lifecycle when Adapter tests need real external processes
- Never assume Docker services are already running — the harness must be self-contained

### 6. CONFIGURE MUTATION TESTING

Install appropriate mutation testing tool (see Mutation Testing Reference below). Configure with:

- Mutator targeting source files, **explicitly excluding test files** — if tests are colocated, the exclusion globs must match the naming convention exactly (e.g., `!src/**/*.domain.test.*`, `!src/**/*.use-case.test.*`, `!src/**/*.adapter.test.*`, `!src/**/*.contract.ts`). For TypeScript projects, include the precise layer suffixes: `!src/**/*.domain.test.ts`, `!src/**/*.use-case.test.ts`, `!src/**/*.adapter.test.ts`, `!src/**/*.component.test.ts`, `!src/**/*.system.test.ts`, `!src/**/*.journey.test.ts`, `!test/**/*.component.test.ts`, `!test/**/*.system.test.ts`, `!test/**/*.journey.test.ts`, and `!src/**/*.contract.ts`.
- Mutation test runners select only Domain and Use-case tests when the framework supports test selection. Adapter, Component, System, and Journey tests are too slow for mutation testing.
- Thresholds: `high: 80, low: 60, break: 50`
- Incremental mode where available (stores state between runs for speed)
- Add script/command (e.g., `npm run test:mutate`)

### 7. CONFIGURE LINTING

Configure a conventional normal linter with the ecosystem's strong recommended rules, plus hex-boundary lint. Use the project's language conventions and merge existing lint configuration rather than replacing it. The outcome is one combined lint command that CI can run.

| Supported ecosystem | Normal linter | Strong rules |
|---|---|---|
| JS | ESLint | `@eslint/js` `recommended` |
| TypeScript | ESLint | `@eslint/js` `recommended` plus `typescript-eslint` `strictTypeChecked` |
| Elixir | Credo | `mix credo --strict` |
| Go | golangci-lint | `standard` plus `errorlint`, `exhaustive`, `gosec`, `nilerr`, `nilnil`, and `wrapcheck` |

For JS, install `eslint` and `@eslint/js`, then write or merge `eslint.config.mjs` with `js.configs.recommended`.

For TypeScript, also install `typescript-eslint`, extend `tseslint.configs.strictTypeChecked`, and configure `parserOptions.projectService: true`. Run TypeScript checking from `lint:code` so the normal lint gate covers both ESLint and the compiler.

For Elixir, add Credo to `mix.exs` for `:dev` and `:test`, generate `.credo.exs`, and use strict analysis so low-priority findings are enforced instead of hidden.

For Go, install golangci-lint and write `.golangci.yml` with `default: standard` plus `errorlint`, `exhaustive`, `gosec`, `nilerr`, `nilnil`, and `wrapcheck`. Use `golangci-lint run` as the normal lint command.

Contree also prescribes hexagonal architecture: domain is pure, I/O lives in adapters, dependencies point inward. Install a hex-boundary linter that enforces this so boundary violations break the build rather than the review.

The enforced hex-boundary lint rules are: Domain has no I/O, use-cases depend on ports/interfaces and not concrete adapters, and circular dependencies are rejected.

For JS/TS domain code, merge this entry into `eslint.config.mjs` so purity also excludes asynchronous functions:

```javascript
{
  name: 'contree/domain-no-async',
  files: ['src/domain/**/*.{js,jsx,ts,tsx}', 'src/**/domain/**/*.{js,jsx,ts,tsx}'],
  rules: {
    'no-restricted-syntax': [
      'error',
      {
        selector: ':matches(FunctionDeclaration, FunctionExpression, ArrowFunctionExpression)[async=true]',
        message: 'Domain code must be synchronous.',
      },
    ],
  },
}
```

**For JS/TS projects** — install dependency-cruiser alongside the normal linter:

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
      from: { path: '(^|/)domain/' },
      to: { path: '(^|/)(application|use-cases?|adapters?|infrastructure)/' },
    },
    {
      name: 'domain-no-external-dependencies',
      severity: 'error',
      from: { path: '(^|/)domain/' },
      to: {
        dependencyTypes: ['core', 'npm', 'npm-dev', 'npm-optional', 'npm-peer', 'npm-bundled', 'npm-no-pkg', 'npm-unknown'],
      },
    },
    {
      name: 'use-case-no-adapter',
      severity: 'error',
      from: { path: '(^|/)(application|use-cases?)/' },
      to: { path: '(^|/)(adapters?|infrastructure)/' },
    },
    {
      name: 'use-case-no-external-dependencies',
      severity: 'error',
      from: { path: '(^|/)(application|use-cases?)/' },
      to: {
        dependencyTypes: ['core', 'npm', 'npm-dev', 'npm-optional', 'npm-peer', 'npm-bundled', 'npm-no-pkg', 'npm-unknown'],
      },
    },
    {
      name: 'use-case-only-domain-data-and-ports',
      severity: 'error',
      from: { path: '(^|/)(application|use-cases?)/' },
      to: {
        dependencyTypes: ['local', 'localmodule'],
        pathNot: '(^|/)(domain|ports?|data|types)(/|$)',
      },
    },
    {
      name: 'adapters-only-from-composition-root',
      severity: 'error',
      from: { pathNot: '^src/composition-root\\.[cm]?[jt]sx?$' },
      to: { path: '(^|/)(adapters?|infrastructure)/' },
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

Identify the project's single composition root during REVIEW and replace the example composition-root path with the exact project path before writing `.dependency-cruiser.cjs`.

Add a script and wire it into the project's lint command:

```json
{
  "scripts": {
    "lint:code": "eslint .",
    "lint:code:fix": "eslint . --fix",
    "lint:arch": "depcruise src --config .dependency-cruiser.cjs",
    "lint": "pnpm lint:code && pnpm lint:arch"
  }
}
```

This makes `lint:code` the normal lint command, `lint:arch` the hex-boundary lint command, and `lint` the combined lint command.

Ensure CI runs `pnpm lint` or the ecosystem's combined lint command so normal and boundary violations fail the build.

Create one project-level `PostToolUse` lint hook for each supported coding harness. Merge into existing project hook configuration without replacing other settings or hooks:

- Claude Code: `.claude/settings.json`
- Codex: `.codex/hooks.json`

Add this matcher group under `hooks.PostToolUse` in both files:

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "command",
      "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/lint-on-save.sh\"",
      "statusMessage": "Fixing lint"
    }
  ]
}
```

The `Edit|Write` matcher covers Claude Code's file tools and Codex `apply_patch`. After creating or changing the project hook, require the coding harness to trust it, then verify it through an actual file edit. A hook that is only present on disk is not configured until the harness loads and trusts it.

Add the same Stop matcher group to `.claude/settings.json` and `.codex/hooks.json`:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/architecture-on-stop.sh\"",
      "statusMessage": "Checking architecture"
    }
  ]
}
```

Merge the Stop matcher group without replacing existing settings or hooks. When a Stop matcher group already exists, append this command hook to its `hooks` array.

Create executable `.contree/hooks/lint-on-save.sh` with `set -euo pipefail`. It changes to the project root returned by `git rev-parse --show-toplevel`, then runs the ecosystem's exact normal lint autofix command after every matched save:

| Ecosystem | Hook command |
|---|---|
| JS/TS | `pnpm lint:code:fix` |
| Elixir | `mix format`, then `mix credo --strict` |
| Go | `golangci-lint run --fix` |

Run the autofix command from the project root. This covers multi-file edits without depending on a single file path in the hook payload.

Use the matching complete script body.

JS/TS:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if output=$(pnpm lint:code:fix 2>&1); then
  exit 0
fi
printf '%s\n' "$output" >&2
exit 2
```

Elixir:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if output=$(mix format 2>&1); then
  true
else
  printf '%s\n' "$output" >&2
  exit 2
fi
if output=$(mix credo --strict 2>&1); then
  exit 0
fi
printf '%s\n' "$output" >&2
exit 2
```

Go:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if output=$(golangci-lint run --fix 2>&1); then
  exit 0
fi
printf '%s\n' "$output" >&2
exit 2
```

Keep the handler as a synchronous PostToolUse command. Do not set `async`; the autofix process must finish and write its changes before the coding agent continues.

Capture the autofix command's output. If remaining lint violations make the command fail, write the linter output to stderr and exit 2 so the coding harness reports the violations visibly. Do not swallow the failure or return success.

**For non-JS/TS hex-boundary lint** — recommend the language-native equivalent. Don't attempt to install without a template; tell the user the rules they need to enforce (no imports from domain into adapters; no imports from application into adapters) and name the tool:

| Language | Tool |
|---|---|
| Java / Kotlin | ArchUnit |
| Go | `go list` + `depguard` |
| Python | `import-linter` |
| Rust | `cargo-modules` with CI assertions |

State the limitation honestly: without contree-provided config, the user wires the rules themselves.

### 8. CREATE TEST_TREES.md

Create `TEST_TREES.md` at the project root if it does not already exist, containing a short header noting that the file holds the project's test trees.

**Do not compose the trees yourself in this step.** Setup prepares the project. It does not define requirements.

**Do not create any `*.test.*` or `*.spec.*` files in this step**, not even with `.todo`/`.skip` stubs. Tests are the `tdd` skill's output.

### 9. SCAFFOLD MENTAL_MODEL.md

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

### 10. VERIFY

Configured examples must follow the setup rules: no copied comments, no env-var behaviour switches, and strong preference for composition over inheritance. Environment variables remain appropriate for secrets and external connection details because they configure boundaries rather than changing test/runtime behaviour.

Run the configured commands and confirm tree-shaped output where the framework can produce it:

- Normal test command — Unit, Port contract, Adapter, and Component tests
- Functional test command — System and Journey tests
- Combined lint command — normal lint and hex-boundary lint
- Mutation testing command — unit-level mutation report

**Do NOT create test files to verify the reporter.** If no tests exist yet, the empty suite's output (no tests found, reporter-formatted) is sufficient evidence that the reporter is wired correctly. Writing smoke tests or stubs violates the No test files rule. The `tdd` skill writes tests later, from the trees.

---

## Framework Reference

The examples in this reference must obey the setup process above and the session-start rules:

- Configure exactly one normal command and one functional command.
- Keep Unit, Port contract, Adapter, and Component in the normal command.
- Keep System and Journey in the functional command.
- Do not add per-layer test commands during setup.
- Do not use environment variables to switch behaviour between test and runtime. Environment variables are only for secrets and external connection details.
- Do not copy example comments into generated config or tests.
- Prefer composition patterns over inherited test classes.

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

**Normal command mapping** — include Unit, Port contract, Adapter, and Component tests in the default config:
```ts
export default defineConfig({
  test: {
    reporters: ['tree', 'junit'],
    outputFile: { junit: './reports/junit.xml' },
    include: [
      'src/**/*.unit.test.{ts,js}',
      'src/**/*.domain.test.{ts,js}',
      'src/**/*.use-case.test.{ts,js}',
      'src/**/*.adapter.test.{ts,js}',
      'test/component/**/*.component.test.{ts,js}',
    ],
  },
})
```

**Functional command mapping** — use a second config for System and Journey:
```ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    reporters: ['tree', 'junit'],
    outputFile: { junit: './reports/junit-functional.xml' },
    include: [
      'test/system/**/*.system.test.{ts,js}',
      'test/journey/**/*.journey.test.{ts,js}',
    ],
    testTimeout: 60_000,
    hookTimeout: 60_000,
  },
})
```

**Scripts:**
```json
{
  "test": "vitest run",
  "test:functional": "vitest run --config vitest.functional.config.ts",
  "test:watch": "vitest",
  "test:mutate": "stryker run",
  "lint": "pnpm lint:code && pnpm lint:arch"
}
```

**Gotchas:**
- Functional tests need their own include globs because System and Journey do not run from the normal command.
- Adapter tests stay in the normal command even when they need a Docker harness; the normal command should start that harness itself.

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
      displayName: 'normal',
      testMatch: [
        '<rootDir>/src/**/*.unit.test.{ts,js}',
        '<rootDir>/src/**/*.domain.test.{ts,js}',
        '<rootDir>/src/**/*.use-case.test.{ts,js}',
        '<rootDir>/src/**/*.adapter.test.{ts,js}',
        '<rootDir>/test/component/**/*.component.test.{ts,js}',
      ],
      transform: { '^.+\\.tsx?$': 'ts-jest' },
      testEnvironment: 'node',
    },
    {
      displayName: 'functional',
      testMatch: [
        '<rootDir>/test/system/**/*.system.test.{ts,js}',
        '<rootDir>/test/journey/**/*.journey.test.{ts,js}',
      ],
      transform: { '^.+\\.tsx?$': 'ts-jest' },
      testEnvironment: 'node',
      testTimeout: 60_000,
    },
  ],
}

export default config
```

**Scripts:**
```json
{
  "test": "jest --selectProjects normal",
  "test:functional": "jest --selectProjects functional",
  "test:mutate": "stryker run"
}
```

**Gotchas:**
- `verbose` and `reporters` are shared across all projects — you cannot set them per-project
- `displayName` is required for `--selectProjects` and `--ignoreProjects` to work
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

**Normal and functional test suites** — use separate config files:

`.mocharc.yml`:
```yaml
require: [tsx]
spec:
  - 'src/**/*.unit.test.{ts,js}'
  - 'src/**/*.domain.test.{ts,js}'
  - 'src/**/*.use-case.test.{ts,js}'
  - 'src/**/*.adapter.test.{ts,js}'
  - 'test/component/**/*.component.test.{ts,js}'
reporter: spec
parallel: true
jobs: 4
timeout: 5000
```

`.mocharc.functional.yml`:
```yaml
require: [tsx]
spec:
  - 'test/system/**/*.system.test.{ts,js}'
  - 'test/journey/**/*.journey.test.{ts,js}'
reporter: spec
parallel: false
timeout: 60000
```

**Scripts:**
```json
{
  "test": "mocha --config .mocharc.yml",
  "test:functional": "mocha --config .mocharc.functional.yml",
  "test:mutate": "stryker run"
}
```

**Gotchas:**
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
testpaths = ["src", "test"]
addopts = "--spec --strict-markers"

describe_prefixes = ["describe_", "context_", "when_"]

spec_header_format = "{module_path}:"
spec_test_format = "{result} {name}"
spec_success_indicator = "+"
spec_failure_indicator = "-"
spec_skipped_indicator = "?"

markers = [
    "normal: Unit, Port contract, Adapter, and Component tests",
    "functional: System and Journey tests",
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

**Normal and functional command mapping:**
```
src/
  wallet/
    wallet.domain.test.py
    save_wallet.use_case.test.py
    postgres_wallet.adapter.test.py
test/
  component/
    wallet.component.test.py
  system/
    wallet.system.test.py
  journey/
    checkout.journey.test.py
```

Configure the project commands:
```bash
pytest src test/component
pytest test/system test/journey
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
tests_dir = ["src/"]
runner = "python -m pytest src -x --tb=short -q"
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

**Normal and functional command mapping:**
```ruby
RSpec.configure do |config|
  config.example_status_persistence_file_path = "spec/examples.txt"
end
```

Configure the project commands:
```bash
rspec spec src test/component
rspec test/system test/journey
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

**Normal and functional command mapping** uses explicit package lists because `go test ./...` is flat and includes every package:
```bash
gotestsum --format testdox ./internal/... ./pkg/... ./test/component/...
gotestsum --format testdox ./test/system/... ./test/journey/...
```

**Mutation testing — gremlins:**
```bash
go install github.com/go-gremlins/gremlins/cmd/gremlins@latest
```

```bash
gremlins unleash
gremlins unleash ./internal/...
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

**Normal and functional command mapping** follows Rust's package and expression filters:
- Domain and Use-case tests stay close to the code that owns them.
- Adapter and Component tests run from the normal command.
- System and Journey tests run from the functional command.

```bash
cargo nextest run --lib
cargo nextest run -E 'package(test_system) | package(test_journey)'
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

**Normal and functional command mapping:**
```elixir
ExUnit.start(trace: true, exclude: [:functional])
```

```elixir
@moduletag :functional
```

```bash
mix test
mix test --only functional
```

**Mix aliases** for convenience in `mix.exs`:
```elixir
defp aliases do
  [
    "test": ["test --exclude functional"],
    "test.functional": ["test --only functional"],
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
        <testsuite name="Normal">
            <directory>test/normal</directory>
        </testsuite>
        <testsuite name="Functional">
            <directory>test/functional</directory>
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
vendor/bin/phpunit --testsuite=Normal
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
    "testFrameworkOptions": "--testsuite=Normal"
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

**Normal and functional command mapping** — JVM Test Suite Plugin (built-in since Gradle 7.3):
```kotlin
testing {
    suites {
        val test by getting(JvmTestSuite::class) {
            useJUnitJupiter()
        }
        val functionalTest by registering(JvmTestSuite::class) {
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
```

Run: `./gradlew test` for Unit, Port contract, Adapter, and Component. Run `./gradlew functionalTest` for System and Journey.

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
    targetTests.set(setOf("com.example.*DomainTest*", "com.example.*UseCaseTest*"))
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
        <targetTests>
            <param>com.example.*DomainTest*</param>
            <param>com.example.*UseCaseTest*</param>
        </targetTests>
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
  MyApp.NormalTests/MyApp.NormalTests.csproj
  MyApp.FunctionalTests/MyApp.FunctionalTests.csproj
```

```bash
dotnet test tests/MyApp.NormalTests/
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
        "test-projects": ["tests/MyApp.NormalTests/MyApp.NormalTests.csproj"],
        "mutate": ["**/*.cs", "!**/obj/**", "!**/bin/**", "!**/Migrations/**"],
        "reporters": ["html", "progress", "cleartext"],
        "thresholds": { "high": 80, "low": 60, "break": 50 },
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


npm run test:functional
```

#### package.json scripts (Node.js)

```json
{
  "test": "vitest run",
  "test:functional": "bash test/functional/run-docker.sh"
}
```

#### Makefile (language-agnostic)

```makefile
.PHONY: test-functional
test-functional:
	bash test/functional/run-docker.sh
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
