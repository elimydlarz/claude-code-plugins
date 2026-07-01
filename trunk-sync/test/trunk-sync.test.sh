#!/bin/bash
set -euo pipefail

# Test suite for trunk-sync.sh PostToolUse hook.
# Uses git worktrees (not separate clones) to simulate multi-agent scenarios.
# Output: TAP (Test Anything Protocol)

HOOK="$(cd "$(dirname "$0")/../scripts" && pwd)/trunk-sync.sh"
HOOKS_JSON="$(cd "$(dirname "$0")/../hooks" && pwd)/hooks.json"
PASS=0
FAIL=0
TEST_NUM=0

# ── Helpers ──────────────────────────────────────────────────────────────────

make_input() {
  local file_path="${1:-}" session_id="${2:-}" tool_name="${3:-Edit}" transcript_path="${4:-}"
  jq -n \
    --arg fp "$file_path" \
    --arg sid "$session_id" \
    --arg tn "$tool_name" \
    --arg tp "$transcript_path" \
    '{tool_input:{file_path:$fp}, session_id:$sid, tool_name:$tn, transcript_path:$tp}'
}

create_transcript() {
  local path="$1" message="$2"
  jq -cn --arg msg "$message" '{type:"user", message:{role:"user", content:$msg}}' > "$path"
}

throttle_path() { echo "${TMPDIR:-/tmp}/trunk-sync-clockin-$1"; }

# Mark a session as having already clocked in, so the first-clock-in WIP nudge
# (run-the-tests / resume-WIP, exit 2) does not fire in tests that aren't about it.
seed_clockin() { [[ -n "$1" ]] || return 0; printf '%s' "$(( $(date +%s) * 1000 ))" > "$(throttle_path "$1")"; }
clear_clockin() { [[ -n "$1" ]] || return 0; rm -f "$(throttle_path "$1")"; }

run_hook() {
  local input="$1"
  HOOK_EXIT=0
  HOOK_STDERR=""
  # Default: a returning agent (already clocked in), so existing assertions hold.
  seed_clockin "$(printf '%s' "$input" | jq -r '.session_id // ""')"
  local stderr_file="$TMPDIR_BASE/stderr"
  printf '%s' "$input" | bash "$HOOK" >/dev/null 2>"$stderr_file" || HOOK_EXIT=$?
  HOOK_STDERR=$(cat "$stderr_file")
}

# Like run_hook, but as the session's very first clock-in (WIP nudge may fire).
run_hook_first_clockin() {
  local input="$1"
  HOOK_EXIT=0
  HOOK_STDERR=""
  clear_clockin "$(printf '%s' "$input" | jq -r '.session_id // ""')"
  local stderr_file="$TMPDIR_BASE/stderr"
  printf '%s' "$input" | bash "$HOOK" >/dev/null 2>"$stderr_file" || HOOK_EXIT=$?
  HOOK_STDERR=$(cat "$stderr_file")
}

