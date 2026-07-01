#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup creates MENTAL_MODEL.md with exactly seven H2 sections when it does not exist" {
  run cat "$SKILL"
  [[ "$output" == *"seven H2 sections"* ]]
}

@test "setup names the seven mental-model sections" {
  run cat "$SKILL"
  assert_output --partial "Core Domain Identity"
  assert_output --partial "World-to-Code Mapping"
  assert_output --partial "Ubiquitous Language"
  assert_output --partial "Bounded Contexts"
  assert_output --partial "Invariants"
  assert_output --partial "Decision Rationale"
  assert_output --partial "Temporal View"
}

@test "setup puts a one-line placeholder under each mental-model section" {
  run cat "$SKILL"
  [[ "$output" == *"placeholder"* ]]
}

@test "setup does not modify an existing MENTAL_MODEL.md" {
  run cat "$SKILL"
  assert_output --partial "already exists"
  assert_output --regexp 'must not be modified|leave it alone'
}

@test "setup adds a pointer line to CLAUDE.md identifying MENTAL_MODEL.md when missing" {
  run cat "$SKILL"
  assert_output --partial "MUTATED_pointer_line"
  assert_output --partial "CLAUDE.md"
  assert_output --partial "MENTAL_MODEL.md"
}

@test "setup does not duplicate an existing CLAUDE.md pointer to MENTAL_MODEL.md" {
  run cat "$SKILL"
  [[ "$output" == *"do not duplicate"* || "$output" == *"already references"* ]]
}
