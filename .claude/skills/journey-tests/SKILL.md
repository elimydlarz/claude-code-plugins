---
name: journey-tests
description: "Run and evaluate the contree plugin's Docker-based journey tests. TRIGGER when the user mentions 'journey test', 'journey tests', 'docker-run', 'test-kinds-workflow', 'test transcript', 'verify against trees', 'review the transcript', asks to 'kick off / run the end-to-end test', asks whether the plugin behaves correctly end-to-end, or asks to evaluate a completed test run."
---

# Contree journey tests

The Contree plugin ships journey scenarios that drive a real coding-agent session through production-like arcs and produce transcripts. Evaluate each transcript against every tree in `contree/TEST_TREES.md`.

| Scenario | Fixture | Exercises |
|---|---|---|
| `setup` | `setup-existing` | Comprehensive setup, bootstrap, commands, hooks, and feedback loops |
| `test-kinds-workflow` | `bookmarks-api` | Journey, Component, Integration, and Unit concerns across an HTTP API and repository port |

Run one scenario or the full matrix. `test-kinds-workflow` exercises the four test kinds while domain, use-case, adapter, and port remain architecture subjects.

## When to use

- User asks to run a journey test, an end-to-end test, or `test-kinds-workflow`
- User wants to verify a just-made change to a skill, hook, or rule didn't regress plugin behaviour
- User asks you to evaluate an existing transcript under `contree/test/journey/`
- After any non-trivial edit to `contree/skills/`, `contree/hooks/`, `contree/rules/`, or `contree/TEST_TREES.md` — offer to run the relevant journey test

## Process

### 1. Kick off the run

Run in the background — it takes roughly 5–15 minutes end-to-end (Docker build cached after first run, then three sonnet phases at up to `$0.50` each):

```
cd contree/test/journey && bash docker-run.sh setup 2>&1 | tee /tmp/setup-run.log
```

Or for the four-kind workflow:

```
cd contree/test/journey && bash docker-run.sh test-kinds-workflow 2>&1 | tee /tmp/test-kinds-workflow-run.log
```

Or both in parallel (`all`).

Use `run_in_background: true` with a generous timeout. Do **not** poll — wait for the completion notification, then proceed to step 2. Do **not** attempt to evaluate a partial transcript.

Prerequisites: `DEEPSEEK_API_KEY` available in the environment or `contree/test/journey/.env`, and Docker running. If either is missing, stop and report.

### 2. Pull the evidence

Three sources matter — read each directly, do not delegate:

- **Phase boundaries** — `grep -E "^(===|\\[harness\\]|Transcript:|Verify:)" /tmp/test-kinds-workflow-run.log`
- **Tool-call sequence** — extract the ordered list of what Claude actually did, with skill invocations visible:

  ```
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name): \(.input.file_path // .input.command // .input.pattern // .input.skill // "")"' contree/test/journey/test-kinds-workflow-claude-transcript.jsonl | nl
  ```

- **Assistant text** — final text across phases, for verdicts/decisions/summaries:

  ```
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' contree/test/journey/test-kinds-workflow-claude-transcript.jsonl | tail -80
  ```

- **Hook fires** (SessionStart rules + pressure phrase, Stop drift-check between phases):

  ```
  jq -r 'select(.type == "user") | (.message.content | if type == "array" then (.[]? | select(.type == "text") | .text) else empty end)' contree/test/journey/test-kinds-workflow-claude-transcript.jsonl | grep -E "Stop hook|SessionStart"
  ```

- **TEST_TREES.md edits** — get the test trees the coding agent wrote from its edit tool calls.

Do NOT try to read the raw transcript line-by-line; it's ~250 KB. Use the `jq` recipes above and targeted `grep`s.

### 3. Evaluate — trees ARE the checklist

The `<name>-verify.txt` file says: *"Evaluate the transcript against every tree in `contree/CLAUDE.md` `## Test Trees`. Per when/then path: PASS, FAIL, or N/A with evidence."*

That's you. Open `contree/CLAUDE.md`, read every tree. For each `when/then` (and `if/then`) path, render one verdict and quote evidence from the transcript:

