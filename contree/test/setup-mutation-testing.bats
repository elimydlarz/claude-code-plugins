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

@test "when an operator asks to set up mutation testing then mutation test runners select only Domain and Use-case tests when the framework supports test selection" {
  run cat "$SKILL"
  assert_output --partial "only Domain and Use-case tests"
  assert_output --partial "when the framework supports test selection"
}

@test "when an operator asks to set up mutation testing then incremental mode and a native mutation command provide the fastest available repeat feedback" {
  run cat "$SKILL"
  assert_output --partial "incremental mode"
  assert_output --partial "native mutation command"
  assert_output --partial "fastest available repeat feedback"
}

@test "when an operator asks to set up mutation testing then project Stop hooks run incremental mutation feedback only when relevant Domain or Use-case subjects or tests changed" {
  run cat "$SKILL"
  assert_output --partial "project-local incremental mutation command"
  assert_output --partial "Domain and Use-case subjects and test files"
  assert_output --partial "without invoking the mutation tool"
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
  assert_output --partial ".contree/hooks/mutation-on-stop.sh"
  assert_output --partial "stop_hook_active"
  assert_output --partial "before invoking mutation feedback"
  assert_output --partial "synchronous"
}

@test "when an operator asks to set up mutation testing then mutation configuration and Stop hooks preserve project-owned configuration and coexist with every previously installed feedback hook" {
  run cat "$SKILL"
  assert_output --partial "Preserve project-owned configuration"
  assert_output --partial "coexist with normal-test and architecture Stop hooks"
}

@test "when an operator asks to set up mutation testing then the hook preserves complete surviving-mutant output and fails visibly when the agreed threshold is missed" {
  run cat "$SKILL"
  assert_output --partial "complete mutation output"
  assert_output --partial "surviving mutants"
  assert_output --partial "tool failure"
  assert_output --partial "stderr"
  assert_output --partial "exit 2"
  assert_output --partial "actual coding-agent Stop turns"
}

@test "when an operator asks to set up mutation testing then the skill runs mutation testing before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "Run mutation testing before reporting completion"
}

@test "when an operator asks to set up mutation testing then the skill proves irrelevant changes skip mutation, relevant changes run mutation, and threshold or tool failures remain visible through actual Stop turns in both coding harnesses" {
  run cat "$SKILL"
  assert_output --partial "Change an irrelevant file"
  assert_output --partial "Change one Domain or Use-case subject or test file"
  assert_output --partial "controlled missed-threshold result"
  assert_output --partial "actual coding-agent Stop turns in both supported harnesses"
}

@test "when an operator asks to set up mutation testing then the skill reports the mutation command, scope, exclusions, selected tests, incremental state, threshold, duration, score, and remaining survivors" {
  run cat "$SKILL"
  assert_output --partial "Report the mutation command"
  assert_output --partial "selected Domain and Use-case tests"
  assert_output --partial "remaining survivors"
}

@test "if surviving mutants keep the agreed threshold from passing then the skill routes missing contract behaviour through change, strengthens the responsible Domain or Use-case tests through tdd, and reruns only the affected mutation scope until it passes" {
  run cat "$SKILL"
  assert_output --partial "behaviour is absent from the contract"
  assert_output --partial "`change` skill"
  assert_output --partial "responsible Domain or Use-case tests"
  assert_output --partial "`tdd` skill"
  assert_output --partial "Rerun only the affected mutation scope"
  assert_output --partial "until the agreed threshold passes"
}
