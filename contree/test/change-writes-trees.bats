#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "change skill targets TEST_TREES.md for tree writes" {
  run grep -qE "TEST_TREES\.md" "$SKILL"
  assert_success
}

@test "change skill does not instruct writing trees into CLAUDE.md's ## Test Trees section" {
  run grep -qE '## Test Trees.*CLAUDE\.md|CLAUDE\.md.*## Test Trees|trees in `## Test Trees` of the project|subsection under `## Test Trees`' "$SKILL"
  assert_failure
}
