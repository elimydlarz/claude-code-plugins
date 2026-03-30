#!/usr/bin/env bash
set -euo pipefail

# Run and analyse contree functional tests in Docker.
#
# Secrets are passed via environment variables — never baked into the image.
# Test artefacts (container, temp files) are torn down on exit.
#
# Usage:
#   ./docker-run.sh <test-name>          # run one test
#   ./docker-run.sh all                  # run all tests
#   ./docker-run.sh analyse [test-name]  # analyse transcripts from a prior run
#   ./docker-run.sh                      # show help
#
# Requires: docker, ANTHROPIC_API_KEY in environment or .env file

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$CONTREE_ROOT/.." && pwd)"
IMAGE_NAME="contree-functional-test"
CONTAINER_NAME="contree-functional-test-$$"

# Load .env if present
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/.env"
  set +a
fi

ALL_TESTS=(
  incidental-pass
  setup-generates-requirements
  tdd-writes-requirement-first
  stop-hook-fires
  setup-docker-testing
)

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Warning: ANTHROPIC_API_KEY not set — claude will attempt token auth inside Docker" >&2
fi

# Tear down on exit
trap 'docker rm -f "$CONTAINER_NAME" 2>/dev/null || true' EXIT

# Build image (cached after first run)
ensure_image() {
  echo "Building test image..."
  docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR"
}

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

analyse_test() {
  local test_name="$1"
  local transcript="$SCRIPT_DIR/${test_name}-transcript.jsonl"

  if [ ! -f "$transcript" ]; then
    echo "=== $test_name: SKIP (no transcript) ==="
    return
  fi

  echo ""
  echo "=== Analysing: $test_name ==="

  docker run --rm \
    --name "$CONTAINER_NAME" \
    -e ANTHROPIC_API_KEY \
    -v "$SCRIPT_DIR:/output:ro" \
    -v "$REPO_ROOT:/repo:ro" \
    "$IMAGE_NAME" \
    bash -c "
      cp -r /repo/contree /work/contree
      chmod +x /work/contree/test/functional/*.sh
      /work/contree/test/functional/analyse.sh $test_name
    "
}

# --- Main ---

ACTION="${1:-}"

case "$ACTION" in
  analyse)
    ensure_image
    TEST_NAME="${2:-all}"
    if [ "$TEST_NAME" = "all" ]; then
      for t in "\${ALL_TESTS[@]}"; do
        analyse_test "$t"
      done
    else
      analyse_test "$TEST_NAME"
    fi
    ;;

  all)
    ensure_image
    for t in "${ALL_TESTS[@]}"; do
      run_test "$t"
    done
    echo ""
    echo "=== All tests complete ==="
    echo "Transcripts in: $SCRIPT_DIR/*-transcript.jsonl"
    echo "Run './docker-run.sh analyse' to verify transcripts."
    ;;

  "")
    echo "Usage: ./docker-run.sh <command>"
    echo ""
    echo "Commands:"
    echo "  <test-name>          Run a single test"
    echo "  all                  Run all tests"
    echo "  analyse [test-name]  Analyse transcripts (default: all)"
    echo ""
    echo "Available tests:"
    for t in "${ALL_TESTS[@]}"; do
      echo "  $t"
    done
    exit 0
    ;;

  *)
    # Assume it's a test name
    ensure_image
    run_test "$ACTION"
    echo ""
    echo "=== Done ==="
    echo "Transcript: $SCRIPT_DIR/${ACTION}-transcript.jsonl"
    echo "Run './docker-run.sh analyse $ACTION' to verify."
    ;;
esac
