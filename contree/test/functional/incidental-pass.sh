#!/usr/bin/env bash
set -euo pipefail

# Functional test: incidental pass verification
#
# Sets up a project where reset() is already implemented, then asks the
# TDD skill to implement the "when reset" test tree path. The test will
# pass incidentally. The agent should follow the incidental-pass protocol:
# break the implementation, observe failure, fix it, observe pass.
#
# This test captures the full transcript for human/Claude analysis.
# There are no programmatic assertions — run it, then read the transcript.
#
# Requires: claude CLI authenticated, git, node/pnpm

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES="$SCRIPT_DIR/../fixtures/incidental-pass"

setup_project() {
  local dir
  dir=$(mktemp -d /tmp/contree-incidental-pass-XXXXXX)
  cp -r "$FIXTURES"/* "$dir/"
  cp "$FIXTURES"/CLAUDE.md "$dir/"
  (cd "$dir" && git init -q && git add -A && git commit -q -m "seed: counter with reset already implemented")
  # Install deps so vitest is available
  (cd "$dir" && npm install --silent 2>/dev/null)
  echo "$dir"
}

echo "Setting up project..."
PROJECT_DIR=$(setup_project)
echo "Project dir: $PROJECT_DIR"

TRANSCRIPT_FILE="$SCRIPT_DIR/incidental-pass-transcript.jsonl"

echo "Running claude -p with TDD skill..."
echo "Transcript will be written to: $TRANSCRIPT_FILE"

(cd "$PROJECT_DIR" && env -u ANTHROPIC_API_KEY claude -p \
  "Use the tdd skill to implement the 'when reset after incrementing / then value is zero' path from the Counter test tree in ## Requirements. The reset() function already exists in counter.js — follow the TDD process exactly as described in the skill, including the incidental-pass protocol if the test passes on first run." \
  --plugin-dir "$CONTREE_ROOT" \
  --dangerously-skip-permissions \
  --model sonnet \
  --max-budget-usd 0.50 \
  --no-session-persistence \
  --output-format stream-json 2>&1) | tee "$TRANSCRIPT_FILE"

echo ""
echo "--- Done ---"
echo "Transcript saved to: $TRANSCRIPT_FILE"
echo "Project dir (preserved): $PROJECT_DIR"

# Extract readable summary: assistant text messages and tool calls
echo ""
echo "=== Assistant messages ==="
grep -o '{"type":"assistant"[^}]*"message":"[^"]*"' "$TRANSCRIPT_FILE" 2>/dev/null || true
echo ""
echo "=== Tool uses (name only) ==="
jq -r 'select(.type == "tool_use") | .tool' "$TRANSCRIPT_FILE" 2>/dev/null || true
echo ""
echo "To analyse: read the transcript and verify the agent:"
echo "  1. Wrote a test for 'when reset after incrementing'"
echo "  2. Observed the test passing incidentally"
echo "  3. Broke the reset implementation intentionally"
echo "  4. Observed the test failing"
echo "  5. Fixed the implementation"
echo "  6. Observed the test passing"
