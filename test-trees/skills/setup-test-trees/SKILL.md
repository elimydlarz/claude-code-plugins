---
name: setup-test-trees
description: "Set up a test framework with tree-style reporter output. Run this once per project to configure your test runner."
---

# Test Framework Setup

Configure the project's test framework to produce tree-style reporter output — nested, human-readable test results that read as a specification.

## Goal

Ensure that when tests are run, output looks like this:

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
4. **Determine test strategy** — based on the project review and chosen framework, confirm how the conventions from the `tdd` skill (colocated test files, naming conventions, test tree output format) will apply to this specific project
5. **Configure the tree-style reporter** — this is the most critical step. You MUST write the reporter/formatter config into the project's test configuration file. The reporter must produce nested, indented, tree-shaped output where `describe` blocks create indentation levels. See the Framework Reference below for the exact config to write for each framework. Do NOT skip this step. Do NOT rely on defaults — explicitly configure the reporter even if it happens to be the default.
6. **Set up a changed-test runner** — configure a simple way to run only the tests that have changed (or whose subjects have changed) since the last test run. This enables fast feedback during TDD. Approach depends on the framework:
   - Use built-in support where available (e.g. Vitest `--changed`, Jest `--onlyChanged`)
   - Otherwise, create a script/command that uses git to detect changed test files and changed source files, maps source files to their colocated test files, and runs only those tests
   - The command should be simple to invoke (e.g. a package.json script, Makefile target, or shell alias)
7. **Update the project's CLAUDE.md** — add a section with the actual test commands for this project so the `tdd` skill can use them concretely. Include:
   - Command to run all tests with tree output
   - Command to run only changed tests (from step 6)
   - Any other project-specific testing conventions
8. **Verify** by running the test suite and confirming output is tree-shaped — nested and indented like the Goal example above, NOT a flat list of test names. If no tests exist yet, create a minimal smoke test with nested `describe`/`it` blocks and run it to confirm tree-shaped output before finishing.

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
