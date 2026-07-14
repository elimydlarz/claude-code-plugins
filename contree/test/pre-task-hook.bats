#!/usr/bin/env bats

load test_helper

hook_command() {
  jq -r '.hooks.SessionStart[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
}

run_hook_in() {
  local project_dir="$1"
  local cmd
  cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" PROJECT_DIR="$project_dir" bash -c 'cd "$PROJECT_DIR" && bash -c "$CMD"'
}

@test "when a session starts then MENTAL_MODEL.md contents are displayed" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf 'UNIQUE_MENTAL_MODEL_MARKER_STRING\n' > "$project/MENTAL_MODEL.md"
  run_hook_in "$project"
  assert_output --partial "UNIQUE_MENTAL_MODEL_MARKER_STRING"
}

@test "when a session starts and TEST_TREES.md contents are displayed" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf 'UNIQUE_TEST_TREES_MARKER_STRING\n' > "$project/TEST_TREES.md"
  run_hook_in "$project"
  assert_output --partial "UNIQUE_TEST_TREES_MARKER_STRING"
}

@test "when a session starts and the agent is directed to use the mental model's existing concepts, vocabulary, and decisions rather than inventing parallel ones" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "concepts, vocabulary, and decisions"
  assert_output --partial "inventing parallel"
}

@test "when a session starts and the agent is directed to preserve the mental model's invariants, surfacing conflict when a task appears to require breaking one rather than routing around it" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "invariants"
  assert_output --partial "surface"
  assert_output --partial "routing around"
}

@test "when a session starts and the agent is directed to flag the mental model as wrong, incomplete, or misleading rather than silently reshaping it through code" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "wrong, incomplete, or misleading"
  assert_output --partial "silently reshaping"
}

@test "when a session starts and the agent is directed that trees are the contract — every observable behaviour and side effect belongs in TEST_TREES.md, every tree maps to one test file, and every test file's describe/it hierarchy mirrors its tree verbatim" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Trees are the contract"
  assert_output --partial "every observable behaviour and side effect"
  assert_output --partial "every tree maps to one test file"
  assert_output --partial "describe/it hierarchy mirrors its tree verbatim"
}

@test "when a session starts and the agent is directed to describe each level's observable behaviour at its interface — inputs, outputs, and side-effects — not the implementation inside it" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Behaviour, not internals"
  assert_output --partial "interface"
  assert_output --partial "never the implementation inside"
}

@test "when a session starts and the agent is directed that Journey, System, Component, Adapter, Port contract, and Unit are the test kinds" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Journey: broad, production-like test of a curated user arc across capabilities."
  assert_output --partial "System: deep, production-like test of one capability through the whole app."
  assert_output --partial "Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles."
  assert_output --partial "Adapter: test of one concrete boundary implementation against the real boundary it adapts"
  assert_output --partial "Port contract: tests for an application interface"
  assert_output --partial "Unit: test of one public surface on one subject"
  refute_output --partial "Integration:"
}

@test "when a session starts and the agent is directed to work outside-in and consumer-driven from the behaviour in the current tree" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Outside-in TDD"
  assert_output --partial "current tree"
  assert_output --partial "consumer"
}

@test "when a session starts and the agent is directed to write a test, observe RED, implement GREEN, then notice too much branching in the test or tree during REFACTOR" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "RED"
  assert_output --partial "GREEN"
  assert_output --partial "REFACTOR"
  assert_output --partial "too much branching"
}

@test "when a session starts and the agent is directed to extract some branching into a new unit with a mock and a stub that throws NotImplemented" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "mock"
  assert_output --partial "stub"
  assert_output --partial "NotImplemented"
}

@test "when a session starts and the agent is directed that the mock makes consumer tests pass while the stub makes running code fail loudly, signalling that the TDD process repeats from step 1 for the new unit" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "mock makes the consumer tests pass"
  assert_output --partial "stub makes running code fail loudly"
  assert_output --partial "repeat the TDD process from step 1 for the new unit"
}

@test "when a session starts and the agent is directed to decide obvious questions itself rather than asking the user — consulting these rules and the mental model first, then its own best judgment from the code in front of it, escalating to the user only a consequential, genuinely under-determined choice that neither resolves" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Decide, don't ask"
  assert_output --partial "Run the ladder before asking"
  assert_output --partial "only escalate"
}

@test "when a session starts and the agent is directed to apply the same ladder to anything it would flag, caveat, or surface — fixing it where these rules or the mental model direct, else using its judgment, else staying silent rather than reporting it" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Don't manufacture flags"
  assert_output --partial "same ladder"
  assert_output --partial "stay silent"
}

@test "when a session starts and the agent is directed to use Contree skills as directed by skill frontmatter" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "Use Contree skills as directed by their frontmatter"
}

@test "when a session starts and the agent is shown every focused setup skill alongside change, tdd, sync, setup, and change-without-me" {
  run_hook_in "$BATS_TEST_TMPDIR"
  assert_output --partial "setup-test-feedback"
  assert_output --partial "setup-linter"
  assert_output --partial "setup-architecture-linter"
  assert_output --partial "fix-architecture"
  assert_output --partial "setup-mental-model"
  assert_output --partial "setup-test-trees"
  assert_output --partial "bootstrap-test-trees"
  assert_output --partial "setup-mutation-testing"
  assert_output --partial "change"
  assert_output --partial "tdd"
  assert_output --partial "sync"
  assert_output --partial "setup"
  assert_output --partial "change-without-me"
}