assert_exit() {
  local expected="$1" label="$2"
  TEST_NUM=$((TEST_NUM + 1))
  if [[ "$HOOK_EXIT" -eq "$expected" ]]; then
    echo "ok $TEST_NUM - $label"
    PASS=$((PASS + 1))
  else
    echo "not ok $TEST_NUM - $label"
    echo "  # expected exit $expected, got $HOOK_EXIT"
    [[ -n "$HOOK_STDERR" ]] && echo "  # stderr: $(head -1 <<< "$HOOK_STDERR")"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  TEST_NUM=$((TEST_NUM + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "ok $TEST_NUM - $label"
    PASS=$((PASS + 1))
  else
    echo "not ok $TEST_NUM - $label"
    echo "  # expected to contain: $needle"
    echo "  # actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  TEST_NUM=$((TEST_NUM + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "ok $TEST_NUM - $label"
    PASS=$((PASS + 1))
  else
    echo "not ok $TEST_NUM - $label"
    echo "  # expected NOT to contain: $needle"
    echo "  # actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_equals() {
  local expected="$1" actual="$2" label="$3"
  TEST_NUM=$((TEST_NUM + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "ok $TEST_NUM - $label"
    PASS=$((PASS + 1))
  else
    echo "not ok $TEST_NUM - $label"
    echo "  # expected: $expected"
    echo "  # actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

commit_count() {
  git -C "$1" rev-list --count HEAD
}

last_subject() {
  git -C "$1" log -1 --format='%s'
}

last_body() {
  git -C "$1" log -1 --format='%b'
}

# ── Setup ────────────────────────────────────────────────────────────────────

TMPDIR_BASE=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# Isolate clock-in throttle files to this run's temp dir (the hook reads $TMPDIR).
export TMPDIR="$TMPDIR_BASE"

setup_repos() {
  cd "$TMPDIR_BASE"
  rm -rf "$TMPDIR_BASE/remote.git" "$TMPDIR_BASE/project" "$TMPDIR_BASE/wt-a" "$TMPDIR_BASE/wt-b"

  # Bare "remote" repo
  REMOTE="$TMPDIR_BASE/remote.git"
  git init --bare "$REMOTE" -b main >/dev/null 2>&1

  # Main project clone (not where agents work — just the base repo)
  PROJECT="$TMPDIR_BASE/project"
  git clone "$REMOTE" "$PROJECT" >/dev/null 2>&1
  git -C "$PROJECT" config user.email "test@test.com"
  git -C "$PROJECT" config user.name "Test"

  # Seed commit so HEAD exists
  echo "seed" > "$PROJECT/seed.txt"
  git -C "$PROJECT" add seed.txt
  git -C "$PROJECT" commit -m "seed" >/dev/null 2>&1
  git -C "$PROJECT" push origin main >/dev/null 2>&1

  # This suite's fixtures assume "main" as the sync target throughout — pin it
  # via .trunk-sync/config rather than relying on the "agents" default, and do
  # so before worktrees are created so both check the file out.
  mkdir -p "$PROJECT/.trunk-sync"
  echo "target-branch=main" > "$PROJECT/.trunk-sync/config"
  git -C "$PROJECT" add .trunk-sync/config
  git -C "$PROJECT" commit -m "config: target-branch=main" >/dev/null 2>&1
  git -C "$PROJECT" push origin main >/dev/null 2>&1

  # Worktree A — agent A's isolated working directory
  WT_A="$TMPDIR_BASE/wt-a"
  git -C "$PROJECT" worktree add "$WT_A" -b trunk-sync/agent-a origin/main >/dev/null 2>&1
  git -C "$WT_A" config user.email "agent-a@test.com"
  git -C "$WT_A" config user.name "Agent A"

  # Worktree B — agent B's isolated working directory
  WT_B="$TMPDIR_BASE/wt-b"
  git -C "$PROJECT" worktree add "$WT_B" -b trunk-sync/agent-b origin/main >/dev/null 2>&1
  git -C "$WT_B" config user.email "agent-b@test.com"
  git -C "$WT_B" config user.name "Agent B"
}

setup_repos

# ── Tests ────────────────────────────────────────────────────────────────────

# --- Early exits ---

# 1. Empty file_path → exit 0, no commit
BEFORE=$(commit_count "$WT_A")
cd "$WT_A"
run_hook "$(make_input "" "" "Edit" "")"
assert_exit 0 "empty file_path exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$BEFORE" "$AFTER" "empty file_path creates no commit"

# 2. Not in a git repo → exit 0
NOT_GIT="$TMPDIR_BASE/not-a-repo"
mkdir -p "$NOT_GIT"
echo "hello" > "$NOT_GIT/file.txt"
cd "$NOT_GIT"
run_hook "$(make_input "$NOT_GIT/file.txt" "" "Edit" "")"
assert_exit 0 "not in a git repo exits 0"

# 3. No remote → commits locally, exits 0, does not attempt push
NO_REMOTE="$TMPDIR_BASE/no-remote"
git init "$NO_REMOTE" -b main >/dev/null 2>&1
git -C "$NO_REMOTE" config user.email "test@test.com"
git -C "$NO_REMOTE" config user.name "Test"
echo "seed" > "$NO_REMOTE/seed.txt"
git -C "$NO_REMOTE" add seed.txt
git -C "$NO_REMOTE" commit -m "seed" >/dev/null 2>&1

echo "edited" > "$NO_REMOTE/seed.txt"
cd "$NO_REMOTE"
run_hook "$(make_input "$NO_REMOTE/seed.txt" "no-remote-sess" "Edit" "")"
assert_exit 0 "no remote exits 0"
SUBJECT=$(last_subject "$NO_REMOTE")
assert_contains "$SUBJECT" "auto(no-remot" "no remote still commits locally"
NR_COUNT=$(commit_count "$NO_REMOTE")
assert_equals "2" "$NR_COUNT" "no remote created exactly one new commit"

# 4. File outside repo → exit 0, no commit
OUTSIDE="$TMPDIR_BASE/outside.txt"
echo "outside" > "$OUTSIDE"
cd "$WT_A"
BEFORE=$(commit_count "$WT_A")
run_hook "$(make_input "$OUTSIDE" "" "Edit" "")"
assert_exit 0 "file outside repo exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$BEFORE" "$AFTER" "file outside repo creates no commit"

# 4. Gitignored file → exit 0, no commit
echo "*.log" > "$WT_A/.gitignore"
cd "$WT_A"
git add .gitignore
git commit -m "add gitignore" >/dev/null 2>&1
git push origin HEAD:main >/dev/null 2>&1
echo "debug output" > "$WT_A/debug.log"
BEFORE=$(commit_count "$WT_A")
run_hook "$(make_input "$WT_A/debug.log" "" "Edit" "")"
assert_exit 0 "gitignored file exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$BEFORE" "$AFTER" "gitignored file creates no commit"

# --- Merge conflict path ---

# 5. MERGE_HEAD present + all conflicts resolved → commit with merge message
setup_repos

# Agent A commits and pushes via the hook
echo "line from A" > "$WT_A/conflict.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/conflict.txt" "" "Edit" "")"

# Agent B makes a conflicting change — first pull A's change, then diverge
git -C "$WT_B" pull origin main --no-rebase >/dev/null 2>&1
echo "line from B" > "$WT_B/conflict.txt"
cd "$WT_B"
git -C "$WT_B" add conflict.txt
git -C "$WT_B" commit -m "B's version" >/dev/null 2>&1
git -C "$WT_B" push origin HEAD:main >/dev/null 2>&1

# Now agent A edits the same file — pull will conflict
echo "A's updated line" > "$WT_A/conflict.txt"
cd "$WT_A"
git -C "$WT_A" add conflict.txt
git -C "$WT_A" commit -m "A updates" >/dev/null 2>&1
git -C "$WT_A" pull origin main --no-rebase >/dev/null 2>&1 || true

# Resolve the conflict
echo "resolved content" > "$WT_A/conflict.txt"
git -C "$WT_A" add conflict.txt

run_hook "$(make_input "$WT_A/conflict.txt" "abc12345session" "Edit" "")"
assert_exit 0 "merge conflict resolved exits 0"
SUBJECT=$(last_subject "$WT_A")
assert_contains "$SUBJECT" "resolve merge conflict" "merge commit subject contains resolve merge conflict"

# 6. MERGE_HEAD present + unresolved files remain → git commit refuses
setup_repos

# Agent A creates two files and pushes
echo "a1" > "$WT_A/file1.txt"
echo "a2" > "$WT_A/file2.txt"
cd "$WT_A"
git -C "$WT_A" add file1.txt file2.txt
git -C "$WT_A" commit -m "A's files" >/dev/null 2>&1
git -C "$WT_A" push origin HEAD:main >/dev/null 2>&1

# Agent B pulls, modifies both, pushes
git -C "$WT_B" pull origin main --no-rebase >/dev/null 2>&1
echo "b1" > "$WT_B/file1.txt"
echo "b2" > "$WT_B/file2.txt"
git -C "$WT_B" add file1.txt file2.txt
git -C "$WT_B" commit -m "B's files" >/dev/null 2>&1
git -C "$WT_B" push origin HEAD:main >/dev/null 2>&1

# Agent A diverges on both files
echo "a1-v2" > "$WT_A/file1.txt"
echo "a2-v2" > "$WT_A/file2.txt"
git -C "$WT_A" add file1.txt file2.txt
git -C "$WT_A" commit -m "A updates both" >/dev/null 2>&1
git -C "$WT_A" pull origin main --no-rebase >/dev/null 2>&1 || true

# Resolve only file1, leave file2 with markers
echo "resolved file1" > "$WT_A/file1.txt"
git -C "$WT_A" add file1.txt

cd "$WT_A"
run_hook "$(make_input "$WT_A/file1.txt" "" "Edit" "")"
assert_exit 128 "partial merge resolution exits 128 — git refuses commit with unresolved paths"

# --- Normal commit path ---

# 7. No changes → exit 0, no new commit
setup_repos
cd "$WT_A"
BEFORE=$(commit_count "$WT_A")
run_hook "$(make_input "$WT_A/seed.txt" "" "Edit" "")"
assert_exit 0 "no changes exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$BEFORE" "$AFTER" "no changes creates no commit"

# 8. Commit with session_id → subject includes truncated session prefix
setup_repos
echo "modified" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "abcdef1234567890" "Edit" "")"
assert_exit 0 "commit with session_id exits 0"
SUBJECT=$(last_subject "$WT_A")
assert_equals "auto(abcdef12): edit seed.txt" "$SUBJECT" "subject has session prefix and action"

# 9. Commit without session_id → subject has no parenthesized prefix
setup_repos
echo "modified" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "" "Edit" "")"
assert_exit 0 "commit without session_id exits 0"
SUBJECT=$(last_subject "$WT_A")
assert_equals "auto: edit seed.txt" "$SUBJECT" "subject without session_id"

# 9b. First clock-in of a session → exit 2 nudging the agent to run the tests and resume WIP
setup_repos
echo "modified" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook_first_clockin "$(make_input "$WT_A/seed.txt" "firstclockin1" "Edit" "")"
assert_exit 2 "first clock-in exits 2 with WIP nudge"
assert_contains "$HOOK_STDERR" "TRUNK-SYNC WIP" "first clock-in mentions WIP"
assert_contains "$HOOK_STDERR" "Run the test suite" "first clock-in tells agent to run the tests"
assert_contains "$HOOK_STDERR" "resume" "first clock-in tells agent to resume WIP"

# 9c. Second edit of the same session → throttled, no WIP nudge, exit 0
echo "again" > "$WT_A/seed.txt"
run_hook "$(make_input "$WT_A/seed.txt" "firstclockin1" "Edit" "")"
assert_exit 0 "subsequent clock-in exits 0"
assert_not_contains "$HOOK_STDERR" "TRUNK-SYNC WIP" "subsequent clock-in omits the WIP nudge"

# 10. Tool name lowercased
setup_repos
echo "modified" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "" "Write" "")"
SUBJECT=$(last_subject "$WT_A")
assert_contains "$SUBJECT" "write" "tool name lowercased in subject"

# 11. Transcript task goes into subject, File into body
setup_repos
TRANSCRIPT="$TMPDIR_BASE/transcript.jsonl"
create_transcript "$TRANSCRIPT" "Implement the login page"
echo "modified" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "sess1234" "Edit" "$TRANSCRIPT")"
SUBJECT=$(last_subject "$WT_A")
assert_contains "$SUBJECT" "Implement the login page" "subject contains task from transcript"

