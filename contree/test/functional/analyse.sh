#!/usr/bin/env bash
set -euo pipefail

# Analyse functional test transcripts.
# Runs in Docker for a clean environment (no plugins interfering).
#
# Usage:
#   ./analyse.sh                     # analyse all transcripts
#   ./analyse.sh incidental-pass     # analyse one

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IMAGE_NAME="contree-functional-test"
CONTAINER_NAME="contree-analyse-$$"

[ -f "$SCRIPT_DIR/.env" ] && set -a && . "$SCRIPT_DIR/.env" && set +a

ALL_TESTS=(incidental-pass setup-generates-requirements tdd-writes-requirement-first stop-hook-fires setup-docker-testing)

trap 'docker rm -f "$CONTAINER_NAME" 2>/dev/null || true' EXIT

echo "Building test image..."
docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR"

analyse_test() {
  local test_name="$1"
  local transcript="$SCRIPT_DIR/${test_name}-transcript.jsonl"

  if [ ! -f "$transcript" ]; then
    echo "=== $test_name: SKIP (no transcript) ==="
    return
  fi

  echo ""
  echo "=== Analysing: $test_name ==="

  docker run --rm --name "$CONTAINER_NAME" \
    -e ANTHROPIC_API_KEY \
    -v "$SCRIPT_DIR:/transcripts:ro" \
    -v "$REPO_ROOT:/repo:ro" \
    "$IMAGE_NAME" \
    bash -c "
      cp -r /repo/contree /work/contree
      chmod +x /work/contree/test/functional/*.sh
      /work/contree/test/functional/analyse-inner.sh $test_name
    "
}

TEST_NAME="${1:-all}"

if [ "$TEST_NAME" = "all" ]; then
  for t in "${ALL_TESTS[@]}"; do analyse_test "$t"; done
else
  analyse_test "$TEST_NAME"
fi
