#!/usr/bin/env bash
set -euo pipefail

# Run trunk-sync functional (System-layer, real-CLI) tests in Docker.
# The real `claude` binary runs INSIDE the container with --dangerously-skip-permissions;
# the host is never asked to skip permissions. Mirrors contree/test/functional/docker-run.sh.
#
# Usage:
#   ./docker-run.sh handover            # the handover System case (real claude, claude harness)
#   ./docker-run.sh handover codex      # the same System case with Codex
#   ./docker-run.sh all                 # every functional case through every supported harness
#
# Writes <test>-<harness>-transcript.jsonl and <test>-<harness>-verify.txt next to this script.
# The entrypoint self-verifies deterministically (no AI eval) and exits non-zero on failure.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IMAGE_NAME="trunk-sync-functional-test"
MATRIX=(
  "handover:claude"
  "handover:codex"
)

for env_file in "$SCRIPT_DIR/.env" "$REPO_ROOT/.env"; do
  [ -f "$env_file" ] && set -a && . "$env_file" && set +a
done

# Provider selection: DeepSeek (preferred) or Anthropic — same pattern as contree.
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
  export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
  export ANTHROPIC_MODEL="deepseek-v4-pro[1m]"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1m]"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
  export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
  DOCKER_LLM_ENV=(
    -e ANTHROPIC_BASE_URL -e ANTHROPIC_AUTH_TOKEN -e ANTHROPIC_MODEL
    -e ANTHROPIC_DEFAULT_SONNET_MODEL -e ANTHROPIC_DEFAULT_HAIKU_MODEL -e CLAUDE_CODE_SUBAGENT_MODEL
  )
elif [ "${1:-handover}" != "all" ]; then
  : "${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY (or DEEPSEEK_API_KEY) in env or test/functional/.env}"
  DOCKER_LLM_ENV=(-e ANTHROPIC_API_KEY)
else
  DOCKER_LLM_ENV=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}")
fi

TEST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NAME="${1:-handover}"
HARNESS="${2:-claude}"

echo "Building test image..."
docker build -q -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$TEST_DIR"

run_pair() {
  local name="$1"
  local harness="$2"
  echo "=== Starting: $name ($harness) ==="
  docker run --rm \
    --name "trunk-sync-test-${name}-${harness}-$$" \
    "${DOCKER_LLM_ENV[@]}" \
    -e "CODEX_API_KEY=${OPENAI_API_KEY:-}" \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$SCRIPT_DIR:/output" \
    "$IMAGE_NAME" \
    bash -c "cp -r /repo/trunk-sync /work/trunk-sync && chmod +x /work/trunk-sync/test/functional/*.sh /work/trunk-sync/scripts/*.sh && /work/trunk-sync/test/functional/docker-entrypoint.sh $name $harness"
}

if [ "$NAME" = "all" ]; then
  for pair in "${MATRIX[@]}"; do
    run_pair "${pair%%:*}" "${pair##*:}"
  done
else
  run_pair "$NAME" "$HARNESS"
fi

echo ""
echo "Done. Transcript + verify:"
if [ "$NAME" = "all" ]; then
  for pair in "${MATRIX[@]}"; do
    echo "  $SCRIPT_DIR/${pair%%:*}-${pair##*:}-transcript.jsonl"
    echo "  $SCRIPT_DIR/${pair%%:*}-${pair##*:}-verify.txt"
  done
else
  echo "  $SCRIPT_DIR/${NAME}-${HARNESS}-transcript.jsonl"
  echo "  $SCRIPT_DIR/${NAME}-${HARNESS}-verify.txt"
fi
