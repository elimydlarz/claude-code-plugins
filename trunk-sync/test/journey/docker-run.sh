#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

for env_file in "$SCRIPT_DIR/.env" "$REPO_ROOT/.env"; do
  [ -f "$env_file" ] && set -a && . "$env_file" && set +a
done

[ -n "${OPENAI_API_KEY:-}" ] || { echo "OPENAI_API_KEY is required" >&2; exit 1; }

IMAGE_NAME="trunk-sync-journey-test"
docker build -q -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"

run_harness() {
  local harness="$1"
  local mode="$2"
  local state_root="$3"
  local expected_harnesses="$4"
  docker run --rm \
    -e OPENAI_API_KEY \
    -e EXPECTED_HARNESSES="$expected_harnesses" \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$SCRIPT_DIR:/output" \
    -v "$state_root:/journey-state" \
    "$IMAGE_NAME" \
    bash "/repo/trunk-sync/test/journey/${mode}-plugin-compatibility.journey.test.sh" "$harness"
}

HARNESS="${1:-all}"
MODE="${2:-source}"
case "$HARNESS" in all|claude|codex) ;; *) echo "unsupported harness: $HARNESS" >&2; exit 1;; esac
case "$MODE" in source|installed) ;; *) echo "unsupported mode: $MODE" >&2; exit 1;; esac

STATE_ROOT="$(mktemp -d "/tmp/trunk-sync-journey-clones.XXXXXX")"
cleanup() {
  rm -rf "$STATE_ROOT"
}
trap cleanup EXIT

chmod 0777 "$STATE_ROOT"
docker run --rm \
  -v "$REPO_ROOT:/repo:ro" \
  -v "$STATE_ROOT:/journey-state" \
  "$IMAGE_NAME" \
  bash /repo/trunk-sync/test/journey/prepare-checkout-topology.sh

if [ "$HARNESS" = "all" ]; then
  run_harness claude "$MODE" "$STATE_ROOT" 2 &
  claude_pid=$!
  run_harness codex "$MODE" "$STATE_ROOT" 2 &
  codex_pid=$!
  failed=0
  wait "$claude_pid" || failed=1
  wait "$codex_pid" || failed=1
  [ "$failed" -eq 0 ]
else
  run_harness "$HARNESS" "$MODE" "$STATE_ROOT" 1
fi
