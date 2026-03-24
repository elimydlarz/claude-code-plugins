---
name: setup-test-trees
description: "Set up a test framework with tree-style reporter output. Run this once per project to configure your test runner."
---

# Test Framework Setup

Configure the project's test framework for outside-in TDD with tree-style reporter output at every layer — unit tests, functional tests, and mutation testing.

## Principles

The `tdd` skill enforces these — setup must make them possible:

1. **Outside-in, always.** Every behaviour change starts with a failing functional test, then TDDs inward through unit layers.
2. **Tests are specifications.** Tree output describes operating principles, not case enumerations.
3. **Two test layers, different jobs.** Functional = end-to-end proof (no mocks). Unit = design driver + fast feedback (mocked collaborators).
4. **One failing test at a time.** Changed-test runners enable tight feedback loops.
5. **Mutation testing validates finished work.** Stryker runs at the end, not during development.
6. **Tree output at every layer.** Nested, indented, readable by default — the most critical setup task.

## Goal

Set up a testing environment where:

1. **Unit tests** run fast, test modules in isolation, produce tree-shaped output
2. **Functional tests** exercise the real system end-to-end, produce tree-shaped output
3. **Stryker mutation testing** validates that unit tests assert meaningful behaviour
4. **Every layer** produces nested, human-readable output that reads as a specification:

```text
MyModule
  when input is valid
    and user is authenticated
      then returns the resource
    and user is NOT authenticated
      then returns 401
  when input is invalid
    then returns 400
```

## Process

1. **Review** the project — read project files, any existing tests, and config to understand the project's language, ecosystem, and what behaviours it defines. A project doesn't need application code to have testable behaviour — declarative config, skill definitions, and other non-code artifacts all define behaviour that can be verified.
2. **Identify** candidate test frameworks:
   - Detect any existing test framework from project files (package.json, Cargo.toml, go.mod, mix.exs, Gemfile, composer.json, *.csproj, build.gradle, pom.xml, etc.)
   - If no test framework is installed, identify the most suitable options for the project's language
3. **Suggest** the identified frameworks to the user — present the options with trade-offs and a recommendation, then let the user choose before proceeding
4. **Determine test strategy** — based on the project review and chosen framework, confirm how the `tdd` skill conventions apply:
   - Unit tests: colocated with source, named `*.unit.test.*`
   - Functional tests: in `test/functional/`, named `*.functional.test.*`
   - Tree-style output at both layers
5. **Configure the unit test runner** — write the tree-style reporter config into the project's test configuration file. See the Framework Reference below. Do NOT skip this step. Do NOT rely on defaults.
6. **Configure the functional test runner** — set up a separate test command/config for functional tests:
   - Functional tests live in `test/functional/` at the project root
   - They must also produce tree-style output
   - They should be runnable independently from unit tests (separate command or config)
   - Configure with the same framework where possible, or a dedicated integration/e2e framework if more appropriate
7. **Configure Stryker mutation testing** — set up Stryker to run against the unit test suite:
   - Install the appropriate Stryker package for the project's language
   - Configure `stryker.config.mjs` (or language-equivalent) with:
     - Mutator targeting source files (not test files)
     - Unit test runner and test command
     - Thresholds: `high: 80, low: 60, break: 50` as starting defaults
   - Add a script/command to run Stryker (e.g. `npm run test:mutate`, `make mutate`)
   - See the Stryker Reference below for language-specific setup
8. **Set up changed-test runners** — configure commands to run only tests that have changed since the last run, for fast TDD feedback at each layer:
   - Unit: Use built-in support where available (e.g. Vitest `--changed`, Jest `--onlyChanged`), otherwise script with git
   - Functional: Similar, but scoped to `test/functional/`
   - The commands should be simple to invoke (e.g. package.json scripts, Makefile targets)
9. **Update the project's CLAUDE.md** — add a testing section so the `tdd` skill can use concrete commands. Include:
   - Command to run all unit tests with tree output
   - Command to run all functional tests with tree output
   - Command to run only changed unit tests
   - Command to run only changed functional tests
   - Command to run Stryker mutation testing
   - The outside-in TDD workflow: "start with a failing functional test, TDD through unit layers, verify functional test passes, then run Stryker"
   - An example of the expected test tree structure at both layers for this project
