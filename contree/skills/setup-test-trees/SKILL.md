---
name: setup-test-trees
description: "Set up test trees and durable project-local coding-agent steering without implementing tests. TRIGGER when: an operator asks to establish, discover, backfill, configure, or set up test trees for an existing or new project."
---

# Setup Test Trees

Establish `TEST_TREES.md` as the project's behavioural contract and install durable steering that keeps coding agents working from it. This skill owns trees and project-local tree steering. It does not implement tests.

## 1. Distinguish the Project

Read the project root, source, existing tests, public documentation, project configuration, `MENTAL_MODEL.md`, and `TEST_TREES.md` when present.

An existing project already exposes behaviour to a consumer. A new project has no consumer-visible behaviour, even when manifests, configuration, or empty source directories exist.

## 2. Existing Project: Agree Discovery Scope

Explain the behavioural evidence that setup will gather:

- observable inputs, outputs, errors, and side effects
- public seams through which consumers observe behaviour
- existing tests and the behaviour they prove
- contradictions among source, tests, documentation, and operator intention
- architecture boundaries that identify test subjects without creating extra test kinds

Derive complete non-overlapping behavioural areas from direct project evidence. Present those areas and their boundaries. Agree complete non-overlapping scope with the operator before dispatching discovery. Every area in scope must have exactly one owner.

## 3. Existing Project: Discover in Parallel

Dispatch discovery subagents over the agreed areas. Give each subagent one explicit ownership boundary. Discovery subagents inspect every agreed area exactly once for observable behaviour, existing tests, public seams, errors, side effects, and contradictions.

Discovery is read-only. Each subagent returns file-backed evidence in the consumer's vocabulary. Subagents do not edit source, tests, `MENTAL_MODEL.md`, or `TEST_TREES.md`.

## 4. Existing Project: Reconcile the Contract

Reconcile the evidence yourself before proposing trees. Resolve overlaps, vocabulary differences, and contradictions against direct evidence and operator intention.

Reconcile the evidence with the operator through `change` into EARS trees with honest coverage. Follow its consumer-driven test kinds, causal nesting, one-tree-one-test-file boundary, and coverage syntax.

Every discovered behaviour is expressed at its consumer-visible seam. Describe principles rather than examples and include observable errors, side effects, and prevented effects. Do not invent unsupported behaviour.

Name every applicable `src`, `unit`, `integration`, `component`, and `journey` coverage path. Use `none` where a test is expected but absent and omit only inapplicable test kinds. Existing tests count as coverage only when their hierarchy and assertions actually reify the tree.

Present the complete reconciled trees to the operator and obtain agreement before installing steering. Do not implement tests, create placeholder tests, or change production behaviour. Test implementation belongs to `tdd` after setup.

## 5. New Project: Create the Empty Home

Create an empty `TEST_TREES.md` containing only a heading and one sentence identifying it as the home for test trees.

Do not invent behaviour, write behaviour paths, or infer a first capability. Do not create test files. The first requested capability pulls its trees and tests into existence through `change` and `tdd`.

Install and prove the same project-local SessionStart and Stop hooks described below.

## 6. Install Durable SessionStart Steering

Create executable `.contree/hooks/test-trees-session-start.sh` with this body:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
printf '%s\n' '# Test Trees'
cat TEST_TREES.md
cat <<'EOF'

# Test-tree writing rules

- TEST_TREES.md is the behavioural contract.
- Write trees before tests or implementation.
- Use EARS paths at consumer-visible seams.
- One tree maps to exactly one test file, whose hierarchy mirrors the tree verbatim.
- Name honest src, unit, integration, component, and journey coverage; use none for expected gaps and omit only inapplicable test kinds.
- Route contract changes through contree:change and test or implementation gaps through contree:tdd.
EOF
```

The script loads `TEST_TREES.md` and the tree-writing rules before coding agents work. It fails visibly if the repository root or tree contract cannot be read.

Merge this synchronous project-local `SessionStart` entry into both `.claude/settings.json` and `.codex/hooks.json` without replacing existing settings or hooks:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/test-trees-session-start.sh\"",
            "statusMessage": "Loading test trees"
          }
        ]
      }
    ]
  }
}
```

Preserve every existing matcher group and command. Do not duplicate an equivalent test-tree SessionStart command.

## 7. Install Durable Stop Steering

Create executable `.contree/hooks/test-trees-on-stop.sh` with this body:

```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
if printf '%s' "$input" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then
  printf '{}\n'
  exit 0
fi
cd "$(git rev-parse --show-toplevel)"
printf '%s\n' 'TEST TREES: Before finishing, reconcile drift between trees, tests, and implementation. Update the contract through contree:change and close test or implementation gaps through contree:tdd. If no drift exists, reply 0.' >&2
exit 2
```

The project Stop hook asks the coding agent to reconcile drift between trees, tests, and implementation before it finishes. The `stop_hook_active` guard prevents the hook's follow-up Stop turn from creating a loop.

Merge this synchronous project-local `Stop` entry into both `.claude/settings.json` and `.codex/hooks.json` without replacing existing settings or hooks:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/test-trees-on-stop.sh\"",
            "statusMessage": "Reconciling test-tree drift"
          }
        ]
      }
    ]
  }
}
```

Preserve every existing matcher group and command. Do not duplicate an equivalent test-tree Stop command.

## 8. Prove Steering Through Actual Turns

Require both coding harnesses to load and trust their project configuration. Presence on disk is not proof that a harness loaded a hook.

For Claude Code and Codex separately:

1. Start a fresh actual coding-agent SessionStart turn through that harness without manually invoking the hook. Prove the agent receives the current `TEST_TREES.md` content and the tree-writing rules before its prompt.
2. Run an actual coding-agent Stop turn through that harness without manually invoking the hook. Prove the drift request reaches the agent before it finishes.
3. Let the hook's follow-up Stop turn run and prove the loop guard exits successfully without another drift request.

Fix hook scripts, permissions, trust, and merged configuration at the source, then repeat the actual turns until all four event-and-harness paths work. Do not report completion while either harness has only file-presence or direct-script evidence.

## Complete

Do not report completion until:

- the operator agreed the existing project's complete discovery scope and reconciled trees, or the new project has an empty tree home
- no test file or production behaviour was created by this skill
- both project config files preserve their prior settings and contain both steering hooks
- an actual coding-agent SessionStart turn and actual coding-agent Stop turn prove both hooks under both harnesses

Report the agreed scope, created or reconciled trees, honest coverage gaps, installed hook paths, merged project configs, and actual-turn proof to the operator.