# 12. Body includes File and Session lines (no Transcript — path is derived)
BODY=$(last_body "$WT_A")
assert_contains "$BODY" "File: seed.txt" "body contains File line when task in subject"
assert_contains "$BODY" "Session: sess1234" "body contains Session line"
assert_not_contains "$BODY" "Transcript:" "body does not contain Transcript line"

# 13. No File line when transcript missing — body has Session only, no blank lines
setup_repos
echo "modified" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "sess5678" "Edit" "")"
BODY=$(last_body "$WT_A")
assert_contains "$BODY" "Session: sess5678" "body contains Session without transcript"
assert_not_contains "$BODY" "File:" "no File line when transcript missing"
FIRST_LINE=$(head -1 <<< "$BODY")
assert_equals "Session: sess5678" "$FIRST_LINE" "no blank lines before Session"

# --- Sync path (worktree-to-worktree via origin/main) ---

# 14. Clean sync — push to origin/main succeeds from worktree branch
setup_repos
echo "new content" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "sync1234" "Edit" "")"
assert_exit 0 "clean sync exits 0"
REMOTE_COUNT=$(git -C "$REMOTE" rev-list --count main)
LOCAL_COUNT=$(commit_count "$WT_A")
assert_equals "$LOCAL_COUNT" "$REMOTE_COUNT" "commit reached remote"

# 15. Agent B's change is visible to agent A after sync
setup_repos
echo "B wrote this" > "$WT_B/new-file.txt"
cd "$WT_B"
run_hook "$(make_input "$WT_B/new-file.txt" "agent-b" "Write" "")"
assert_exit 0 "agent B sync exits 0"

# Agent A edits something — the pull should bring in B's file
echo "A edited seed" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "agent-a" "Edit" "")"
assert_exit 0 "agent A sync exits 0"
# B's file should now exist in A's worktree
TEST_NUM=$((TEST_NUM + 1))
if [[ -f "$WT_A/new-file.txt" ]]; then
  echo "ok $TEST_NUM - agent B's file visible in agent A's worktree after sync"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - agent B's file visible in agent A's worktree after sync"
  FAIL=$((FAIL + 1))
fi

# 16. Pull conflict — both agents modify same file
setup_repos
# Agent B writes and syncs first
echo "B was here" > "$WT_B/seed.txt"
cd "$WT_B"
run_hook "$(make_input "$WT_B/seed.txt" "" "Edit" "")"

# Agent A modifies same file (will conflict on pull)
echo "A was here" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "" "Edit" "")"
assert_exit 2 "pull conflict exits 2"
assert_contains "$HOOK_STDERR" "TRUNK-SYNC CONFLICT" "stderr contains TRUNK-SYNC CONFLICT"

# 17. Push retry — agents modify different files, push fails then retries
setup_repos
# Agent B pushes a different file
echo "B's file" > "$WT_B/other.txt"
cd "$WT_B"
run_hook "$(make_input "$WT_B/other.txt" "" "Edit" "")"

# Agent A modifies a different file — push fails (behind), pull merges cleanly, retry succeeds
echo "A modifies seed" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "" "Edit" "")"
assert_exit 0 "push retry succeeds after non-conflicting pull"
REMOTE_LOG=$(git -C "$REMOTE" log --oneline main)
assert_contains "$REMOTE_LOG" "auto:" "remote has agent commits"

# 18. Both worktrees converge — after sync, both have the same files
CONTENT_A=$(cat "$WT_A/other.txt")
assert_equals "B's file" "$CONTENT_A" "agent A has agent B's file content after sync"

