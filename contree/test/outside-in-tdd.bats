#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/tdd/SKILL.md"

@test "tdd directs one failing test at a time in tree order" {
  run cat "$SKILL"
  [[ "$output" == *"one failing test at a time"* ]]
}

@test "tdd starts each capability from a failing Journey test at the highest tolerable realism" {
  run cat "$SKILL"
  [[ "$output" == *"highest tolerable realism"* || "$output" == *"max realism"* || "$output" == *"max-realism"* ]]
  [[ "$output" == *"real driving and driven adapters"* || "$output" == *"real driven adapters"* ]]
  [[ "$output" == *"Journey"* ]]
}

@test "tdd leans on the journey and pushes detail to inner layers when breadth at max realism is unaffordable" {
  run cat "$SKILL"
  [[ "$output" == *"unaffordable"* ]]
  [[ "$output" == *"lean on the journey"* ]]
}

@test "tdd keeps the journey curated and runnable under 5 minutes, trimmed to highest-impact and most-recent" {
  run cat "$SKILL"
  [[ "$output" == *"curated"* ]]
  [[ "$output" == *"under 5 minutes"* ]]
  [[ "$output" == *"highest-impact"* ]]
  [[ "$output" == *"most-recent"* ]]
}

@test "tdd gates implementation on a ground-level failing test under the journey/functional failure" {
  run cat "$SKILL"
  [[ "$output" == *"ground layer"* ]]
  [[ "$output" == *"journey/functional failure"* ]]
}

@test "tdd adds inner-layer tests only when failing functional-test pressure demands them" {
  run cat "$SKILL"
  [[ "$output" == *"pressure"* ]]
  [[ "$output" == *"inner"* ]]
}

@test "tdd writes tests at the tree's layer (Journey / System / Component / Adapter / Use-case / Domain)" {
  run cat "$SKILL"
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"Use-case"* ]]
  [[ "$output" == *"Component"* ]]
  [[ "$output" == *"Adapter"* ]]
  [[ "$output" == *"System"* ]]
  [[ "$output" == *"Journey"* ]]
}

@test "tdd describes the Component layer — real adapters, externals doubled at the edge, in-process" {
  run cat "$SKILL"
  [[ "$output" == *"Component"* ]]
  [[ "$output" == *"in-memory database"* ]]
  [[ "$output" == *"stubbed outbound HTTP"* ]]
  [[ "$output" == *"in-process"* ]]
}

@test "tdd threads Component between System and the inner layers in the descent" {
  run cat "$SKILL"
  [[ "$output" == *"System → Component"* ]]
}

@test "tdd reframes System as the same surface a Component test covers, validated against real infrastructure, selective" {
  run cat "$SKILL"
  [[ "$output" == *"same single-capability surface a Component test covers"* ]]
  [[ "$output" == *"selective, not exhaustive"* ]]
}

@test "tdd mirrors the tree in describe/it hierarchy" {
  run cat "$PROJECT_ROOT/skills/tdd/SKILL.md" "$PROJECT_ROOT/skills/change/SKILL.md"
  [[ "$output" == *"describe"* ]]
  [[ "$output" == *"mirror"* || "$output" == *"mirrors"* ]]
}

@test "tdd does not silently modify existing trees" {
  run cat "$SKILL"
  [[ "$output" == *"Don't change existing trees silently"* || "$output" == *"existing trees are not modified"* || "$output" == *"not modify or remove"* ]]
}

@test "tdd wires in-memory adapters for use-case tests" {
  run cat "$SKILL"
  [[ "$output" == *"in-memory adapter"* ]]
  [[ "$output" == *"Use-case"* ]]
}

@test "tdd imports the shared port contract suite for driven adapter tests" {
  run cat "$SKILL"
  [[ "$output" == *"shared"* ]]
  [[ "$output" == *"contract"* ]]
}

@test "tdd exercises real infrastructure when testing a real driven adapter" {
  run cat "$SKILL"
  [[ "$output" == *"real infrastructure"* || "$output" == *"real infra"* ]]
}

