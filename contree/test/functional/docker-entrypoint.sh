#!/usr/bin/env bash
set -euo pipefail

# Runs the contree functional test.
# Works both inside Docker (called by docker-run.sh) and directly on the host.
#
# Expects:
#   - ANTHROPIC_API_KEY in environment or in .env file
#   - $1 is the test name (currently just "full-workflow")

TEST_NAME="${1:?Usage: docker-entrypoint.sh <test-name>}"

# When running inside Docker, contree is at /work/contree.
# When running locally, derive from script location.
if [ -d "/work/contree" ]; then
  CONTREE_ROOT="/work/contree"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Load .env if present (for local runs — API key for functional tests only)
ENV_FILE="$CONTREE_ROOT/test/functional/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi
FIXTURES="$CONTREE_ROOT/test/fixtures"
PROJECT_DIR="/tmp/contree-test-project"
# Transcripts go next to this script (host) or /output (Docker)
OUTPUT_DIR="$CONTREE_ROOT/test/functional"
if [ -d "/output" ]; then
  OUTPUT_DIR="/output"
fi
TRANSCRIPT_FILE="$OUTPUT_DIR/${TEST_NAME}-transcript.jsonl"
VERIFY_FILE="$OUTPUT_DIR/${TEST_NAME}-verify.txt"

# Clean transcript so phases append to a fresh file.
rm -f "$TRANSCRIPT_FILE"

# --- Helpers ---

seed_project() {
  local fixture_name="$1"
  local fixture_dir="/fixtures/$fixture_name"
  [ -d "$fixture_dir" ] || fixture_dir="$FIXTURES/$fixture_name"

  rm -rf "$PROJECT_DIR"
  cp -r "$fixture_dir" "$PROJECT_DIR"
  [ -f "$FIXTURES/$fixture_name/CLAUDE.md" ] && cp "$FIXTURES/$fixture_name/CLAUDE.md" "$PROJECT_DIR/"
  (cd "$PROJECT_DIR" && git init -q && git config user.email "test@test" && git config user.name "test" && git add -A && git commit -q -m "seed")
}

# Tracks whether we've started a Claude session in this run — subsequent calls
# pass `-c` to continue the same session so Claude has memory across phases.
CLAUDE_CALL_COUNT=0

run_claude() {
  local prompt="$1"
  shift
  local continue_flag=()
  if [ "$CLAUDE_CALL_COUNT" -gt 0 ]; then
    continue_flag=(-c)
  fi
  CLAUDE_CALL_COUNT=$((CLAUDE_CALL_COUNT + 1))

  # Don't abort on claude failure — we still need to emit the VERIFY file
  (cd "$PROJECT_DIR" && claude -p "$prompt" \
    "${continue_flag[@]}" \
    --plugin-dir "$CONTREE_ROOT" \
    --dangerously-skip-permissions \
    --model sonnet \
    --max-budget-usd 2.00 \
    --output-format stream-json \
    --verbose \
    "$@" 2>&1) | tee -a "$TRANSCRIPT_FILE" || true
}

write_verify() {
  cat > "$VERIFY_FILE"
  echo ""
  cat "$VERIFY_FILE"
}

# --- Test ---

case "$TEST_NAME" in
  full-workflow)
    # One scenario, three phases in one session, covers every tree in
    # contree/CLAUDE.md ## Test Trees.
    seed_project "greenfield"

    echo ""
    echo "=== Phase 1: setup ==="
    run_claude \
      "This project has no code yet — read CLAUDE.md for the Mental Model, then run /contree:setup to configure the test framework and generate test trees."

    echo ""
    echo "=== Phase 2: workflow (change → sync → tdd) ==="
    run_claude \
      "Now implement the project. Use /contree:workflow to set expected behaviour in trees and drive the implementation outside-in."

    echo ""
    echo "=== Phase 3: drift injection + sync ==="
    # Inject drift: add an undocumented capability to the source without updating the trees.
    if [ -f "$PROJECT_DIR/src/codes.js" ]; then
      DRIFT_TARGET="$PROJECT_DIR/src/codes.js"
    elif [ -f "$PROJECT_DIR/src/index.js" ]; then
      DRIFT_TARGET="$PROJECT_DIR/src/index.js"
    else
      DRIFT_TARGET="$(find "$PROJECT_DIR/src" -maxdepth 2 -name '*.js' -not -name '*.test.*' | head -n 1)"
    fi
    if [ -n "$DRIFT_TARGET" ] && [ -f "$DRIFT_TARGET" ]; then
      cat >> "$DRIFT_TARGET" <<'DRIFT'

