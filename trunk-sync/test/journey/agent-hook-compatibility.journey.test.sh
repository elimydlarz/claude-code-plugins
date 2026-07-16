#!/usr/bin/env bash
set -euo pipefail

HARNESS="${1:?harness is required}"
case "$HARNESS" in claude|codex) ;; *) echo "unsupported harness: $HARNESS" >&2; exit 1;; esac
MODE="${2:-source}"
case "$MODE" in source|installed) ;; *) echo "unsupported mode: $MODE" >&2; exit 1;; esac
[ -n "${OPENAI_API_KEY:-}" ] || { echo "OPENAI_API_KEY is required" >&2; exit 1; }

TRUNK_SYNC_ROOT="/work/trunk-sync"
PROJECT_DIR="/journey-state/consumer-$HARNESS"
REMOTE_DIR="/journey-state/remote.git"
TRANSCRIPT_FILE="/output/agent-hook-compatibility-${MODE}-clones-${HARNESS}-transcript.jsonl"
INSTALL_RESULT="/tmp/trunk-sync-install-${HARNESS}.json"

rm -rf "$TRUNK_SYNC_ROOT"
cp -r /repo/trunk-sync "$TRUNK_SYNC_ROOT"

if [ "$HARNESS" = "claude" ]; then
  AGENT_NAME="Claude Code"
  AGENT_LABEL="Claude"
  AGENT_PROVENANCE="claude"
  NATIVE_TOOL="Write"
else
  AGENT_NAME="Codex"
  AGENT_LABEL="Codex"
  AGENT_PROVENANCE="codex"
  NATIVE_TOOL="apply_patch"
fi
AGENT_NOTE="agent-note-$HARNESS.txt"

rm -f "$TRANSCRIPT_FILE"
if [ "$HARNESS" = "claude" ]; then
  CLAUDE_HOME="/home/testuser"
  PLUGIN_ARGS=(--plugin-dir "$TRUNK_SYNC_ROOT")
  if [ "$MODE" = "installed" ]; then
    CLAUDE_HOME="/tmp/trunk-sync-claude-home"
    rm -rf "$CLAUDE_HOME"
    mkdir -p "$CLAUDE_HOME"
    HOME="$CLAUDE_HOME" claude plugin marketplace add /repo > "$INSTALL_RESULT"
    HOME="$CLAUDE_HOME" claude plugin install trunk-sync@elimydlarz --scope user >> "$INSTALL_RESULT"
    PLUGIN_ARGS=()
  fi
  CLAUDE_OPENAI_PROXY_PORT=8783 node "$TRUNK_SYNC_ROOT/test/journey/claude-openai-responses-proxy.mjs" >/tmp/claude-openai-proxy.log 2>&1 &
  PROXY_PID=$!
  trap 'kill "$PROXY_PID" 2>/dev/null || true' EXIT
  for _ in $(seq 1 50); do
    curl -fsS http://127.0.0.1:8783/health >/dev/null 2>&1 && break
    sleep 0.1
  done
  curl -fsS http://127.0.0.1:8783/health >/dev/null
  (
    cd "$PROJECT_DIR"
    HOME="$CLAUDE_HOME" ANTHROPIC_BASE_URL="http://127.0.0.1:8783" \
    ANTHROPIC_AUTH_TOKEN="$OPENAI_API_KEY" \
    ANTHROPIC_MODEL="gpt-5.6-luna" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-5.6-luna" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-5.6-luna" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-5.6-luna" \
    claude -p \
      "First use Bash to run exactly: git commit --allow-empty -m forbidden. After it is rejected, use Bash to run exactly: cd . && git status. After that is rejected, use the native Write tool, not Bash or a shell, to create $AGENT_NOTE containing exactly claude followed by a newline. Then use no more tools and reply with the single word DONE." \
      "${PLUGIN_ARGS[@]}" \
      --dangerously-skip-permissions \
      --model sonnet \
      --max-budget-usd 1.00 \
      --output-format stream-json \
      --verbose
  ) > "$TRANSCRIPT_FILE" 2>&1
else
  CODEX_HOME="/tmp/trunk-sync-codex-home"
  rm -rf "$CODEX_HOME"
  mkdir -p "$CODEX_HOME"
  if [ "$MODE" = "installed" ]; then
    CODEX_HOME="$CODEX_HOME" codex plugin marketplace add /repo --json > "$INSTALL_RESULT"
    CODEX_HOME="$CODEX_HOME" codex plugin add trunk-sync@elimydlarz --json >> "$INSTALL_RESULT"
    cp "$CODEX_HOME/config.toml" /tmp/trunk-sync-manager-config.toml
  else
    CACHE_DIR="$CODEX_HOME/plugins/cache/local-marketplace/trunk-sync/local"
    mkdir -p "$(dirname "$CACHE_DIR")"
    cp -r "$TRUNK_SYNC_ROOT" "$CACHE_DIR"
  fi
  cat > "$CODEX_HOME/config.toml" <<CONFIG
