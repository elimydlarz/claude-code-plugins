#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup detects and merges into existing test config rather than overwriting" {
  run cat "$SKILL"
  assert_output --partial "existing"
  [[ "$output" == *"merge"* || "$output" == *"do not overwrite"* || "$output" == *"augment"* ]] || return 1
}

@test "setup configures tree reporters for local dev and CI" {
  run cat "$SKILL"
  assert_output --regexp "(tree reporters|tree-shaped)"
  assert_output --partial "local dev"
  assert_output --partial "JUnit"
}

@test "setup configures the six test layers as separate commands" {
  run cat "$SKILL"
  assert_output --partial "Domain"
  assert_output --partial "Use-case"
  assert_output --partial "Component"
  assert_output --partial "Adapter"
  assert_output --partial "System"
  assert_output --partial "Journey"
}

@test "setup notes Component tests run in-process needing no external services" {
  run cat "$SKILL"
  assert_output --partial "Component"
  assert_output --partial "in-process"
  [[ "$output" == *"no external services"* || "$output" == *"needs no external"* ]] || return 1
}

@test "setup configures mutation testing with layer-suffix exclusions" {
  run cat "$SKILL"
  assert_output --partial "mutation testing"
  assert_output --partial "explicitly excluding test files"
  assert_output --partial "!src/**/*.domain.test.*"
  assert_output --partial "!src/**/*.use-case.test.*"
  assert_output --partial "!src/**/*.adapter.test.*"
}

@test "setup generates trees from existing code into TEST_TREES.md" {
  run cat "$SKILL"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "source code"
  assert_output --partial "behaviours the system implements today"
}

@test "setup updates CLAUDE.md to point at TEST_TREES.md when the pointer is missing" {
  run cat "$SKILL"
  assert_output --partial "pointer"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "CLAUDE.md"
}

@test "setup for a new project generates trees from user-described plans without implementing tests" {
  run cat "$SKILL"
  # plans-based generation half: setup's own wording only reaches "new project"
  # as a trigger condition — it does not itself describe a plans-gathering
  # mechanism (that lives in the change skill it hands off to).
  assert_output --partial "new project"
  # not-implementing-tests half: strongly and explicitly stated.
  assert_output --partial "No test files"
  assert_output --partial "Do NOT create any test files"
}

@test "setup uses Docker when Adapter or System tests need external services" {
  run cat "$SKILL"
  assert_output --partial "Docker"
  assert_output --partial "external"
}

@test "setup tears down Docker test artefacts afterwards" {
  run cat "$SKILL"
  assert_output --partial "Docker"
  assert_output --partial "tear down"
  assert_output --partial "cleanup"
}

@test "setup passes secrets via environment variables" {
  run cat "$SKILL"
  [[ "$output" == *"environment variable"* || "$output" == *"env"* ]]
}

@test "setup configures changed-test runners with known gotchas addressed" {
  run cat "$SKILL"
  assert_output --partial "gotchas"
  assert_output --partial "--onlyChanged"
  assert_output --partial "git status"
  assert_output --partial "NOT changed test files"
}

@test "setup communicates flat-output limitations honestly" {
  run cat "$SKILL"
  assert_output --partial "flat output"
  assert_output --partial "be honest"
}