# --- Local main sync ---

# 19. Local main is fast-forwarded after worktree push
setup_repos
echo "from worktree" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "" "Edit" "")"
assert_exit 0 "worktree push exits 0"
# PROJECT has main checked out — hook should have fast-forwarded it
PROJECT_CONTENT=$(cat "$PROJECT/seed.txt")
assert_equals "from worktree" "$PROJECT_CONTENT" "local main working tree updated after worktree push"

# 20. Local main tracks multiple agents — B pushes, main updates, A pushes, main updates again
setup_repos
echo "B first" > "$WT_B/seed.txt"
cd "$WT_B"
run_hook "$(make_input "$WT_B/seed.txt" "" "Edit" "")"
PROJECT_CONTENT=$(cat "$PROJECT/seed.txt")
assert_equals "B first" "$PROJECT_CONTENT" "local main has B's content"

echo "A second" > "$WT_A/newfile.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/newfile.txt" "" "Write" "")"
TEST_NUM=$((TEST_NUM + 1))
if [[ -f "$PROJECT/newfile.txt" ]]; then
  echo "ok $TEST_NUM - local main has A's new file after A pushes"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - local main has A's new file after A pushes"
  FAIL=$((FAIL + 1))
fi

# 21. Local commits on main are incorporated — user commits on main, agent picks them up
setup_repos
# User commits directly on main in the project
echo "user's local work" > "$PROJECT/user-file.txt"
git -C "$PROJECT" add user-file.txt
git -C "$PROJECT" commit -m "user commit on main" >/dev/null 2>&1
# This commit is NOT on origin — only on local main

# Agent edits in worktree — the hook should merge local main, push everything
echo "agent work" > "$WT_A/agent-file.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/agent-file.txt" "" "Write" "")"
assert_exit 0 "agent push exits 0 with local-only commits on main"

# User's file should now be on origin (the hook pushed it along)
REMOTE_FILES=$(git -C "$REMOTE" ls-tree --name-only -r main)
assert_contains "$REMOTE_FILES" "user-file.txt" "user's local commit reached origin via agent push"

# Local main should be up to date (ff worked because we merged main before pushing)
PROJECT_FILES=$(ls "$PROJECT")
assert_contains "$PROJECT_FILES" "agent-file.txt" "local main has agent's file after sync"

# --- File deletion sync ---

# 22. Single file deletion — Bash with no file_path stages and commits the deletion
setup_repos
echo "to be deleted" > "$WT_A/doomed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/doomed.txt" "" "Write" "")"
assert_exit 0 "create file for deletion test"

# Delete the file (simulating agent running rm via Bash)
rm "$WT_A/doomed.txt"
BEFORE=$(commit_count "$WT_A")
run_hook "$(make_input "" "del-sess1" "Bash" "")"
assert_exit 0 "deletion sync exits 0"
AFTER=$(commit_count "$WT_A")
TEST_NUM=$((TEST_NUM + 1))
if [[ "$AFTER" -gt "$BEFORE" ]]; then
  echo "ok $TEST_NUM - deletion created a commit"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - deletion created a commit"
  FAIL=$((FAIL + 1))
fi
SUBJECT=$(last_subject "$WT_A")
assert_contains "$SUBJECT" "delete" "deletion commit subject contains delete"
assert_contains "$SUBJECT" "doomed.txt" "deletion commit subject contains filename"

# File should be gone from remote too
REMOTE_FILES=$(git -C "$REMOTE" ls-tree --name-only -r main)
assert_not_contains "$REMOTE_FILES" "doomed.txt" "deleted file removed from remote"

# 23. Multiple file deletion — commit message summarizes count
setup_repos
echo "a" > "$WT_A/del1.txt"
echo "b" > "$WT_A/del2.txt"
echo "c" > "$WT_A/del3.txt"
cd "$WT_A"
git -C "$WT_A" add del1.txt del2.txt del3.txt
git -C "$WT_A" commit -m "add files to delete" >/dev/null 2>&1
git -C "$WT_A" push origin HEAD:main >/dev/null 2>&1

rm "$WT_A/del1.txt" "$WT_A/del2.txt" "$WT_A/del3.txt"
run_hook "$(make_input "" "" "Bash" "")"
assert_exit 0 "multi-deletion sync exits 0"
SUBJECT=$(last_subject "$WT_A")
assert_contains "$SUBJECT" "delete" "multi-deletion subject contains delete"
assert_contains "$SUBJECT" "+2 more" "multi-deletion subject shows count of additional files"

# 24. No deletions — Bash with no file_path and no deleted files exits 0, no commit
setup_repos
cd "$WT_A"
BEFORE=$(commit_count "$WT_A")
run_hook "$(make_input "" "" "Bash" "")"
assert_exit 0 "no deletions exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$BEFORE" "$AFTER" "no deletions creates no commit"

# 25. Deletion syncs to other agent — agent B sees file removed after sync
setup_repos
echo "shared file" > "$WT_A/shared.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/shared.txt" "" "Write" "")"

# Agent B pulls to get the file
cd "$WT_B"
echo "trigger" > "$WT_B/trigger.txt"
run_hook "$(make_input "$WT_B/trigger.txt" "" "Write" "")"
TEST_NUM=$((TEST_NUM + 1))
if [[ -f "$WT_B/shared.txt" ]]; then
  echo "ok $TEST_NUM - agent B has shared file before deletion"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - agent B has shared file before deletion"
  FAIL=$((FAIL + 1))
fi

# Agent A deletes it
rm "$WT_A/shared.txt"
cd "$WT_A"
run_hook "$(make_input "" "" "Bash" "")"
assert_exit 0 "deletion by A exits 0"

# Agent B edits something — pull should bring in the deletion
echo "more work" > "$WT_B/trigger.txt"
cd "$WT_B"
run_hook "$(make_input "$WT_B/trigger.txt" "" "Edit" "")"
TEST_NUM=$((TEST_NUM + 1))
if [[ ! -f "$WT_B/shared.txt" ]]; then
  echo "ok $TEST_NUM - agent B no longer has deleted file after sync"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - agent B no longer has deleted file after sync"
  FAIL=$((FAIL + 1))
fi

# --- Concurrent push race ---

# 26. Concurrent push — two worktrees push different files simultaneously,
#     at least one needs to retry; both succeed
setup_repos

