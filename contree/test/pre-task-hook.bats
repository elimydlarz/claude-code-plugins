#!/usr/bin/env bats

load test_helper

hook_command() {
  jq -r '.hooks.SessionStart[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
}

run_hook_in() {
  local project_dir="$1"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" PROJECT_DIR="$project_dir" \
    bash -c 'cd "$PROJECT_DIR" && bash -c "$CMD"'
}

# --- File interpolation (real behaviour) ---

@test "session start displays MENTAL_MODEL.md contents when file exists" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf 'UNIQUE_MENTAL_MODEL_MARKER_STRING\n' > "$project/MENTAL_MODEL.md"
  run_hook_in "$project"
  [[ "$output" == *"UNIQUE_MENTAL_MODEL_MARKER_STRING"* ]]
}

@test "session start displays TEST_TREES.md contents when file exists" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf 'UNIQUE_TEST_TREES_MARKER_STRING\n' > "$project/TEST_TREES.md"
  run_hook_in "$project"
  [[ "$output" == *"UNIQUE_TEST_TREES_MARKER_STRING"* ]]
}

# --- Prompt content (golden-file) ---
# The pressure-phrase line is replaced with __PRESSURE_PHRASE__ before diffing,
# because it is drawn randomly from a pool. If this fails: the rules or trailer
# changed. Review the diff, then update test/fixtures/expected/session-start.out
# deliberately.

@test "session start emits the expected rules and trailer in an empty cwd" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  local actual="$BATS_TEST_TMPDIR/actual"
  ( cd "$project" && bash "$PROJECT_ROOT/hooks/session-start.sh" ) \
    | sed -E 's/^([^#\-].+)$/__PRESSURE_PHRASE__/' > "$actual"
  diff "$actual" "$PROJECT_ROOT/test/fixtures/expected/session-start.out"
}
