#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup skill instructs to create MENTAL_MODEL.md with seven H2 sections when it does not exist" {
  run grep -qE "MENTAL_MODEL\.md.*seven.*(section|H2)|seven.*(section|H2).*MENTAL_MODEL" "$SKILL"
  assert_success
}

@test "setup skill names the seven mental-model sections" {
  run grep -q "Core Domain Identity" "$SKILL"
  assert_success
  run grep -q "World-to-Code Mapping" "$SKILL"
  assert_success
  run grep -q "Ubiquitous Language" "$SKILL"
  assert_success
  run grep -q "Bounded Contexts" "$SKILL"
  assert_success
  run grep -q "Invariants" "$SKILL"
  assert_success
  run grep -q "Decision Rationale" "$SKILL"
  assert_success
  run grep -q "Temporal View" "$SKILL"
  assert_success
}

@test "setup skill instructs each section be followed by a one-line placeholder" {
  run grep -qE "one-line placeholder|placeholder.*each section|each section.*placeholder" "$SKILL"
  assert_success
}
