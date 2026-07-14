---
name: setup-mental-model
description: "Discover and reconcile an existing project's mental model, or create its empty seven-section home, then install durable project-local steering hooks. TRIGGER when: an operator asks to set up, discover, bootstrap, or enforce a project mental model."
---

# Setup Mental Model

Establish the project's domain theory with the operator and make coding agents load and reconcile it on every turn. Evidence owns the content; the fixed seven-section form owns its shape.

## Distinguish the project

Inspect the project root, manifests, source, tests, public documentation, configuration, history available in the workspace, and any existing `MENTAL_MODEL.md`.

An existing project has consumer-visible behaviour or domain decisions evidenced by its files. A new project has neither, even when manifests or empty source directories exist.

## Existing project

### Agree discovery

Explain that discovery will gather supported domain knowledge from running code, tests, public seams, documentation, configuration, and recorded decisions. Propose complete non-overlapping areas that cover the project exactly once. Agree the evidence and non-overlapping discovery areas with the operator before dispatching work.

### Discover with subagents

Discovery subagents inspect every agreed area. Dispatch at least one subagent even for a small existing project. Give each subagent exclusive file or capability ownership and require file paths plus the directly observed evidence for every claim.

Every report covers domain identity, world-to-code mapping, language, boundaries, invariants, rationale, temporal knowledge, and contradictions from inspected files:

- what the product is and who observes its behaviour
- how domain concepts map to source, tests, ports, adapters, and composition roots
- the vocabulary used consistently by operators, consumers, tests, and code
- bounded contexts, ownership, and dependency boundaries
- rules that remain true across behaviours
- decisions and the evidence for why they were made
- meaningful ordering, lifecycle, state transitions, and change over time
- contradictions between documentation, tests, source, configuration, and operator intent

Discovery is read-only. Subagents do not edit the mental model or resolve contradictions.

### Reconcile with the operator

Reconcile the evidence with the operator. Deduplicate overlapping findings, prefer direct behaviour and recorded decisions over inference, and use the project's established vocabulary.

Write `MENTAL_MODEL.md` with exactly these seven H2 sections in this order:

1. `## Core Domain Identity`
2. `## World-to-Code Mapping`
3. `## Ubiquitous Language`
4. `## Bounded Contexts`
5. `## Invariants`
6. `## Decision Rationale`
7. `## Temporal View`

Move supported existing content into its owning section. Remove no supported knowledge merely to shorten the file. Do not create extra H2 sections, metadata sections, appendices, or parallel mental-model documents.

Keep unsupported claims and consequential disagreements visible in the reconciliation presented to the operator. Do not invent evidence or silently resolve them. Put only agreed, evidenced statements into `MENTAL_MODEL.md`; report unresolved claims and disagreements separately with their conflicting evidence.

Obtain operator agreement on the reconciled seven-section mental model before installing steering.

## New project

Create the seven-section mental-model home in `MENTAL_MODEL.md` with the same seven H2 headings in the exact order above. Put one concise line under each heading describing the evidence that belongs there, without inventing domain knowledge. Do not infer a product identity, vocabulary, boundary, invariant, rationale, or lifecycle from empty scaffolding.

Install and prove the same project-local steering hooks used by an existing project.

## Install durable steering

Create executable `.contree/hooks/load-mental-model.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
model="$root/MENTAL_MODEL.md"
if [ ! -f "$model" ]; then
  printf '%s\n' 'MENTAL_MODEL.md is missing at the project root' >&2
  exit 2
fi
printf '%s\n\n' '# Mental Model'
cat "$model"
printf '%s\n' 'Use the mental model vocabulary and preserve its invariants. Surface consequential conflicts instead of routing around them.'
```

The project-local `SessionStart` hooks load the complete `MENTAL_MODEL.md` before coding agents work. They emit the model and steering on stdout and fail visibly if the repository root or model cannot be read.

Create executable `.contree/hooks/reconcile-mental-model.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
if printf '%s' "$input" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then
  printf '{}\n'
  exit 0
fi
root=$(git rev-parse --show-toplevel)
model="$root/MENTAL_MODEL.md"
if [ ! -f "$model" ]; then
  printf '%s\n' 'MENTAL_MODEL.md is missing at the project root' >&2
  exit 2
fi
printf '%s\n' 'MENTAL MODEL: Reconcile newly learned domain knowledge before finishing. Identify its owning section, prefer tightening existing knowledge, preserve evidenced invariants, and keep consequential conflicts visible. If this turn learned nothing new, reply 0.' >&2
exit 2
```

The project-local `Stop` hooks ask the coding agent to reconcile newly learned domain knowledge before it finishes. The `stop_hook_active` guard prevents the hook's follow-up turn from creating a loop.

Merge synchronous command entries into both `.claude/settings.json` and `.codex/hooks.json` without replacing project-owned settings or existing hooks:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/load-mental-model.sh\"",
            "statusMessage": "Loading mental model"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/reconcile-mental-model.sh\"",
            "statusMessage": "Reconciling mental model"
          }
        ]
      }
    ]
  }
}
```

Use the exact project configuration schema supported by the installed harness version while preserving these event and command semantics. Merge into existing event arrays rather than duplicating an identical command.

Preserve complete output from both scripts. Do not capture, summarize, truncate, redirect away, or swallow model content and errors. Fail visibly with the complete native error and exit 2 when either hook cannot find the project root, read the mental model, parse its required input, or execute its dependency.

Require both harnesses to load and trust the project configuration.

## Prove the steering

Prove both hooks through actual coding-agent turns before reporting completion. A script invocation is not proof that a harness loaded, trusted, and delivered a project hook.

For both Claude Code and Codex:

1. Start a fresh coding-agent turn in the project and require it to report one exact, distinctive fact from the loaded mental model without reading the file during the turn.
2. Start a separate turn that introduces one explicit piece of newly learned domain knowledge, then let the agent finish normally.
3. Verify the actual Stop follow-up asks for reconciliation and that a no-change response terminates without another hook loop.
4. Inspect the complete turn output for hook execution errors or truncated mental-model content.

Repair the script, configuration merge, trust, permissions, or event delivery whenever proof fails, then repeat the actual turn. Do not report completion until SessionStart and Stop delivery are proven under both harnesses.

Report the agreed discovery areas, evidence sources, reconciled or empty mental-model result, unresolved claims, installed hook paths, project configurations, and four actual-turn proof results to the operator.