10. **Verify** each layer by running the test suite and confirming:
    - Unit test output is tree-shaped
    - Functional test output is tree-shaped
    - Stryker runs and produces a mutation score report
    - If no tests exist yet, create minimal smoke tests at both layers with nested `describe`/`it` blocks and run them to confirm tree-shaped output before finishing

## Framework Reference

For each framework below, you MUST write the reporter config into the project's configuration file. Do not just pass CLI flags — persist the config so every test run produces tree output by default.

**Tree support varies by framework.** Not all test frameworks support nested tree output:
- **True tree output** (nested indentation from describe/context blocks): Jest, Mocha, RSpec, Vitest (with `tree` reporter), Gradle (with test-logger-plugin)
- **Partial tree output** (one level of grouping): pytest (with pytest-spec), PHPUnit (testdox)
- **Flat only** (no describe/context nesting in the testing model): Go, Rust, Elixir, Bats, Swift, .NET CLI

For flat-only frameworks, configure the best available verbose output and be transparent with the user that tree output is not supported by the framework's testing model.

### JavaScript / TypeScript

#### Vitest
- **Reporter:** `tree` — this is the reporter that produces nested, indented tree output from `describe` blocks. Do NOT use `verbose` — it produces flat, redundant output in Vitest v3+.
- **Config:** Write `reporters: ['tree']` into `vitest.config.ts`:
  ```ts
  export default defineConfig({
    test: {
      reporters: ['tree'],
    },
  })
  ```
- **Docs:** https://vitest.dev/guide/reporters
- **GitHub:** https://github.com/vitest-dev/vitest

#### Jest
- **Reporter:** `verbose` — produces nested, indented tree output from `describe` blocks. You MUST configure this; Jest's default does NOT produce tree output.
- **Config:** Write `verbose: true` into `jest.config.js` or `jest.config.ts`:
  ```js
  module.exports = {
    verbose: true,
  }
  ```
- **Docs:** https://github.com/jestjs/jest/blob/main/docs/Configuration.md
- **GitHub:** https://github.com/jestjs/jest

#### Mocha
- **Reporter:** `spec` — produces nested, indented tree output. This is Mocha's default, but you MUST explicitly set it in config to be safe.
- **Config:** Write into `.mocharc.yml`:
  ```yaml
  reporter: spec
  ```
- **Docs:** https://mochajs.org/api/mocha.reporters.spec
- **GitHub:** https://github.com/mochajs/mocha

### Python

#### pytest
- **Reporter:** Plain `-v` produces flat output. Install `pytest-spec` for output grouped by class/module with one level of indentation (class > test method). For deeper nesting, also use `pytest-describe` which adds nested `describe` blocks.
- **Config:** Install `pytest-spec` and write into `pyproject.toml`:
  ```toml
  [tool.pytest.ini_options]
  addopts = "--spec"
  ```
  If `pytest-spec` is not viable, fall back to `-v` but note output will be flat. For deeper nesting, also install `pytest-describe`.
- **Docs:** https://docs.pytest.org/en/stable/how-to/output.html
- **GitHub:** https://github.com/pytest-dev/pytest

### Ruby

#### RSpec
- **Reporter:** `documentation` formatter — produces nested, indented tree output from `describe`/`context` blocks. You MUST configure this; RSpec's default `progress` formatter only shows dots.
- **Config:** Write into `.rspec`:
  ```
  --format documentation
  ```
- **Docs:** https://github.com/rspec/rspec-core
- **GitHub:** https://github.com/rspec/rspec-core

### Go

#### go test
- **Reporter:** `go test -v` produces flat output. Go's testing model (TestXxx functions with t.Run subtests) does not support describe/context nesting, so true tree output is not possible.
- **Best available:** Use `gotestsum --format testdox` for readable flat output grouped by package. This is the best Go can offer — be honest with the user that Go test output is flat by design.
- **Config:** Install and create a Makefile target or script:
  ```makefile
  test:
  	gotestsum --format testdox
  ```
- **Install:** `go install gotest.tools/gotestsum@latest`
- **Docs:** https://github.com/gotestyourself/gotestsum

### PHP