# Agent A and B each create different files
echo "A's content" > "$WT_A/a-file.txt"
echo "B's content" > "$WT_B/b-file.txt"

# Returning agents — isolate this test from the first-clock-in WIP nudge
seed_clockin race-a
seed_clockin race-b

# Run both hooks concurrently — they race to push to origin/main
cd "$WT_A"
HOOK_EXIT_A=0
STDERR_A=""
STDERR_FILE_A="$TMPDIR_BASE/stderr-race-a"
(printf '%s' "$(make_input "$WT_A/a-file.txt" "race-a" "Write" "")" | bash "$HOOK" >/dev/null 2>"$STDERR_FILE_A") &
PID_A=$!

cd "$WT_B"
HOOK_EXIT_B=0
STDERR_B=""
STDERR_FILE_B="$TMPDIR_BASE/stderr-race-b"
(printf '%s' "$(make_input "$WT_B/b-file.txt" "race-b" "Write" "")" | bash "$HOOK" >/dev/null 2>"$STDERR_FILE_B") &
PID_B=$!

wait $PID_A || HOOK_EXIT_A=$?
wait $PID_B || HOOK_EXIT_B=$?
STDERR_A=$(cat "$STDERR_FILE_A")
STDERR_B=$(cat "$STDERR_FILE_B")

# Both must succeed (push retry handles the race)
TEST_NUM=$((TEST_NUM + 1))
if [[ "$HOOK_EXIT_A" -eq 0 && "$HOOK_EXIT_B" -eq 0 ]]; then
  echo "ok $TEST_NUM - concurrent push: both agents succeed"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - concurrent push: both agents succeed"
  echo "  # agent A exit=$HOOK_EXIT_A, agent B exit=$HOOK_EXIT_B"
  [[ -n "$STDERR_A" ]] && echo "  # agent A stderr: $(head -1 <<< "$STDERR_A")"
  [[ -n "$STDERR_B" ]] && echo "  # agent B stderr: $(head -1 <<< "$STDERR_B")"
  FAIL=$((FAIL + 1))
fi

# Both files should be on the remote
REMOTE_FILES=$(git -C "$REMOTE" ls-tree --name-only -r main)
assert_contains "$REMOTE_FILES" "a-file.txt" "concurrent push: agent A's file on remote"
assert_contains "$REMOTE_FILES" "b-file.txt" "concurrent push: agent B's file on remote"

# The agent that retried will have pulled the other's file.
# The first-pusher won't have the other's file yet (no pull after its own push).
# Verify at least one worktree has the other's file (the retrier).
TEST_NUM=$((TEST_NUM + 1))
if [[ -f "$WT_A/b-file.txt" ]] || [[ -f "$WT_B/a-file.txt" ]]; then
  echo "ok $TEST_NUM - concurrent push: retrier pulled the other agent's file"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - concurrent push: retrier pulled the other agent's file"
  echo "  # WT_A has b-file.txt: $(test -f "$WT_A/b-file.txt" && echo yes || echo no)"
  echo "  # WT_B has a-file.txt: $(test -f "$WT_B/a-file.txt" && echo yes || echo no)"
  FAIL=$((FAIL + 1))
fi

# 27. Concurrent push conflict — two worktrees edit the same file simultaneously,
#     one succeeds, the other gets a conflict (exit 2)
setup_repos

echo "A's version" > "$WT_A/seed.txt"
echo "B's version" > "$WT_B/seed.txt"

# Returning agents — isolate this test from the first-clock-in WIP nudge
seed_clockin conf-a
seed_clockin conf-b

cd "$WT_A"
HOOK_EXIT_A=0
STDERR_FILE_A="$TMPDIR_BASE/stderr-conflict-a"
(printf '%s' "$(make_input "$WT_A/seed.txt" "conf-a" "Edit" "")" | bash "$HOOK" >/dev/null 2>"$STDERR_FILE_A") &
PID_A=$!

cd "$WT_B"
HOOK_EXIT_B=0
STDERR_FILE_B="$TMPDIR_BASE/stderr-conflict-b"
(printf '%s' "$(make_input "$WT_B/seed.txt" "conf-b" "Edit" "")" | bash "$HOOK" >/dev/null 2>"$STDERR_FILE_B") &
PID_B=$!

wait $PID_A || HOOK_EXIT_A=$?
wait $PID_B || HOOK_EXIT_B=$?
STDERR_A=$(cat "$STDERR_FILE_A")
STDERR_B=$(cat "$STDERR_FILE_B")

# Exactly one should succeed (0) and one should conflict (2)
TEST_NUM=$((TEST_NUM + 1))
EXITS_SORTED=$(printf '%s\n%s' "$HOOK_EXIT_A" "$HOOK_EXIT_B" | sort -n | tr '\n' ',')
if [[ "$EXITS_SORTED" == "0,2," ]]; then
  echo "ok $TEST_NUM - concurrent conflict: one succeeds, one conflicts"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - concurrent conflict: one succeeds, one conflicts"
  echo "  # exits: A=$HOOK_EXIT_A B=$HOOK_EXIT_B (expected one 0, one 2)"
  FAIL=$((FAIL + 1))
fi

# The failing agent should get TRUNK-SYNC CONFLICT feedback
CONFLICT_STDERR=""
if [[ "$HOOK_EXIT_A" -eq 2 ]]; then CONFLICT_STDERR="$STDERR_A"; fi
if [[ "$HOOK_EXIT_B" -eq 2 ]]; then CONFLICT_STDERR="$STDERR_B"; fi
assert_contains "$CONFLICT_STDERR" "TRUNK-SYNC CONFLICT" "concurrent conflict: loser gets conflict message"

# --- Git-block (PreToolUse) ---

# Extract the PreToolUse command from hooks.json so we test the real hook logic
GIT_BLOCK_CMD=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")

make_bash_input() {
  local cmd="$1"
  jq -n --arg c "$cmd" '{tool_input:{command:$c}}'
}

run_git_block() {
  local input="$1"
  HOOK_EXIT=0
  HOOK_STDERR=""
  local stderr_file="$TMPDIR_BASE/stderr-gitblock"
  printf '%s' "$input" | bash -c "$GIT_BLOCK_CMD" >/dev/null 2>"$stderr_file" || HOOK_EXIT=$?
  HOOK_STDERR=$(cat "$stderr_file")
}

