---
name: setup-contree
description: "Set up test framework with tree reporters, and generate initial requirement trees in CLAUDE.md. Run once per project."
---

# Setup Contree

Sets up a project for test-tree-driven development: configures the test framework, generates initial requirement trees in CLAUDE.md, and prepares the project for the `tdd` and `sync-requirements` skills.

## Process

### 1. REVIEW

Read project files — source code, existing tests, configs, CLAUDE.md. Understand:

- Language and ecosystem
- Existing test framework (if any)
- What behaviours the system implements today
- Whether `## Requirements` already exists in CLAUDE.md

### 2. IDENTIFY FRAMEWORKS

Detect existing test framework from project manifests (package.json, Cargo.toml, go.mod, mix.exs, Gemfile, composer.json, *.csproj, build.gradle, pom.xml). If none exists, identify the most suitable for the project's language.

### 3. SUGGEST

Present identified frameworks with trade-offs and recommendation. Let the user choose before proceeding.

### 4. DETERMINE TEST STRATEGY

Confirm how conventions apply to this project:

- Unit tests: colocated with source, `*.unit.test.*`
- Functional tests: `test/functional/` at project root, `*.functional.test.*`
- Tree-style output at both layers

### 5. CONFIGURE UNIT TEST RUNNER

Write tree-style reporter config into the project's test configuration. Use the Framework Reference below. Do NOT skip. Do NOT rely on defaults.

### 6. CONFIGURE FUNCTIONAL TEST RUNNER

Separate test command/config:

- `test/functional/` at project root
- Tree-style output
- Runnable independently from unit tests
- Same framework where possible

### 7. CONFIGURE MUTATION TESTING

Install appropriate Stryker package (or language equivalent). Configure with:

- Mutator targeting source files (not test files)
- Unit test runner
- Thresholds: `high: 80, low: 60, break: 50`
- Add script/command (e.g., `npm run test:mutate`)

See Stryker Reference below for language-specific setup.

### 8. SET UP CHANGED-TEST RUNNERS

Configure commands to run only tests changed since last run:

- Unit: built-in support where available (Vitest `--changed`, Jest `--onlyChanged`), otherwise script with git
- Functional: similar, scoped to `test/functional/`
- Commands should be simple to invoke (package.json scripts, Makefile targets)

### 9. GENERATE INITIAL REQUIREMENT TREES

This is the key step that distinguishes contree from a plain test framework setup.

**Read the codebase and generate test trees that describe what the system does today.** These become the `## Requirements` section in CLAUDE.md.

Process:
1. Identify the system's capabilities — what does it do from the consumer's perspective?
2. For each capability, write a functional-level test tree using `when/then` format
3. Describe operating principles, not implementation details
4. Include positive and negative paths
5. If existing tests exist, use them as input — but rewrite as principle-describing trees, don't copy test names verbatim
6. If the system is new/empty, write requirement trees for the planned capabilities based on what the user describes

**Do NOT implement the test trees** — they are requirements only at this stage. The `tdd` skill handles implementation later.

Write the trees into `## Requirements` in CLAUDE.md:

```markdown
## Requirements

### UserRegistration

```
UserRegistration
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  when the email is already registered
    then registration is rejected
```

### InvoiceGeneration

```
InvoiceGeneration
  when a completed order is submitted for invoicing
    then a PDF invoice is generated with line items
    and the invoice is emailed to the customer
  when the order has no line items
    then invoicing is rejected
```
```

Each capability gets its own subsection under `## Requirements`.

### 10. UPDATE CLAUDE.md

Add or update the following sections:

- `## Requirements` — the test trees from step 9
- Testing commands section with:
  - Command to run all unit tests with tree output
  - Command to run all functional tests with tree output
  - Command to run only changed unit/functional tests
  - Command to run Stryker mutation testing
  - Outside-in TDD workflow summary
  - Example test tree structure for this project

### 11. VERIFY

Run each layer's test suite and confirm:

- Unit test output is tree-shaped
- Functional test output is tree-shaped
- Stryker runs and produces mutation score
- If no tests exist yet, create minimal smoke tests at both layers with nested describe/it blocks, run to confirm tree-shaped output

## Framework Reference

### Tree Output Support

**True tree output** (nested indentation): Jest, Mocha, RSpec, Vitest, Gradle test-logger-plugin
**Partial tree** (one level grouping): pytest-spec, PHPUnit testdox
**Flat only** (no nesting model): Go, Rust, Elixir, Bats, Swift, .NET CLI

### JavaScript/TypeScript

- **Vitest**: `reporters: ['tree']` in vitest.config.ts (NOT verbose)
- **Jest**: `verbose: true` in jest.config
- **Mocha**: `reporter: spec` in .mocharc.yml

### Python

- **pytest**: Install `pytest-spec`, optionally `pytest-describe`. `addopts = "--spec"` in pyproject.toml

### Ruby

- **RSpec**: `--format documentation` in .rspec

### Go

- `go test -v` is flat. Use `gotestsum --format testdox` as best available. Be honest about limitations.

### PHP

- **PHPUnit**: `testdox="true"` in phpunit.xml

### Java/Kotlin

- **JUnit 5 + Gradle**: `gradle-test-logger-plugin` with `mocha` theme
- **JUnit 5 + Maven**: Surefire verbose config

### Rust

- `cargo test` has no nesting. Use `cargo nextest run` for cleaner flat output. Be honest.

### Elixir

- **ExUnit**: `trace: true` in test_helper.exs. Flat by design.

### C#/.NET

- `console;verbosity=detailed` or .csproj config

### Shell/Bash

- **Bats**: Flat only. `bats --pretty test/`. Simulate tree through naming.

### Swift

- `swift test --verbose` is flat.

## Stryker Reference

### JavaScript/TypeScript
- `@stryker-mutator/core` + runner plugin (vitest/jest/mocha)
- `stryker.config.mjs` with testRunner, mutate, reporters, thresholds

### Python
- `mutmut` (more mature than Stryker Python)
- Config in pyproject.toml

### Ruby
- `mutant` gem or `mutant-rspec`

### Java/Kotlin
- PIT (pitest) Gradle/Maven plugin

### C#/.NET
- `Stryker.NET` with `stryker-config.json`

### PHP
- `infection/infection` with `infection.json5`

### Go/Rust/Elixir/Swift
- Go: `go-mutesting` (experimental)
- Rust: `cargo-mutants`
- Elixir/Swift: no mature tool, skip and note
