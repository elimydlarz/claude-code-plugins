#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "when a behaviour change is needed then the change is discussed with the user before modifying trees" {
  run cat "$SKILL"
  [[ "$output" == *"Talk it through with the user"* || "$output" == *"discuss"* ]]
}

@test "when a behaviour change is needed then every layer is consumer-driven" {
  run cat "$SKILL"
  assert_output --partial "every layer is consumer-driven"
  assert_output --partial "consumer is created before the thing it consumes is implemented"
}

@test "when a Journey, System, Component, or Adapter tree is written then paths describe principles, not enumerated cases" {
  run cat "$SKILL"
  assert_output --partial "principles, not cases"
  assert_output --partial "Journey, System, Component, and Adapter"
}

@test "when a Domain, Use-case, or Port tree is written then the tree describes what its consumer needs to observe at that subject's public seam" {
  run cat "$SKILL"
  assert_output --partial "Domain, Use-case, and Port trees"
  assert_output --partial "public inputs, outputs, and errors"
}

@test "change treats pure functions as consumer-driven" {
  run cat "$SKILL"
  assert_output --partial "Pure functions are still consumer-driven"
  assert_output --partial "observe its result or error"
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

@test "when a behaviour change is needed then the layer is chosen from Journey, System, Component, Adapter, Use-case, Domain, and Port according to the observable seam under test" {
  run cat "$SKILL"
  assert_output --partial "Journey"
  assert_output --partial "System"
  assert_output --partial "Component"
  assert_output --partial "Adapter"
  assert_output --partial "Use-case"
  assert_output --partial "Domain"
  assert_output --partial "Port"
  assert_output --partial "observable"
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

@test "when a tree is written then its coverage uses the seven labelled categories" {
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

@test "change treats path and file-boundary mismatch as design feedback" {
  run cat "$SKILL"
  assert_output --partial "mismatch between the consumer need and the file boundaries"
  assert_output --partial "design feedback"
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

@test "when a tree is named then its first line is exactly <Layer>: <Subject> and the layer prefix lets readers and sync detect duplication across trees that share a subject at different layers" {
  run cat "$SKILL"
  assert_output --partial "<Layer>: <Subject>"
  assert_output --partial "Without the layer prefix"
  assert_output --partial "detect duplication across layers"
}

@test "change nests a when-trigger that can only occur as a consequence of a prior then-outcome as a child, not a sibling" {
  run cat "$SKILL"
  assert_output --partial "Causal nesting"
  assert_output --partial "not a sibling — it is a child"
}
