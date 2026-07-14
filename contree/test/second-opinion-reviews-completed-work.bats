#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/second-opinion/SKILL.md"

@test "second-opinion skill determines the work to review from any natural-language indication the user gave" {
  run cat "$SKILL"
  assert_output --regexp 'natural-language|natural language'
  assert_output --partial "indicat"
}

@test "second-opinion skill absent a clear indication reviews the current worktree" {
  run cat "$SKILL"
  assert_output --partial "Absent a clear indication"
  assert_output --partial "current worktree"
}

@test "second-opinion skill gathers work that includes new files not yet tracked by git" {
  run cat "$SKILL"
  [[ "$output" == *"untracked"* ]]
}

@test "second-opinion skill reads the test trees as the contract the work must satisfy" {
  run cat "$SKILL"
  assert_output --regexp 'Test Trees|TEST_TREES\.md'
  assert_output --partial "contract"
}

@test "second-opinion skill directs the independent model to review database-schema changes" {
  run cat "$SKILL"
  assert_output --partial "database schema"
}

@test "second-opinion skill directs the independent model to review API-contract changes" {
  run cat "$SKILL"
  assert_output --partial "API contract"
}

@test "second-opinion skill directs the independent model to review impacts on other systems" {
  run cat "$SKILL"
  assert_output --partial "impacts on other systems"
}

@test "second-opinion skill sends the work and test trees to OpenAI's Responses API authenticated with OPENAI_API_KEY, using gpt-5.6-sol with high reasoning effort" {
  run cat "$SKILL"
  assert_output --partial "api.openai.com/v1/responses"
  assert_output --partial "OPENAI_API_KEY"
  assert_output --partial "gpt-5.6-sol"
  assert_output --partial 'effort: "high"'
  refute_output --partial "ZAI_API_KEY"
  refute_output --partial "DEEPSEEK_API_KEY"
  refute_output --partial "chat/completions"
}

@test "second-opinion skill surfaces the independent model's review to the user attributed to gpt-5.6-sol" {
  run cat "$SKILL"
  assert_output --regexp 'surface|Surface'
  assert_output --partial "attribut"
  assert_output --partial "gpt-5.6-sol"
}

@test "second-opinion skill says so and stops without calling the API when there are no non-trivial changes to review" {
  run cat "$SKILL"
  assert_output --regexp 'no non-trivial change|nothing to review'
  assert_output --partial "stop"
}

@test "second-opinion skill surfaces a failed review request as an error and fabricates no review" {
  run cat "$SKILL"
  assert_output --partial "fails"
  assert_output --partial "error"
  assert_output --partial "fabricate"
  assert_output --partial "missing both"
  assert_output --partial "ZAI_API_KEY"
  assert_output --partial "DEEPSEEK_API_KEY"
}
