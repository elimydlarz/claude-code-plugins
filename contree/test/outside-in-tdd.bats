#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/tdd/SKILL.md"

@test "tdd directs one failing test at a time in tree order" {
  run cat "$SKILL"
  [[ "$output" == *"one failing test at a time"* ]]
}

@test "tdd writes tests at the tree's layer (Domain / Use-case / Adapter / System)" {
  run cat "$SKILL"
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"Use-case"* ]]
  [[ "$output" == *"Adapter"* ]]
  [[ "$output" == *"System"* ]]
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
