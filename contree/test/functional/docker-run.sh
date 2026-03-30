#!/usr/bin/env bash
set -euo pipefail

# Run contree functional tests in Docker.
#
# Secrets are passed via environment variables — never baked into the image.
# Test artefacts (container, temp files) are torn down on exit.
#
# Usage:
#   ANTHROPIC_API_KEY=sk-... ./docker-run.sh [test-name]
#
# Examples:
#   ./docker-run.sh incidental-pass    # run one test
#   ./docker-run.sh                    # list available tests
#
# Requires: docker, ANTHROPIC_API_KEY set in environment

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$CONTREE_ROOT/.." && pwd)"
IMAGE_NAME="contree-functional-test"
CONTAINER_NAME="contree-functional-test-$$"

ALL_TESTS=(
  incidental-pass
  setup-generates-requirements
  tdd-writes-requirement-first
  stop-hook-fires
  setup-docker-testing
)

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Error: ANTHROPIC_API_KEY must be set" >&2
  exit 1
fi

# Tear down on exit
trap 'docker rm -f "$CONTAINER_NAME" 2>/dev/null || true' EXIT

# Build image (cached after first run)
echo "Building test image..."
docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR"

run_test() {
  local test_name="$1"

  echo ""
  echo "=== Running: $test_name ==="

  docker run --rm \
    --name "$CONTAINER_NAME" \
    -e ANTHROPIC_API_KEY \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$SCRIPT_DIR:/output" \
    "$IMAGE_NAME" \
    bash -c "
      cp -r /repo/contree /work/contree
      chmod +x /work/contree/test/functional/*.sh
      /work/contree/test/functional/docker-entrypoint.sh $test_name
    "
}

TEST_NAME="${1:-}"

if [ -z "$TEST_NAME" ]; then
  echo ""
  echo "Usage: ./docker-run.sh <test-name>"
  echo ""
  echo "Available tests:"
  for t in "${ALL_TESTS[@]}"; do
    echo "  $t"
  done
  echo ""
  echo "  all  — run all tests sequentially"
  exit 0
elif [ "$TEST_NAME" = "all" ]; then
  for t in "${ALL_TESTS[@]}"; do
    run_test "$t"
  done
else
  run_test "$TEST_NAME"
fi

echo ""
echo "=== Done ==="
echo "Transcripts in: $SCRIPT_DIR/*-transcript.jsonl"
