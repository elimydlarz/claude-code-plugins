---
name: setup-mutation-testing
description: "Set up and prove fast mutation-test feedback, then strengthen Domain and Use-case tests until the agreed threshold passes. TRIGGER when: an operator asks to configure, run, optimize, or fix mutation testing."
---

# Setup Mutation Testing

Configure mutation testing as a fast test-quality feedback loop, prove it against the existing project, and close the test gaps it exposes.

## 1. Inspect and agree

Inspect the source and test layout before changing files:

- production-source roots and generated or vendored code
- colocated and separate test roots, suffixes, contracts, fixtures, and declarations
- the normal test framework and its native related-test selection
- existing mutation configuration, reports, incremental state, and CI commands
- the Domain and Use-case tests that can observe production mutations cheaply

Read the latest official mutation-tool and runner documentation through Context7 before configuring their APIs.

Present the exact production mutation scope, excluded patterns, selected tests, incremental strategy, native command, and proposed threshold. Agree the mutation scope and useful feedback threshold with the operator before changing files. Prefer the smallest production scope that represents the operator's current quality gate; do not mutate generated code, adapters, configuration, or speculative future code.

## 2. Configure mutation feedback

Install and merge the ecosystem's mutation tool and the runner matching the project's test framework. Preserve project-owned configuration.

Target production source with an explicit exclusion for every colocated test pattern. Include the project's actual patterns for Unit, Domain, Use-case, Port contract, Adapter, Component, System, and Journey tests, plus declarations, generated code, and fixtures that sit under the source root. Broad source globs without exact test exclusions are invalid.

Mutation test runners select only Domain and Use-case tests when the framework supports test selection. Do not spend mutation cycles on Adapter, Component, System, or Journey tests. Configure framework-native related-test selection or per-test coverage so each mutant runs only tests capable of observing its source.

Enable incremental mode and retain its machine-local state outside version control. Add one native mutation command using the project's command conventions. Together, incremental mode, related-test selection, and the native mutation command provide the fastest available repeat feedback.

Use the threshold agreed with the operator as a failing quality gate. Configure concise terminal progress plus a durable report that identifies each surviving mutant, source location, mutation, and responsible test scope.

## 3. Install progressive Stop feedback

Add a project-local incremental mutation command alongside the native full mutation command. Back it with an executable runner under `.contree/scripts/` that records content hashes for the project's actual Domain or Use-case production and test files in `.contree/state/`. Keep that state out of version control.

The changed-file runner must:

1. Compare the current relevant-file hashes with the hashes recorded after the last successful full or incremental mutation run.
2. Exit successfully without invoking the mutation tool when no Domain or Use-case production or test files changed.
3. Invoke the mutation tool in incremental mode, scoped through its related-test or per-test coverage data, when any relevant file changed.
4. Preserve the complete mutation output, including surviving mutants, source locations, score, and threshold result.
5. Record the new hashes only after mutation feedback passes the agreed threshold.
6. Return the mutation tool's failure when the threshold is missed or the tool cannot run.

Use the project's native conventions for both commands. In a JavaScript project, for example, keep `test:mutate` as the full command and add `test:mutate:changed` for the project-local incremental mutation command. Generate the runner with the exact detected paths and native commands; do not leave example globs or multiple ecosystem alternatives in the project.

Create executable `.contree/hooks/mutation-on-stop.sh`, substituting the project's exact incremental command:

```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
if printf '%s' "$input" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then
  printf '{}\n'
  exit 0
fi
cd "$(git rev-parse --show-toplevel)"
if output=$(pnpm test:mutate:changed 2>&1); then
  [ -z "$output" ] || printf '%s\n' "$output" >&2
  printf '{}\n'
  exit 0
fi
printf '%s\n' "$output" >&2
exit 2
```

Check `stop_hook_active` before invoking mutation feedback so the hook's own follow-up Stop task exits silently. Capture and preserve the complete mutation output. A missed threshold and a tool failure both write the complete output to stderr and exit 2.

Merge this synchronous project Stop hook into both `.claude/settings.json` and `.codex/hooks.json` without replacing existing settings or hooks:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/mutation-on-stop.sh\"",
            "statusMessage": "Mutation testing relevant changes"
          }
        ]
      }
    ]
  }
}
```

Keep this hook synchronous so the coding agent receives surviving-mutant and tool failures before finishing its turn. The hook must coexist with normal-test and architecture Stop hooks; it does not replace or combine them.

## 4. Run and strengthen

Run mutation testing before reporting completion. Treat tool crashes, test-runner mismatch, unselected tests, and invalid mutation globs as configuration failures: fix the configuration and rerun the smallest command that proves the repair.

If surviving mutants keep the threshold from passing:

1. Map each survivor to the Domain or Use-case tree path whose observable behaviour should kill it.
2. If the behaviour is absent from the contract, use the `change` skill to agree and add it before writing a test.
3. Use the `tdd` skill to write one responsible Domain or Use-case test, observe RED against the surviving behavior, and make it GREEN.
4. Strengthen the responsible Domain or Use-case tests without asserting implementation details.
5. Rerun only the affected mutation scope until the agreed threshold passes.

Never kill mutants by weakening exclusions, lowering the agreed threshold, ignoring survivors, asserting incidental dependency calls, or adding tests without observable behaviour.

After the native full mutation command passes, record the relevant-file baseline for progressive feedback. Then verify the hooks through actual coding-agent Stop turns in both supported harnesses:

1. Change an irrelevant file and prove the project-local runner does not invoke mutation testing.
2. Change one Domain or Use-case production or test file and prove incremental mutation runs before the coding agent finishes.
3. Exercise a controlled missed-threshold result and a controlled tool failure, and prove each actual Stop turn receives the complete mutation output on stderr with exit 2.
4. Restore only the deliberate verification edits and restore the passing mutation command without discarding pre-existing project changes.

Do not accept direct hook invocation as verification of the harness wiring. Require the project to trust and load both hook configurations, then observe the results through actual coding-agent Stop turns. Keep native full mutation verification: rerun the full mutation command after hook verification and do not report completion unless it passes the agreed threshold.

Report the mutation command, production scope, exact test exclusions, selected Domain and Use-case tests, incremental state, threshold, duration, score, and remaining survivors to the operator. Do not claim completion until the native mutation command runs and the agreed threshold passes.
