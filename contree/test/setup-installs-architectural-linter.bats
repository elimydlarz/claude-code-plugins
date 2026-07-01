#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup installs a hex-boundary linter" {
  run cat "$SKILL"
  [[ "$output" == *"dependency-cruiser"* || "$output" == *"hex-boundary"* || "$output" == *"architectural linter"* ]]
}

@test "setup configures the linter to enforce Domain has no I/O" {
  run cat "$SKILL"
  assert_output --partial "Domain"
  assert_output --regexp 'no I/O|not reach adapters'
}

@test "setup configures the linter to enforce use-cases depend on ports, not concrete adapters" {
  run cat "$SKILL"
  assert_output --partial "ports"
  assert_output --regexp 'not concrete adapters|interfaces'
}

@test "setup configures the linter to enforce no circular dependencies" {
  run cat "$SKILL"
  assert_output --partial "no-circular"
  assert_output --partial "circular: true"
}

@test "setup wires CI to run the linter so boundary violations fail the build" {
  run cat "$SKILL"
  assert_output --partial "Ensure CI runs"
  assert_output --partial "architectural violations fail builds"
}

@test "setup names the language-native equivalent tool and states the rules to enforce when no first-party template exists" {
  run cat "$SKILL"
  assert_output --partial "For non-JS/TS projects"
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
