#!/usr/bin/env bats

load test_helper

# Helper: run the hook command with given JSON input
run_hook() {
  local input="$1"
  # Extract command from hooks.json and run it with input on stdin
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  # Redirect stderr to stdout so bats can capture the prompt
  run bash -c "echo '$input' | bash -c '$cmd' 2>&1"
}

# --- Loop prevention ---

@test "hook exits 0 when stop_hook_active is true" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  echo '{"stop_hook_active": true}' | bash -c "$cmd" 2>/dev/null
  # If we get here without error, exit was 0
}

@test "hook exits 0 when stop_hook_active is true among other fields" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  echo '{"stop_hook_active": true, "other": "data"}' | bash -c "$cmd" 2>/dev/null
}

# --- Normal operation ---

@test "hook exits 2 when stop_hook_active is false" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  run bash -c 'echo "{\"stop_hook_active\": false}" | bash -c '"'"''"$cmd"''"'"' 2>&1'
  [ "$status" -eq 2 ]
}

@test "hook exits 2 when stop_hook_active is absent" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  run bash -c 'echo "{}" | bash -c '"'"''"$cmd"''"'"' 2>&1'
  [ "$status" -eq 2 ]
}

@test "hook exits 2 with empty input" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  run bash -c 'echo "" | bash -c '"'"''"$cmd"''"'"' 2>&1'
  [ "$status" -eq 2 ]
}

# --- Review prompt content ---

@test "hook prompt mentions Requirements" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"Requirements"* ]]
}

@test "hook prompt mentions test trees" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"test trees"* ]]
}

@test "hook prompt mentions Mental Model" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"Mental Model"* ]]
}

@test "hook prompt mentions Repo Map" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"Repo Map"* ]]
}

@test "hook prompt mentions when/then format" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"when/then"* ]]
}
