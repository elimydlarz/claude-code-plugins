#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup-mental-model/SKILL.md"

@test "when an operator asks to set up a mental model for an existing project then the skill agrees the evidence and non-overlapping discovery areas with the operator" {
  run cat "$SKILL"
  assert_output --partial "Agree the evidence and non-overlapping discovery areas with the operator"
}

@test "when an operator asks to set up a mental model for an existing project and discovery subagents report domain identity, world-to-code mapping, language, boundaries, invariants, rationale, temporal knowledge, and contradictions from inspected files" {
  run cat "$SKILL"
  assert_output --partial "Discovery subagents"
  assert_output --partial "domain identity, world-to-code mapping, language, boundaries, invariants, rationale, temporal knowledge, and contradictions"
  assert_output --partial "inspected files"
}

@test "when an operator asks to set up a mental model for an existing project and the coding agent reconciles the evidence with the operator into exactly the seven mental-model sections" {
  run cat "$SKILL"
  assert_output --partial "Reconcile the evidence with the operator"
  assert_output --partial "exactly these seven H2 sections in this order"
  assert_output --partial "## Core Domain Identity"
  assert_output --partial "## World-to-Code Mapping"
  assert_output --partial "## Ubiquitous Language"
  assert_output --partial "## Bounded Contexts"
  assert_output --partial "## Invariants"
  assert_output --partial "## Decision Rationale"
  assert_output --partial "## Temporal View"
}

@test "when an operator asks to set up a mental model for an existing project and unsupported claims and consequential disagreements remain visible rather than being silently invented or resolved" {
  run cat "$SKILL"
  assert_output --partial "Keep unsupported claims and consequential disagreements visible"
  assert_output --partial "Do not invent evidence or silently resolve them"
}

@test "when an operator asks to set up a mental model for an existing project and project SessionStart hooks load the mental model before coding agents work" {
  run cat "$SKILL"
  assert_output --partial 'project-local `SessionStart` hooks'
  assert_output --partial 'load the complete `MENTAL_MODEL.md` before coding agents work'
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
}

@test "when an operator asks to set up a mental model for an existing project and project Stop hooks ask the coding agent to reconcile newly learned domain knowledge before it finishes" {
  run cat "$SKILL"
  assert_output --partial 'project-local `Stop` hooks'
  assert_output --partial "reconcile newly learned domain knowledge before it finishes"
  assert_output --partial "stop_hook_active"
}

@test "when an operator asks to set up a mental model for an existing project and the skill proves both hooks through actual coding-agent turns before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "Prove both hooks through actual coding-agent turns before reporting completion"
  assert_output --partial "A script invocation is not proof"
}

@test "when an operator asks to set up a mental model for a new project then the skill creates the seven-section mental-model home without inventing domain knowledge" {
  run cat "$SKILL"
  assert_output --partial "Create the seven-section mental-model home"
  assert_output --partial "without inventing domain knowledge"
}

@test "when an operator asks to set up a mental model for a new project and it installs and proves the same project-local steering hooks" {
  run cat "$SKILL"
  assert_output --partial "Install and prove the same project-local steering hooks"
}

@test "project-local mental-model hooks are durable and preserve complete failure output" {
  run cat "$SKILL"
  assert_output --partial ".contree/hooks/load-mental-model.sh"
  assert_output --partial ".contree/hooks/reconcile-mental-model.sh"
  assert_output --partial "set -euo pipefail"
  assert_output --partial "Preserve complete output"
  assert_output --partial "exit 2"
  assert_output --partial "Fail visibly"
}
