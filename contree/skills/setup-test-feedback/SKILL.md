---
name: setup-test-feedback
description: "Set up fast test feedback for coding agents by configuring normal, journey, and impacted-test commands plus project save hooks. TRIGGER when: an operator asks to configure a test framework, test commands, test output, changed-test selection, test hooks, or Docker-backed tests."
---

# Setup Test Feedback

Build the project's test feedback loop with the operator. Configure tests; do not invent behaviours, test trees, or test files.

## Outcome

Coding agents receive fast normal-test feedback after each file edit, while the operator retains a separate production-like journey command. Existing project choices survive unless the operator agrees to change them.

## 1. Inspect and agree

Inspect the existing project before changing files:

- language, ecosystem, package manager, workspaces, and native command conventions
- source layout, existing tests, test suffixes, and test framework configuration
- current normal, journey, CI, and project-hook commands
- external services required by Integration, Component, or Journey tests
- framework-native related-test or impact-selection support

Read the latest official framework documentation through Context7 before configuring an API or plugin.

Present the detected framework, evidence, tree-output quality, exact normal and journey mapping, changed-test mechanism, and any Docker lifecycle to the operator. Agree the framework choice and command mapping with the operator before changing files. If choosing or replacing the main application framework would be necessary, resolve that consequential decision separately.

## 2. Merge the test configuration

Merge existing test configuration. Never replace a project-owned configuration file or discard its reporters, coverage, CI, timeouts, setup files, or plugins.

Configure tree-shaped output for both normal and journey commands where the ecosystem supports it. When the ecosystem only produces flat output, configure its strongest native grouping and tell the operator the exact limitation.

Map the fixed Contree strategy:

- the normal command runs Unit, Integration, and Component tests
- a separate journey command runs Journey tests
- Unit tests are colocated with their subjects as `*.unit.test.*`
- Integration tests are colocated with their highest-level subjects as `*.integration.test.*`
- Component tests live under `test/component/` as `*.component.test.*`
- Journey tests live under `test/journey/` as `*.journey.test.*`
- Journey is a broad, production-like test of a curated user arc across capabilities, with external services replaced by test doubles only if unavoidable
- Component is a deep in-process test of one capability through the whole app, with external services replaced by test doubles
- Integration starts from the highest-level subject and mocks everything except the subjects you are integrating to see if they really work together as expected
- Unit tests cover every public surface with native unit tests, and every dependency outside the subject is mocked

Use native project commands such as package scripts, Make targets, task aliases, build-tool tasks, or ecosystem equivalents. Do not create separate commands for every test kind.

## 3. Configure impacted tests

Create a native `test-changed` command using the framework's maintained related-test or dependency-selection capability. It must identify project files changed since the last completed normal test run and run only impacted normal tests. A changed test file impacts itself; shared test configuration and dependency changes impact every normal test.

Keep machine-local baseline state out of version control. If no completed normal run exists, run the normal command and record the project-file state only after it completes successfully. After a successful impacted run, record the new state. Do not substitute watch mode, last-failed selection, mutation selection, or an unconditional full suite for impact analysis.

Create an executable project wrapper under `.contree/hooks/` that:

- changes to the repository root
- invokes the exact native `test-changed` command
- preserves complete test output
- exits `2` when impacted tests fail

Merge synchronous `PostToolUse` hooks into both `.claude/settings.json` and `.codex/hooks.json` without replacing existing settings or hooks:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/test-changed.sh\"",
            "statusMessage": "Running impacted tests"
          }
        ]
      }
    ]
  }
}
```

The project save hooks give coding agents the impacted normal-test result after each file edit and before they continue.

Require each coding harness to load and trust its project hook. A hook present on disk but not exercised by its harness is not verified.

## 4. Own external-service lifecycles

When tests need external services, make the relevant test command own a self-contained Docker lifecycle. It starts the services, waits for readiness, runs its tests, and uses an exit trap to always tear test artefacts down. Never depend on services already running. Pass secrets and external connection details through environment variables; do not use environment variables as test/runtime behaviour switches.

Integration and Component tests remain in the normal command even when that command must own Docker. Journey infrastructure remains owned by the journey command.

## 5. Verify and fix

Run both test commands and preserve their tree-shaped output. Then verify the changed-test feedback path:

1. Run the normal command to establish a successful baseline.
2. Change one known source file.
3. Run `test-changed` and prove the related normal test runs while an unrelated normal test does not.
4. Exercise each project save hook through an actual coding-agent file edit and prove its result reaches the agent before it continues.
5. Restore only the deliberate verification edit while preserving all project changes that existed before setup.

Fix failed test commands and hooks, then rerun the complete verification until the feedback path works. Fail visibly with the complete native output if an external dependency, unavailable tool, or consequential operator decision prevents repair. Do not report completion until the normal command, journey command, baseline, impact selection, and both project hooks work.

Report the agreed framework, normal command, journey command, changed-test command, installed save hooks, Docker-owned commands, and verification results to the operator.
