#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change-without-me/SKILL.md"

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition" {
  run cat "$SKILL"
  assert_output --partial "CHANGE"
  assert_output --partial "Do not pause for alignment"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing" {
  run cat "$SKILL"
  assert_output --partial "sync"
  assert_output --partial "proceed directly"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements each gap immediately without pausing" {
  run cat "$SKILL"
  assert_output --partial "tdd"
  assert_output --partial "proceed directly to implementation"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements each gap immediately without pausing when tdd closes all gaps then mutation testing runs at the end of the tdd phase when mutation testing passes then all test trees have passing tests" {
  run cat "$SKILL"
  [[ "$output" == *"passing tests"* ]]
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements each gap immediately without pausing when tdd closes all gaps then mutation testing runs at the end of the tdd phase when mutation testing passes then all test trees have passing tests when the work is synced and implemented then second-opinion reviews the completed work with an independent model" {
  run cat "$SKILL"
  assert_output --partial "SECOND OPINION"
  assert_output --partial "second-opinion"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements each gap immediately without pausing when tdd closes all gaps then mutation testing runs at the end of the tdd phase" {
  run cat "$SKILL"
  assert_output --partial "### 3. TDD"
  assert_output --partial "Run mutation testing at the end"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements each gap immediately without pausing when tdd closes all gaps then mutation testing runs at the end of the tdd phase when mutation testing passes then all test trees have passing tests when the work is synced and implemented then second-opinion reviews the completed work with an independent model when second-opinion finds drift or gaps then they are routed back through change, sync, or tdd" {
  run cat "$SKILL"
  assert_output --partial "### 4. SECOND OPINION"
  assert_output --partial "route them back through"
}
