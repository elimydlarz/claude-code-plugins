#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup configures a normal linter" {
  run cat "$SKILL"
  assert_output --partial "normal linter"
  assert_output --partial "project's language conventions"
}

@test "when setup is run then a conventional normal linter is installed and configured with the ecosystem's strong recommended rules" {
  run cat "$SKILL"
  assert_output --partial "@eslint/js"
  assert_output --partial "strictTypeChecked"
  assert_output --partial "credo --strict"
  assert_output --partial "golangci-lint run"
}

@test "when setup is run then a project-level hook is created for coding-agent file saves" {
  run cat "$SKILL"
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
  assert_output --partial "PostToolUse"
  assert_output --partial '"matcher": "Edit|Write"'
  assert_output --partial "merge into existing project hook configuration"
}

@test "setup configures a hex-boundary linter" {
  run cat "$SKILL"
  [[ "$output" == *"dependency-cruiser"* || "$output" == *"hex-boundary"* || "$output" == *"architectural linter"* ]]
}

@test "setup configures one combined lint command" {
  run cat "$SKILL"
  assert_output --partial "combined lint command"
  assert_output --partial "normal lint"
  assert_output --partial "hex-boundary lint"
}

@test "setup configures the hex-boundary linter to enforce Domain has no I/O" {
  run cat "$SKILL"
  assert_output --partial "Domain"
  assert_output --regexp 'no I/O|not reach adapters'
}

@test "setup configures the hex-boundary linter to enforce use-cases depend on ports, not concrete adapters" {
  run cat "$SKILL"
  assert_output --partial "ports"
  assert_output --regexp 'not concrete adapters|interfaces'
}

@test "setup configures the hex-boundary linter to enforce no circular dependencies" {
  run cat "$SKILL"
  assert_output --partial "no-circular"
  assert_output --partial "circular: true"
}

@test "setup wires CI to run the combined lint command so normal and boundary violations fail the build" {
  run cat "$SKILL"
  assert_output --partial "Ensure CI runs"
  assert_output --partial "normal and boundary violations fail the build"
}

@test "setup names the language-native equivalent tool and states the rules to enforce when no first-party template exists" {
  run cat "$SKILL"
  assert_output --partial "For non-JS/TS hex-boundary lint"
  assert_output --partial "recommend the language-native equivalent"
  assert_output --partial "ArchUnit"
  assert_output --partial "depguard"
  assert_output --partial "import-linter"
  assert_output --partial "cargo-modules"
}

@test "setup communicates honestly that the user wires the rules themselves without a first-party template" {
  run cat "$SKILL"
  assert_output --partial "State the limitation honestly"
  assert_output --partial "the user wires the rules themselves"
}
