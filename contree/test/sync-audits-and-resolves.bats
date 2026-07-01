#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/sync/SKILL.md"

@test "sync checks every when/then path for implementation and tests" {
  run cat "$SKILL"
  assert_output --partial "every"
  assert_output --partial "when/then"
}

@test "sync identifies drift between trees and implementation" {
  run cat "$SKILL"
  [[ "$output" == *"drift"* ]]
}

@test "sync discusses implementation-without-tree with the user before resolving" {
  run cat "$SKILL"
  assert_output --partial "Implementation exists without a tree"
  [[ "$output" == *"Ask"* || "$output" == *"Do not choose"* ]] || return 1
}

@test "sync flags tree-without-implementation as a gap to implement" {
  run cat "$SKILL"
  [[ "$output" == *"Implementation missing for a tree path"* || "$output" == *"tree exists, no code"* ]] || return 1
  assert_output --partial "gap"
}

@test "sync discusses stale trees with the user before removal" {
  run cat "$SKILL"
  assert_output --partial "Stale trees"
  [[ "$output" == *"Ask"* || "$output" == *"Present to the user"* ]] || return 1
}

@test "sync discusses dead paths with the user" {
  run cat "$SKILL"
  assert_output --partial "Dead paths"
  [[ "$output" == *"Present to the user"* || "$output" == *"Ask"* ]] || return 1
}

@test "sync suggests tdd to implement identified gaps" {
  run cat "$SKILL"
  assert_output --partial "tdd"
  assert_output --partial "gaps"
}

@test "sync suggests second-opinion for an independent review once the project is in sync" {
  run cat "$SKILL"
  assert_output --partial "second-opinion"
  assert_output --partial "independent review"
}

@test "sync never resolves drift unilaterally" {
  run cat "$SKILL"
  [[ "$output" == *"Never resolve drift unilaterally"* ]]
}

@test "sync parses the describe/it hierarchy in each test file and compares it to its tree" {
  run cat "$SKILL"
  assert_output --partial "describe/it hierarchy"
  [[ "$output" == *"parse"* || "$output" == *"Parse"* ]] || return 1
  assert_output --partial "framework-agnostic"
}

@test "sync flags describe/it drift and presents both sides without picking" {
  run cat "$SKILL"
  assert_output --partial "Describe/it drift"
  assert_output --partial "Do not pick"
}

@test "sync verifies each tree's labelled paths against the filesystem per category" {
  run cat "$SKILL"
  [[ "$output" == *"labelled"* || "$output" == *"per category"* ]] || return 1
  assert_output --partial "filesystem"
}

@test "sync flags tree-named paths that do not exist on disk as drift" {
  run cat "$SKILL"
  [[ "$output" == *"does not exist"* || "$output" == *"not exist on disk"* ]] || return 1
  assert_output --partial "drift"
}

@test "sync surfaces every 'none' value as an explicit declared gap" {
  run cat "$SKILL"
  assert_output --partial "none"
  [[ "$output" == *"Declared gap"* || "$output" == *"declared gap"* || "$output" == *"explicit gap"* ]] || return 1
}

@test "sync flags coverage-by-proxy when a unit is reachable only through higher-layer tests with no native tree" {
  run cat "$SKILL"
  assert_output --partial "Coverage-by-proxy"
  assert_output --partial "reachable only through higher-layer"
}

@test "sync proposes a native-layer tree plus its own failing tests to resolve coverage-by-proxy, never removal of the higher-layer test" {
  run cat "$SKILL"
  assert_output --partial "new tree at the unit's native layer"
  assert_output --partial "own failing tests"
  assert_output --partial "never removal of the higher-layer test"
}

@test "sync requires a concrete user decision before any edit, for every drift case" {
  run cat "$SKILL"
  assert_output --partial "Never resolve drift unilaterally"
  assert_output --partial "requires a concrete user decision before any edit"
}

@test "sync stops and suggests running setup first when test trees do not exist or are empty" {
  run cat "$SKILL"
  assert_output --partial "doesn't exist or has no trees"
  assert_output --partial "stop and suggest running"
  assert_output --partial "setup"
}

@test "sync checks branch parity for Domain, Use-case, and Port-contract trees in both directions" {
  run cat "$SKILL"
  assert_output --partial "Branch parity"
  assert_output --partial "every observable branch in the unit's code corresponds to a tree path"
  assert_output --partial "every path corresponds to a branch"
}

@test "sync assumes the implementation is wrong by default for failing tests and is not complete while any test is red" {
  run cat "$SKILL"
  assert_output --partial "Failing tests"
  assert_output --partial "Default assumption is the implementation is wrong"
  assert_output --partial "Sync is not complete while any test is red"
}

@test "sync writes a System tree or confirms the pure-library exception for a missing System tree, never inventing one silently" {
  run cat "$SKILL"
  assert_output --partial "Missing System tree"
  assert_output --partial "outside-in drift"
  assert_output --partial "Do not invent a System tree silently"
}

@test "sync runs mutation testing against Domain and Use-case as final validation once all gaps are implemented and tests pass" {
  run cat "$SKILL"
  assert_output --partial "If mutation testing is configured"
  assert_output --partial "run Stryker against Domain + Use-case as final validation"
}
