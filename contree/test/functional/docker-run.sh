#!/usr/bin/env bash
set -euo pipefail

# Run contree functional tests in Docker.
#
# Usage:
#   ./docker-run.sh incidental-pass    # run one test
#   ./docker-run.sh all                # run all in parallel
#
# Transcripts are saved to *-transcript.jsonl.
# Run ./analyse.sh to verify them.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IMAGE_NAME="contree-functional-test"

for env_file in "$SCRIPT_DIR/.env" "$REPO_ROOT/.env"; do
  [ -f "$env_file" ] && set -a && . "$env_file" && set +a
done

ALL_TESTS=(incidental-pass setup-generates-requirements tdd-writes-requirement-first stop-hook-fires setup-docker-testing)

echo "Building test image..."
docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR"

run_test() {
  local name="$1"
  echo "=== Starting: $name ==="
  docker run --rm \
    --name "contree-test-${name}-$$" \
    -e ANTHROPIC_API_KEY \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$SCRIPT_DIR:/output" \
    "$IMAGE_NAME" \
    bash -c "cp -r /repo/contree /work/contree && chmod +x /work/contree/test/functional/*.sh && /work/contree/test/functional/docker-entrypoint.sh $name" \
    && echo "=== Done: $name ===" \
    || echo "=== Failed: $name ==="
}

TEST_NAME="${1:?Usage: ./docker-run.sh <test-name|all>}"

if [ "$TEST_NAME" = "all" ]; then
  pids=()
  for t in "${ALL_TESTS[@]}"; do
    run_test "$t" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do wait "$pid" || true; done
else
  run_test "$TEST_NAME"
fi

echo ""
echo "Done. Run ./analyse.sh to verify transcripts."
