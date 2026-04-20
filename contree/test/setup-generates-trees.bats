#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup skill instructs to add a CLAUDE.md pointer to TEST_TREES.md if missing" {
  run grep -qE "pointer.*TEST_TREES|TEST_TREES.*pointer|CLAUDE\.md.*(identif|point).*TEST_TREES" "$SKILL"
  assert_success
}

@test "setup skill names TEST_TREES.md as where trees live" {
  run grep -qE "TEST_TREES\.md.*tree|tree.*TEST_TREES\.md" "$SKILL"
  assert_success
}

@test "setup skill does not instruct writing a ## Test Trees section into CLAUDE.md" {
  run grep -qE '## Test Trees.*CLAUDE\.md|CLAUDE\.md.*## Test Trees|Write the trees into `## Test Trees` in CLAUDE' "$SKILL"
  assert_failure
}

@test "setup skill offers to invoke the change skill for initial test trees" {
  run grep -qE "/contree:change|change skill" "$SKILL"
  assert_success
}

@test "setup skill does not itself instruct writing tree content inline" {
  # The old instruction "Write the trees into ..." should be gone — setup defers tree composition to the change skill.
  run grep -qE 'Write the trees into' "$SKILL"
  assert_failure
}