# 28b. git clone is allowed
run_git_block "$(make_bash_input "git clone https://github.com/foo/bar")"
assert_exit 0 "git-block: git clone is allowed"

# 28c. git diff is allowed
run_git_block "$(make_bash_input "git diff")"
assert_exit 0 "git-block: git diff is allowed"

# 28d. git diff with args is allowed
run_git_block "$(make_bash_input "git diff --stat origin/main")"
assert_exit 0 "git-block: git diff --stat is allowed"

# 28e. git log is allowed
run_git_block "$(make_bash_input "git log")"
assert_exit 0 "git-block: git log is allowed"

# 28f. git log with args is allowed
run_git_block "$(make_bash_input "git log --oneline -10")"
assert_exit 0 "git-block: git log --oneline is allowed"

# 28f2. git show is allowed
run_git_block "$(make_bash_input "git show HEAD")"
assert_exit 0 "git-block: git show is allowed"

# 28g. git push is blocked
run_git_block "$(make_bash_input "git push origin main")"
assert_exit 2 "git-block: git push is blocked"
assert_contains "$HOOK_STDERR" "TRUNK-SYNC" "git-block: push gets TRUNK-SYNC feedback"

# 28h. git commit is blocked
run_git_block "$(make_bash_input "git commit -m 'manual'")"
assert_exit 2 "git-block: git commit is blocked"

# 28i. git add is blocked
run_git_block "$(make_bash_input "git add .")"
assert_exit 2 "git-block: git add is blocked"

# 28j. git checkout is blocked
run_git_block "$(make_bash_input "git checkout main")"
assert_exit 2 "git-block: git checkout is blocked"

# 28k. git status is blocked
run_git_block "$(make_bash_input "git status")"
assert_exit 2 "git-block: git status is blocked"

# 28k2. git stash is blocked
run_git_block "$(make_bash_input "git stash")"
assert_exit 2 "git-block: git stash is blocked"

# 28k3. git stash pop is blocked
run_git_block "$(make_bash_input "git stash pop")"
assert_exit 2 "git-block: git stash pop is blocked"

# 28l. non-git command passes through
run_git_block "$(make_bash_input "ls -la")"
assert_exit 0 "git-block: non-git command passes through"

# --- Codex local_shell git-block ---

# Extract the local_shell PreToolUse command (second PreToolUse entry in hooks.json)
LOCAL_SHELL_BLOCK_CMD=$(jq -r '.hooks.PreToolUse[1].hooks[0].command' "$HOOKS_JSON")

run_local_shell_block() {
  local input="$1"
  HOOK_EXIT=0
  HOOK_STDERR=""
  local stderr_file="$TMPDIR_BASE/stderr-localshell"
  printf '%s' "$input" | bash -c "$LOCAL_SHELL_BLOCK_CMD" >/dev/null 2>"$stderr_file" || HOOK_EXIT=$?
  HOOK_STDERR=$(cat "$stderr_file")
}

make_local_shell_input_array() {
  jq -n --argjson c "$1" '{tool_input:{command:$c}}'
}

make_local_shell_input_string() {
  jq -n --arg c "$1" '{tool_input:{command:$c}}'
}

# Codex 1: array-form git push is blocked
run_local_shell_block "$(make_local_shell_input_array '["git","push","origin","main"]')"
assert_exit 2 "local_shell git-block: array git push blocked"
assert_contains "$HOOK_STDERR" "TRUNK-SYNC" "local_shell git-block: array git push gets feedback"

# Codex 2: array-form git diff is allowed
run_local_shell_block "$(make_local_shell_input_array '["git","diff","--stat"]')"
assert_exit 0 "local_shell git-block: array git diff allowed"

# Codex 3: array-form git log is allowed
run_local_shell_block "$(make_local_shell_input_array '["git","log","--oneline"]')"
assert_exit 0 "local_shell git-block: array git log allowed"

# Codex 4: string-form git commit is blocked
run_local_shell_block "$(make_local_shell_input_string "git commit -m foo")"
assert_exit 2 "local_shell git-block: string git commit blocked"

# Codex 5: array-form non-git command passes through
run_local_shell_block "$(make_local_shell_input_array '["ls","-la"]')"
assert_exit 0 "local_shell git-block: array non-git command passes through"

# --- Codex PostToolUse: apply_patch and local_shell ---
#
# Intent: when Codex fires PostToolUse with its native tool names, the hook
# treats the change like a file-edit even though the payload carries no
# `file_path` field — discovery happens via `git status` (mirrors the
# Edit/Write-with-no-file_path code path that already powers modification-sync
# and deletion-sync). The patch envelope and local_shell command body are
# never parsed; the hook trusts git to surface what actually changed on disk.

make_apply_patch_input() {
  local session_id="${1:-}"
  local patch_envelope="${2:-*** Begin Patch\n*** End Patch\n}"
  jq -n \
    --arg sid "$session_id" \
    --arg patch "$patch_envelope" \
    '{tool_input:{input:$patch}, session_id:$sid, tool_name:"apply_patch", transcript_path:""}'
}

make_local_shell_post_input() {
  local session_id="${1:-}"
  local cmd_json="${2:-[\"true\"]}"
  jq -n \
    --arg sid "$session_id" \
    --argjson c "$cmd_json" \
    '{tool_input:{command:$c}, session_id:$sid, tool_name:"local_shell", transcript_path:""}'
}

# Codex P1. apply_patch: hook commits a modified tracked file even with no file_path
setup_repos
echo "v2 from codex apply_patch" > "$WT_A/seed.txt"
BEFORE=$(commit_count "$WT_A")
cd "$WT_A"
run_hook "$(make_apply_patch_input "codex01a-aaaa-aaaa-aaaa-aaaaaaaaaaaa" "*** Begin Patch\n*** Update File: seed.txt\n@@\n-seed\n+v2 from codex apply_patch\n*** End Patch\n")"
assert_exit 0 "codex apply_patch: hook exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$AFTER" "$((BEFORE + 1))" "codex apply_patch: one new commit"
HEAD_FILES=$(git -C "$WT_A" diff-tree --no-commit-id --name-only -r HEAD)
assert_contains "$HEAD_FILES" "seed.txt" "codex apply_patch: modified file is in the commit"

