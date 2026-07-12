---
name: setup
description: "Comprehensively install Contree's coding-agent feedback loops through a dynamic, operator-guided workflow. TRIGGER when: the operator asks for full, complete, comprehensive, or luxury Contree setup, or starts a project and wants all steering configured."
---

# Setup

Prepare a project with fast, useful feedback that steers coding agents while they work. Orchestrate the focused setup skills; do not duplicate their implementation guidance here.

## Inspect

Read the project mental model, test trees, source, tests, manifests, test and lint configuration, CI, and coding-harness hooks. Establish which feedback loops already work by running their native commands.

Build a dynamic setup workflow containing only missing or broken steering:

- `setup-test-feedback` for normal, functional, and impacted-test feedback
- `setup-linter` for conventional lint, automatic fixes, CI, and save-time feedback
- `setup-architecture-linter` for enforced hexagonal boundaries and Stop feedback
- `fix-architecture` when the architecture command reports violations
- `bootstrap-test-trees` for the mental model, behavioural contract, and tests that reify it
- `setup-mutation-testing` for fast Domain and Use-case test-quality feedback

## Engage the operator

Present the dynamic setup workflow with the project evidence behind it. Engage the operator only at consequential choices that project evidence cannot settle:

- replacing or selecting a test or application framework
- defining the intended architecture when the source and mental model disagree
- agreeing the behavioural scope that bootstrap will treat as the contract
- agreeing a mutation threshold that changes the project's quality gate

Make routine ecosystem choices directly. Do not turn conventional package installation or an obvious native command into an approval checkpoint.

## Orchestrate

Run each selected focused skill faithfully.

Use subagents for independent, non-overlapping setup work that can safely proceed in parallel. Keep dependent feedback loops ordered: configure before fixing, establish trees before implementing their tests, and install mutation feedback after Domain and Use-case tests exist. Give every subagent explicit file or capability ownership. Reconcile their results yourself before starting dependent work.

Run `setup-test-feedback` before `bootstrap-test-trees` so the second bootstrap wave has working normal and functional commands. Run `setup-linter` before `setup-architecture-linter` so the combined lint command has a stable conventional-lint half. When architecture setup invokes `fix-architecture`, finish that repair before bootstrap records the project architecture.

## Verify

Run every configured feedback command from the project root:

- normal tests
- functional tests
- impacted tests through the native `test-changed` command and the actual project Stop hook
- conventional lint and its autofix command
- architecture lint and the actual project Stop hook
- mutation testing

Fix every failure through the focused skill that owns it, then rerun that command. Verify coding-harness hooks through real edit and Stop turns; files on disk are not proof that the harness loaded them.

If any specialised setup skill cannot establish its feedback loop, fail visibly. Do not claim that the project is prepared.

## Report

Report the installed commands, automatic hooks, test-tree coverage, and mutation result to the operator. Name any feedback loop that could not be installed as a setup failure, with its complete error.
