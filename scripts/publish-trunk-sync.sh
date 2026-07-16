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

DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- 'trunk-sync/' ':(exclude)trunk-sync/dist/')
if [ -n "$DIRTY" ]; then
  echo "Uncommitted source changes — commit or stash first:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

BRANCH=$(git -C "$REPO_ROOT" branch --show-current)
if [ -z "$BRANCH" ]; then
  echo "A checked-out branch is required to publish." >&2
  exit 1
fi

PRE_RELEASE_HEAD=$(git -C "$REPO_ROOT" rev-parse HEAD)
GIT_DIR=$(git -C "$REPO_ROOT" rev-parse --absolute-git-dir)
INDEX_PATH="$GIT_DIR/index"
ROLLBACK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/trunk-sync-release.XXXXXX")
trap 'rm -rf "$ROLLBACK_DIR"' EXIT
cp "$INDEX_PATH" "$ROLLBACK_DIR/index"
cp .claude-plugin/plugin.json "$ROLLBACK_DIR/claude-plugin.json"
cp .codex-plugin/plugin.json "$ROLLBACK_DIR/codex-plugin.json"
DIST_EXISTED=0
if [ -d dist ]; then
  DIST_EXISTED=1
  mkdir "$ROLLBACK_DIR/dist"
  cp -a dist/. "$ROLLBACK_DIR/dist/"
fi

echo "==> Version bump ($BUMP)"
pnpm run build
VERSION=$(node scripts/bump-plugin-manifests.js "$BUMP")
git -C "$REPO_ROOT" add -A -- trunk-sync/dist trunk-sync/.claude-plugin/plugin.json trunk-sync/.codex-plugin/plugin.json
git -C "$REPO_ROOT" commit --only -m "v$VERSION" -- trunk-sync/dist trunk-sync/.claude-plugin/plugin.json trunk-sync/.codex-plugin/plugin.json
RELEASE_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD)
git -C "$REPO_ROOT" tag -a "v$VERSION" -m "trunk-sync v$VERSION"
if git -C "$REPO_ROOT" push --atomic origin "HEAD:$BRANCH" "refs/tags/v$VERSION"; then
  :
else
  PUSH_STATUS=$?
  git -C "$REPO_ROOT" tag -d "v$VERSION" >/dev/null
  git -C "$REPO_ROOT" update-ref "refs/heads/$BRANCH" "$PRE_RELEASE_HEAD" "$RELEASE_COMMIT"
  cp "$ROLLBACK_DIR/index" "$INDEX_PATH"
  cp "$ROLLBACK_DIR/claude-plugin.json" .claude-plugin/plugin.json
  cp "$ROLLBACK_DIR/codex-plugin.json" .codex-plugin/plugin.json
  rm -rf "$REPO_ROOT/trunk-sync/dist"
  if [ "$DIST_EXISTED" -eq 1 ]; then
    mkdir "$REPO_ROOT/trunk-sync/dist"
    cp -a "$ROLLBACK_DIR/dist/." "$REPO_ROOT/trunk-sync/dist/"
  fi
  exit "$PUSH_STATUS"
fi

echo "==> Create GitHub release"
gh release create "v$VERSION" --title "trunk-sync v$VERSION" --notes-file "$NOTES_FILE"

echo ""
echo "published trunk-sync v$VERSION"
echo "  git: https://github.com/elimydlarz/claude-code-plugins"
