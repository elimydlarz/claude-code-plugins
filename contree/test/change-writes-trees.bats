#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "change discusses the behaviour change with the user before modifying trees" {
  run cat "$SKILL"
  [[ "$output" == *"Talk it through with the user"* || "$output" == *"discuss"* ]]
}

@test "change scopes consumer vocabulary to Adapter and System layers" {
  run cat "$SKILL"
  [[ "$output" == *"consumer"* ]]
  [[ "$output" == *"Adapter and System"* ]]
  [[ "$output" == *"vocabulary"* ]]
}

@test "change scopes principles-not-cases to Adapter and System layers" {
  run cat "$SKILL"
  [[ "$output" == *"Adapter and System"* ]]
  [[ "$output" == *"principles, not cases"* ]]
}

@test "change writes Domain, Use-case, and Port-contract trees with top-level nodes naming exported functions, methods, or port operations" {
  run cat "$SKILL"
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"Use-case"* ]]
  [[ "$output" == *"Port-contract"* || "$output" == *"port contract"* ]]
  [[ "$output" == *"exported functions"* || "$output" == *"functions/methods"* ]]
}

@test "change writes Domain, Use-case, and Port-contract tree paths as observable branches" {
  run cat "$SKILL"
  [[ "$output" == *"observable branch"* ]]
}

@test "change enforces that every tree's describe/it hierarchy mirrors the tree verbatim" {
  run cat "$SKILL"
  [[ "$output" == *"describe/it"* ]]
  [[ "$output" == *"verbatim"* ]]
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

@test "change names file path(s) alongside the tree name in parentheses" {
  run cat "$SKILL"
  [[ "$output" == *"in parentheses"* || "$output" == *"parenthesised"* || "$output" == *"parens"* ]]
  [[ "$output" == *"file path"* ]]
}

@test "change treats awkward path naming as design feedback, not a reason to strip paths" {
  run cat "$SKILL"
  [[ "$output" == *"awkward"* ]]
  [[ "$output" == *"reshape"* || "$output" == *"reshaped"* ]]
}

@test "change reads the actual tests and source of the area it is changing before drafting the tree edit" {
  run cat "$SKILL"
  [[ "$output" == *"actual test"* || "$output" == *"actual tests and source"* || "$output" == *"read the existing tests"* ]]
  [[ "$output" == *"before drafting"* || "$output" == *"before proposing"* || "$output" == *"before modifying"* ]]
}

@test "change reconciles pre-existing tree-code drift in the area as part of the change" {
  run cat "$SKILL"
  [[ "$output" == *"pre-existing"* || "$output" == *"existing drift"* || "$output" == *"tree-code drift"* ]]
  [[ "$output" == *"reconcile"* || "$output" == *"reconciled"* || "$output" == *"coherent"* ]]
}
