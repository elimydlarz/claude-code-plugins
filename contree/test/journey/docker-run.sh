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

export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY:-}"
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

DOCKER_CODEX_ENV=(-e DEEPSEEK_API_KEY)

# (test-name, harness) pairs run by `all`.
MATRIX=(
  "layered-workflow:claude"
  "layered-workflow:codex"
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
  if [ "$harness" = "claude" ] && [ -z "${DEEPSEEK_API_KEY:-}" ]; then
    echo "Claude harness requires DEEPSEEK_API_KEY" >&2
    return 1
  fi
  if [ "$harness" = "codex" ] && [ -z "${DEEPSEEK_API_KEY:-}" ]; then
    echo "Codex harness requires DEEPSEEK_API_KEY" >&2
    return 1
  fi
  local docker_env_args=("${DOCKER_LLM_ENV[@]}")
  if [ "${#DOCKER_CODEX_ENV[@]}" -gt 0 ]; then
    docker_env_args+=("${DOCKER_CODEX_ENV[@]}")
  fi
  echo "=== Starting: $name ($harness) ==="
  if docker run --rm \
    --name "contree-test-${name}-${harness}-$$" \
    "${docker_env_args[@]}" \
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
