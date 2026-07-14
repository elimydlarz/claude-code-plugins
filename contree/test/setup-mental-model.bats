#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup-mental-model/SKILL.md"

@test "when the skill classifies a project then consumer-visible behaviour or evidenced domain decisions make it existing while their absence makes it new" {
  run cat "$SKILL"
  assert_output --partial "consumer-visible behaviour or domain decisions"
  assert_output --partial "A new project has neither"
}

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

@test "when an operator asks to set up a mental model for an existing project and operator agreement on the reconciled mental model is required before steering is installed" {
  run cat "$SKILL"
  assert_output --partial "Obtain operator agreement on the reconciled seven-section mental model before installing steering"
}

@test "when an operator asks to set up a mental model for an existing project and project SessionStart hooks load the mental model before coding agents work" {
  run cat "$SKILL"
  assert_output --partial 'project-local `SessionStart` hooks'
  assert_output --partial 'load the complete `MENTAL_MODEL.md` before coding agents work'
}

@test "when an operator asks to set up a mental model for an existing project and project Stop hooks ask the coding agent to reconcile newly learned domain knowledge before it finishes" {
  run cat "$SKILL"
  assert_output --partial 'project-local `Stop` hooks'
  assert_output --partial "reconcile newly learned domain knowledge before it finishes"
  assert_output --partial "stop_hook_active"
}

@test "when an operator asks to set up a mental model for an existing project and both project configurations preserve existing hooks while receiving each mental-model hook exactly once" {
  run cat "$SKILL"
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
  assert_output --partial "preserving these event and command semantics"
  assert_output --partial "rather than duplicating an identical command"
}

@test "when an operator asks to set up a mental model for an existing project and hook failures preserve complete output and fail visibly" {
  run cat "$SKILL"
  assert_output --partial "Preserve complete output"
  assert_output --partial "Fail visibly with the complete native error and exit 2"
}

@test "when an operator asks to set up a mental model for an existing project and the skill proves both hooks through actual Claude Code and Codex turns before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "Prove both hooks through actual coding-agent turns before reporting completion"
  assert_output --partial "For both Claude Code and Codex"
  assert_output --partial "A script invocation is not proof"
}

@test "when an operator asks to set up a mental model for a new project then the skill creates the seven-section mental-model home with one evidence-guiding line per section without inventing domain knowledge" {
  run cat "$SKILL"
  assert_output --partial "Create the seven-section mental-model home"
  assert_output --partial "one concise line under each heading describing the evidence that belongs there"
  assert_output --partial "without inventing domain knowledge"
}

@test "when an operator asks to set up a mental model for a new project and it installs and proves the same project-local steering hooks" {
  run cat "$SKILL"
  assert_output --partial "Install and prove the same project-local steering hooks"
}
