#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup detects and merges into existing test config rather than overwriting" {
  run cat "$SKILL"
  assert_output --partial "existing"
  [[ "$output" == *"merge"* || "$output" == *"do not overwrite"* || "$output" == *"augment"* ]] || return 1
}

@test "setup configures tree reporters for local dev and CI" {
  run cat "$SKILL"
  assert_output --regexp "(tree reporters|tree-shaped)"
  assert_output --partial "local dev"
  assert_output --partial "JUnit"
}

@test "setup configures the SessionStart test kinds as separate commands" {
  run cat "$SKILL"
  assert_output --partial "Unit"
  assert_output --partial "Port contract"
  assert_output --partial "Component"
  assert_output --partial "Adapter"
  assert_output --partial "System"
  assert_output --partial "Journey"
}

@test "setup notes Component tests run in-process needing no external services" {
  run cat "$SKILL"
  assert_output --partial "Component"
  assert_output --partial "in-process"
  [[ "$output" == *"no external services"* || "$output" == *"needs no external"* ]] || return 1
}

@test "setup configures mutation testing with layer-suffix exclusions" {
  run cat "$SKILL"
  assert_output --partial "mutation testing"
  assert_output --partial "explicitly excluding test files"
  assert_output --partial "!src/**/*.domain.test.ts"
  assert_output --partial "!src/**/*.use-case.test.ts"
  assert_output --partial "!src/**/*.adapter.test.ts"
  assert_output --partial "!src/**/*.component.test.ts"
  assert_output --partial "!src/**/*.system.test.ts"
  assert_output --partial "!src/**/*.journey.test.ts"
  assert_output --partial "!test/**/*.component.test.ts"
  assert_output --partial "!test/**/*.system.test.ts"
  assert_output --partial "!test/**/*.journey.test.ts"
  assert_output --partial "!src/**/*.contract.ts"
}

@test "setup creates TEST_TREES.md without composing trees" {
  run cat "$SKILL"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "Do not compose the trees yourself"
}

@test "setup examples follow SessionStart rules" {
  run cat "$SKILL"
  assert_output --partial "SessionStart rules"
  assert_output --partial "no copied comments"
  assert_output --partial "no env-var behaviour switches"
  assert_output --partial "no config inheritance"
  assert_output --partial "reason-marked"
  assert_output --partial "reason-marked mocks and stubs"
  refute_output --partial "process.env.CI"
  refute_output --partial "extends: true"
  refute_output --partial "inherits ="
  refute_output --partial "fall back"
  refute_output --partial "|| true"
  refute_output --partial "os.environ.get(\"APP_URL\""
  refute_output --partial "baseURL = \"http://localhost:3001\""
  refute_output --partial "\"**objbinMigrations/**\""
  assert_output --partial "\"mutate\": [\"**/*.cs\", \"!**/obj/**\", \"!**/bin/**\", \"!**/Migrations/**\"]"
}

@test "setup chooses test frameworks but asks before choosing the application framework" {
  run cat "$SKILL"
  assert_output --partial "choose the test framework"
  assert_output --partial "Ask before choosing the main application framework"
}

@test "setup updates CLAUDE.md to point at TEST_TREES.md when the pointer is missing" {
  run cat "$SKILL"
  assert_output --partial "pointer"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "CLAUDE.md"
}

@test "setup for a new project creates the tree home without implementing tests" {
  run cat "$SKILL"
  assert_output --partial "new project"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "No test files"
  assert_output --partial "Do NOT create any test files"
}

@test "setup uses Docker when Adapter or System tests need external services" {
  run cat "$SKILL"
  assert_output --partial "Docker"
  assert_output --partial "external"
}

@test "setup tears down Docker test artefacts afterwards" {
  run cat "$SKILL"
  assert_output --partial "Docker"
  assert_output --partial "tear down"
  assert_output --partial "cleanup"
}

@test "setup passes secrets via environment variables" {
  run cat "$SKILL"
  [[ "$output" == *"environment variable"* || "$output" == *"env"* ]]
}

@test "setup configures changed-test runners with known gotchas addressed" {
  run cat "$SKILL"
  assert_output --partial "gotchas"
  assert_output --partial "--onlyChanged"
  assert_output --partial "git status"
  assert_output --partial "NOT changed test files"
}

@test "setup communicates flat-output limitations honestly" {
  run cat "$SKILL"
  assert_output --partial "flat output"
  assert_output --partial "be honest"
}
