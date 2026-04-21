#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "change discusses the behaviour change with the user before modifying trees" {
  run cat "$SKILL"
  [[ "$output" == *"Talk it through with the user"* || "$output" == *"discuss"* ]]
}

@test "change writes trees from the consumer's perspective" {
  run cat "$SKILL"
  [[ "$output" == *"consumer"* ]]
}

@test "change chooses EARS patterns matching each requirement's nature" {
  run cat "$SKILL"
  [[ "$output" == *"EARS"* ]]
  [[ "$output" == *"nature"* || "$output" == *"match"* ]]
}

@test "change rejects tautological then clauses" {
  run cat "$SKILL"
  [[ "$output" == *"tautolog"* || "$output" == *"does not already imply"* ]]
}

@test "change plans System to inner-layer decomposition, one tree per behavioural unit" {
  run cat "$SKILL"
  [[ "$output" == *"one tree per"* || "$output" == *"one tree, one test file"* ]]
  [[ "$output" == *"System"* ]]
}

@test "change only edits affected paths when modifying existing behaviour" {
  run cat "$SKILL"
  [[ "$output" == *"Don't rewrite paths that aren't changing"* || "$output" == *"only affected paths"* ]]
}

@test "change confirms with user before removing a capability" {
  run cat "$SKILL"
  [[ "$output" == *"Confirm with the user"* || "$output" == *"user confirmation"* || "$output" == *"confirm"* ]]
}

@test "change presents trees for alignment before implementation" {
  run cat "$SKILL"
  [[ "$output" == *"alignment"* || "$output" == *"present"* ]]
}

@test "change suggests running sync once trees are complete" {
  run cat "$SKILL"
  [[ "$output" == *"sync"* ]]
}
