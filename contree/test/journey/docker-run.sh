#!/usr/bin/env bash
set -euo pipefail

# Run contree journey tests in Docker.
#
# Usage:
#   ./docker-run.sh layered-workflow                  # default harness: claude
#   ./docker-run.sh layered-workflow codex            # explicit harness
#   ./docker-run.sh all                               # every (test, harness) pair in MATRIX
#
# Each (test, harness) pair writes <test>-<harness>-transcript.jsonl and
# <test>-<harness>-verify.txt. The verify file names the trees to evaluate the
# transcript against — the trees in contree/CLAUDE.md ## Test Trees are the checklist.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IMAGE_NAME="contree-journey-test"

for env_file in "$SCRIPT_DIR/.env" "$REPO_ROOT/.env"; do
  [ -f "$env_file" ] && set -a && . "$env_file" && set +a
done

# Provider selection: DeepSeek (preferred) or Anthropic.
# When DEEPSEEK_API_KEY is set, configure Claude Code to use the DeepSeek
# Anthropic-compatible endpoint per https://api-docs.deepseek.com/quick_start/agent_integrations/claude_code
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  # docker run -e VAR only forwards exported vars, so export every provider var.
  export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
  export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
  export ANTHROPIC_MODEL="deepseek-v4-pro[1m]"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro[1m]"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1m]"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
  export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
  export CLAUDE_CODE_EFFORT_LEVEL="max"
  DOCKER_LLM_ENV=(
    -e ANTHROPIC_BASE_URL
    -e ANTHROPIC_AUTH_TOKEN
    -e ANTHROPIC_MODEL
    -e ANTHROPIC_DEFAULT_OPUS_MODEL
    -e ANTHROPIC_DEFAULT_SONNET_MODEL
    -e ANTHROPIC_DEFAULT_HAIKU_MODEL
    -e CLAUDE_CODE_SUBAGENT_MODEL
    -e CLAUDE_CODE_EFFORT_LEVEL
  )
else
  DOCKER_LLM_ENV=(-e ANTHROPIC_API_KEY)
fi

DOCKER_CODEX_ENV=()
if [ -n "${OPENAI_API_KEY:-}" ]; then
  DOCKER_CODEX_ENV=(-e CODEX_API_KEY="$OPENAI_API_KEY")
elif [ -f "$HOME/.codex/auth.json" ]; then
  DOCKER_CODEX_ENV=(-v "$HOME/.codex/auth.json:/home/testuser/.codex/auth.json:ro")
fi

# (test-name, harness) pairs run by `all`.
MATRIX=(
  "layered-workflow:claude"
  "layered-workflow:codex"
  "mental-model-validator-smoke:claude"
  "mental-model-validator-smoke:codex"
  "describe-it-drift:claude"
  "describe-it-drift:codex"
  "diff-images:claude"
  "diff-images:codex"
  "second-opinion:claude"
  "second-opinion:codex"
)

TEST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Building test image..."
BASE_IMAGE="$(awk '/^FROM /{print $2; exit}' "$SCRIPT_DIR/Dockerfile")"
if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
  echo "[harness] Base image $BASE_IMAGE not present locally — pulling..."
  docker pull "$BASE_IMAGE"
fi
docker build -q -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$TEST_DIR"

run_pair() {
  local name="$1"
  local harness="$2"
  echo "=== Starting: $name ($harness) ==="
  if docker run --rm \
    --name "contree-test-${name}-${harness}-$$" \
    "${DOCKER_LLM_ENV[@]}" \
    "${DOCKER_CODEX_ENV[@]}" \
    -e "ZAI_API_KEY=${ZAI_API_KEY:-}" \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$SCRIPT_DIR:/output" \
    "$IMAGE_NAME" \
    bash -c "cp -r /repo/contree /work/contree && chmod +x /work/contree/test/journey/*.sh && /work/contree/test/journey/docker-entrypoint.sh $name $harness"; then
    echo "=== Done: $name ($harness) ==="
  else
    echo "=== Failed: $name ($harness) ==="
    return 1
  fi
}

ARG="${1:?Usage: ./docker-run.sh <test-name|all> [claude|codex]}"

if [ "$ARG" = "all" ]; then
  pids=()
  for pair in "${MATRIX[@]}"; do
    run_pair "${pair%%:*}" "${pair##*:}" &
    pids+=($!)
  done
  failed=0
  for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
else
  HARNESS="${2:-claude}"
  run_pair "$ARG" "$HARNESS"
  failed=0
fi

echo ""
echo "Done. Read each transcript and evaluate against its verify file:"
if [ "$ARG" = "all" ]; then
  for pair in "${MATRIX[@]}"; do
    t="${pair%%:*}"
    h="${pair##*:}"
    if [ -f "$SCRIPT_DIR/${t}-${h}-transcript.jsonl" ]; then
      echo "  $SCRIPT_DIR/${t}-${h}-transcript.jsonl"
      echo "  $SCRIPT_DIR/${t}-${h}-verify.txt"
      echo ""
    fi
  done
else
  HARNESS="${2:-claude}"
  echo "  $SCRIPT_DIR/${ARG}-${HARNESS}-transcript.jsonl"
  echo "  $SCRIPT_DIR/${ARG}-${HARNESS}-verify.txt"
fi

exit "$failed"
