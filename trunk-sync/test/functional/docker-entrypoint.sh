#!/usr/bin/env bash
set -euo pipefail

# Runs a trunk-sync functional (System-layer, real-agent) case against a harness.
# Works inside Docker (called by docker-run.sh) or directly on the host.
#
# handover: drives TWO real agent sessions in one repo —
#   Agent A makes an edit (hook clocks it in) and records progress via the bundled recorder;
#   Agent B starts fresh and its SessionStart surfaces A's handover.
# Self-verifies DETERMINISTICALLY (no AI eval): the timecard must carry A's authored
# progress, and B's transcript must contain it (proving real SessionStart injection +
# a real agent both writing and receiving the handover). Exits non-zero on any failure.

TEST_NAME="${1:-handover}"
HARNESS="${2:-claude}"
case "$HARNESS" in claude|codex) ;; *) echo "Unknown harness: $HARNESS (use claude or codex)" >&2; exit 1;; esac

if [ -d "/work/trunk-sync" ]; then
  TS_ROOT="/work/trunk-sync"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  TS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

OUTPUT_DIR="$TS_ROOT/test/functional"
[ -d "/output" ] && OUTPUT_DIR="/output"
TRANSCRIPT_FILE="$OUTPUT_DIR/${TEST_NAME}-${HARNESS}-transcript.jsonl"
VERIFY_FILE="$OUTPUT_DIR/${TEST_NAME}-${HARNESS}-verify.txt"
rm -f "$TRANSCRIPT_FILE"

PROJECT_DIR="/tmp/trunk-sync-test-project"
CODEX_TEST_HOME="$PROJECT_DIR/.codex-home"
rm -rf "$PROJECT_DIR"; mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q
git -C "$PROJECT_DIR" config user.email test@test
git -C "$PROJECT_DIR" config user.name test
git -C "$PROJECT_DIR" commit -q --allow-empty -m seed

CODEX_PRIMED=0

append_codex_artifacts() {
  [ "$HARNESS" = "codex" ] || return 0

  local session_file
  session_file="$(find "$CODEX_TEST_HOME/sessions" -type f -name '*.jsonl' 2>/dev/null | sort | tail -n 1 || true)"
  if [ -n "$session_file" ] && [ -f "$session_file" ]; then
    {
      echo ""
      echo "=== codex internal session transcript: $session_file ==="
      cat "$session_file"
    } >> "$TRANSCRIPT_FILE"
  fi

  for name in session-start post-tool-use stop; do
    if [ -f "$PROJECT_DIR/.codex/${name}-input.jsonl" ]; then
      {
        echo ""
        echo "=== codex ${name} hook stdin ==="
        cat "$PROJECT_DIR/.codex/${name}-input.jsonl"
      } >> "$TRANSCRIPT_FILE"
    fi
    if [ -f "$PROJECT_DIR/.codex/${name}-output.jsonl" ]; then
      {
        echo ""
        echo "=== codex ${name} hook stdout ==="
        cat "$PROJECT_DIR/.codex/${name}-output.jsonl"
      } >> "$TRANSCRIPT_FILE"
    fi
    if [ -f "$PROJECT_DIR/.codex/${name}-stderr.jsonl" ]; then
      {
        echo ""
        echo "=== codex ${name} hook stderr ==="
        cat "$PROJECT_DIR/.codex/${name}-stderr.jsonl"
      } >> "$TRANSCRIPT_FILE"
    fi
  done
}

prime_codex_plugin() {
  [ "$CODEX_PRIMED" -eq 1 ] && return 0
  CODEX_PRIMED=1

  rm -rf "$CODEX_TEST_HOME"
  mkdir -p "$CODEX_TEST_HOME"
  if [ -f "$HOME/.codex/auth.json" ]; then
    cp "$HOME/.codex/auth.json" "$CODEX_TEST_HOME/auth.json"
  fi

  local cache_dir="$CODEX_TEST_HOME/plugins/cache/local-marketplace/trunk-sync/local"
  rm -rf "$cache_dir"
  mkdir -p "$(dirname "$cache_dir")"
  cp -r "$TS_ROOT" "$cache_dir"

  mkdir -p "$PROJECT_DIR/.codex"
  cat > "$PROJECT_DIR/.codex/run-hook.sh" <<CONFIG
#!/usr/bin/env bash
set -euo pipefail
name="\$1"
script="\$2"
export CLAUDE_PLUGIN_ROOT="$cache_dir"
input=\$(cat)
printf '%s\n' "\$input" >> "$PROJECT_DIR/.codex/\${name}-input.jsonl"
stdout_file=\$(mktemp)
stderr_file=\$(mktemp)
set +e
printf '%s' "\$input" | bash "$cache_dir/scripts/\$script" >"\$stdout_file" 2>"\$stderr_file"
status=\$?
set -e
if [ -s "\$stdout_file" ]; then
  cat "\$stdout_file" >> "$PROJECT_DIR/.codex/\${name}-output.jsonl"
  cat "\$stdout_file"
fi
if [ -s "\$stderr_file" ]; then
  cat "\$stderr_file" >> "$PROJECT_DIR/.codex/\${name}-stderr.jsonl"
  cat "\$stderr_file" >&2
fi
rm -f "\$stdout_file" "\$stderr_file"
exit "\$status"
CONFIG
  chmod +x "$PROJECT_DIR/.codex/run-hook.sh"

  cat > "$PROJECT_DIR/.codex/hooks.json" <<CONFIG
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "apply_patch|local_shell|Edit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$PROJECT_DIR/.codex/run-hook.sh\" post-tool-use trunk-sync.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$PROJECT_DIR/.codex/run-hook.sh\" session-start trunk-sync-session-start.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$PROJECT_DIR/.codex/run-hook.sh\" stop trunk-sync-stop.sh"
          }
        ]
      }
    ]
  }
}
CONFIG
  {
    echo ".codex/"
    echo ".codex-home/"
  } >> "$PROJECT_DIR/.git/info/exclude"

  cat > "$CODEX_TEST_HOME/config.toml" <<'CONFIG'
