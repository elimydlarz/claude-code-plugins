#!/usr/bin/env bash
set -euo pipefail

HARNESS="${1:?harness is required}"
case "$HARNESS" in claude|codex) ;; *) echo "unsupported harness: $HARNESS" >&2; exit 1;; esac

TRUNK_SYNC_ROOT="/work/trunk-sync"
PROJECT_DIR="/tmp/trunk-sync-consumer"
REMOTE_DIR="/tmp/trunk-sync-remote.git"
TRANSCRIPT_FILE="/output/agent-hook-compatibility-${HARNESS}-transcript.jsonl"

rm -rf "$TRUNK_SYNC_ROOT" "$PROJECT_DIR" "$REMOTE_DIR"
cp -r /repo/trunk-sync "$TRUNK_SYNC_ROOT"
mkdir -p "$PROJECT_DIR"
git init -q --bare "$REMOTE_DIR"
git -C "$PROJECT_DIR" init -q
git -C "$PROJECT_DIR" config user.email "test@example.com"
git -C "$PROJECT_DIR" config user.name "Test User"
printf 'seed\n' > "$PROJECT_DIR/seed.txt"
git -C "$PROJECT_DIR" add seed.txt
git -C "$PROJECT_DIR" commit -q -m seed
git -C "$PROJECT_DIR" remote add origin "$REMOTE_DIR"

rm -f "$TRANSCRIPT_FILE"
if [ "$HARNESS" = "claude" ]; then
  (
    cd "$PROJECT_DIR"
    claude -p \
      "First run the Bash command git commit --allow-empty -m forbidden. It will be rejected. Then run exactly one Bash command: printf 'claude\\n' > agent-note.txt. After that command succeeds, use no more tools and reply with the single word DONE." \
      --plugin-dir "$TRUNK_SYNC_ROOT" \
      --dangerously-skip-permissions \
      --model sonnet \
      --max-budget-usd 1.00 \
      --output-format stream-json \
      --verbose
  ) > "$TRANSCRIPT_FILE" 2>&1
else
  CODEX_HOME="/tmp/trunk-sync-codex-home"
  CACHE_DIR="$CODEX_HOME/plugins/cache/local-marketplace/trunk-sync/local"
  rm -rf "$CODEX_HOME"
  mkdir -p "$(dirname "$CACHE_DIR")"
  cp -r "$TRUNK_SYNC_ROOT" "$CACHE_DIR"
  cat > "$CODEX_HOME/config.toml" <<CONFIG
model = "deepseek-chat"
model_provider = "deepseek"
model_reasoning_effort = "low"

[features]
hooks = true
plugin_hooks = true

[shell_environment_policy]
inherit = "all"

[plugins."trunk-sync@local-marketplace"]
enabled = true

[model_providers.deepseek]
name = "DeepSeek"
base_url = "http://127.0.0.1:8783/v1"
env_key = "DEEPSEEK_API_KEY"
wire_api = "responses"

[projects."$PROJECT_DIR"]
trust_level = "trusted"

[projects."/private$PROJECT_DIR"]
trust_level = "trusted"
CONFIG
  CODEX_DEEPSEEK_PROXY_PORT=8783 node "$TRUNK_SYNC_ROOT/test/journey/codex-deepseek-responses-proxy.mjs" >/tmp/codex-proxy.log 2>&1 &
  PROXY_PID=$!
  trap 'kill "$PROXY_PID" 2>/dev/null || true' EXIT
  for _ in $(seq 1 50); do
    curl -fsS http://127.0.0.1:8783/health >/dev/null 2>&1 && break
    sleep 0.1
  done
  curl -fsS http://127.0.0.1:8783/health >/dev/null
  (
    cd "$PROJECT_DIR"
    CODEX_HOME="$CODEX_HOME" codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      --dangerously-bypass-hook-trust \
      --skip-git-repo-check \
      --json \
      -C "$PROJECT_DIR" \
      "First run the shell command git commit --allow-empty -m forbidden. It will be rejected. Then run exactly one shell command: printf 'codex\\n' > agent-note.txt. After that command succeeds, use no more tools and reply with the single word DONE."
  ) > "$TRANSCRIPT_FILE" 2>&1
fi

git -C "$PROJECT_DIR" fetch -q origin agents
COMMIT_BODY="$(git -C "$PROJECT_DIR" log -1 --format=%B origin/agents -- agent-note.txt)"
REMOTE_CONTENT="$(git -C "$PROJECT_DIR" show origin/agents:agent-note.txt)"
REMOTE_TIMECARDS="$(git -C "$PROJECT_DIR" ls-tree -r --name-only origin/agents -- .trunk-sync/timeclock)"

if [ "$HARNESS" = "claude" ]; then
  AGENT_NAME="Claude Code"
  AGENT_PROVENANCE="claude"
else
  AGENT_NAME="Codex"
  AGENT_PROVENANCE="codex"
fi

printf '%s\n' "Journey: agent-hook-compatibility"
printf '%s\n' "  when $AGENT_NAME uses the published plugin in a consumer repository"
printf '%s\n' "    if it attempts a write-side git command"
if grep -q 'TRUNK-SYNC: Do NOT run git commands' "$TRANSCRIPT_FILE"; then
  printf '%s\n' "      then the command is rejected with instructions to edit file content instead"
else
  printf '%s\n' "      not ok - then the command is rejected with instructions to edit file content instead" >&2
  exit 1
fi
printf '%s\n' "    when it edits a file after the rejection"
if [ "$REMOTE_CONTENT" = "$AGENT_PROVENANCE" ]; then
  printf '%s\n' "      then the edit is committed and pushed to the consumer repository's shared \`agents\` branch"
else
  printf '%s\n' "      not ok - then the edit is committed and pushed to the consumer repository's shared \`agents\` branch" >&2
  exit 1
fi
if printf '%s\n' "$COMMIT_BODY" | grep -q '^Session: ' && printf '%s\n' "$COMMIT_BODY" | grep -q "^Agent: $AGENT_PROVENANCE$"; then
  printf '%s\n' "      and the commit records the $AGENT_NAME session and agent provenance"
else
  printf '%s\n' "      not ok - and the commit records the $AGENT_NAME session and agent provenance" >&2
  printf '%s\n' "$COMMIT_BODY" >&2
  exit 1
fi
printf '%s\n' "    when the session ends"
if [ -z "$REMOTE_TIMECARDS" ]; then
  printf '%s\n' "      then its presence is removed from the shared branch"
else
  printf '%s\n' "      not ok - then its presence is removed from the shared branch" >&2
  printf '%s\n' "$REMOTE_TIMECARDS" >&2
  exit 1
fi
