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
  echo "Usage: publish-contree.sh <patch|minor|major> --notes-file <path>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$NOTES_FILE" ]; then
  PREV=$(git -C "$REPO_ROOT" tag --list --sort=-v:refname 'contree-v*' | head -n1)
  echo "Release notes required. Pass --notes-file <path>." >&2
  echo "Review commits with: git log ${PREV:+$PREV..}HEAD -- contree/" >&2
  exit 1
fi

if [ ! -f "$NOTES_FILE" ]; then
  echo "Notes file not found: $NOTES_FILE" >&2
  exit 1
fi

cd "$REPO_ROOT/contree"

DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- 'contree/')
if [ -n "$DIRTY" ]; then
  echo "Uncommitted changes — commit or stash first:" >&2
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
ROLLBACK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/contree-release.XXXXXX")
trap 'rm -rf "$ROLLBACK_DIR"' EXIT
cp "$INDEX_PATH" "$ROLLBACK_DIR/index"
cp .claude-plugin/plugin.json "$ROLLBACK_DIR/claude-plugin.json"
cp .codex-plugin/plugin.json "$ROLLBACK_DIR/codex-plugin.json"

echo "==> Version bump ($BUMP)"
VERSION=$(node "$REPO_ROOT/scripts/bump-plugin-version.js" .claude-plugin/plugin.json .codex-plugin/plugin.json "$BUMP")

git -C "$REPO_ROOT" add contree/.claude-plugin/plugin.json contree/.codex-plugin/plugin.json
git -C "$REPO_ROOT" commit --only -m "contree v$VERSION" -- contree/.claude-plugin/plugin.json contree/.codex-plugin/plugin.json
RELEASE_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD)
git -C "$REPO_ROOT" tag -a "contree-v$VERSION" -m "contree v$VERSION"
if git -C "$REPO_ROOT" push --atomic origin "HEAD:$BRANCH" "refs/tags/contree-v$VERSION"; then
  :
else
  PUSH_STATUS=$?
  git -C "$REPO_ROOT" tag -d "contree-v$VERSION" >/dev/null
  git -C "$REPO_ROOT" update-ref "refs/heads/$BRANCH" "$PRE_RELEASE_HEAD" "$RELEASE_COMMIT"
  cp "$ROLLBACK_DIR/index" "$INDEX_PATH"
  cp "$ROLLBACK_DIR/claude-plugin.json" .claude-plugin/plugin.json
  cp "$ROLLBACK_DIR/codex-plugin.json" .codex-plugin/plugin.json
  exit "$PUSH_STATUS"
fi

echo "==> Create GitHub release"
gh release create "contree-v$VERSION" --title "contree v$VERSION" --notes-file "$NOTES_FILE"

echo ""
echo "==> Update marketplace and reinstall"
claude plugin marketplace update elimydlarz
claude plugin update contree@elimydlarz --scope user || claude plugin install contree@elimydlarz --scope user

echo ""
echo "published contree v$VERSION"
echo "  git: https://github.com/elimydlarz/claude-code-plugins"
