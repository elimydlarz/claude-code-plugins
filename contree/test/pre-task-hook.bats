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
  assert_output --partial "concepts, vocabulary, and decisions"
  assert_output --partial "inventing parallel"
}

@test "session start directs the agent to preserve invariants and surface conflict rather than route around" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "invariants"
  assert_output --partial "surface"
  assert_output --partial "routing around"
}

@test "session start directs the agent to flag the mental model as wrong, incomplete, or misleading rather than silently reshaping it" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "wrong, incomplete, or misleading"
  assert_output --partial "silently reshaping"
}

@test "session start directs the agent that trees are the contract" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Trees are the contract"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "every observable behaviour and side effect"
  assert_output --partial "describe/it hierarchy mirrors its tree verbatim"
}

@test "session start directs the agent to describe each level's observable behaviour at its interface, not the implementation inside it" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Behaviour, not internals"
  assert_output --partial "observable at the seam"
}

@test "session start explains the test kinds" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Test kinds"
  assert_output --partial "Journey: broad, production-like test of a curated user arc across capabilities"
  assert_output --partial "System: deep, production-like test of one capability through the whole app"
  assert_output --partial "Component: deep in-process test of one capability through the whole app"
  assert_output --partial "Adapter: test of one concrete boundary implementation"
  assert_output --partial "Port contract: tests for an application interface"
  assert_output --partial "Unit: test of one public surface on one subject"
}

@test "session start directs outside-in tdd right to the bottom" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Outside-in TDD"
  assert_output --partial "start with a Journey when the change affects a user arc"
  assert_output --partial "native Unit, Adapter, or Port-contract test"
  assert_output --partial "make tests pass upward"
  assert_output --partial "we always test right to the bottom"
}

@test "session start directs the agent to decide obvious questions itself rather than asking the user" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Decide, don't ask"
  assert_output --partial "Run the ladder before asking"
  assert_output --partial "only escalate"
}

@test "session start directs the agent not to manufacture flags, applying the same ladder before surfacing anything" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Don't manufacture flags"
  assert_output --partial "same ladder"
  assert_output --partial "stay silent"
}

# --- Skill directions ---

@test "session start directs the agent to eagerly use the listed skills to fulfil operator requests where applicable" {
  run_hook_in "$BATS_TEST_TMPDIR"
  [[ "$output" == *"Eagerly use these skills to fulfil operator requests, where applicable"* ]]
}

@test "session start directs the agent to use the change skill for behaviour changes before any code is discussed or written" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "change"
  assert_output --partial "behaviour change"
  assert_output --partial "before any code is discussed or written"
}

@test "session start directs the agent to use the tdd skill when implementing behaviour, writing code, or writing tests" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "tdd"
  assert_output --partial "implementing behaviour, writing code, or writing tests"
}

@test "session start directs the agent to use the sync skill for drift, gaps, staleness, or completeness" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "sync"
  assert_output --partial "drift, gaps, staleness, or completeness"
}

@test "session start directs the agent to use the setup skill when no framework is configured or TEST_TREES.md is absent" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "setup"
  assert_output --partial "no test framework"
  assert_output --partial "TEST_TREES.md"
}

@test "session start directs the agent to use the workflow skill for the full arc from idea to verified working software" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "workflow"
  assert_output --partial "full arc from idea to verified working software"
}
