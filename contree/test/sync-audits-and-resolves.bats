#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/sync/SKILL.md"

@test "sync treats TEST_TREES.md as the operator contract" {
  run cat "$SKILL"
  assert_output --partial 'TEST_TREES.md'
  assert_output --partial "operator expects"
  assert_output --partial "contract with the operator"
}

@test "sync embeds every EARS form and causal nesting" {
  run cat "$SKILL"
  assert_output --partial "then <ubiquitous outcome>"
  assert_output --partial "while <precondition>"
  assert_output --partial "when <trigger>"
  assert_output --partial "where <optional feature>"
  assert_output --partial "if <unwanted condition>"
  assert_output --partial "Causal"
  assert_output --partial "nests"
}

@test "sync stops and suggests setup when test trees do not exist or are empty" {
  run cat "$SKILL"
  assert_output --partial "If TEST_TREES.md does not exist or contains no trees"
  assert_output --partial "stop and suggest"
  assert_output --partial "setup"
}

@test "sync verifies current coverage labels and test hierarchy" {
  run cat "$SKILL"
  assert_output --partial 'src`, `domain`, `use-case`, `adapter`, `component`, `system`, and `journey`'
  assert_output --partial "describe/it hierarchy"
  assert_output --partial "verbatim"
  assert_output --partial "none"
  refute_output --partial "integration"
  refute_output --partial "functional"
}

@test "sync delegates every test-tree leaf review and asks all four questions" {
  run cat "$SKILL"
  assert_output --partial "subagents"
  assert_output --partial "every leaf"
  assert_output --partial "test exists"
  assert_output --partial "expresses the leaf's intention"
  assert_output --partial "implementation passes the test"
  assert_output --partial "fulfils the intention"
  assert_output --partial "spirit"
}

@test "sync delegates a complete reverse review of production code" {
  run cat "$SKILL"
  assert_output --partial "production code"
  assert_output --partial "subagents"
  assert_output --partial "observable behaviour"
  assert_output --partial "does not express"
}

@test "sync delegates a two-way review of every mental-model heading" {
  run cat "$SKILL"
  assert_output --partial "each of the seven headings"
  assert_output --partial "subagent"
  assert_output --partial "accurate and useful"
  assert_output --partial "codebase honours"
}

@test "sync closes missing native coverage while retaining applicable overlapping coverage" {
  run cat "$SKILL"
  assert_output --partial "substantive unit"
  assert_output --partial "natural lowest layer"
  assert_output --partial "gap to close immediately"
  assert_output --partial "higher-layer coverage"
  assert_output --partial "every applicable layer"
  assert_output --partial "Do not invent inner units"
}

@test "sync checks observable branch parity separately from YAGNI" {
  run cat "$SKILL"
  assert_output --partial "Domain, Use-case, and Port"
  assert_output --partial "observable branch"
  assert_output --partial "Internal control flow"
  assert_output --partial "YAGNI"
  assert_output --partial "separately"
}

@test "sync resolves drift proactively through change and tdd using operator intention" {
  run cat "$SKILL"
  assert_output --partial "Resolve every finding now"
  assert_output --partial "operator intention"
  assert_output --partial "change"
  assert_output --partial "tdd"
  assert_output --partial "own judgment"
}

@test "sync escalates only consequential genuinely under-determined choices" {
  run cat "$SKILL"
  assert_output --partial "consequential"
  assert_output --partial "genuinely under-determined"
  assert_output --partial "operator"
}

@test "sync completes only after all audited representations agree and tests pass" {
  run cat "$SKILL"
  assert_output --partial "full suite"
  assert_output --partial "every tree leaf"
  assert_output --partial "no observable implementation"
  assert_output --partial "mental model"
  assert_output --partial "second-opinion"
}