#### PHPUnit
- **Reporter:** `testdox` — produces readable, tree-shaped output grouped by test class. You MUST configure this; PHPUnit's default does NOT produce tree output.
- **Config:** Write `testdox="true"` into `phpunit.xml`:
  ```xml
  <phpunit testdox="true">
  ```
- **Docs:** https://docs.phpunit.de/en/11.5/textui.html
- **GitHub:** https://github.com/sebastianbergmann/phpunit

### Java / Kotlin

#### JUnit 5 + Gradle
- **Reporter:** Gradle's native `testLogging` produces flat output (`ClassName > testMethod PASSED`), NOT tree-shaped. Use the `gradle-test-logger-plugin` with the `mocha` theme for true nested tree output that supports `@Nested` JUnit 5 tests.
- **Config:** Write into `build.gradle`:
  ```groovy
  plugins {
      id 'com.adarshr.test-logger' version '4.0.0'
  }
  testlogger {
      theme 'mocha'
  }
  ```
- **Docs:** https://github.com/radarsh/gradle-test-logger-plugin

#### JUnit 5 + Maven
- **Reporter:** Surefire verbose output
- **Config:** Write into `pom.xml` surefire plugin configuration, or run with `mvn test -Dsurefire.useFile=false`
- **Docs:** https://maven.apache.org/surefire/maven-surefire-plugin/examples/logging.html

### Rust

#### cargo test
- **Reporter:** Rust's testing model does not support describe/context nesting, so true tree output is not possible. `cargo test` and `cargo-nextest` both produce flat output with module-path prefixes.
- **Best available:** Use `cargo nextest run` for cleaner flat output with better formatting than `cargo test`. Be honest with the user that Rust test output is flat by design.
- **Config:** Install nextest and create a Makefile target:
  ```makefile
  test:
  	cargo nextest run
  ```
- **Install:** `cargo install cargo-nextest`
- **Docs:** https://github.com/nextest-rs/nextest

### Elixir

#### ExUnit
- **Reporter:** ExUnit explicitly forbids nested `describe` blocks by design, so true tree output is not possible. Trace mode shows individual test names grouped by module (flat), rather than dots.
- **Best available:** Use `trace: true` for verbose flat output grouped by module. Be honest with the user that Elixir test output is flat by design.
- **Config:** Write into `test/test_helper.exs`:
  ```elixir
  ExUnit.start(trace: true)
  ```
- **Docs:** https://github.com/elixir-lang/elixir/blob/main/lib/ex_unit/lib/ex_unit.ex
- **GitHub:** https://github.com/elixir-lang/elixir

### C# / .NET

#### dotnet test
- **Reporter:** .NET's CLI test output is flat — detailed verbosity shows individual test pass/fail results but without nesting by namespace/class hierarchy. True tree output is only available in Visual Studio's Test Explorer (GUI).
- **Best available:** Use `console;verbosity=detailed` for verbose flat output. Be honest with the user that .NET CLI test output is flat.
- **Config:** Write into the test project's `.csproj`:
  ```xml
  <PropertyGroup>
    <VSTestLogger>console;verbosity=detailed</VSTestLogger>
  </PropertyGroup>
  ```
  Or run with `dotnet test --logger "console;verbosity=detailed"`
- **Docs:** https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-test

### Shell / Bash

#### Bats (Bash Automated Testing System)
- **Reporter:** Bats has no `describe`/`context` blocks — tests are flat `@test "name" { ... }` functions. True tree output is not possible. The `--pretty` formatter colorizes output but it remains a flat list.
- **Best available:** Use `bats --pretty test/` for colorized flat output. Tree structure can only be simulated through test naming conventions (e.g., indented or hierarchical test names). Be honest with the user that Bats output is flat by design.
- **Config:** Run with `bats --pretty test/`
- **Docs:** https://bats-core.readthedocs.io/en/stable/tutorial.html
- **GitHub:** https://github.com/bats-core/bats-core
- **Install:** `npm install -g bats` or via package manager

### Swift

#### Swift Testing
- **Reporter:** `swift test --verbose` produces flat output, not tree-shaped. A hierarchical tree reporter using box-drawing characters was developed as a GSoC 2025 project but may not be in stable releases yet.
- **Best available:** Use `swift test --verbose` for verbose flat output. Be honest with the user that Swift CLI test output is currently flat.
- **Config:** Run with `swift test --verbose`
- **Docs:** https://github.com/swiftlang/swift-testing