# Codex P2. apply_patch: hook commits a deleted tracked file even with no file_path
setup_repos
rm "$WT_A/seed.txt"
BEFORE=$(commit_count "$WT_A")
cd "$WT_A"
run_hook "$(make_apply_patch_input "codex02d-bbbb-bbbb-bbbb-bbbbbbbbbbbb" "*** Begin Patch\n*** Delete File: seed.txt\n*** End Patch\n")"
assert_exit 0 "codex apply_patch delete: hook exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$AFTER" "$((BEFORE + 1))" "codex apply_patch delete: one new commit"
LAST_SUBJECT=$(last_subject "$WT_A")
assert_contains "$LAST_SUBJECT" "delete seed.txt" "codex apply_patch delete: subject describes deletion"

# Codex P3. local_shell: hook commits a tracked file changed by a shell command
setup_repos
echo "v2 from codex local_shell" > "$WT_A/seed.txt"
BEFORE=$(commit_count "$WT_A")
cd "$WT_A"
run_hook "$(make_local_shell_post_input "codex03s-cccc-cccc-cccc-cccccccccccc" '["sed","-i","","s/seed/v2 from codex local_shell/","seed.txt"]')"
assert_exit 0 "codex local_shell: hook exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$AFTER" "$((BEFORE + 1))" "codex local_shell: one new commit"
HEAD_FILES=$(git -C "$WT_A" diff-tree --no-commit-id --name-only -r HEAD)
assert_contains "$HEAD_FILES" "seed.txt" "codex local_shell: modified file is in the commit"

# Codex P4. apply_patch: commit body carries Session: <uuid> for seance
LAST_BODY=$(last_body "$WT_A")
# The previous commit was from codex03s; assert P3's session id is in its body
assert_contains "$LAST_BODY" "codex03s-cccc-cccc-cccc-cccccccccccc" "codex local_shell: Session: trailer in body"

# Codex P5. apply_patch with a no-op patch (no actual file change) is a no-op
setup_repos
BEFORE=$(commit_count "$WT_A")
cd "$WT_A"
run_hook "$(make_apply_patch_input "codex05n-dddd-dddd-dddd-dddddddddddd" "*** Begin Patch\n*** End Patch\n")"
assert_exit 0 "codex apply_patch no-op: hook exits 0"
AFTER=$(commit_count "$WT_A")
assert_equals "$AFTER" "$BEFORE" "codex apply_patch no-op: no commit when nothing changed"

# --- Transcript snapshots ---

# 28. Default: .transcripts/ IS created (commit-transcripts defaults on for seance)
setup_repos
echo "default snapshot" > "$WT_A/seed.txt"
TRANSCRIPT="$TMPDIR_BASE/transcript-defaultsnapshot.jsonl"
create_transcript "$TRANSCRIPT" "Default snapshot task"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "dfsn1234" "Edit" "$TRANSCRIPT")"
assert_exit 0 "default: commit succeeds"
LAST_SHA=$(git -C "$WT_A" rev-parse HEAD)
SNAPSHOT_FILES=$(git -C "$WT_A" diff-tree --no-commit-id --name-only -r "$LAST_SHA" -- .transcripts/)
assert_contains "$SNAPSHOT_FILES" ".transcripts" "default: .transcripts/ created without opt-in"

# 29. Enabled: snapshot in same commit as code change
setup_repos
echo "commit-transcripts=true" > "$HOME/.trunk-sync"
TRANSCRIPT="$TMPDIR_BASE/transcript-snap.jsonl"
create_transcript "$TRANSCRIPT" "Snapshot task"
echo "with snapshot" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "snap1234" "Edit" "$TRANSCRIPT")"
assert_exit 0 "snapshot: commit succeeds"

# Verify snapshot is in the same commit as the code change
LAST_SHA=$(git -C "$WT_A" rev-parse HEAD)
SNAPSHOT_FILES=$(git -C "$WT_A" diff-tree --no-commit-id --name-only -r "$LAST_SHA" -- .transcripts/)
TEST_NUM=$((TEST_NUM + 1))
if [[ -n "$SNAPSHOT_FILES" ]]; then
  echo "ok $TEST_NUM - snapshot: .transcripts/ file in same commit as code change"
  PASS=$((PASS + 1))
else
  echo "not ok $TEST_NUM - snapshot: .transcripts/ file in same commit as code change"
  FAIL=$((FAIL + 1))
fi
assert_contains "$SNAPSHOT_FILES" "snap1234" "snapshot: filename contains session short ID"

# 30. Enabled but no transcript_path: graceful no-op
setup_repos
echo "commit-transcripts=true" > "$HOME/.trunk-sync"
echo "no transcript path" > "$WT_A/seed.txt"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "notp1234" "Edit" "")"
assert_exit 0 "snapshot with no transcript_path: exits 0"
LAST_SHA=$(git -C "$WT_A" rev-parse HEAD)
SNAPSHOT_FILES=$(git -C "$WT_A" diff-tree --no-commit-id --name-only -r "$LAST_SHA" -- .transcripts/)
assert_equals "" "$SNAPSHOT_FILES" "snapshot with no transcript_path: no .transcripts/ created"

# 30b. Opt-out: commit-transcripts=false → no snapshot
setup_repos
echo "commit-transcripts=false" > "$HOME/.trunk-sync"
echo "opt out" > "$WT_A/seed.txt"
TRANSCRIPT="$TMPDIR_BASE/transcript-optout.jsonl"
create_transcript "$TRANSCRIPT" "Opt-out task"
cd "$WT_A"
run_hook "$(make_input "$WT_A/seed.txt" "opto1234" "Edit" "$TRANSCRIPT")"
assert_exit 0 "opt-out: commit succeeds"
LAST_SHA=$(git -C "$WT_A" rev-parse HEAD)
SNAPSHOT_FILES=$(git -C "$WT_A" diff-tree --no-commit-id --name-only -r "$LAST_SHA" -- .transcripts/)
assert_equals "" "$SNAPSHOT_FILES" "opt-out: no .transcripts/ created when commit-transcripts=false"
rm -f "$HOME/.trunk-sync"

# ── Handover: agent-authored progress in timecards ───────────────────────────

DIST_DIR="$(cd "$(dirname "$HOOK")/.." && pwd)/dist"

