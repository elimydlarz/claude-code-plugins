#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup-linter/SKILL.md"

@test "when an operator asks to set up code linting then the skill inspects the ecosystem and existing configuration and agrees the strong conventional rules with the operator" {
  run cat "$SKILL"
  assert_output --partial "Inspect the ecosystem"
  assert_output --partial "existing lint configuration"
  assert_output --partial "agree the strong conventional rules with the operator"
}

@test "when an operator asks to set up code linting then it installs and merges the conventional linter without replacing project-owned rules" {
  run cat "$SKILL"
  assert_output --partial "merge"
  assert_output --partial "Never replace project-owned rules"
  assert_output --partial "@eslint/js"
  assert_output --partial "strictTypeChecked"
  assert_output --partial "credo --strict"
  assert_output --partial "golangci-lint run"
}

@test "when an operator asks to set up code linting then it creates a native lint command and CI gate" {
  run cat "$SKILL"
  assert_output --partial "native project command"
  assert_output --partial "CI"
  assert_output --partial "lint:code"
  assert_output --partial "lint:code:fix"
}

@test "when an operator asks to set up code linting then synchronous project save hooks run the linter's autofix command from the project root before the coding agent continues" {
  run cat "$SKILL"
  assert_output --partial "PostToolUse"
  assert_output --partial '"matcher": "Edit|Write"'
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
  assert_output --partial ".contree/hooks/lint-on-save.sh"
  assert_output --partial 'cd "$(git rev-parse --show-toplevel)"'
  assert_output --partial "synchronous"
  refute_output --partial '"async": true'
}

@test "when an operator asks to set up code linting and the skill runs autofix and lint across the existing project and proves the CI gate and both coding-harness hooks before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "Run autofix across the whole existing project"
  assert_output --partial "run the non-fixing lint command"
  assert_output --partial "Verify the CI gate"
  assert_output --partial "actual Claude Code edit"
  assert_output --partial "actual Codex edit"
  assert_output --partial "Do not report completion until lint passes"
}

@test "if lint violations remain after automatic fixes then the skill fixes the remaining violations and reruns lint until it passes" {
  run cat "$SKILL"
  assert_output --partial "Fix remaining violations directly"
  assert_output --partial "Rerun lint after every repair batch until it passes"
  refute_output --partial "ask the operator to fix"
}

@test "if a save-time autofix cannot complete then the project hook reports the complete linter output and fails visibly" {
  run cat "$SKILL"
  assert_output --partial "complete linter output"
  assert_output --partial "stderr"
  assert_output --partial "exit 2"
}