model = "gpt-5.6-luna"
model_provider = "openai-custom"
model_reasoning_effort = "low"

[features]
hooks = true
plugin_hooks = true

[shell_environment_policy]
inherit = "all"

[model_providers.openai-custom]
name = "OpenAI"
base_url = "https://api.openai.com/v1"
env_key = "OPENAI_API_KEY"
wire_api = "responses"

[projects."$PROJECT_DIR"]
trust_level = "trusted"

[projects."/private$PROJECT_DIR"]
trust_level = "trusted"
CONFIG
  if [ "$MODE" = "installed" ]; then
    cat /tmp/trunk-sync-manager-config.toml >> "$CODEX_HOME/config.toml"
  else
    cat >> "$CODEX_HOME/config.toml" <<CONFIG

[plugins."trunk-sync@local-marketplace"]
enabled = true
CONFIG
  fi
  (
    cd "$PROJECT_DIR"
    OPENAI_API_KEY="$OPENAI_API_KEY" CODEX_HOME="$CODEX_HOME" codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      --dangerously-bypass-hook-trust \
      --skip-git-repo-check \
      --json \
      -C "$PROJECT_DIR" \
      "First use the shell to run exactly: git commit --allow-empty -m forbidden. After it is rejected, use the shell to run exactly: cd . && git status. After that is rejected, use the native apply_patch tool, not the shell, to create $AGENT_NOTE containing exactly codex followed by a newline. Then use no more tools and reply with the single word DONE."
  ) > "$TRANSCRIPT_FILE" 2>&1
fi

touch "/journey-state/completed-$HARNESS"
for _ in $(seq 1 300); do
  completed_count=$(find /journey-state -maxdepth 1 -name 'completed-*' | wc -l | tr -d ' ')
  [ "$completed_count" -eq "${EXPECTED_HARNESSES:?expected harness count is required}" ] && break
  sleep 0.1
done
completed_count=$(find /journey-state -maxdepth 1 -name 'completed-*' | wc -l | tr -d ' ')
[ "$completed_count" -eq "$EXPECTED_HARNESSES" ] || { echo "the other agent harness did not complete" >&2; exit 1; }

assertion_lock_acquired=false
for _ in $(seq 1 300); do
  if mkdir /journey-state/assertion-lock 2>/dev/null; then
    assertion_lock_acquired=true
    break
  fi
  sleep 0.1
done
[ "$assertion_lock_acquired" = "true" ] || { echo "could not acquire the functional assertion lock" >&2; exit 1; }
trap 'rmdir /journey-state/assertion-lock 2>/dev/null || true' EXIT

CURRENT_BRANCH="$(git -C "$PROJECT_DIR" branch --show-current)"
git -C "$PROJECT_DIR" fetch -q origin "$CURRENT_BRANCH"
COMMIT_BODY="$(git -C "$PROJECT_DIR" log -1 --format=%B "origin/$CURRENT_BRANCH" -- "$AGENT_NOTE")"
REMOTE_CONTENT="$(git -C "$PROJECT_DIR" show "origin/$CURRENT_BRANCH:$AGENT_NOTE")"
REMOTE_TIMECARDS="$(git -C "$PROJECT_DIR" ls-tree -r --name-only "origin/$CURRENT_BRANCH" -- .trunk-sync/timeclock)"
REMOTE_SUBJECTS="$(git -C "$REMOTE_DIR" log --format=%s "$CURRENT_BRANCH")"
SESSION_ID="$(printf '%s\n' "$COMMIT_BODY" | sed -n 's/^Session: //p')"

if [ "$MODE" = "installed" ]; then
  JOURNEY_NAME="installed-plugin-compatibility"
  LAUNCH_CONTEXT="when the release/install journey is launched with OPENAI_API_KEY"
  USE_CONTEXT="when $AGENT_NAME uses trunk-sync installed through its plugin manager in a checked-out consumer repository"
else
  JOURNEY_NAME="agent-hook-compatibility"
  LAUNCH_CONTEXT="when the functional journey is launched with OPENAI_API_KEY"
  USE_CONTEXT="when $AGENT_NAME loads the source plugin bundle directly in a checked-out consumer repository"
fi

