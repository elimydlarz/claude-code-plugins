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

cd "$REPO_ROOT/trunk-sync"

DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- 'trunk-sync/')
if [ -n "$DIRTY" ]; then
  echo "Uncommitted source changes — commit or stash first:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

echo "==> Version bump ($BUMP)"
VERSION=$(node scripts/bump-plugin-manifests.js "$BUMP")
git -C "$REPO_ROOT" add trunk-sync/.claude-plugin/plugin.json trunk-sync/.codex-plugin/plugin.json
git -C "$REPO_ROOT" commit -m "v$VERSION"
git -C "$REPO_ROOT" tag -a "v$VERSION" -m "trunk-sync v$VERSION"

echo "==> Create GitHub release"
gh release create "v$VERSION" --title "trunk-sync v$VERSION" --notes-file "$NOTES_FILE"

echo ""
echo "published trunk-sync v$VERSION"
echo "  git: https://github.com/elimydlarz/claude-code-plugins"
