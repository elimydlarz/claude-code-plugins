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

# --- File interpolation ---

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

# --- Agent direction ---

@test "session start directs the agent to use existing mental-model concepts, vocabulary, and decisions" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"concepts, vocabulary, and decisions"* ]]
  [[ "$output" == *"inventing parallel"* ]]
}

@test "session start directs the agent to preserve invariants and surface conflict rather than route around" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"invariants"* ]]
  [[ "$output" == *"surface"* ]]
  [[ "$output" == *"routing around"* ]]
}

@test "session start directs the agent to flag the mental model as wrong, incomplete, or misleading rather than silently reshaping it" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"wrong, incomplete, or misleading"* ]]
  [[ "$output" == *"silently reshaping"* ]]
}

@test "session start directs the agent to treat test trees as the authoritative behaviour contract" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"test trees"* ]]
  [[ "$output" == *"authoritative"* ]]
  [[ "$output" == *"behaviour contract"* ]]
}

# --- Skill directions ---

@test "session start directs the agent to eagerly use the listed skills to fulfil operator requests where applicable" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"Eagerly use these skills to fulfil operator requests, where applicable"* ]]
}

@test "session start directs the agent to use the change skill for behaviour changes before any code is discussed or written" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"change"* ]]
  [[ "$output" == *"behaviour change"* ]]
  [[ "$output" == *"before any code is discussed or written"* ]]
}

@test "session start directs the agent to use the tdd skill when implementing behaviour, writing code, or writing tests" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"tdd"* ]]
  [[ "$output" == *"implementing behaviour, writing code, or writing tests"* ]]
}

@test "session start directs the agent to use the sync skill for drift, gaps, staleness, or completeness" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"sync"* ]]
  [[ "$output" == *"drift, gaps, staleness, or completeness"* ]]
}

@test "session start directs the agent to use the setup skill when no framework is configured or TEST_TREES.md is absent" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"setup"* ]]
  [[ "$output" == *"no test framework"* ]]
  [[ "$output" == *"TEST_TREES.md"* ]]
}

@test "session start directs the agent to use the workflow skill for the full arc from idea to verified working software" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"workflow"* ]]
  [[ "$output" == *"full arc from idea to verified working software"* ]]
}

# --- Pressure phrase integration (pressure-phrase-on-session-start tree) ---

@test "session start prints a random pressure phrase from the pool" {
  run_hook_in "$BATS_TEST_TMPDIR"
  source "$PROJECT_ROOT/hooks/pressure-phrases.sh"
  local found=0
  for phrase in "${pressure_phrases[@]}"; do
    if [[ "$output" == *"$phrase"* ]]; then
      found=1
      break
    fi
  done
  [ "$found" -eq 1 ]
}
