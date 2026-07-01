#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "change discusses the behaviour change with the user before modifying trees" {
  run cat "$SKILL"
  [[ "$output" == *"Talk it through with the user"* || "$output" == *"discuss"* ]]
}

@test "change scopes consumer vocabulary to Journey, System, and Adapter layers" {
  run cat "$SKILL"
  assert_output --partial "consumer"
  assert_output --partial "vocabulary"
  assert_output --partial "Journey, System, and Adapter"
}

@test "change scopes principles-not-cases to Journey, System, and Adapter layers" {
  run cat "$SKILL"
  assert_output --partial "principles, not cases"
  assert_output --partial "Journey, System, and Adapter"
}

@test "change writes Domain, Use-case, and Port-contract trees with top-level nodes naming exported functions, methods, or port operations" {
  run cat "$SKILL"
  assert_output --partial "Domain"
  assert_output --partial "Use-case"
  assert_output --regexp "Port-contract|port contract"
  assert_output --regexp "exported functions|functions/methods"
}

@test "change writes Domain, Use-case, and Port-contract tree paths as observable branches" {
  run cat "$SKILL"
  [[ "$output" == *"observable branch"* ]]
}

@test "change enforces that every tree's describe/it hierarchy mirrors the tree verbatim" {
  run cat "$SKILL"
  assert_output --partial "describe/it"
  assert_output --partial "verbatim"
}

@test "change chooses EARS patterns matching each requirement's nature" {
  run cat "$SKILL"
  assert_output --partial "EARS"
  assert_output --regexp "nature|match"
}

@test "change rejects tautological then clauses" {
  run cat "$SKILL"
  [[ "$output" == *"tautolog"* || "$output" == *"does not already imply"* ]]
}

@test "change plans System to inner-layer decomposition, one tree per behavioural unit" {
  run cat "$SKILL"
  assert_output --regexp "one tree per|one tree, one test file"
  assert_output --partial "System"
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

@test "change names coverage in parenthesised labelled pairs" {
  run cat "$SKILL"
  assert_output --regexp "parenthesised|in parentheses"
  assert_output --partial "labelled"
}

@test "change specifies the seven coverage categories" {
  run cat "$SKILL"
  assert_output --partial "src"
  assert_output --partial "domain"
  assert_output --partial "use-case"
  assert_output --partial "adapter"
  assert_output --partial "component"
  assert_output --partial "system"
  assert_output --partial "journey"
}

@test "change declares gaps explicitly with 'none' and omits not-applicable categories" {
  run cat "$SKILL"
  assert_output --partial "none"
  assert_output --regexp "omitted|omission"
}

@test "change treats awkward path naming as design feedback, not a reason to strip paths" {
  run cat "$SKILL"
  assert_output --partial "awkward"
  assert_output --regexp "reshape|reshaped"
}

@test "change reads the actual tests and source of the area it is changing before drafting the tree edit" {
  run cat "$SKILL"
  assert_output --regexp "actual test|actual tests and source|read the existing tests"
  assert_output --regexp "before drafting|before proposing|before modifying"
}

@test "change reconciles pre-existing tree-code drift in the area as part of the change" {
  run cat "$SKILL"
  assert_output --regexp "pre-existing|existing drift|tree-code drift"
  assert_output --regexp "reconcile|reconciled|coherent"
}

@test "change forbids cross-leaf references so every leaf stands alone" {
  run cat "$SKILL"
  assert_output --partial "see above"
  assert_output --partial "as before"
  assert_output --regexp "stands alone|inline"
}

@test "change duplicates an existing tree's paths when new behaviour is described as 'just like' it" {
  run cat "$SKILL"
  assert_output --regexp "just like|the same as"
  assert_output --regexp "duplicate|duplicated"
}

@test "change collapses duplicated trees into one shared-concept tree with generic implementation" {
  run cat "$SKILL"
  assert_output --regexp "single concept|shared concept|same concept"
  assert_output --partial "generic"
}
