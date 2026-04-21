#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup detects and merges into existing test config rather than overwriting" {
  run cat "$SKILL"
  [[ "$output" == *"existing"* ]]
  [[ "$output" == *"merge"* || "$output" == *"do not overwrite"* || "$output" == *"augment"* ]]
}

@test "setup configures tree reporters for local dev and CI" {
  run cat "$SKILL"
  [[ "$output" == *"tree reporters"* || "$output" == *"tree-shaped"* ]]
}

@test "setup configures the four test layers as separate commands" {
  run cat "$SKILL"
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"Use-case"* ]]
  [[ "$output" == *"Adapter"* ]]
  [[ "$output" == *"System"* ]]
}

@test "setup configures mutation testing with layer-suffix exclusions" {
  run cat "$SKILL"
  [[ "$output" == *"mutation testing"* ]]
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"Use-case"* ]]
}

@test "setup generates trees from existing code into TEST_TREES.md" {
  run cat "$SKILL"
  [[ "$output" == *"TEST_TREES.md"* ]]
}

@test "setup updates CLAUDE.md to point at TEST_TREES.md when the pointer is missing" {
  run cat "$SKILL"
  [[ "$output" == *"pointer"* ]]
  [[ "$output" == *"TEST_TREES.md"* ]]
  [[ "$output" == *"CLAUDE.md"* ]]
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
