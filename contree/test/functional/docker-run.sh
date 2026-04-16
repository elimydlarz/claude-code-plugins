#!/usr/bin/env bash
set -euo pipefail

# Run contree functional tests in Docker.
#
# Usage:
#   ./docker-run.sh full-workflow    # run the scenario
#   ./docker-run.sh all              # run every scenario in ALL_TESTS in parallel
#
# Each scenario writes one appended transcript at <name>-transcript.jsonl and
# one verify file at <name>-verify.txt. The verify file names the trees to
# evaluate the transcript against — the trees in contree/CLAUDE.md ## Test Trees
# are the checklist.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IMAGE_NAME="contree-functional-test"

for env_file in "$SCRIPT_DIR/.env" "$REPO_ROOT/.env"; do
  [ -f "$env_file" ] && set -a && . "$env_file" && set +a
done

ALL_TESTS=(full-workflow)

TEST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Building test image..."
docker build -q -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$TEST_DIR"

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
echo "Done. Read each transcript and evaluate against its verify file:"
if [ "$TEST_NAME" = "all" ]; then
  for t in "${ALL_TESTS[@]}"; do
    if [ -f "$SCRIPT_DIR/${t}-transcript.jsonl" ]; then
      echo "  $SCRIPT_DIR/${t}-transcript.jsonl"
      echo "  $SCRIPT_DIR/${t}-verify.txt"
      echo ""
    fi
  done
else
  echo "  $SCRIPT_DIR/${TEST_NAME}-transcript.jsonl"
  echo "  $SCRIPT_DIR/${TEST_NAME}-verify.txt"
fi
