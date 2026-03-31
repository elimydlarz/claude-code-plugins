#!/usr/bin/env bash
set -euo pipefail

# Analyse functional test transcripts against VERIFY criteria.
#
# Usage:
#   ./analyse.sh                    # analyse all transcripts
#   ./analyse.sh incidental-pass    # analyse one transcript
#
# Extracts VERIFY criteria from docker-entrypoint.sh, feeds them
# along with the transcript to Claude for evaluation.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENTRYPOINT="$SCRIPT_DIR/docker-entrypoint.sh"

# Load API key from .env files (same search order as docker-run.sh)
for env_file in "$SCRIPT_DIR/.env" "$REPO_ROOT/.env"; do
  [ -f "$env_file" ] && set -a && . "$env_file" && set +a
done

extract_verify() {
  local test_name="$1"
  # Extract the VERIFY block for this test from the entrypoint script
  sed -n "/^  ${test_name})/,/^  ;;/p" "$ENTRYPOINT" \
    | sed -n '/=== VERIFY ===/,/^VERIFY$/p' \
    | grep -v '^VERIFY$'
}

analyse_one() {
  local test_name="$1"
  local transcript="$SCRIPT_DIR/${test_name}-transcript.jsonl"

  if [ ! -f "$transcript" ]; then
    echo "SKIP: $test_name — no transcript found"
    return
  fi

  local verify
  verify="$(extract_verify "$test_name")"

  if [ -z "$verify" ]; then
    echo "ERROR: $test_name — no VERIFY criteria found in entrypoint"
    return 1
  fi

  echo "=== Analysing: $test_name ==="

  claude -p "$(cat <<EOF
Analyse this functional test transcript against the VERIFY criteria below.

For each criterion, state PASS or FAIL with one line of evidence.
End with: Overall: PASS (N/M) or FAIL (N/M).

$verify

Transcript (JSONL — each line is a JSON event, look for assistant messages and tool results):
$(cat "$transcript")
EOF
)" --no-session-persistence --model sonnet --max-budget-usd 0.25 --output-format text 2>/dev/null
  echo ""
}

ALL_TESTS=(incidental-pass setup-generates-requirements tdd-writes-requirement-first stop-hook-fires setup-docker-testing discover-change discover-sync discover-setup discover-tdd)

if [ $# -eq 0 ]; then
  # Analyse all transcripts that exist
  for t in "${ALL_TESTS[@]}"; do
    [ -f "$SCRIPT_DIR/${t}-transcript.jsonl" ] && analyse_one "$t"
  done
else
  analyse_one "$1"
fi
