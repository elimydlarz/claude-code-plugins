#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup-architecture-linter/SKILL.md"

@test "when an operator asks to set up architecture linting then the skill maps the project's actual domain, use-case, port, adapter, and composition-root locations with the operator" {
  run cat "$SKILL"
  assert_output --partial "actual source layout"
  assert_output --partial "domain"
  assert_output --partial "use-case"
  assert_output --partial "port"
  assert_output --partial "adapter"
  assert_output --partial "composition root"
  assert_output --partial "agree the map with the operator"
}

@test "when an operator asks to set up architecture linting then it installs and configures rules that keep domain code pure, dependencies pointing inward, adapters reachable only from the composition root, and dependency cycles absent" {
  run cat "$SKILL"
  assert_output --partial "domain-pure"
  assert_output --partial "domain-no-external-dependencies"
  assert_output --partial "domain-no-async"
  assert_output --partial "use-case-only-domain-data-and-ports"
  assert_output --partial "adapters-only-from-composition-root"
  assert_output --partial "no-circular"
  assert_output --partial "dependency-cruiser"
}

@test "when an operator asks to set up architecture linting then it preserves project-owned lint configuration, commands, CI steps, and coding-harness hooks while merging architecture feedback" {
  run cat "$SKILL"
  assert_output --partial "Merge all existing commands and CI steps"
  assert_output --partial "without replacing existing settings or hooks"
}

@test "when an operator asks to set up architecture linting then it creates a native architecture command, combines it with the project lint command, and adds the combined gate to CI" {
  run cat "$SKILL"
  assert_output --partial "lint:arch"
  assert_output --partial "combined lint command"
  assert_output --partial "CI"
}

@test "when an operator asks to set up architecture linting then project Stop hooks run every architecture rule from the project root before the coding agent finishes" {
  run cat "$SKILL"
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
  assert_output --partial ".contree/hooks/architecture-on-stop.sh"
  assert_output --partial 'cd "$(git rev-parse --show-toplevel)"'
  assert_output --partial "every architecture rule"
}

@test "when an operator asks to set up architecture linting then the skill runs every architecture rule before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "Run the native architecture command"
  assert_output --partial "Do not report completion before every rule has run"
}

@test "when an operator asks to set up architecture linting then the skill proves the project Stop hook through an actual coding-agent Stop turn before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "actual Stop turn"
  assert_output --partial "before reporting completion"
}

@test "if the project's ecosystem cannot enforce every required boundary then the skill fails visibly without claiming architecture feedback is configured" {
  run cat "$SKILL"
  assert_output --partial "Fail visibly"
  assert_output --partial "Do not claim architecture feedback is configured"
}

@test "if architecture violations are found during setup then the skill invokes fix-architecture with the complete violations" {
  run cat "$SKILL"
  assert_output --partial "contree:fix-architecture"
  assert_output --partial "complete architecture-linter output"
}

@test "if architecture violations are found during setup then it reruns the native architecture command and combined lint command until both pass" {
  run cat "$SKILL"
  assert_output --partial "rerun the native architecture command and combined lint command"
  assert_output --partial "until both pass"
}

@test "if the architecture linter cannot run from a project Stop hook then the hook reports the execution error and fails visibly" {
  run cat "$SKILL"
  assert_output --partial "complete execution error"
  assert_output --partial "stderr"
  assert_output --partial "exit 2"
}

@test "when the project Stop hook receives its own follow-up Stop task then it exits silently without running architecture lint again" {
  run cat "$SKILL"
  assert_output --partial "stop_hook_active"
  assert_output --partial "exit 0"
  assert_output --partial "before invoking architecture lint"
}
