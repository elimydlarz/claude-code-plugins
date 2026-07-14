#!/usr/bin/env bats

load test_helper

SITE="$PROJECT_ROOT/website/index.html"

@test "when a visitor loads the contree website then the page bridges from test-first practice to test trees as living requirements" {
  run cat "$SITE"
  assert_output --partial "You already write the test first"
  assert_output --partial "Start from what you know"
  assert_output --partial "test trees as living requirements"
}

@test "when a visitor loads the contree website and the page explains the seven tree layers Journey, System, Component, Adapter, Use-case, Domain, and Port" {
  run cat "$SITE"
  assert_output --partial "hexagonal"
  assert_output --partial "Journey <small>test/journey</small>"
  assert_output --partial "System <small>test/system</small>"
  assert_output --partial "Component <small>test/component</small>"
  assert_output --partial "Adapter <small>*.adapter.test</small>"
  assert_output --partial "Use-case <small>*.use-case.test</small>"
  assert_output --partial "Domain <small>*.domain.test</small>"
  assert_output --partial "Port <small>*.port-contract.test</small>"
}

@test "when a visitor loads the contree website and the page walks the skill workflow — setup, change, sync, tdd, second-opinion" {
  run cat "$SITE"
  assert_output --partial "Six skills carry you from idea to verified, reviewed code"
  assert_output --partial "/setup"
  assert_output --partial "/change"
  assert_output --partial "/sync"
  assert_output --partial "/tdd"
  assert_output --partial "/second-opinion"
}

@test "when a visitor loads the contree website and the page offers change-without-me for the full arc" {
  run cat "$SITE"
  assert_output --partial "/change-without-me"
}

@test "when a visitor loads the contree website and the page explains the Claude Code hook mechanics — the stdout, stderr-exit-2, and additionalContext injection channels, and the Stop-hook control flow" {
  run cat "$SITE"
  assert_output --partial "stdout · exit 0"
  assert_output --partial "stderr · exit 2"
  assert_output --partial "additionalContext"
  assert_output --partial "loop guard"
  assert_output --partial "stop_hook_active"
  assert_output --partial "four reconciliation prompts"
}

@test "when a visitor loads the contree website and the page requires no build step" {
  run cat "$SITE"
  refute_output --partial "<script"
  assert_output --partial "<style>"
}
