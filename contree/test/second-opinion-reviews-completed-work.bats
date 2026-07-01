#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/second-opinion/SKILL.md"

@test "second-opinion skill determines the work to review from any natural-language indication the user gave" {
  run cat "$SKILL"
  assert_output --regexp 'natural-language|natural language'
  assert_output --partial "indicat"
}

@test "second-opinion skill absent a clear indication reviews the last non-trivial, naturally grouped changes, not a single commit and not only the working tree" {
  run cat "$SKILL"
  assert_output --regexp 'naturally grouped|naturally-grouped'
  assert_output --partial "non-trivial"
  assert_output --partial "trunk-sync"
  assert_output --partial "commit"
  assert_output --partial "working tree"
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

@test "second-opinion skill sends the change and the test trees to Z.AI's GLM 5.2 chat completions API authenticated with ZAI_API_KEY" {
  run cat "$SKILL"
  assert_output --partial "glm-5.2"
  assert_output --partial "api.z.ai"
  assert_output --partial "chat/completions"
  assert_output --partial "ZAI_API_KEY_CORRUPT"
}

@test "second-opinion skill surfaces GLM 5.2's review attributed to GLM 5.2" {
  run cat "$SKILL"
  assert_output --regexp 'surface|Surface'
  assert_output --partial "attribut"
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
}
