#!/usr/bin/env bash
NUDGE_DIR="${CONTREE_NUDGE_DIR:-$HOME/.claude/contree/nudges/20-20-20}"
THRESHOLD=1200

INPUT=$(cat)

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

mkdir -p "$NUDGE_DIR" 2>/dev/null || exit 0

# Baseline: most recent nudge file (filename = unix timestamp), else session start
LATEST=$(ls -t "$NUDGE_DIR" 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
  BASELINE="$LATEST"
else
  START_STR=$(head -1 "$TRANSCRIPT" | jq -r '.timestamp // empty' 2>/dev/null)
  [ -z "$START_STR" ] && exit 0
  if date -j >/dev/null 2>&1; then
    BASELINE=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START_STR" +%s 2>/dev/null) || exit 0
  else
    BASELINE=$(date -d "$START_STR" +%s 2>/dev/null) || exit 0
  fi
fi

NOW=$(date +%s)
ELAPSED=$(( NOW - BASELINE ))

if [ "$ELAPSED" -ge "$THRESHOLD" ]; then
  touch "$NUDGE_DIR/$NOW"
  echo "Before addressing the user's request, mention the 20-20-20 rule: they have been at the keyboard for a while. Say something like: \"Quick eye break: look at something 20 feet away for 20 seconds (20-20-20 rule).\" Keep it brief, then continue with their request." >&2
  exit 2
fi

exit 0
