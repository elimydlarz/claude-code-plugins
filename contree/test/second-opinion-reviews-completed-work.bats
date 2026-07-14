#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/second-opinion/SKILL.md"

@test "when the second-opinion skill is invoked then it determines the work to review from any natural-language indication the user gave" {
  run cat "$SKILL"
  assert_output --regexp 'natural-language|natural language'
  assert_output --partial "indicat"
}

@test "when the second-opinion skill is invoked and absent a clear indication it reviews the current worktree" {
  run cat "$SKILL"
  assert_output --partial "Absent a clear indication"
  assert_output --partial "current worktree"
}

@test "when the second-opinion skill is invoked and the work it gathers includes new files not yet tracked by git" {
  run cat "$SKILL"
  [[ "$output" == *"untracked"* ]]
}

@test "when the second-opinion skill is invoked and it reads the test trees as the contract the work must satisfy" {
  run cat "$SKILL"
  assert_output --regexp 'Test Trees|TEST_TREES\.md'
  assert_output --partial "contract"
}

@test "when the second-opinion skill is invoked and it directs the independent model to review database-schema changes" {
  run cat "$SKILL"
  assert_output --partial "database schema"
}

@test "when the second-opinion skill is invoked and it directs the independent model to review API-contract changes" {
  run cat "$SKILL"
  assert_output --partial "API contract"
}

@test "when the second-opinion skill is invoked and it directs the independent model to review impacts on other systems" {
  run cat "$SKILL"
  assert_output --partial "impacts on other systems"
}

@test "when the second-opinion skill is invoked and it sends the work and test trees to OpenAI's Responses API authenticated with OPENAI_API_KEY, using gpt-5.6-sol with high reasoning effort" {
  run cat "$SKILL"
  assert_output --partial "api.openai.com/v1/responses"
  assert_output --partial "OPENAI_API_KEY"
  assert_output --partial "gpt-5.6-sol"
  assert_output --partial 'effort: "high"'
  refute_output --partial "ZAI_API_KEY"
  refute_output --partial "DEEPSEEK_API_KEY"
  refute_output --partial "chat/completions"
}

@test "when the second-opinion skill is invoked and it surfaces the independent model's review to the user attributed to gpt-5.6-sol" {
  run cat "$SKILL"
  assert_output --regexp 'surface|Surface'
  assert_output --partial "attribut"
  assert_output --partial "gpt-5.6-sol"
}

@test "when the current worktree contains no non-trivial work to review then it says so and stops without calling the API" {
  run cat "$SKILL"
  assert_output --partial "current worktree"
  assert_output --regexp 'no non-trivial work|nothing to review'
  assert_output --partial "stop"
}

@test "if the review request fails — OPENAI_API_KEY is missing, the API returns an error or non-2xx response, or the response contains no review then the failure is surfaced as an error and no review is fabricated" {
  run cat "$SKILL"
  assert_output --partial "OPENAI_API_KEY"
  assert_output --partial "error"
  assert_output --partial "non-2xx"
  assert_output --partial "no review"
  assert_output --partial "fabricate"
}
