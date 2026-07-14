#!/usr/bin/env bats

load test_helper

@test "when a user describes a behaviour change without naming a skill then the change skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/change/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "behaviour change"
  assert_output --partial "before code changes"
}

@test "when a user asks about drift between code and requirements without naming a skill then the sync skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/sync/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "drift"
  assert_output --partial "gaps"
  assert_output --partial "staleness"
}

@test "when a user asks to set up testing without naming a skill then the setup-test-feedback skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-test-feedback/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "test"
  assert_output --partial "feedback"
}

@test "when a user asks to set up conventional linting without naming a skill then the setup-linter skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-linter/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "lint"
}

@test "when a user asks to set up architecture enforcement without naming a skill then the setup-architecture-linter skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-architecture-linter/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "architecture"
}

@test "when a user asks to fix architecture violations without naming a skill then the fix-architecture skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/fix-architecture/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "violations"
}

@test "when a user asks to discover and test the behaviour of an existing project without naming a skill then the bootstrap-test-trees skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/bootstrap-test-trees/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "bootstrap"
}

@test "when a user asks to establish or repair a project mental model without naming a skill then the setup-mental-model skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-mental-model/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "mental model"
}

@test "when a user asks to establish behavioural test trees without implementing their tests then the setup-test-trees skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-test-trees/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "test trees"
}

@test "when a user asks to set up mutation testing without naming a skill then the setup-mutation-testing skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup-mutation-testing/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "mutation"
}

@test "when a user asks for every Contree feedback loop without naming a skill then the comprehensive setup skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "comprehensive"
  assert_output --partial "all steering"
}

@test "when a user asks to implement from existing requirements without naming a skill then the tdd skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/tdd/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "implementing behaviour"
  assert_output --partial "writing tests"
}

@test "when a user asks to take an idea through the full workflow without naming a skill then the change-without-me skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/change-without-me/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "full workflow"
  assert_output --partial "end to end"
}

@test "when a user asks for an independent review without naming a skill then the second-opinion skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/second-opinion/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "independent review"
}

@test "when a user asks to visualise the current change without naming a skill then the diff-for-humans skill is triggered" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/diff-for-humans/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "visualise"
  run cat "$PROJECT_ROOT/hooks/session-start.sh"
  assert_output --partial "second-opinion"
  assert_output --partial "diff-for-humans"
}
