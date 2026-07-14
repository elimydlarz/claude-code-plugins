#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup-mutation-testing/SKILL.md"

@test "when an operator asks to set up mutation testing then the skill inspects the source and test layout and agrees the mutation scope and useful feedback threshold with the operator" {
  run cat "$SKILL"
  assert_output --partial "Inspect the source and test layout"
  assert_output --partial "Agree the mutation scope and useful feedback threshold with the operator"
}

@test "when an operator asks to set up mutation testing and it configures the ecosystem's mutation tool to mutate production source while explicitly excluding every colocated test pattern" {
  run cat "$SKILL"
  assert_output --partial "ecosystem's mutation tool"
  assert_output --partial "production source"
  assert_output --partial "explicit exclusion for every colocated test pattern"
}

@test "when an operator asks to set up mutation testing and mutation test runners select only Domain and Use-case tests when the framework supports test selection" {
  run cat "$SKILL"
  assert_output --partial "only Domain and Use-case tests"
  assert_output --partial "when the framework supports test selection"
}

@test "when an operator asks to set up mutation testing and incremental mode and a native mutation command provide the fastest available repeat feedback" {
  run cat "$SKILL"
  assert_output --partial "incremental mode"
  assert_output --partial "native mutation command"
  assert_output --partial "fastest available repeat feedback"
}

@test "when an operator asks to set up mutation testing and project Stop hooks run incremental mutation feedback only when relevant Domain or Use-case source or tests changed" {
  run cat "$SKILL"
  assert_output --partial "project-local incremental mutation command"
  assert_output --partial "Domain or Use-case production and test files"
  assert_output --partial "without invoking the mutation tool"
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
  assert_output --partial ".contree/hooks/mutation-on-stop.sh"
  assert_output --partial "stop_hook_active"
  assert_output --partial "before invoking mutation feedback"
  assert_output --partial "synchronous"
}

@test "when an operator asks to set up mutation testing and the hook preserves complete surviving-mutant output and fails visibly when the agreed threshold is missed" {
  run cat "$SKILL"
  assert_output --partial "complete mutation output"
  assert_output --partial "surviving mutants"
  assert_output --partial "tool failure"
  assert_output --partial "stderr"
  assert_output --partial "exit 2"
  assert_output --partial "actual coding-agent Stop turns"
}

@test "when an operator asks to set up mutation testing and the skill runs mutation testing before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "Run mutation testing before reporting completion"
}

@test "if surviving mutants keep the agreed threshold from passing then the skill strengthens the responsible Domain or Use-case tests and reruns only the affected mutation scope until it passes" {
  run cat "$SKILL"
  assert_output --partial "Strengthen the responsible Domain or Use-case tests"
  assert_output --partial "Rerun only the affected mutation scope"
  assert_output --partial "until the agreed threshold passes"
}
