#!/usr/bin/env bash
set -euo pipefail

BUMP=""
NOTES_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    patch|minor|major) BUMP="$1"; shift ;;
    --notes-file) NOTES_FILE="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! "$BUMP" =~ ^(patch|minor|major)$ ]]; then
  echo "Usage: publish-trunk-sync.sh <patch|minor|major> --notes-file <path>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$NOTES_FILE" ]; then
  PREV=$(git -C "$REPO_ROOT" tag --list --sort=-v:refname 'v[0-9]*' | head -n1)
  echo "Release notes required. Pass --notes-file <path>." >&2
  echo "Review commits with: git log ${PREV:+$PREV..}HEAD -- trunk-sync/ ':!trunk-sync/dist/'" >&2
  exit 1
fi

if [ ! -f "$NOTES_FILE" ]; then
  echo "Notes file not found: $NOTES_FILE" >&2
  exit 1
fi

if [ ! -f "$REPO_ROOT/.env" ]; then
  echo ".env not found at repo root — create it with TRUNK_SYNC_PUBLISHER=..." >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
source "$REPO_ROOT/.env"
set +a

if [ -z "${TRUNK_SYNC_PUBLISHER:-}" ]; then
  echo "TRUNK_SYNC_PUBLISHER is not set in $REPO_ROOT/.env" >&2
  exit 1
fi

cd "$REPO_ROOT/trunk-sync"

# Source changes must be committed — dist/ staleness is handled below
DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- 'trunk-sync/' ':!trunk-sync/dist/')
if [ -n "$DIRTY" ]; then
  echo "Uncommitted source changes — commit or stash first:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

# Build and test
echo "==> Build"
pnpm run build

echo "==> Test (unit)"
pnpm test

echo "==> Test (e2e)"
pnpm run test:e2e

# Commit dist/ if the build produced changes
if [ -n "$(git -C "$REPO_ROOT" status --porcelain trunk-sync/dist/)" ]; then
  echo "==> Committing stale dist/"
  git -C "$REPO_ROOT" add trunk-sync/dist/
  git -C "$REPO_ROOT" commit -m "build: compile trunk-sync dist/"
fi

# Bump version — lifecycle script syncs plugin.json
echo "==> Version bump ($BUMP)"
pnpm version "$BUMP" --no-git-tag-version
node scripts/sync-plugin-version.js

VERSION=$(node -p "require('./package.json').version")
git -C "$REPO_ROOT" add trunk-sync/package.json trunk-sync/.claude-plugin/plugin.json trunk-sync/.codex-plugin/plugin.json
git -C "$REPO_ROOT" commit -m "v$VERSION"
git -C "$REPO_ROOT" tag -a "v$VERSION" -m "trunk-sync v$VERSION"

# Publish to npm — auth via TRUNK_SYNC_PUBLISHER, no OTP
echo "==> Publish to npm"
NPMRC="$REPO_ROOT/trunk-sync/.npmrc"
trap 'rm -f "$NPMRC"' EXIT
printf '//registry.npmjs.org/:_authToken=%s\n' "$TRUNK_SYNC_PUBLISHER" > "$NPMRC"
pnpm publish --no-git-checks

# Push commits + tag to GitHub
echo "==> Push to GitHub"
git -C "$REPO_ROOT" push origin main --follow-tags

echo "==> Create GitHub release"
gh release create "v$VERSION" --title "trunk-sync v$VERSION" --notes-file "$NOTES_FILE"

echo ""
echo "published @elimydlarz/trunk-sync v$VERSION"
echo "  npm: https://www.npmjs.com/package/@elimydlarz/trunk-sync"
echo "  git: https://github.com/elimydlarz/claude-code-plugins"
