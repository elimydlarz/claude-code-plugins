#!/usr/bin/env bash
set -euo pipefail

# Functional tests for contree plugin.
# Runs Claude with contree loaded against a seed project in /tmp,
# then asserts on file system artifacts.
#
# Requires: claude CLI authenticated, jq, git

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES="$SCRIPT_DIR/../fixtures/seed-project"

PASS=0
FAIL=0
TOTAL=0

# --- Helpers ---

setup_project() {
  local dir
  dir=$(mktemp -d /tmp/contree-test-XXXXXX)
  cp -r "$FIXTURES"/* "$dir/"
  cp "$FIXTURES"/CLAUDE.md "$dir/"
  (cd "$dir" && git init -q && git add -A && git commit -q -m "seed")
  echo "$dir"
}

cleanup_project() {
  rm -rf "$1"
}

run_claude() {
  local project_dir="$1"
  local prompt="$2"

  # Claude uses cwd as the project directory
  (cd "$project_dir" && claude -p "$prompt" \
    --plugin-dir "$CONTREE_ROOT" \
    --dangerously-skip-permissions \
    --model sonnet \
    --max-budget-usd 0.50 \
    --no-session-persistence 2>/dev/null) || true
}

assert() {
  local description="$1"
  local condition="$2"
  TOTAL=$((TOTAL + 1))

  if eval "$condition"; then
    PASS=$((PASS + 1))
    echo "ok $TOTAL - $description"
  else
    FAIL=$((FAIL + 1))
    echo "not ok $TOTAL - $description"
  fi
}

assert_file_exists() {
  assert "$1" "test -f '$2'"
}

assert_file_contains() {
  assert "$1" "grep -q '$2' '$3'"
}

# --- Test: setup-contree generates requirement trees ---

test_setup_generates_requirements() {
  echo "# Test: setup-contree generates requirement trees"

  local dir
  dir=$(setup_project)

  run_claude "$dir" \
    "Run /setup-contree on this project. It's a simple JS counter module. Use Vitest. Don't implement any tests yet — just configure the framework and generate requirement trees."

  assert_file_contains \
    "CLAUDE.md has ## Requirements section after setup" \
    "Requirements" "$dir/CLAUDE.md"

  assert_file_contains \
    "requirement trees use when/then format" \
    "when" "$dir/CLAUDE.md"

  # Check test framework was configured (vitest.config.ts or .js or .mts)
  local has_vitest_config=false
  for ext in ts js mts mjs; do
    if [ -f "$dir/vitest.config.$ext" ]; then
      has_vitest_config=true
      break
    fi
  done
  assert "vitest config exists after setup" "$has_vitest_config"

  assert_file_contains \
    "vitest is in package.json dependencies" \
    "vitest" "$dir/package.json"

  cleanup_project "$dir"
}

# --- Test: tdd skill writes requirement tree before implementing ---

test_tdd_writes_requirement_first() {
  echo "# Test: tdd skill writes requirement tree before implementing"

  local dir
  dir=$(setup_project)

  # Pre-populate with a basic setup so tdd can work
  cat >> "$dir/CLAUDE.md" << 'EOF'

## Requirements

### Counter

```
Counter
  when created with default
    then value is zero
  when incremented
    then value increases by one
```
EOF
  (cd "$dir" && git add -A && git commit -q -m "add requirements")

  run_claude "$dir" \
    "Add a reset feature to the counter that sets it back to zero. Follow the tdd skill."

  # The requirement tree should have been extended with reset behaviour
  assert_file_contains \
    "CLAUDE.md mentions reset in requirements" \
    "reset\|Reset" "$dir/CLAUDE.md"

  # A test file should exist somewhere
  local has_test=false
  if find "$dir" -name '*.test.*' -not -path '*/node_modules/*' | grep -q .; then
    has_test=true
  fi
  assert "test file exists after tdd" "$has_test"

  cleanup_project "$dir"
}

# --- Test: stop hook updates CLAUDE.md ---

test_stop_hook_fires() {
  echo "# Test: stop hook prompts CLAUDE.md updates"

  local dir
  dir=$(setup_project)

  # Give claude a task that changes the system
  run_claude "$dir" \
    "Add an 'amount' parameter to increment() so it can increment by more than 1. Update counter.js."

  # CLAUDE.md should mention the amount parameter (stop hook prompted update)
  assert_file_contains \
    "CLAUDE.md was updated to reflect the change" \
    "amount\|Amount\|parameter\|increment" "$dir/CLAUDE.md"

  cleanup_project "$dir"
}

# --- Run all tests ---

echo "TAP version 13"
echo "1..5"

test_setup_generates_requirements
test_tdd_writes_requirement_first
test_stop_hook_fires

echo ""
echo "# $PASS/$TOTAL passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
