#!/usr/bin/env bash
HEARTBEAT_DIR="${CONTREE_HEARTBEAT_DIR:-$HOME/.claude/contree/heartbeats}"

mkdir -p "$HEARTBEAT_DIR" 2>/dev/null || exit 0
touch "$HEARTBEAT_DIR/$(date +%s)" 2>/dev/null || exit 0

exit 0
