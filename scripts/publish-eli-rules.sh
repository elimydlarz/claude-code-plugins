#!/usr/bin/env bash
set -euo pipefail

BUMP="${1:-}"
if [[ ! "$BUMP" =~ ^(patch|minor|major)$ ]]; then
  echo "Usage: publish-eli-rules.sh <patch|minor|major>" >&2
  exit 1
fi
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT/eli-rules"

# Source changes must be committed
DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- 'eli-rules/')
if [ -n "$DIRTY" ]; then
  echo "Uncommitted changes — commit or stash first:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

# Test
echo "==> Test"
pnpm test

# Bump version
echo "==> Version bump ($BUMP)"
pnpm version "$BUMP" --no-git-tag-version

VERSION=$(node -p "require('./package.json').version")
git -C "$REPO_ROOT" add eli-rules/package.json
git -C "$REPO_ROOT" commit -m "eli-rules v$VERSION"
git -C "$REPO_ROOT" tag "eli-rules-v$VERSION"

# Publish to npm
echo "==> Publish to npm"
pnpm publish --no-git-checks

# Push commits + tag to GitHub
echo "==> Push to GitHub"
git -C "$REPO_ROOT" push origin main --follow-tags

echo ""
echo "published @susu-eng/eli-rules v$VERSION"
echo "  npm: https://www.npmjs.com/package/@susu-eng/eli-rules"
echo "  git: https://github.com/elimydlarz/claude-code-plugins"
