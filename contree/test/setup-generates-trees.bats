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
  [[ "$output" == *"tree reporters"* || "$output" == *"tree-shaped"* ]]
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
  assert_output --partial "Domain"
  assert_output --partial "Use-case"
}

@test "setup generates trees from existing code into TEST_TREES.md" {
  run cat "$SKILL"
  [[ "$output" == *"TEST_TREES.md"* ]]
}

@test "setup updates CLAUDE.md to point at TEST_TREES.md when the pointer is missing" {
  run cat "$SKILL"
  assert_output --partial "pointer"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "CLAUDE.md"
}

@test "setup for a new project generates trees from user-described plans without implementing tests" {
  run cat "$SKILL"
  [[ "$output" == *"hand off"* || "$output" == *"change"* ]]
}

@test "setup uses Docker when Adapter or System tests need external services" {
  run cat "$SKILL"
  [[ "$output" == *"Docker"* ]]
}

@test "setup passes secrets via environment variables" {
  run cat "$SKILL"
  [[ "$output" == *"environment variable"* || "$output" == *"env"* ]]
}