## Stryker Reference

Stryker is a mutation testing framework. It modifies your source code (creates "mutants") and runs your unit tests against each mutant. If tests still pass with a mutation, those tests aren't actually verifying that behaviour — the mutant "survived."

**Always configure Stryker to run against unit tests only** — functional tests are too slow for mutation testing and should be excluded.

### JavaScript / TypeScript

- **Package:** `@stryker-mutator/core` + runner plugin (`@stryker-mutator/vitest-runner`, `@stryker-mutator/jest-runner`, `@stryker-mutator/mocha-runner`)
- **Install:** `npm install -D @stryker-mutator/core @stryker-mutator/vitest-runner` (or jest/mocha equivalent)
- **Config:** Create `stryker.config.mjs`:
  ```js
  /** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
  export default {
    testRunner: 'vitest',  // or 'jest', 'mocha'
    mutate: ['src/**/*.ts', '!src/**/*.test.*', '!src/**/*.d.ts'],
    reporters: ['clear-text', 'html'],
    thresholds: { high: 80, low: 60, break: 50 },
  };
  ```
- **Script:** Add to package.json: `"test:mutate": "stryker run"`
- **Docs:** https://stryker-mutator.io/docs/stryker-js/introduction/

### Python

- **Package:** `mutmut` (Stryker's Python equivalent is less mature; `mutmut` is the standard Python mutation tester)
- **Install:** `pip install mutmut`
- **Config:** Write into `pyproject.toml` or `setup.cfg`:
  ```toml
  [tool.mutmut]
  paths_to_mutate = "src/"
  tests_dir = "."
  runner = "python -m pytest -x --spec"
  ```
- **Script:** Add Makefile target: `mutate: mutmut run`
- **Docs:** https://github.com/boxed/mutmut

### Ruby

- **Package:** `mutant` gem (or `mutant-rspec` for RSpec integration)
- **Install:** `gem install mutant-rspec`
- **Config:** Run with: `bundle exec mutant run --include lib --require your_lib --use rspec 'YourModule*'`
- **Docs:** https://github.com/mbj/mutant

### Java / Kotlin

- **Package:** PIT (pitest) — the standard JVM mutation testing tool
- **Gradle:** Add `id 'info.solidsoft.pitest' version '1.15.0'` plugin
- **Config:** Write into `build.gradle`:
  ```groovy
  pitest {
      targetClasses = ['com.yourpackage.*']
      targetTests = ['com.yourpackage.*']
      outputFormats = ['HTML']
      threads = 4
      timestampedReports = false
      mutationThreshold = 50
  }
  ```
- **Docs:** https://pitest.org/

### C# / .NET

- **Package:** `Stryker.NET`
- **Install:** `dotnet tool install -g dotnet-stryker`
- **Config:** Create `stryker-config.json`:
  ```json
  {
    "stryker-config": {
      "reporters": ["cleartext", "html"],
      "thresholds": { "high": 80, "low": 60, "break": 50 }
    }
  }
  ```
- **Script:** `dotnet stryker`
- **Docs:** https://stryker-mutator.io/docs/stryker-net/introduction/

### PHP

- **Package:** `infection/infection`
- **Install:** `composer require --dev infection/infection`
- **Config:** Create `infection.json5`:
  ```json5
  {
    "source": { "directories": ["src"] },
    "logs": { "text": "infection.log", "html": "infection.html" },
    "minMsi": 50,
    "minCoveredMsi": 80
  }
  ```
- **Script:** `vendor/bin/infection --threads=4`
- **Docs:** https://infection.github.io/guide/

### Go / Rust / Elixir / Swift

Mutation testing tooling for these languages is less mature. If the project uses one of these languages:
- **Go:** `go-mutesting` exists but is experimental. Mention it and let the user decide.
- **Rust:** `cargo-mutants` is available. `cargo install cargo-mutants && cargo mutants`
- **Elixir:** No mature mutation testing tool. Skip and note this.
- **Swift:** No mature mutation testing tool. Skip and note this.
