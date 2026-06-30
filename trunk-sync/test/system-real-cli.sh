#!/bin/bash
set -euo pipefail

# Real-CLI System test for the handover feature — drives the ACTUAL claude binary
# (not simulated hook stdin). Billable + non-deterministic, so it is NOT part of
# `pnpm test` / `test:e2e`; run it manually:  bash test/system-real-cli.sh
#
# Proves what the simulated System test (test/trunk-sync.test.sh) cannot:
#   1. A real claude SessionStart injects runSessionStart's stdout into the agent.
#   2. A real agent, so instructed, runs `trunk-sync progress`, writing its timecard.
#   3. A second real session's SessionStart surfaces the first's handover, and the
#      agent actually receives it.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 1; }

echo "== building dist =="
( cd "$ROOT" && pnpm run build >/dev/null )

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# `trunk-sync` on PATH for the agent (production installs it globally via npm).
BIN="$WORK/bin"; mkdir -p "$BIN"
printf '#!/bin/bash\nexec node "%s/dist/cli.js" "$@"\n' "$ROOT" > "$BIN/trunk-sync"
chmod +x "$BIN/trunk-sync"
export PATH="$BIN:$PATH"

REPO="$WORK/project"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t
git -C "$REPO" config user.name t
git -C "$REPO" commit -q --allow-empty -m init

run_agent() { # prompt → captured stream-json transcript on stdout
  ( cd "$REPO" && claude -p "$1" \
      --plugin-dir "$ROOT" \
      --dangerously-skip-permissions \
      --model sonnet \
      --max-budget-usd 2.00 \
      --output-format stream-json \
      --verbose 2>&1 )
}

echo "== Agent A: work + record progress (real claude) =="
A_PROMPT='This project uses trunk-sync. At session start you were given your trunk-sync session id and how to record progress. Do exactly: (1) create a file notes.txt containing the word hello, using the Write tool; (2) then run the trunk-sync progress command for YOUR session id with --last "implemented the parser" and --next "wire the CLI and write tests". Finally, print the exact command you ran.'
A_OUT="$(run_agent "$A_PROMPT")"

CARD="$(ls "$REPO"/.trunk-sync/timeclock/*.json 2>/dev/null | head -1 || true)"
echo "-- timecard written by the real session: $CARD"
[ -n "$CARD" ] && cat "$CARD"

PASS=0; FAIL=0
check() { if eval "$2"; then echo "ok - $1"; PASS=$((PASS+1)); else echo "NOT OK - $1"; FAIL=$((FAIL+1)); fi; }

check "real session clocked in (timecard exists)" '[ -n "$CARD" ]'
check "agent recorded lastStep via trunk-sync progress" 'grep -q "implemented the parser" "$CARD" 2>/dev/null'
check "agent recorded remainingSteps via trunk-sync progress" 'grep -q "wire the CLI and write tests" "$CARD" 2>/dev/null'

echo "== Agent B: fresh real session — does its SessionStart surface A's handover? =="
B_PROMPT='At session start, trunk-sync may have shown you a TRUNK-SYNC HANDOVER from other sessions. Report verbatim every line you were shown that begins with "last:" or "next:". If you saw no handover, reply exactly NO HANDOVER.'
B_OUT="$(run_agent "$B_PROMPT")"

check "B's real session received A's last step (real SessionStart injection)" 'grep -q "implemented the parser" <<< "$B_OUT"'
check "B's real session received A's remaining steps" 'grep -q "wire the CLI and write tests" <<< "$B_OUT"'

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
