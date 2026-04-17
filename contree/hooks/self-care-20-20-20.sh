#!/usr/bin/env bash
HEARTBEAT_DIR="${CONTREE_HEARTBEAT_DIR:-$HOME/.claude/contree/heartbeats}"

mkdir -p "$HEARTBEAT_DIR"
touch "$HEARTBEAT_DIR/$(date +%s)"

exit 0
