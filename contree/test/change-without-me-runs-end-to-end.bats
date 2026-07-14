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

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements every gap immediately without pausing" {
  run cat "$SKILL"
  assert_output --partial "For every gap identified by sync"
  assert_output --partial "without pausing"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements every gap immediately without pausing when tdd closes the identified gaps then mutation testing validates Domain and Use-case tests" {
  run cat "$SKILL"
  assert_output --partial "Mutation testing validates Domain and Use-case tests"
}

@test "when the operator explicitly instructs change-without-me to skip mutation testing then the skip is recorded without claiming mutation passed and completion sync continues" {
  run cat "$SKILL"
  assert_output --partial "explicitly instructs you to skip mutation testing"
  assert_output --partial "Do not claim mutation passed"
  assert_output --partial "proceed to completion sync"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements every gap immediately without pausing when tdd closes the identified gaps then mutation testing validates Domain and Use-case tests when mutation testing passes then sync reruns its complete audit and full suite" {
  run cat "$SKILL"
  assert_output --partial 'Rerun the complete `sync` audit and its full suite after mutation testing passes'
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements every gap immediately without pausing when tdd closes the identified gaps then mutation testing validates Domain and Use-case tests when mutation testing passes then sync reruns its complete audit and full suite if the completion audit finds drift or gaps then the finding is routed through change, sync, or tdd and mutation unless explicitly skipped plus completion sync repeat" {
  run cat "$SKILL"
  assert_output --partial "repeat mutation testing unless it was explicitly skipped"
  assert_output --partial "complete sync audit"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements every gap immediately without pausing when tdd closes the identified gaps then mutation testing validates Domain and Use-case tests when mutation testing passes then sync reruns its complete audit and full suite when the completion audit proves intention, trees, tests, implementation, and mental model agree then second-opinion reviews the completed work with an independent model" {
  run cat "$SKILL"
  assert_output --partial "### 5. SECOND OPINION"
  assert_output --partial 'run the `second-opinion` skill process'
}

@test "while the second-opinion review request is pending change-without-me polls the same in-progress command or session to a terminal tool event without reporting it unavailable, ending the turn, or advancing to DONE" {
  run cat "$SKILL"
  assert_output --partial "status `in_progress` or returns a session identifier"
  assert_output --partial "poll that same command or session until the tool reports its terminal event"
  assert_output --partial "An assistant message is not a terminal result"
  assert_output --partial "Do not report it unavailable"
  assert_output --partial "end the turn"
  assert_output --partial "advance to DONE"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements every gap immediately without pausing when tdd closes the identified gaps then mutation testing validates Domain and Use-case tests when mutation testing passes then sync reruns its complete audit and full suite when the completion audit proves intention, trees, tests, implementation, and mental model agree then second-opinion reviews the completed work with an independent model if second-opinion finds actionable drift or gaps then every finding is routed through change, sync, or tdd and all completion gates repeat before another independent review" {
  run cat "$SKILL"
  assert_output --partial "rerun mutation testing unless it was explicitly skipped"
  assert_output --partial "complete sync audit and full suite"
  assert_output --partial "before requesting another independent review"
}

@test "if second-opinion terminates without a usable review then change-without-me surfaces the review failure and does not advance to DONE" {
  run cat "$SKILL"
  assert_output --partial "terminates without a usable review"
  assert_output --partial "Do not advance to DONE"
}

@test "when change-without-me is run with an idea then change runs without pausing for a phase transition when change completes then sync runs immediately without pausing when sync identifies gaps then tdd implements every gap immediately without pausing when tdd closes the identified gaps then mutation testing validates Domain and Use-case tests when mutation testing passes then sync reruns its complete audit and full suite when the completion audit proves intention, trees, tests, implementation, and mental model agree then second-opinion reviews the completed work with an independent model when second-opinion has no actionable findings then change-without-me reports verified, independently reviewed working software" {
  run cat "$SKILL"
  assert_output --partial "no actionable findings"
  assert_output --partial "verified, independently reviewed working software"
  assert_output --partial "explicitly skipped"
}

@test "if a phase fails then its complete error is surfaced and no later phase or completion claim runs" {
  run cat "$SKILL"
  assert_output --partial "surface the complete error"
  assert_output --partial "Do not run a later phase or claim completion"
}

@test "if a consequential choice cannot be resolved from the rules, mental model, trees, tests, code, and operator intention then the operator is consulted without adding routine phase-transition pauses" {
  run cat "$SKILL"
  assert_output --partial "consequential choice"
  assert_output --partial "Do not add routine phase-transition pauses"
}
