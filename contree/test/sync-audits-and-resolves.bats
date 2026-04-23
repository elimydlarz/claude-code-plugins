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

@test "sync parses the describe/it hierarchy in each test file and compares it to its tree" {
  run cat "$SKILL"
  [[ "$output" == *"describe/it hierarchy"* ]]
  [[ "$output" == *"parse"* || "$output" == *"Parse"* ]]
  [[ "$output" == *"framework-agnostic"* ]]
}

@test "sync flags describe/it drift and presents both sides without picking" {
  run cat "$SKILL"
  [[ "$output" == *"Describe/it drift"* ]]
  [[ "$output" == *"Do not pick"* ]]
}

@test "sync verifies each tree's named file paths against the filesystem" {
  run cat "$SKILL"
  [[ "$output" == *"named file paths"* || "$output" == *"named paths"* ]]
  [[ "$output" == *"filesystem"* ]]
}

@test "sync flags tree-named paths that do not exist on disk as drift" {
  run cat "$SKILL"
  [[ "$output" == *"does not exist"* || "$output" == *"not exist on disk"* ]]
  [[ "$output" == *"drift"* ]]
}
