#!/usr/bin/env bash
set -euo pipefail

HARNESS="${1:?harness is required}"
[ "$HARNESS" = "claude" ] || { echo "unsupported harness: $HARNESS" >&2; exit 1; }

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
(
  cd "$PROJECT_DIR"
  claude -p \
    "Create agent-note.txt containing exactly claude. Use a file-editing tool. Do not run any git command." \
    --plugin-dir "$TRUNK_SYNC_ROOT" \
    --dangerously-skip-permissions \
    --model sonnet \
    --max-budget-usd 1.00 \
    --output-format stream-json \
    --verbose
) > "$TRANSCRIPT_FILE"

git -C "$PROJECT_DIR" fetch -q origin agents
COMMIT_BODY="$(git -C "$PROJECT_DIR" log -1 --format=%B origin/agents -- agent-note.txt)"

printf '%s\n' "Journey: agent-hook-compatibility"
printf '%s\n' "  when Claude Code uses the published plugin in a consumer repository"
printf '%s\n' "    when it edits a file after the rejection"
if printf '%s\n' "$COMMIT_BODY" | grep -q '^Session: ' && printf '%s\n' "$COMMIT_BODY" | grep -q '^Agent: claude$'; then
  printf '%s\n' "      and the commit records the Claude session and agent provenance"
else
  printf '%s\n' "      not ok - and the commit records the Claude session and agent provenance" >&2
  printf '%s\n' "$COMMIT_BODY" >&2
  exit 1
fi
