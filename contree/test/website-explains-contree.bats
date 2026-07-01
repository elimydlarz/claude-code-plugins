#!/usr/bin/env bats

load test_helper

SITE="$PROJECT_ROOT/website/index.html"

@test "the page bridges from test-first practice to test trees as living requirements" {
  run cat "$SITE"
  assert_output --partial "You already write the test first"
  assert_output --partial "Start from what you know"
  assert_output --partial "test trees as living requirements"
}

@test "the page explains the layered testing architecture from Journey down to Domain" {
  run cat "$SITE"
  assert_output --partial "hexagonal"
  assert_output --partial "Journey <small>test/journey</small>"
  assert_output --partial "System <small>test/system</small>"
  assert_output --partial "Component <small>test/component</small>"
  assert_output --partial "Adapter <small>*.adapter.test</small>"
  assert_output --partial "Use-case <small>*.use-case.test</small>"
  assert_output --partial "Domain <small>*.domain.test</small>"
}

@test "the page walks the skill workflow — setup, change, sync, tdd, workflow" {
  run cat "$SITE"
  assert_output --partial "Five skills carry you from idea to verified code"
  assert_output --partial "/setup"
  assert_output --partial "/change"
  assert_output --partial "/sync"
  assert_output --partial "/tdd"
  assert_output --partial "/workflow"
}

@test "the page explains the Claude Code hook mechanics — the injection channels and the Stop-hook control flow" {
  run cat "$SITE"
  assert_output --partial "stdout · exit 0"
  assert_output --partial "stderr · exit 2"
  assert_output --partial "additionalContext"
  assert_output --partial "loop guard"
  assert_output --partial "stop_hook_active"
  assert_output --partial "QUESTION STOP"
}

@test "the page requires no build step" {
  run cat "$SITE"
  refute_output --partial "<script"
  assert_output --partial "<style>"
}
