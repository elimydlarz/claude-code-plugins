#!/usr/bin/env bash
set -euo pipefail

# Runs a trunk-sync functional (System-layer, real-agent) case against claude.
# Works inside Docker (called by docker-run.sh) or directly on the host.
#
# handover: drives TWO real claude sessions in one repo —
#   Agent A makes an edit (hook clocks it in) and records progress via the bundled recorder;
#   Agent B starts fresh and its SessionStart surfaces A's handover.
# Self-verifies DETERMINISTICALLY (no AI eval): the timecard must carry A's authored
# progress, and B's transcript must contain it (proving real SessionStart injection +
# a real agent both writing and receiving the handover). Exits non-zero on any failure.

TEST_NAME="${1:-handover}"
HARNESS="${2:-claude}"
[ "$HARNESS" = "claude" ] || { echo "Only the claude harness is supported: $HARNESS" >&2; exit 1; }

if [ -d "/work/trunk-sync" ]; then
  TS_ROOT="/work/trunk-sync"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  TS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

OUTPUT_DIR="$TS_ROOT/test/functional"
[ -d "/output" ] && OUTPUT_DIR="/output"
TRANSCRIPT_FILE="$OUTPUT_DIR/${TEST_NAME}-${HARNESS}-transcript.jsonl"
VERIFY_FILE="$OUTPUT_DIR/${TEST_NAME}-${HARNESS}-verify.txt"
rm -f "$TRANSCRIPT_FILE"

PROJECT_DIR="/tmp/trunk-sync-test-project"
rm -rf "$PROJECT_DIR"; mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q
git -C "$PROJECT_DIR" config user.email test@test
git -C "$PROJECT_DIR" config user.name test
git -C "$PROJECT_DIR" commit -q --allow-empty -m seed

run_agent() { # prompt → stdout (stream-json), also appended to the transcript
  ( cd "$PROJECT_DIR" && claude -p "$1" \
      --plugin-dir "$TS_ROOT" \
      --dangerously-skip-permissions \
      --model sonnet \
      --max-budget-usd 2.00 \
      --output-format stream-json \
      --verbose 2>&1 ) | tee -a "$TRANSCRIPT_FILE"
}

LAST="implemented the parser"
NEXT="wire the CLI and write tests"

echo "=== Agent A: edit + record progress (real claude) ==="
A_PROMPT="This project uses trunk-sync. At session start you were given your trunk-sync session id and the exact command to record progress. Do exactly: (1) create a file notes.txt containing the word hello using the Write tool; (2) then record your progress by running that exact command for YOUR session id with --last \"$LAST\" and --next \"$NEXT\". Finally print the exact command you ran."
run_agent "$A_PROMPT" >/dev/null

CARD="$(ls "$PROJECT_DIR"/.trunk-sync/timeclock/*.json 2>/dev/null | head -1 || true)"

echo "=== Agent B: fresh session — SessionStart should surface A's handover ==="
B_PROMPT='At session start, trunk-sync may have shown you a TRUNK-SYNC HANDOVER from other sessions. Report verbatim every line you were shown that begins with "last:" or "next:". If you saw no handover, reply exactly NO HANDOVER.'
B_OUT="$(run_agent "$B_PROMPT")"

# --- Deterministic verification (no AI eval) ---
PASS=0; FAIL=0
check() { if eval "$2"; then echo "PASS - $1"; PASS=$((PASS+1)); else echo "FAIL - $1"; FAIL=$((FAIL+1)); fi; }

{
  echo "trunk-sync handover System test — deterministic verification"
  echo "timecard: ${CARD:-<none>}"
  echo ""
} > "$VERIFY_FILE"

check "A's real session clocked in (timecard exists)" '[ -n "$CARD" ]'
check "A recorded lastStep via bundled progress recorder"     'grep -q "$LAST" "${CARD:-/nonexistent}" 2>/dev/null'
check "A recorded remainingSteps via bundled progress recorder" 'grep -q "$NEXT" "${CARD:-/nonexistent}" 2>/dev/null'
check "B's real SessionStart injected A's last step"      'grep -q "$LAST" <<< "$B_OUT"'
check "B's real SessionStart injected A's remaining steps" 'grep -q "$NEXT" <<< "$B_OUT"'

{
  echo ""
  echo "$PASS passed, $FAIL failed"
} | tee -a "$VERIFY_FILE"

[ "$FAIL" -eq 0 ]
