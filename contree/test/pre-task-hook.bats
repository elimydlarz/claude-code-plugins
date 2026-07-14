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
  assert_output --partial "Journey: broad, production-like test of a curated user arc across capabilities, with external services replaced by test doubles only if unavoidable."
  assert_output --partial "Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles."
  assert_output --partial "Integration: when concerned integration of some (but not all) pieces, test from the highest-level subject and mock everything except the subjects you are integrating to see if they really work together as expected"
  assert_output --partial "Unit: test of one public surface on one subject; every public surface gets native unit tests, and every dependency outside the subject is mocked."
  refute_output --partial "System:"
  refute_output --partial "Adapter: test"
  refute_output --partial "Port contract: tests"
}

@test "session start directs recursive outside-in consumer-driven tdd" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Outside-in TDD"
  assert_output --partial "current tree"
  assert_output --partial "RED"
  assert_output --partial "GREEN"
  assert_output --partial "REFACTOR"
  assert_output --partial "too much branching"
  assert_output --partial "mock"
  assert_output --partial "stub"
  assert_output --partial "NotImplemented"
  assert_output --partial "mock makes the consumer tests pass"
  assert_output --partial "stub makes running code fail loudly"
  assert_output --partial "repeat the TDD process from step 1 for the new unit"
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

@test "session start points skill routing to frontmatter and names the skills" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Use Contree skills as directed by their frontmatter"
  assert_output --partial "change"
  assert_output --partial "tdd"
  assert_output --partial "sync"
  assert_output --partial "setup"
  assert_output --partial "setup-test-feedback"
  assert_output --partial "setup-linter"
  assert_output --partial "setup-architecture-linter"
  assert_output --partial "fix-architecture"
  assert_output --partial "setup-mental-model"
  assert_output --partial "setup-test-trees"
  assert_output --partial "bootstrap-test-trees"
  assert_output --partial "setup-mutation-testing"
  assert_output --partial "change-without-me"
}