- **PASS** — the transcript demonstrates the plugin behaviour the tree asserts. Quote the tool call, assistant text, or hook output that proves it.
- **FAIL** — the transcript contradicts the plugin behaviour the tree asserts. This is a **contree regression** — the plugin's specification was violated. Quote the contradicting evidence.
- **N/A** — the scenario didn't exercise this assertion (e.g. pure-library scenario doesn't touch the in-memory adapter pattern).

**What you are verifying is contree plugin behaviour — not Claude's coding quality.** These are different things. Claude may write buggy code, hit budget limits, take shortcuts, or produce imperfect implementations. None of those are contree regressions. A FAIL means the *plugin's specification was violated*:

- The skill didn't trigger when it should have → FAIL (skill-discoverability regression)
- Trees were silently modified → FAIL (contract violation)
- Drift was resolved without asking the user → FAIL (sync regression)
- Claude wrote bad code but followed the right process → PASS (the plugin guided correctly)
- Budget ran out before mutation testing → PASS (contree prescribed it; Claude couldn't afford it)
- Claude wrote tests in parallel instead of one-at-a-time → PASS (contree prescribed one-at-a-time; Claude took a shortcut under pressure — the plugin still fired the right skill and showed the right process)
- The harness injected broken drift code and tests failed → PASS on the sync check (contree found the drift); irrelevant to other trees

Report grouped by tree, with a final summary: total PASS / FAIL / N-A across all trees, then a short "Regressions" list (only genuine plugin spec violations) and an optional "Observations" list for anything notable but not a regression.

### 4. What to specifically watch for

Concerns the workflow scenario has surfaced in the past — check each:

- **Phase 3 must invoke `/contree:sync`.** Look for `Skill: contree:sync` in the tool-call list. If absent, the sync skill's discoverability has regressed (`skills/sync/SKILL.md` frontmatter description should contain loose phrasings: *"audit", "check for drift", "something feels off", "propose fixes"*).
- **Phase 3 must NOT resolve drift unilaterally.** Claude should present options and stop. If you see an Edit/rm against `shortcode.js` in phase 3 without a prior "which do you want?" moment, the sync skill's RESOLVE DRIFT step has regressed.
- **Mutation testing must complete.** Look for `npm run test:mutate` followed by a score (e.g. *"100% mutation score — 13 killed"*). If it says Stryker aborted, the Dockerfile may have lost `procps`.
- **Bi-directional tree↔file rule.** No Unit test file without a Unit tree; no tree without a corresponding test file. Check the trees against the files created.
- **SessionStart hook must fire per phase** — each phase starts a new session (three SessionStart `hook_response` events), each ends with a different pressure phrase drawn from the pool in `hooks/session-start.sh`.
- **Stop hook must fire between phases** — two Stop-hook drift-check messages as synthesized user turns.

### 5. Report format

Produce one markdown message, structured like:

```
### <tree-name>

- `<when/then path>` — **PASS** (evidence)
- `<if/then path>` — **FAIL** (evidence)
- ...

### Summary

- PASS: N
- FAIL: N
- N/A: N

### Real concerns
- <genuine regressions>

### Scenario noise
- <N/A that don't matter>
```

Then ask the user what to address first, or whether to kick another run.

## Files touched

- `contree/test/journey/docker-run.sh` — runs the Docker harness
- `contree/test/journey/docker-entrypoint.sh` — defines the scenarios
- `contree/test/journey/Dockerfile` — test image
- `contree/test/fixtures/bookmarks-api/` — the four-kind workflow fixture
- `contree/test/journey/<scenario>-<harness>-transcript.jsonl` — produced output
- `contree/test/journey/<scenario>-<harness>-verify.txt` — produced verification instructions
- `contree/TEST_TREES.md` — the checklist
- `contree/test/journey/analyse-transcripts.sh` — lightweight tool-call summariser

## Don't

- Don't paraphrase the trees into a separate checklist in the verify file or report — the trees ARE the checklist. Any restatement creates drift between the trees and the VERIFY.
- Don't invent scenarios Claude "should have" exercised. If a tree path is genuinely unreachable by this scenario, it's N/A, not FAIL.
- Don't claim PASS without a concrete quotation of transcript evidence.
- Don't run mutation testing, Bats, or other suites as a substitute for the journey test — Bats covers structure, not production-like behaviour.
