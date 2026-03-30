#!/usr/bin/env bash
set -euo pipefail

# Run contree functional tests in Docker.
#
# Usage:
#   ./docker-run.sh incidental-pass    # run one test
#   ./docker-run.sh all                # run all tests
#
# Transcripts are saved to *-transcript.jsonl.
# Run ./analyse.sh to verify them.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IMAGE_NAME="contree-functional-test"
CONTAINER_NAME="contree-functional-test-$$"

# Load .env if present
for env_file in "$SCRIPT_DIR/.env" "$REPO_ROOT/.env"; do
  [ -f "$env_file" ] && set -a && . "$env_file" && set +a
done

ALL_TESTS=(incidental-pass setup-generates-requirements tdd-writes-requirement-first stop-hook-fires setup-docker-testing)

trap 'docker rm -f "$CONTAINER_NAME" 2>/dev/null || true' EXIT

echo "Building test image..."
docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR"

run_test() {
  echo ""
  echo "=== Running: $1 ==="
  docker run --rm --name "$CONTAINER_NAME" \
    -e ANTHROPIC_API_KEY \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$SCRIPT_DIR:/output" \
    "$IMAGE_NAME" \
    bash -c "cp -r /repo/contree /work/contree && chmod +x /work/contree/test/functional/*.sh && /work/contree/test/functional/docker-entrypoint.sh $1"
}

TEST_NAME="${1:?Usage: ./docker-run.sh <test-name|all>}"

if [ "$TEST_NAME" = "all" ]; then
  for t in "${ALL_TESTS[@]}"; do run_test "$t"; done
else
  run_test "$TEST_NAME"
fi

echo ""
echo "Done. Run ./analyse.sh to verify transcripts."
