#!/usr/bin/env bash
set -euo pipefail

# Runs a single functional test inside the Docker container.
# Called by docker-run.sh — not meant to be run directly.
#
# Expects:
#   - ANTHROPIC_API_KEY in environment
#   - /work/contree/ contains the plugin source
#   - /output/ is mounted for transcript output
#   - $1 is the test name (e.g. "incidental-pass")

TEST_NAME="${1:?Usage: docker-entrypoint.sh <test-name>}"
CONTREE_ROOT="/work/contree"
FIXTURES="$CONTREE_ROOT/test/fixtures"
PROJECT_DIR="/tmp/contree-test-project"
TRANSCRIPT_FILE="/output/${TEST_NAME}-transcript.jsonl"

case "$TEST_NAME" in
  incidental-pass)
    FIXTURE_DIR="$FIXTURES/incidental-pass"

    # Set up the seed project
    rm -rf "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cp -r "$FIXTURE_DIR"/* "$PROJECT_DIR/"
    cp "$FIXTURE_DIR"/CLAUDE.md "$PROJECT_DIR/"
    (cd "$PROJECT_DIR" && git init -q && git config user.email "test@test" && git config user.name "test" && git add -A && git commit -q -m "seed: counter with reset already implemented")
    (cd "$PROJECT_DIR" && npm install --silent 2>/dev/null)

    echo "Running claude -p for incidental-pass test..."

    (cd "$PROJECT_DIR" && claude -p \
      "Use the tdd skill to implement the 'when reset after incrementing / then value is zero' path from the Counter test tree in ## Requirements. The reset() function already exists in counter.js — follow the TDD process exactly as described in the skill, including the incidental-pass protocol if the test passes on first run." \
      --plugin-dir "$CONTREE_ROOT" \
      --dangerously-skip-permissions \
      --model sonnet \
      --max-budget-usd 0.50 \
      --no-session-persistence \
      --output-format stream-json \
      --verbose 2>&1) | tee "$TRANSCRIPT_FILE"

    echo ""
    echo "Transcript saved to: $TRANSCRIPT_FILE"
    ;;

  *)
    echo "Unknown test: $TEST_NAME" >&2
    exit 1
    ;;
esac