// Drift injected by the functional harness — this capability is NOT in the trees.
export function generateBatch(n) {
  const out = []
  for (let i = 0; i < n; i++) out.push(generate())
  return out
}
DRIFT
      (cd "$PROJECT_DIR" && git add -A && git commit -q -m "inject drift: generateBatch")
      echo "[harness] Injected drift into $DRIFT_TARGET (added generateBatch)."
    else
      echo "[harness] WARNING: could not find a source file to drift. Phase 3 may PASS/FAIL on sync without seeing drift."
    fi

    run_claude \
      "Something feels off in this project — please audit for drift between the trees and the implementation, then propose fixes."

    write_verify << 'VERIFY'
Evaluate the transcript against every tree in the plugin's
`contree/CLAUDE.md` `## Test Trees` section.

For each `when/then` (or `if/then`) path in each tree, return one of:

  PASS — transcript demonstrates the assertion (quote evidence)
  FAIL — transcript contradicts the assertion (quote evidence)
  N/A  — the scenario did not exercise this assertion

The trees ARE the checklist. Report results grouped by tree, then a final summary
of PASS / FAIL / N/A counts across all trees.
VERIFY
    ;;

  layered-workflow)
    # Exercises the Use-case / Adapter / port-contract / in-memory-adapter paths
    # that full-workflow (pure utility) leaves as N/A.
    seed_project "bookmarks-api"

    echo ""
    echo "=== Phase 1: setup ==="
    run_claude \
      "This project has no code yet — read CLAUDE.md for the Mental Model, then run /contree:setup to configure the test framework and generate test trees. This project has HTTP endpoints and a persistence port, so expect trees at multiple layers."

    echo ""
    echo "=== Phase 2: workflow (change → sync → tdd) ==="
    run_claude \
      "Now implement the project. Use /contree:workflow to set expected behaviour in trees and drive the implementation outside-in. The project has a BookmarkRepository port — remember to build an in-memory adapter and a shared port contract suite alongside the file-based production adapter."

    echo ""
    echo "=== Phase 3: drift injection + sync ==="
    # Inject drift: add an undocumented DELETE endpoint without updating trees.
    HANDLER_FILE="$(find "$PROJECT_DIR/src" -maxdepth 3 -name '*.js' -not -name '*.test.*' | xargs grep -l 'router\|app\.\(get\|post\|delete\|put\)' 2>/dev/null | head -n 1)"
    if [ -n "$HANDLER_FILE" ] && [ -f "$HANDLER_FILE" ]; then
      cat >> "$HANDLER_FILE" <<'DRIFT'

// Drift injected by the functional harness — this endpoint is NOT in the trees.
app.delete('/bookmarks/:id', (req, res) => {
  res.status(204).end()
})
DRIFT
      (cd "$PROJECT_DIR" && git add -A && git commit -q -m "inject drift: DELETE endpoint")
      echo "[harness] Injected drift into $HANDLER_FILE (added DELETE /bookmarks/:id)."
    else
      echo "[harness] WARNING: could not find a route handler to drift. Phase 3 may not see drift."
    fi

    run_claude \
      "Something feels off in this project — please audit for drift between the trees and the implementation, then propose fixes."

    write_verify << 'VERIFY'
Evaluate the transcript against every tree in the plugin's
`contree/CLAUDE.md` `## Test Trees` section.

Focus especially on the trees that exercise hex layering:
  - change-decomposes-across-layers (port decomposition, in-memory + real adapters, shared contract)
  - outside-in-tdd (Use-case wiring with in-memory adapters, Adapter with shared contract, System through driving adapter)
  - composable-testing (four file naming conventions, port contract suite)

For each `when/then` (or `if/then`) path in each tree, return one of:

  PASS — transcript demonstrates the assertion (quote evidence)
  FAIL — transcript contradicts the assertion (quote evidence)
  N/A  — the scenario did not exercise this assertion

The trees ARE the checklist. Report results grouped by tree, then a final summary
of PASS / FAIL / N/A counts across all trees.
VERIFY
    ;;

  *)
    echo "Unknown test: $TEST_NAME" >&2
    echo ""
    echo "Available tests:"
    echo "  full-workflow     — pure utility: setup → workflow → drift → sync (Domain-weighted)"
    echo "  layered-workflow  — HTTP API: setup → workflow → drift → sync (exercises all four layers + ports + in-memory adapters)"
    exit 1
    ;;
esac

echo ""
echo "Transcript: $TRANSCRIPT_FILE"
echo "Verify:     $VERIFY_FILE"
