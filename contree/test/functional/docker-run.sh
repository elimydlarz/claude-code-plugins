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
#   ./docker-run.sh                    # run all functional tests
#
# Requires: docker, ANTHROPIC_API_KEY set in environment

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$CONTREE_ROOT/.." && pwd)"
IMAGE_NAME="contree-functional-test"
CONTAINER_NAME="contree-functional-test-$$"

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Error: ANTHROPIC_API_KEY must be set" >&2
  exit 1
fi

# Tear down on exit
trap 'docker rm -f "$CONTAINER_NAME" 2>/dev/null || true' EXIT

# Build image (cached after first run)
echo "Building test image..."
docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR"

TEST_NAME="${1:-all}"

run_test() {
  local test_script="$1"
  local test_basename
  test_basename="$(basename "$test_script" .sh)"

  echo ""
  echo "=== Running: $test_basename ==="

  docker run --rm \
    --name "$CONTAINER_NAME" \
    -e ANTHROPIC_API_KEY \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$SCRIPT_DIR:/output" \
    "$IMAGE_NAME" \
    bash -c "
      # Copy contree plugin to a writable location (mounted read-only)
      cp -r /repo/contree /work/contree

      # Run the test script adapted for Docker
      /work/contree/test/functional/docker-entrypoint.sh $test_basename
    "
}

if [ "$TEST_NAME" = "all" ]; then
  for script in "$SCRIPT_DIR"/*-pass.sh "$SCRIPT_DIR"/*-test.sh; do
    [ -f "$script" ] || continue
    run_test "$script"
  done
else
  run_test "$TEST_NAME"
fi

echo ""
echo "=== All tests complete ==="
