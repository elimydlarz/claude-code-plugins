#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup installs a hex-boundary linter" {
  run cat "$SKILL"
  [[ "$output" == *"dependency-cruiser"* || "$output" == *"hex-boundary"* || "$output" == *"architectural linter"* ]]
}

@test "setup configures the linter to enforce Domain has no I/O" {
  run cat "$SKILL"
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"no I/O"* || "$output" == *"not reach adapters"* ]]
}

@test "setup configures the linter to enforce use-cases depend on ports, not concrete adapters" {
  run cat "$SKILL"
  [[ "$output" == *"ports"* ]]
  [[ "$output" == *"not concrete adapters"* || "$output" == *"interfaces"* ]]
}
