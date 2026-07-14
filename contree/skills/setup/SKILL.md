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
- `setup-mental-model` for the seven-section model and project-local model steering
- `setup-test-trees` for the behavioural contract and project-local tree steering
- `bootstrap-test-trees` to compose both steering skills and implement their trees as tests
- `setup-mutation-testing` for fast Domain and Use-case test quality feedback

## Engage the operator

Present the dynamic setup workflow with the project evidence behind it. Engage the operator only at consequential choices that project evidence cannot settle:

- replacing or selecting a test or application framework
- defining the intended architecture when the source and mental model disagree
- agreeing the behavioural scope that bootstrap will treat as the contract
- agreeing a mutation threshold that changes the project's quality gate

Make routine ecosystem choices directly. Do not turn conventional package installation or an obvious native command into an approval checkpoint.

## Orchestrate

Run each selected focused skill faithfully.

Treat setup as Contree progressively expanding into the project. After each focused skill, prove its project-local hooks before continuing so every later coding-agent turn receives all steering installed by the earlier phases. Preserve and merge earlier hooks; no setup phase may replace or disconnect feedback installed by another.

Use subagents for independent, non-overlapping setup work that can safely proceed in parallel. Keep dependent feedback loops ordered: configure before fixing, establish trees before implementing their tests, and install mutation feedback after Domain and Use-case tests exist. Give every subagent explicit file or capability ownership, then reconcile their results yourself before starting dependent work.

Keep ownership of the dynamic workflow in this coordinator. Do not delegate an entire focused skill to an unattended background agent. Invoke each focused skill yourself, let that skill dispatch its required bounded subagents, and wait for every selected phase to finish. Before advancing, confirm that no subagent is still running for that phase. A background task launch is not phase completion.

Run `setup-test-feedback` before `bootstrap-test-trees` so the second bootstrap wave has working normal and journey commands. Within bootstrap, `setup-mental-model` runs before `setup-test-trees`, and both project-local steering hooks must work before the test implementation wave. Run `setup-linter` before `setup-architecture-linter` so the combined lint command has a stable conventional-lint half. When architecture setup invokes `fix-architecture`, finish that repair before bootstrap records the project architecture.

Gate dependent phases on retained evidence. Never accept a subagent summary as proof. After every focused skill, inspect its changed files and run its owning command. After `bootstrap-test-trees`, require at least one retained consumer-driven EARS tree for an existing project and exactly one retained test file for each tree, with its hierarchy mirrored, before mutation setup begins. If those artifacts are absent, resume or repair bootstrap instead of moving on.

## Verify

Run every configured feedback command from the project root:

- normal tests
- journey tests
- impacted tests through the native `test-changed` command and the actual synchronous project save hooks
- conventional lint and its autofix command
- architecture lint and the actual project Stop hook
- mutation testing and its relevant-change project Stop hook

Fix every failure through the focused skill that owns it, then rerun that command and verify its feedback. Verify each save hook through an actual file edit and each Stop hook through an actual Stop turn; files on disk are not proof that the harness loaded them.

Before reporting, list every selected phase and prove that it passed its artifact gate, command gate, and subagent-completion gate. Do not mark an orchestration task complete while one of its focused-skill agents is still running.

If any specialised setup skill cannot establish its feedback loop, fail visibly. Do not claim that the project is prepared.

## Report

Report the installed commands, progressively accumulated automatic hooks, mental-model and test-tree steering, test-tree coverage, and mutation result to the operator. Name any feedback loop that could not be installed as a setup failure, with its complete error.
