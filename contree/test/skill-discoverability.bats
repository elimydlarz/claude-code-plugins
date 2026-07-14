#!/usr/bin/env bats

load test_helper

@test "change skill's frontmatter TRIGGERs on behaviour-change phrasings" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/change/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "behaviour change"
  assert_output --partial "before code changes"
}

@test "sync skill's frontmatter TRIGGERs on drift/gaps/staleness phrasings" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/sync/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "drift"
  assert_output --partial "gaps"
  assert_output --partial "staleness"
}

@test "setup-test-feedback skill's frontmatter TRIGGERs when test feedback is missing" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-test-feedback/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "test"
  assert_output --partial "feedback"
}

@test "setup-linter skill's frontmatter TRIGGERs on conventional lint setup" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-linter/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "lint"
}

@test "setup-architecture-linter skill's frontmatter TRIGGERs on architecture enforcement setup" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-architecture-linter/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "architecture"
}

@test "fix-architecture skill's frontmatter TRIGGERs on architecture violations" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/fix-architecture/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "violations"
}

@test "bootstrap-test-trees skill's frontmatter TRIGGERs on discovering existing behaviour" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/bootstrap-test-trees/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "bootstrap"
}

@test "setup-mutation-testing skill's frontmatter TRIGGERs on mutation feedback setup" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-mutation-testing/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "mutation"
}

@test "setup skill's frontmatter TRIGGERs comprehensive setup" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "comprehensive"
  assert_output --partial "all steering"
}

@test "tdd skill's frontmatter TRIGGERs on implementing behaviour or writing tests" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/tdd/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "implementing behaviour"
  assert_output --partial "writing tests"
}

@test "change-without-me skill's frontmatter TRIGGERs on full end-to-end workflow phrasings" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/change-without-me/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "full workflow"
  assert_output --partial "end to end"
}