@test "tdd adds newly discovered cases without removing existing paths" {
  run cat "$SKILL"
  [[ "$output" == *"add new cases as you discover them"* || "$output" == *"add newly discovered cases"* ]]
  [[ "$output" == *"Never modify or remove an existing path"* || "$output" == *"not modify or remove"* ]]
}

@test "tdd breaks the implementation intentionally when a red test passes" {
  run cat "$SKILL"
  [[ "$output" == *"break the implementation intentionally"* ]]
}

@test "tdd runs mutation testing at the end, not during the cycle" {
  run cat "$SKILL"
  [[ "$output" == *"mutation"* ]]
  [[ "$output" == *"end of"* || "$output" == *"Never during the cycle"* || "$output" == *"never during the cycle"* ]]
}

@test "tdd suggests sync after all trees for a slice pass" {
  run cat "$SKILL"
  [[ "$output" == *"sync"* ]]
}

@test "tdd suggests change first when no tree covers the behaviour" {
  run cat "$SKILL"
  [[ "$output" == *"suggest"* ]]
  [[ "$output" == *"change"* ]]
  [[ "$output" == *"no tree"* ]]
}

@test "tdd updates the tree's parenthesised paths when creating a file at a path the tree does not yet name" {
  run cat "$SKILL"
  [[ "$output" == *"parenthesised path"* || "$output" == *"parenthesised paths"* || "$output" == *"tree's named paths"* ]]
  [[ "$output" == *"before moving to the next test"* || "$output" == *"before the next test"* ]]
}

@test "tdd places new files under the correct coverage category and closes 'none' gaps" {
  run cat "$SKILL"
  [[ "$output" == *"category"* ]]
  [[ "$output" == *"src"* ]]
  [[ "$output" == *"unit"* ]]
  [[ "$output" == *"integration"* ]]
  [[ "$output" == *"functional"* ]]
  [[ "$output" == *"none"* ]]
}

@test "tdd updates the tree's parenthesised paths when moving or renaming a file the tree names" {
  run cat "$SKILL"
  [[ "$output" == *"move"* || "$output" == *"rename"* || "$output" == *"moved or renamed"* ]]
  [[ "$output" == *"parenthesised path"* || "$output" == *"tree's named paths"* ]]
}

@test "tdd corrects errors it notices in tree leaf text before writing the test" {
  run cat "$SKILL"
  [[ "$output" == *"leaf"* ]]
  [[ "$output" == *"typo"* || "$output" == *"inaccuracy"* || "$output" == *"error"* ]]
  [[ "$output" == *"corrected"* || "$output" == *"fix"* || "$output" == *"reconcile"* ]]
}

@test "tdd directs that a unit pulled into being by a higher-layer test gets its own tree and failing tests at its native ground layer before the code lands" {
  run cat "$SKILL"
  [[ "$output" == *"own tree"* ]]
  [[ "$output" == *"own failing test"* ]]
  [[ "$output" == *"native ground layer"* ]]
  [[ "$output" == *"before any implementation lands"* ]]
}

@test "tdd directs that overlap between layers is intentional and the higher-layer test never excuses the unit's own coverage" {
  run cat "$SKILL"
  [[ "$output" == *"Overlap between layers is the intended shape"* || "$output" == *"overlap across layers is intentional"* ]]
  [[ "$output" == *"never a reason to skip"* ]]
}

@test "tdd descends from each failing higher-layer test to the lowest layer the behaviour reaches" {
  run cat "$SKILL"
  [[ "$output" == *"read its failure"* ]]
  [[ "$output" == *"lowest layer"* ]]
  [[ "$output" == *"never stop descending because"* || "$output" == *"Never stop descending because"* ]]
}

@test "tdd writes the full ladder of tests down to the lowest level" {
  run cat "$SKILL"
  [[ "$output" == *"full ladder of tests down to the lowest level"* ]]
}

@test "tdd folds back up once the lowest-layer test passes" {
  run cat "$SKILL"
  [[ "$output" == *"fold back up"* || "$output" == *"FOLD BACK UP"* ]]
  [[ "$output" == *"a layer beneath it lacks coverage"* || "$output" == *"a layer beneath is missing coverage"* ]]
}
