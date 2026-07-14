---
name: bootstrap-test-trees
description: "Compose mental-model and test-tree setup, then implement every existing-project tree through a second subagent wave. TRIGGER when: the operator asks to bootstrap, backfill, discover, or implement a project's existing behaviour as test trees and tests."
---

# Bootstrap Test Trees

Expand Contree into the project in three ordered phases: establish mental-model steering, establish test-tree steering, then make every existing-project tree executable. Keep phase ownership in the coordinator and prove retained artifacts and hooks before advancing.

## Distinguish the project

Read the project root, source, tests, configuration, consumer documentation, `MENTAL_MODEL.md`, and `TEST_TREES.md` when present.

A project is existing when it already has consumer-visible behaviour. A project is new when it has no consumer-visible behaviour, even if manifests or empty source directories exist.

## Establish the steering

Run `setup-mental-model` faithfully and wait for its discovery, reconciliation, artifact, SessionStart-hook, and Stop-hook gates to pass.

Run `setup-test-trees` faithfully and wait for its discovery, reconciliation, artifact, SessionStart-hook, and Stop-hook gates to pass.

Invoke both focused skills yourself. Do not delegate either entire skill to an unattended background agent. Inspect the retained `MENTAL_MODEL.md`, `TEST_TREES.md`, project hook scripts, `.claude/settings.json`, and `.codex/hooks.json`; a subagent summary is not proof. Continue only after actual coding-agent turns prove that later agents receive both the mental model and test trees while they work and receive drift feedback before they finish.

## Existing project: implement the tests

After the operator has agreed the contract, start a second wave of subagents regardless of project size. Partition complete non-overlapping trees across the wave. One tree belongs to exactly one subagent.

Exactly one tree maps to exactly one test file and exactly one test file maps to exactly one tree. Separate behaviours into separate files when they are separate trees; never share one test file across multiple trees.

Each implementation subagent uses `tdd` for its owned trees and:

- writes one test at a time and observes RED before trusting it
- implements tests at each tree's native seam
- makes each test hierarchy mirror its tree verbatim
- updates the tree's coverage path when its test file is created
- creates no placeholder, skipped, or fake tests
- writes no comments in test code
- runs the narrowest owning test after every test addition

Subagents do not weaken trees to make tests pass and do not edit trees outside their ownership.

Reconcile the implementations yourself. Confirm every retained tree has exactly one retained uncommented test file whose hierarchy mirrors it verbatim. Run the project's normal and journey test commands. If a test exposes disagreement with operator intention, leave it visible and use `change` for a contract correction or `tdd` for an implementation correction.

## New project

Stop after `setup-mental-model` and `setup-test-trees` have created their empty homes and proved the project-local steering hooks. Do not write behaviour trees or tests. Leave them to be pulled into existence by the first requested capability through `change` and `tdd`.

## Complete

For an existing project, bootstrap is complete only when both focused setup skills passed, both steering hooks were proved through actual turns, every agreed tree has exactly one passing mirrored test file, and the normal and journey commands pass.

For a new project, bootstrap is complete only when both empty homes exist, both steering hooks were proved through actual turns, and no behaviour tree or test was created.
