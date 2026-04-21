#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup creates MENTAL_MODEL.md with exactly seven H2 sections when it does not exist" {
  run cat "$SKILL"
  [[ "$output" == *"seven H2 sections"* ]]
}

@test "setup names the seven mental-model sections" {
  run cat "$SKILL"
  [[ "$output" == *"Core Domain Identity"* ]]
  [[ "$output" == *"World-to-Code Mapping"* ]]
  [[ "$output" == *"Ubiquitous Language"* ]]
  [[ "$output" == *"Bounded Contexts"* ]]
  [[ "$output" == *"Invariants"* ]]
  [[ "$output" == *"Decision Rationale"* ]]
  [[ "$output" == *"Temporal View"* ]]
}

@test "setup puts a one-line placeholder under each mental-model section" {
  run cat "$SKILL"
  [[ "$output" == *"placeholder"* ]]
}

@test "setup does not modify an existing MENTAL_MODEL.md" {
  run cat "$SKILL"
  [[ "$output" == *"already exists"* ]]
  [[ "$output" == *"must not be modified"* || "$output" == *"leave it alone"* ]]
}

@test "setup adds a pointer line to CLAUDE.md identifying MENTAL_MODEL.md when missing" {
  run cat "$SKILL"
  [[ "$output" == *"pointer line"* ]]
  [[ "$output" == *"CLAUDE.md"* ]]
  [[ "$output" == *"MENTAL_MODEL.md"* ]]
}

@test "setup does not duplicate an existing CLAUDE.md pointer to MENTAL_MODEL.md" {
  run cat "$SKILL"
  [[ "$output" == *"do not duplicate"* || "$output" == *"already references"* ]]
}
