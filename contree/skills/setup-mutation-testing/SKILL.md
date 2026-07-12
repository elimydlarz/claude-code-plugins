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

## 3. Run and strengthen

Run mutation testing before reporting completion. Treat tool crashes, test-runner mismatch, unselected tests, and invalid mutation globs as configuration failures: fix the configuration and rerun the smallest command that proves the repair.

If surviving mutants keep the threshold from passing:

1. Map each survivor to the Domain or Use-case tree path whose observable behaviour should kill it.
2. If the behaviour is absent from the contract, use the `change` skill to agree and add it before writing a test.
3. Use the `tdd` skill to write one responsible Domain or Use-case test, observe RED against the surviving behavior, and make it GREEN.
4. Strengthen the responsible Domain or Use-case tests without asserting implementation details.
5. Rerun only the affected mutation scope until the agreed threshold passes.

Never kill mutants by weakening exclusions, lowering the agreed threshold, ignoring survivors, asserting incidental dependency calls, or adding tests without observable behaviour.

Report the mutation command, production scope, exact test exclusions, selected Domain and Use-case tests, incremental state, threshold, duration, score, and remaining survivors to the operator. Do not claim completion until the native mutation command runs and the agreed threshold passes.
