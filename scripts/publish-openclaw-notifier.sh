#!/usr/bin/env bash
set -euo pipefail

BUMP="${1:-}"
if [[ ! "$BUMP" =~ ^(patch|minor|major)$ ]]; then
  echo "Usage: publish-openclaw-notifier.sh <patch|minor|major>" >&2
  exit 1
fi
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT/openclaw-notifier"

# Source changes must be committed
DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- 'openclaw-notifier/')
if [ -n "$DIRTY" ]; then
  echo "Uncommitted changes — commit or stash first:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

# Bump version in plugin.json
echo "==> Version bump ($BUMP)"
VERSION=$(node "$REPO_ROOT/scripts/bump-plugin-version.js" .claude-plugin/plugin.json "$BUMP")

git -C "$REPO_ROOT" add openclaw-notifier/.claude-plugin/plugin.json
git -C "$REPO_ROOT" commit -m "openclaw-notifier v$VERSION"
git -C "$REPO_ROOT" tag "openclaw-notifier-v$VERSION"

# Push commits + tag to GitHub
echo "==> Push to GitHub"
git -C "$REPO_ROOT" push origin main --follow-tags

echo ""
echo "published openclaw-notifier v$VERSION"
echo "  git: https://github.com/elimydlarz/claude-code-plugins"
