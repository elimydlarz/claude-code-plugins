#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup-test-feedback/SKILL.md"

@test "when an operator asks to set up test feedback then the skill inspects the existing project and agrees the framework choice and command mapping with the operator before changing files" {
  run cat "$SKILL"
  assert_output --partial "Inspect the existing project"
  assert_output --partial "Agree the framework choice and command mapping with the operator before changing files"
}

@test "when an operator asks to set up test feedback and it merges existing test configuration instead of replacing it" {
  run cat "$SKILL"
  assert_output --partial "Merge existing test configuration"
  assert_output --partial "Never replace"
}

@test "when an operator asks to set up test feedback and it configures tree-shaped normal and journey test output where the ecosystem supports it" {
  run cat "$SKILL"
  assert_output --partial "tree-shaped output"
  assert_output --partial "normal and journey"
  assert_output --partial "where the ecosystem supports it"
}

@test "when an operator asks to set up test feedback and the normal command runs Unit Integration and Component tests while the journey command separately runs Journey tests" {
  run cat "$SKILL"
  assert_output --partial "Unit, Integration, and Component"
  assert_output --partial "Journey tests"
  assert_output --partial "separate journey command"
}

@test "when an operator asks to set up test feedback and a native test-changed command plus synchronous project save hooks give coding agents the impacted normal-test result after each file edit" {
  run cat "$SKILL"
  assert_output --partial 'native `test-changed` command'
  assert_output --partial 'synchronous `PostToolUse` hooks'
  assert_output --partial '"matcher": "Edit|Write"'
  assert_output --partial "impacted normal-test result after each file edit"
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
  refute_output --partial 'project-level `Stop` hooks'
}

@test "when an operator asks to set up test feedback and it runs both test commands and verifies the test-changed baseline and impact selection before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "Run both test commands"
  assert_output --partial "baseline"
  assert_output --partial "impact selection"
  assert_output --partial "Do not report completion until"
}

@test "if a configured test command or project hook fails verification then the skill fixes the configuration and reruns verification until the feedback path works" {
  run cat "$SKILL"
  assert_output --partial "Fix failed test commands and hooks"
  assert_output --partial "rerun the complete verification"
  assert_output --partial "until the feedback path works"
}

@test "when tests need external services then the relevant command owns a self-contained Docker lifecycle and always tears its test artefacts down" {
  run cat "$SKILL"
  assert_output --partial "self-contained Docker lifecycle"
  assert_output --partial "relevant test command"
  assert_output --partial "always tear test artefacts down"
}
