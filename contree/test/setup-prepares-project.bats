#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup detects and merges into existing test config rather than overwriting" {
  run cat "$SKILL"
  assert_output --partial "existing"
  [[ "$output" == *"merge"* || "$output" == *"do not overwrite"* || "$output" == *"augment"* ]] || return 1
}

@test "setup configures tree-shaped output where available" {
  run cat "$SKILL"
  assert_output --regexp "(tree reporters|tree-shaped)"
}

@test "setup maps the fixed Contree strategy to normal and functional test commands" {
  run cat "$SKILL"
  assert_output --partial "fixed Contree test strategy"
  assert_output --partial "normal test command"
  assert_output --partial "functional test command"
  assert_output --partial "Unit"
  assert_output --partial "Port contract"
  assert_output --partial "Component"
  assert_output --partial "Adapter"
  assert_output --partial "System"
  assert_output --partial "Journey"
  assert_output --partial "test:functional"
  refute_output --partial "\"test:domain\""
  refute_output --partial "\"test:use-case\""
  refute_output --partial "\"test:adapter\""
  refute_output --partial "\"test:component\""
  refute_output --partial "\"test:system\""
  refute_output --partial "\"test:journey\""
  refute_output --partial "SessionStart hook"
}

@test "setup creates a native test-changed command that runs only normal tests impacted since the last completed normal test run" {
  run cat "$SKILL"
  assert_output --partial "test-changed"
  assert_output --partial "last completed normal test run"
  assert_output --partial "runs only the normal tests impacted by those files"
}

@test "setup notes Component tests run in-process needing no external services" {
  run cat "$SKILL"
  assert_output --partial "Component"
  assert_output --partial "in-process"
  [[ "$output" == *"no external services"* || "$output" == *"needs no external"* ]] || return 1
}

@test "setup configures mutation testing with layer-suffix exclusions and selects only Domain and Use-case tests" {
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
  assert_output --partial "'src/**/*.ts'"
  assert_output --partial "'!src/**/*.test.ts'"
  assert_output --partial "'!src/**/*.d.ts'"
  assert_output --partial 'targetTests.set(setOf("com.example.*DomainTest*", "com.example.*UseCaseTest*"))'
  assert_output --partial '<param>com.example.*DomainTest*</param>'
  assert_output --partial '<param>com.example.*UseCaseTest*</param>'
  refute_output --partial 'targetTests.set(setOf("com.example.*Test"))'
  refute_output --partial '<targetTests><param>com.example.*Test</param></targetTests>'
}

@test "setup creates TEST_TREES.md without composing trees" {
  run cat "$SKILL"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "Do not compose the trees yourself"
}

@test "setup examples follow setup rules" {
  run cat "$SKILL"
  assert_output --partial "setup rules"
  assert_output --partial "no copied comments"
  assert_output --partial "no env-var behaviour switches"
  assert_output --partial "composition over inheritance"
  refute_output --partial "process.env.CI"
  refute_output --partial "fall back"
  refute_output --partial "|| true"
  refute_output --partial "os.environ.get(\"APP_URL\""
  refute_output --partial "baseURL = \"http://localhost:3001\""
  refute_output --partial "\"**objbinMigrations/**\""
  assert_output --partial "\"mutate\": [\"**/*.cs\", \"!**/obj/**\", \"!**/bin/**\", \"!**/Migrations/**\"]"
  refute_output --partial "test.unit"
  refute_output --partial "test.integration"
  refute_output --partial "--tag domain"
  refute_output --partial "--tag system"
  refute_output --partial "tests/domain/"
  refute_output --partial "tests/system/"
  refute_output --partial "go test -tags=integration"
  refute_output --partial "go test -short"
  refute_output --partial "dependsOn(testing.suites.named(\"systemTest\"))"
  refute_output --partial "\"break\": 0"
  refute_output --partial "|| (docker compose"
}

@test "setup chooses test frameworks but asks before choosing the application framework" {
  run cat "$SKILL"
  assert_output --partial "choose the test framework"
  assert_output --partial "Ask before choosing the main application framework"
}

@test "setup creates native project commands for configured DX" {
  run cat "$SKILL"
  assert_output --partial "native project commands"
  assert_output --partial "package.json scripts"
  assert_output --partial "Makefile targets"
  assert_output --partial "\"test\""
  assert_output --partial "\"test:functional\""
  assert_output --partial "\"lint\""
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

@test "setup communicates flat-output limitations honestly" {
  run cat "$SKILL"
  assert_output --partial "flat output"
  assert_output --partial "be honest"
}
