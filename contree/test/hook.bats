#!/usr/bin/env bats

load test_helper

# Extract the hook command from hooks.json
HOOK_CMD=$(jq -r '.hooks.Stop[0].hooks[0].command' "$BATS_TEST_DIRNAME/../hooks/hooks.json")

# --- Loop prevention ---

@test "hook exits 0 when stop_hook_active is true" {
  run bash -c 'echo "{\"stop_hook_active\": true}" | '"$HOOK_CMD"
  assert_success
  refute_output --partial 'Check:'
}

@test "hook exits 0 when stop_hook_active is true among other fields" {
  run bash -c 'echo "{\"stop_hook_active\": true, \"other\": \"data\"}" | '"$HOOK_CMD"
  assert_success
}

# --- Normal operation ---

@test "hook exits 2 when stop_hook_active is false" {
  run bash -c 'echo "{\"stop_hook_active\": false}" | '"$HOOK_CMD"
  assert_failure 2
}

@test "hook exits 2 when stop_hook_active is absent" {
  run bash -c 'echo "{}" | '"$HOOK_CMD"
  assert_failure 2
}

@test "hook exits 2 with empty input" {
  run bash -c 'echo "" | '"$HOOK_CMD"
  assert_failure 2
}

# --- Review prompt content ---

@test "hook prompt mentions Requirements" {
  output=$(echo '{}' | bash -c "$HOOK_CMD" 2>&1 || true)
  [[ "$output" == *"Requirements"* ]]
}

@test "hook prompt mentions test trees" {
  output=$(echo '{}' | bash -c "$HOOK_CMD" 2>&1 || true)
  [[ "$output" == *"test trees"* ]]
}

@test "hook prompt mentions Mental Model" {
  output=$(echo '{}' | bash -c "$HOOK_CMD" 2>&1 || true)
  [[ "$output" == *"Mental Model"* ]]
}

@test "hook prompt mentions Repo Map" {
  output=$(echo '{}' | bash -c "$HOOK_CMD" 2>&1 || true)
  [[ "$output" == *"Repo Map"* ]]
}

@test "hook prompt mentions when/then format" {
  output=$(echo '{}' | bash -c "$HOOK_CMD" 2>&1 || true)
  [[ "$output" == *"when/then"* ]]
}
