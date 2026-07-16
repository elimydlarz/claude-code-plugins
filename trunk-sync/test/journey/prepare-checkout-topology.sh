#!/usr/bin/env bash
set -euo pipefail

STATE_ROOT="/journey-state"
REMOTE_DIR="$STATE_ROOT/remote.git"
SEED_DIR="$STATE_ROOT/seed"

git init -q --bare "$REMOTE_DIR"
git init -q "$SEED_DIR"
git -C "$SEED_DIR" config user.email "test@example.com"
git -C "$SEED_DIR" config user.name "Test User"
printf 'seed\n' > "$SEED_DIR/seed.txt"
git -C "$SEED_DIR" add seed.txt
git -C "$SEED_DIR" commit -q -m seed
git -C "$SEED_DIR" remote add origin "$REMOTE_DIR"
git -C "$SEED_DIR" push -q origin HEAD

for project_dir in "$STATE_ROOT/consumer-claude" "$STATE_ROOT/consumer-codex"; do
  git clone -q "$REMOTE_DIR" "$project_dir"
  git -C "$project_dir" config user.email "test@example.com"
  git -C "$project_dir" config user.name "Test User"
done