model_reasoning_effort = "low"

[features]
hooks = true
plugin_hooks = true

[shell_environment_policy]
inherit = "all"

[plugins."trunk-sync@local-marketplace"]
enabled = true
CONFIG

  cat >> "$CODEX_TEST_HOME/config.toml" <<CONFIG

[projects."$PROJECT_DIR"]
trust_level = "trusted"

[projects."/private${PROJECT_DIR}"]
trust_level = "trusted"
CONFIG

  export CODEX_HOME="$CODEX_TEST_HOME"

  if [ ! -f "$CODEX_TEST_HOME/auth.json" ] && [ -z "${CODEX_API_KEY:-}" ]; then
    echo "Codex harness requires either ~/.codex/auth.json or CODEX_API_KEY" >&2
    exit 1
  fi
}

AGENT_CALL_COUNT=0

run_agent() { # prompt → stdout (stream-json), also appended to the transcript
  local prompt="$1"
  AGENT_CALL_COUNT=$((AGENT_CALL_COUNT + 1))

  if [ "$HARNESS" = "claude" ]; then
    ( cd "$PROJECT_DIR" && claude -p "$prompt" \
      --plugin-dir "$TS_ROOT" \
      --dangerously-skip-permissions \
      --model sonnet \
      --max-budget-usd 2.00 \
      --output-format stream-json \
      --verbose 2>&1 ) | tee -a "$TRANSCRIPT_FILE"
    return
  fi

  prime_codex_plugin
  if [ "$AGENT_CALL_COUNT" -eq 1 ]; then
    ( cd "$PROJECT_DIR" && codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      --dangerously-bypass-hook-trust \
      --skip-git-repo-check \
      --json \
      -m gpt-5.4-mini \
      -C "$PROJECT_DIR" \
      "$prompt" 2>&1 ) | tee -a "$TRANSCRIPT_FILE"
    append_codex_artifacts
    return
  fi

  ( cd "$PROJECT_DIR" && codex exec resume --last \
    --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust \
    --skip-git-repo-check \
    --json \
    -m gpt-5.4-mini \
    "$prompt" 2>&1 ) | tee -a "$TRANSCRIPT_FILE"
  append_codex_artifacts
}

assert_no_hook_runner_errors() {
  if grep -Eiq "hook .*failed|hook exited with code|command not found|exec: .*: not found" "$TRANSCRIPT_FILE"; then
    echo "Hook runner error found in $TRANSCRIPT_FILE:" >&2
    grep -Ein "hook .*failed|hook exited with code|command not found|exec: .*: not found" "$TRANSCRIPT_FILE" >&2
    exit 1
  fi
}

LAST="implemented the parser"
NEXT="wire the CLI and write tests"

echo "=== Agent A: edit + record progress (real $HARNESS) ==="
A_PROMPT="This project uses trunk-sync. At session start you were given your trunk-sync session id and the exact command to record progress. Do exactly: (1) create a file notes.txt containing the word hello using the Write tool; (2) then record your progress by running that exact command for YOUR session id with --last \"$LAST\" and --next \"$NEXT\". Finally print the exact command you ran."
run_agent "$A_PROMPT" >/dev/null

CARD="$(ls "$PROJECT_DIR"/.trunk-sync/timeclock/*.json 2>/dev/null | head -1 || true)"

echo "=== Agent B: fresh session — SessionStart should surface A's handover (real $HARNESS) ==="
B_PROMPT='At session start, trunk-sync may have shown you a TRUNK-SYNC HANDOVER from other sessions. Report verbatim every line you were shown that begins with "last:" or "next:". If you saw no handover, reply exactly NO HANDOVER.'
B_OUT="$(run_agent "$B_PROMPT")"

# --- Deterministic verification (no AI eval) ---
PASS=0; FAIL=0
check() { if eval "$2"; then echo "PASS - $1"; PASS=$((PASS+1)); else echo "FAIL - $1"; FAIL=$((FAIL+1)); fi; }

{
  echo "trunk-sync handover System test — deterministic verification"
  echo "timecard: ${CARD:-<none>}"
  echo ""
} > "$VERIFY_FILE"

check "A's real session clocked in (timecard exists)" '[ -n "$CARD" ]'
check "A recorded lastStep via bundled progress recorder"     'grep -q "$LAST" "${CARD:-/nonexistent}" 2>/dev/null'
check "A recorded remainingSteps via bundled progress recorder" 'grep -q "$NEXT" "${CARD:-/nonexistent}" 2>/dev/null'
check "B's real SessionStart injected A's last step"      'grep -q "$LAST" <<< "$B_OUT"'
check "B's real SessionStart injected A's remaining steps" 'grep -q "$NEXT" <<< "$B_OUT"'

assert_no_hook_runner_errors

{
  echo ""
  echo "$PASS passed, $FAIL failed"
} | tee -a "$VERIFY_FILE"

[ "$FAIL" -eq 0 ]