record_progress() { # cwd id last next
  ( cd "$1" && node "$DIST_DIR/cli.js" progress "$2" --last "$3" --next "$4" )
}
run_session_start() { # cwd session_id
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionStart","transcript_path":""}' "$2" "$1" \
    | node "$DIST_DIR/lib/session-start-entry.js"
}
run_stop() { # cwd session_id
  ( cd "$1" && printf '{"session_id":"%s","hook_event_name":"Stop","stop_hook_active":false,"transcript_path":""}' "$2" \
    | node "$DIST_DIR/lib/stop-entry.js" )
}

# 31. Agent A clocks in (hook), then records progress via the real CLI.
setup_repos
cd "$WT_A"
echo "work" > "$WT_A/seed.txt"
run_hook "$(make_input "$WT_A/seed.txt" "agentaaa" "Edit" "")"   # clock A in, commit timecard
record_progress "$WT_A" "agentaaa" "wrote the parser" "wire the CLI and add tests"
CARD="$WT_A/.trunk-sync/timeclock/agentaaa.json"
assert_equals "wrote the parser" "$(jq -r '.lastStep' "$CARD")" "progress: lastStep written to timecard"
assert_equals "wire the CLI and add tests" "$(jq -r '.remainingSteps' "$CARD")" "progress: remainingSteps written to timecard"
assert_equals "agentaaa" "$(jq -r '.sessionId' "$CARD")" "progress: sessionId preserved"

# 32. The HOOK ALONE commits and pushes the progress-updated timecard (no manual push —
#     this proves the hook propagates the handover to the remote on its own).
echo "more" > "$WT_A/seed.txt"
run_hook "$(make_input "$WT_A/seed.txt" "agentaaa" "Edit" "")"   # next fire commits + pushes the updated timecard
REMOTE_CARD=$(git -C "$REMOTE" show "main:.trunk-sync/timeclock/agentaaa.json" 2>/dev/null || echo "")
assert_contains "$REMOTE_CARD" "wrote the parser" "propagation: hook alone pushes the handover to the remote"

# 33. Agent B's SessionStart surfaces A's handover and B's own record instruction.
SS_OUT=$(run_session_start "$WT_A" "agentbbb")
assert_contains "$SS_OUT" "TRUNK-SYNC HANDOVER" "session-start: handover roster shown"
assert_contains "$SS_OUT" "wrote the parser" "session-start: A's last step surfaced"
assert_contains "$SS_OUT" "wire the CLI and add tests" "session-start: A's remaining steps surfaced"
assert_contains "$SS_OUT" "trunk-sync progress agentbbb" "session-start: B told how to record its own progress"

# 34. A clock-in re-fire preserves the agent-authored progress (does not wipe it).
record_progress "$WT_A" "agentaaa" "all tests green" "ship it"
echo "again" > "$WT_A/seed.txt"
run_hook "$(make_input "$WT_A/seed.txt" "agentaaa" "Edit" "")"
assert_equals "all tests green" "$(jq -r '.lastStep' "$CARD")" "preservation: clock-in keeps lastStep"
assert_equals "ship it" "$(jq -r '.remainingSteps' "$CARD")" "preservation: clock-in keeps remainingSteps"

# 35. The Stop hook bumps and commits a stale heartbeat, then no-ops while it is fresh.
STALE_TS=$(node -e 'console.log(new Date(Date.now()-45*60*1000).toISOString())')
jq --arg t "$STALE_TS" '.lastActiveAt=$t' "$CARD" > "$CARD.tmp" && mv "$CARD.tmp" "$CARD"
( cd "$WT_A" && git add -A && git commit -q -m "stale the card" )
run_stop "$WT_A" "agentaaa" >/dev/null 2>&1 || true
assert_contains "$(git -C "$WT_A" log -1 --format=%s)" "heartbeat" "stop: stale heartbeat is committed"
[[ "$(jq -r '.lastActiveAt' "$CARD")" != "$STALE_TS" ]] && HB_BUMPED=yes || HB_BUMPED=no
assert_equals "yes" "$HB_BUMPED" "stop: stale heartbeat value is refreshed"
REMOTE_HB=$(git -C "$REMOTE" show "main:.trunk-sync/timeclock/agentaaa.json" 2>/dev/null | jq -r '.lastActiveAt' 2>/dev/null || echo "")
[[ -n "$REMOTE_HB" && "$REMOTE_HB" != "$STALE_TS" ]] && HB_PUSHED=yes || HB_PUSHED=no
assert_equals "yes" "$HB_PUSHED" "stop: the refreshed heartbeat is synced to the remote"
COUNT_AFTER_BUMP=$(git -C "$WT_A" rev-list --count HEAD)
run_stop "$WT_A" "agentaaa" >/dev/null 2>&1 || true
assert_equals "$COUNT_AFTER_BUMP" "$(git -C "$WT_A" rev-list --count HEAD)" "stop: a fresh heartbeat makes no commit"

# 36. A disrupted card (stale heartbeat, unfinished steps) is surfaced at SessionStart as a handover.
STALE_HB=$(node -e 'console.log(new Date(Date.now()-2*60*60*1000).toISOString())')  # 2h ago
jq --arg t "$STALE_HB" '.lastActiveAt=$t' "$CARD" > "$CARD.tmp" && mv "$CARD.tmp" "$CARD"
SS_STALE=$(run_session_start "$WT_A" "agentccc")
assert_contains "$SS_STALE" "possibly disrupted" "session-start: a stale card is surfaced labelled possibly-disrupted"
assert_contains "$SS_STALE" "ship it" "session-start: the disrupted card's remaining steps are still surfaced"

# 37. An abandoned card (heartbeat past the 14-day TTL) is swept on the next agent's commit.
OLD_TS=$(node -e 'console.log(new Date(Date.now()-20*24*60*60*1000).toISOString())')
GHOST="$WT_A/.trunk-sync/timeclock/ghostagent.json"
printf '{"sessionId":"ghostagent","hostname":"old-host","clockedInAt":"%s","lastActiveAt":"%s","branch":"main","task":null,"lastStep":null,"remainingSteps":"never finished"}' "$OLD_TS" "$OLD_TS" > "$GHOST"
( cd "$WT_A" && git add -A && git commit -q -m "add abandoned card" )
echo "trigger reap" > "$WT_A/seed.txt"
run_hook "$(make_input "$WT_A/seed.txt" "agentaaa" "Edit" "")"
[[ -f "$GHOST" ]] && REAPED=no || REAPED=yes
assert_equals "yes" "$REAPED" "reap: an abandoned card past the TTL is swept on the next commit"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "1..$TEST_NUM"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
