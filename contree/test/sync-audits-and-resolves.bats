#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/sync/SKILL.md"

@test "sync checks every when/then path for implementation and tests" {
  run cat "$SKILL"
  [[ "$output" == *"every"* ]]
  [[ "$output" == *"when/then"* ]]
}

@test "sync identifies drift between trees and implementation" {
  run cat "$SKILL"
  [[ "$output" == *"drift"* ]]
}

@test "sync discusses implementation-without-tree with the user before resolving" {
  run cat "$SKILL"
  [[ "$output" == *"Implementation exists without a tree"* ]]
  [[ "$output" == *"Ask"* || "$output" == *"Do not choose"* ]]
}

@test "sync flags tree-without-implementation as a gap to implement" {
  run cat "$SKILL"
  [[ "$output" == *"Implementation missing for a tree path"* || "$output" == *"tree exists, no code"* ]]
  [[ "$output" == *"gap"* ]]
}

@test "sync discusses stale trees with the user before removal" {
  run cat "$SKILL"
  [[ "$output" == *"Stale trees"* ]]
  [[ "$output" == *"Ask"* || "$output" == *"Present to the user"* ]]
}

@test "sync discusses dead paths with the user" {
  run cat "$SKILL"
  [[ "$output" == *"Dead paths"* ]]
  [[ "$output" == *"Present to the user"* || "$output" == *"Ask"* ]]
}

@test "sync suggests tdd to implement identified gaps" {
  run cat "$SKILL"
  [[ "$output" == *"tdd"* ]]
  [[ "$output" == *"gaps"* ]]
}

@test "sync never resolves drift unilaterally" {
  run cat "$SKILL"
  [[ "$output" == *"Never resolve drift unilaterally"* ]]
}
