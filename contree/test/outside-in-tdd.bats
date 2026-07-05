#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/tdd/SKILL.md"

@test "tdd directs one failing test at a time in tree order" {
  run cat "$SKILL"
  [[ "$output" == *"one failing test at a time"* ]]
}

@test "tdd starts each capability from a failing Journey test at the highest tolerable realism" {
  run cat "$SKILL"
  assert_output --regexp "highest tolerable realism|max realism|max-realism"
  assert_output --regexp "real driving and driven adapters|real driven adapters"
  assert_output --partial "Journey"
}

@test "tdd walks representative error paths in a Journey test and eventually succeeds, not enumerating every error" {
  run cat "$SKILL"
  assert_output --partial "representative"
  assert_output --partial "eventually succeeds"
  assert_output --regexp "does not enumerate every error|not enumerate every error"
}

@test "tdd leans on the journey and pushes detail to inner layers when breadth at max realism is unaffordable" {
  run cat "$SKILL"
  assert_output --partial "unaffordable"
  assert_output --partial "lean on the journey"
}

@test "tdd keeps the journey curated and runnable under 5 minutes, trimmed to highest-impact and most-recent" {
  run cat "$SKILL"
  assert_output --partial "curated"
  assert_output --partial "under 5 minutes"
  assert_output --partial "highest-impact"
  assert_output --partial "most-recent"
}

@test "tdd gates implementation on a ground-level failing test under the journey/functional failure" {
  run cat "$SKILL"
  assert_output --partial "ground layer"
  assert_output --partial "journey/functional failure"
}

@test "tdd adds inner-layer tests only when failing functional-test pressure demands them" {
  run cat "$SKILL"
  assert_output --partial "pressure"
  assert_output --partial "inner"
}

@test "tdd writes tests at the tree's layer (Journey / System / Component / Adapter / Use-case / Domain)" {
  run cat "$SKILL"
  assert_output --partial "Domain"
  assert_output --partial "Use-case"
  assert_output --partial "Component"
  assert_output --partial "Adapter"
  assert_output --partial "System"
  assert_output --partial "Journey"
}

@test "tdd describes the Component layer — real adapters, externals doubled at the edge, in-process" {
  run cat "$SKILL"
  assert_output --partial "Component"
  assert_output --partial "in-memory database"
  assert_output --partial "stubbed outbound HTTP"
  assert_output --partial "in-process"
}

@test "tdd threads Component between System and the inner layers in the descent" {
  run cat "$SKILL"
  [[ "$output" == *"System → Component"* ]]
}

@test "tdd reframes System as the same surface a Component test covers, validated against real infrastructure, selective" {
  run cat "$SKILL"
  assert_output --partial "same single-capability surface a Component test covers"
  assert_output --partial "selective, not exhaustive"
}

@test "tdd mirrors the tree in describe/it hierarchy" {
  run cat "$PROJECT_ROOT/skills/tdd/SKILL.md" "$PROJECT_ROOT/skills/change/SKILL.md"
  assert_output --partial "describe"
  assert_output --regexp "mirror|mirrors"
}

@test "tdd does not silently modify existing trees" {
  run cat "$SKILL"
  [[ "$output" == *"Don't change existing trees silently"* || "$output" == *"existing trees are not modified"* || "$output" == *"not modify or remove"* ]]
}

@test "tdd wires in-memory adapters for use-case tests" {
  run cat "$SKILL"
  assert_output --partial "in-memory adapter"
  assert_output --partial "Use-case"
}

@test "tdd imports the shared port contract suite for driven adapter tests" {
  run cat "$SKILL"
  assert_output --partial "shared"
  assert_output --partial "contract"
}

@test "tdd exercises real infrastructure when testing a real driven adapter" {
  run cat "$SKILL"
  [[ "$output" == *"real infrastructure"* || "$output" == *"real infra"* ]]
}

@test "tdd adds adapter-specific tests for behaviour beyond the shared contract when testing a real driven adapter" {
  run cat "$SKILL"
  assert_output --partial "adapter-specific"
  assert_output --regexp "beyond the port contract|beyond the shared contract"
}

@test "tdd adds newly discovered cases without removing existing paths" {
  run cat "$SKILL"
  assert_output --regexp "add new cases as you discover them|add newly discovered cases"
  assert_output --regexp "Never modify or remove an existing path|not modify or remove"
}

@test "tdd breaks the implementation intentionally when a red test passes" {
  run cat "$SKILL"
  [[ "$output" == *"break the implementation intentionally"* ]]
}

@test "tdd observes the test failing, then fixes the implementation, observes it passing, and moves on" {
  run cat "$SKILL"
  assert_output --partial "observe the test failing"
  assert_output --regexp "fix it, observe it passing, move on|fix, observe passing, move on"
}