printf '%s\n' "Journey: $JOURNEY_NAME"
printf '%s\n' "  $LAUNCH_CONTEXT"
printf '%s\n' "    then OpenAI-backed model access is available to the selected agent harness"
if [ "$MODE" = "installed" ]; then
  printf '%s\n' "      when the repository marketplace is added and trunk-sync is installed"
  if [ "$HARNESS" = "claude" ]; then
    INSTALLED_PATH=$(jq -r '.plugins["trunk-sync@elimydlarz"][0].installPath' "$CLAUDE_HOME/.claude/plugins/installed_plugins.json")
    DISCOVERED=$(jq -Rsc '[split("\n")[] | fromjson?] | any(.[]; .type == "system" and .subtype == "init" and any(.plugins[]?; .name == "trunk-sync" and .source != "trunk-sync@inline"))' "$TRANSCRIPT_FILE")
  else
    INSTALLED_PATH=$(sed -n 's/.*"installedPath": "\([^"]*\)".*/\1/p' "$INSTALL_RESULT")
    CODEX_HOME="$CODEX_HOME" codex plugin list --json > /tmp/trunk-sync-plugin-list.json
    DISCOVERED=$(jq -r 'any(.installed[]?; .pluginId == "trunk-sync@elimydlarz" and .installed and .enabled)' /tmp/trunk-sync-plugin-list.json)
  fi
  if [[ "$INSTALLED_PATH" == *"/plugins/cache/elimydlarz/trunk-sync/"* && "$DISCOVERED" = "true" ]]; then
    printf '%s\n' "        then the host discovers the installed plugin from its cache"
  else
    printf '%s\n' "        not ok - then the host discovers the installed plugin from its cache" >&2
    exit 1
  fi
fi
printf '%s\n' "      $USE_CONTEXT"
printf '%s\n' "        if it attempts a write-side git command"
if grep -q 'TRUNK-SYNC: Do NOT run write-side git commands' "$TRANSCRIPT_FILE"; then
  printf '%s\n' "          then the command is rejected with instructions to edit file content instead"
else
  printf '%s\n' "          not ok - then the command is rejected with instructions to edit file content instead" >&2
  exit 1
fi
printf '%s\n' "        if it composes Git inspection with another shell command"
if grep -q 'Run standalone Git inspection' "$TRANSCRIPT_FILE"; then
  printf '%s\n' "          then the command is rejected with standalone inspection guidance"
else
  printf '%s\n' "          not ok - then the command is rejected with standalone inspection guidance" >&2
  exit 1
fi
if [ "$HARNESS" = "claude" ]; then
  NATIVE_USED=$(jq -Rsc '[split("\n")[] | fromjson?] | any(.[]; .type == "assistant" and any(.message.content[]?; .type == "tool_use" and .name == "Write"))' "$TRANSCRIPT_FILE")
else
  NATIVE_USED=$(jq -Rsc '[split("\n")[] | fromjson?] | any(.[]; .type == "item.completed" and .item.type == "file_change")' "$TRANSCRIPT_FILE")
fi
printf '%s\n' "        when it uses the native $NATIVE_TOOL tool after the rejections"
if [ "$NATIVE_USED" = "true" ]; then
  printf '%s\n' "          then the transcript records the native tool use"
else
  printf '%s\n' "          not ok - then the transcript records the native tool use" >&2
  exit 1
fi
if [ "$REMOTE_CONTENT" = "$AGENT_PROVENANCE" ]; then
  printf '%s\n' "          then the edit is committed and pushed to the current branch in the consumer repository"
else
  printf '%s\n' "          not ok - then the edit is committed and pushed to the current branch in the consumer repository" >&2
  exit 1
fi
if printf '%s\n' "$COMMIT_BODY" | grep -q '^Session: ' && printf '%s\n' "$COMMIT_BODY" | grep -q "^Agent: $AGENT_PROVENANCE$"; then
  printf '%s\n' "          and the commit records the $AGENT_LABEL session and agent provenance"
else
  printf '%s\n' "          not ok - and the commit records the $AGENT_NAME session and agent provenance" >&2
  printf '%s\n' "$COMMIT_BODY" >&2
  exit 1
fi
printf '%s\n' "        when the session starts and ends"
if printf '%s\n' "$REMOTE_SUBJECTS" | grep -q "^auto: clock-in ${SESSION_ID:0:8}$" && printf '%s\n' "$REMOTE_SUBJECTS" | grep -q "^auto: clock-out ${SESSION_ID:0:8}$"; then
  printf '%s\n' "          then clock-in and clock-out commits are retained in remote history"
else
  printf '%s\n' "          not ok - then clock-in and clock-out commits are retained in remote history" >&2
  printf '%s\n' "$REMOTE_SUBJECTS" >&2
  exit 1
fi
printf '%s\n' "        when the session ends"
if ! printf '%s\n' "$REMOTE_TIMECARDS" | grep -q "/$SESSION_ID.json$"; then
  printf '%s\n' "          then its presence is removed from the current branch"
else
  printf '%s\n' "          not ok - then its presence is removed from the current branch" >&2
  printf '%s\n' "$REMOTE_TIMECARDS" >&2
  exit 1
fi
