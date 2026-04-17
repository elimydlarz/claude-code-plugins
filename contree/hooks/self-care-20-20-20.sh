#!/usr/bin/env bash
HEARTBEAT_DIR="${CONTREE_HEARTBEAT_DIR:-$HOME/.claude/contree/heartbeats}"
NUDGE_DIR="${CONTREE_NUDGE_DIR:-$HOME/.claude/contree/nudges/20-20-20}"
GAP_THRESHOLD=300
WINDOW=1200
PRUNE_AGE=3600

mkdir -p "$HEARTBEAT_DIR" 2>/dev/null || exit 0
NOW=$(date +%s)
touch "$HEARTBEAT_DIR/$NOW" 2>/dev/null || exit 0

prune_cutoff=$(( NOW - PRUNE_AGE ))
for ts in $(ls "$HEARTBEAT_DIR" 2>/dev/null); do
  if [ "$ts" -lt "$prune_cutoff" ] 2>/dev/null; then
    rm -f "$HEARTBEAT_DIR/$ts"
  fi
done

stretch_start=$NOW
prev=$NOW
for ts in $(ls "$HEARTBEAT_DIR" 2>/dev/null | sort -rn); do
  [ "$ts" = "$NOW" ] && continue
  gap=$(( prev - ts ))
  if [ "$gap" -gt "$GAP_THRESHOLD" ]; then
    break
  fi
  stretch_start=$ts
  prev=$ts
done

stretch=$(( NOW - stretch_start ))
if [ "$stretch" -lt "$WINDOW" ]; then
  exit 0
fi

last_nudge=$(ls "$NUDGE_DIR" 2>/dev/null | sort -rn | head -1)
if [ -n "$last_nudge" ] && [ "$(( NOW - last_nudge ))" -lt "$WINDOW" ]; then
  exit 0
fi

mkdir -p "$NUDGE_DIR" 2>/dev/null || exit 0
touch "$NUDGE_DIR/$NOW" 2>/dev/null || exit 0

MESSAGE='Before addressing the user’s request, mention the 20-20-20 rule: they have been at the keyboard for a while. Say something like: "Quick eye break: look at something 20 feet away for 20 seconds (20-20-20 rule)." Keep it brief, then continue with their request.'
jq -n --arg msg "$MESSAGE" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $msg}}'
exit 0