@test "tdd runs mutation testing at the end, not during the cycle" {
  run cat "$SKILL"
  assert_output --partial "mutation"
  assert_output --regexp "end of|Never during the cycle|never during the cycle"
}

@test "tdd suggests sync after all trees for a slice pass" {
  run cat "$SKILL"
  [[ "$output" == *"sync"* ]]
}

@test "tdd suggests change first when no tree covers the behaviour" {
  run cat "$SKILL"
  assert_output --partial "suggest"
  assert_output --partial "change"
  assert_output --partial "no tree"
}

@test "tdd updates the tree's parenthesised paths when creating a file at a path the tree does not yet name" {
  run cat "$SKILL"
  assert_output --regexp "parenthesised path|parenthesised paths|tree's named paths"
  assert_output --regexp "before moving to the next test|before the next test"
}

@test "tdd places new files under the correct coverage category and closes 'none' gaps" {
  run cat "$SKILL"
  assert_output --partial "category"
  assert_output --partial "src"
  assert_output --partial "domain"
  assert_output --partial "use-case"
  assert_output --partial "adapter"
  assert_output --partial "component"
  assert_output --partial "system"
  assert_output --partial "none"
}

@test "tdd updates the tree's parenthesised paths when moving or renaming a file the tree names" {
  run cat "$SKILL"
  assert_output --regexp "move|rename|moved or renamed"
  assert_output --regexp "parenthesised path|tree's named paths"
}

@test "tdd corrects errors it notices in tree leaf text before writing the test" {
  run cat "$SKILL"
  assert_output --partial "leaf"
  assert_output --regexp "typo|inaccuracy|error"
  assert_output --regexp "corrected|fix|reconcile"
}

@test "tdd directs that a unit pulled into being by a higher-layer test gets its own tree and failing tests at its native ground layer before the code lands" {
  run cat "$SKILL"
  assert_output --partial "own tree"
  assert_output --partial "own failing test"
  assert_output --partial "native ground layer"
  assert_output --partial "before any implementation lands"
}

@test "tdd directs that overlap between layers is intentional and the higher-layer test never excuses the unit's own coverage" {
  run cat "$SKILL"
  assert_output --regexp "Overlap between layers is the intended shape|overlap across layers is intentional"
  assert_output --partial "never a reason to skip"
}

@test "tdd descends from each failing higher-layer test to the lowest layer the behaviour reaches" {
  run cat "$SKILL"
  assert_output --partial "read its failure"
  assert_output --partial "lowest layer"
  assert_output --regexp "never stop descending because|Never stop descending because"
}

@test "tdd writes the full ladder of tests down to the lowest level" {
  run cat "$SKILL"
  [[ "$output" == *"full ladder of tests down to the lowest level"* ]]
}

@test "tdd folds back up once the lowest-layer test passes" {
  run cat "$SKILL"
  assert_output --regexp "fold back up|FOLD BACK UP"
  assert_output --regexp "a layer beneath it lacks coverage|a layer beneath is missing coverage"
}

@test "tdd states the covering tree explicitly and proceeds with an incomplete-seeming tree" {
  run cat "$SKILL"
  assert_output --partial "Identify which tree"
  assert_output --partial "State it explicitly"
  assert_output --partial "tree seems incomplete"
  assert_output --partial "proceed with what's there"
}

@test "tdd writes Domain tests as a pure rule with no collaborators, calling functions directly and asserting on returned data" {
  run cat "$SKILL"
  assert_output --partial "pure rule"
  assert_output --partial "Collaborators: none."
  assert_output --partial "Call functions directly, assert on returned data."
}

@test "tdd writes a driving-adapter test with the use-case mocked when protocol translation is non-trivial" {
  run cat "$SKILL"
  assert_output --partial "translation is non-trivial"
  assert_output --partial "use-case mocked"
  assert_output --partial "protocol-to-input translation"
  assert_output --partial "routing, deserialization"
  assert_output --partial "auth extraction"
  assert_output --partial "error-code shaping"
}

@test "tdd refactors only the code just changed, treating duplication as a hint not a command" {
  run cat "$SKILL"
  assert_output --partial "refactor the code you just changed"
  assert_output --partial "no broader"
  assert_output --partial "Duplication is a hint, not a command"
  assert_output --partial "don't extract abstractions until patterns have proven themselves"
}

@test "tdd handles failing tests by fixing unrelated failures first, related failures as part of continuing, and correcting missing or wrong tests" {
  run cat "$SKILL"
  assert_output --partial "Unrelated failure"
  assert_output --partial "fix it first, then continue"
  assert_output --partial "Related failure"
  assert_output --partial "fix and continue the cycle"
  assert_output --partial "Missing/wrong test"
  assert_output --partial "fix the test, then continue"
}
