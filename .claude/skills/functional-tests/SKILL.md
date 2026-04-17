---
name: functional-tests
description: "Run and evaluate the contree plugin's Docker-based functional test. TRIGGER when the user mentions 'functional test', 'functional tests', 'docker-run', 'full-workflow', 'test transcript', 'verify against trees', 'review the transcript', asks to 'kick off / run the end-to-end test', asks whether the plugin behaves correctly end-to-end, or asks to evaluate a completed test run."
---

# Contree functional tests

The contree plugin ships two functional scenarios that each drive a real Claude session through three phases (setup → workflow → drift+sync) and produce a transcript. You (this Claude Code session) evaluate each transcript against every tree in `contree/CLAUDE.md` `## Test Trees`.

| Scenario | Fixture | Exercises |
|---|---|---|
| `full-workflow` | `greenfield` (pure utility, no I/O) | Domain layer, setup, change, tdd cycle, mutation, sync discoverability, stop hook, rules/pressure |
| `layered-workflow` | `bookmarks-api` (HTTP + repository port) | All four layers, in-memory adapter pattern, shared port contract suite, driving + driven adapter tests, System through HTTP |

Run one or both. `full-workflow` covers the broadest tree set. `layered-workflow` fills in the Use-case / Adapter / port / in-memory paths that `full-workflow` leaves as N/A.

## When to use

- User asks to run the functional test, the end-to-end test, or `full-workflow`
- User wants to verify a just-made change to a skill, hook, or rule didn't regress plugin behaviour
- User asks you to evaluate an existing transcript at `contree/test/functional/full-workflow-transcript.jsonl`
- After any non-trivial edit to `contree/skills/`, `contree/hooks/`, `contree/rules/`, `contree/CLAUDE.md` — offer to run the functional test

## Process

### 1. Kick off the run

Run in the background — it takes roughly 5–15 minutes end-to-end (Docker build cached after first run, then three sonnet phases at up to `$0.50` each):

```
cd contree/test/functional && bash docker-run.sh full-workflow 2>&1 | tee /tmp/full-workflow-run.log
```

Use `run_in_background: true` with a generous timeout. Do **not** poll — wait for the completion notification, then proceed to step 2. Do **not** attempt to evaluate a partial transcript.

Prerequisites (check before running): `ANTHROPIC_API_KEY` available in env or in `contree/test/functional/.env`, Docker daemon running. If either is missing, stop and report.

### 2. Pull the evidence

Three sources matter — read each directly, do not delegate:

- **Phase boundaries** — `grep -E "^(===|\\[harness\\]|Transcript:|Verify:)" /tmp/full-workflow-run.log`
- **Tool-call sequence** — extract the ordered list of what Claude actually did, with skill invocations visible:

  ```
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name): \(.input.file_path // .input.command // .input.pattern // .input.skill // "")"' contree/test/functional/full-workflow-transcript.jsonl | nl
  ```

- **Assistant text** — final text across phases, for verdicts/decisions/summaries:

  ```
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' contree/test/functional/full-workflow-transcript.jsonl | tail -80
  ```

- **Hook fires** (SessionStart rules + pressure phrase, Stop drift-check between phases):

  ```
  jq -r 'select(.type == "user") | (.message.content | if type == "array" then (.[]? | select(.type == "text") | .text) else empty end)' contree/test/functional/full-workflow-transcript.jsonl | grep -E "Stop hook|SessionStart"
  ```

- **CLAUDE.md edits** — get the test trees Claude wrote (inspect `new_string` of the Edit tool call to the fixture's `CLAUDE.md`).

Do NOT try to read the raw transcript line-by-line; it's ~250 KB. Use the `jq` recipes above and targeted `grep`s.

### 3. Evaluate — trees ARE the checklist

The `<name>-verify.txt` file says: *"Evaluate the transcript against every tree in `contree/CLAUDE.md` `## Test Trees`. Per when/then path: PASS, FAIL, or N/A with evidence."*

That's you. Open `contree/CLAUDE.md`, read every tree. For each `when/then` (and `if/then`) path, render one verdict and quote evidence from the transcript:

- **PASS** — the transcript demonstrates the assertion. Quote the tool call, assistant text, or hook output that proves it.
- **FAIL** — the transcript contradicts the assertion. Quote the contradicting evidence.
- **N/A** — the scenario didn't exercise this assertion (e.g. pure-library scenario doesn't touch the in-memory adapter pattern).

Report grouped by tree, with a final summary: total PASS / FAIL / N-A across all trees, then a short "Real concerns" list for anything that matters vs "Scenario noise" for things that don't (headless mode means `change` can't literally "discuss with user", etc.).

### 4. What to specifically watch for

Concerns the `full-workflow` scenario has surfaced in the past — check each:

- **Phase 3 must invoke `/contree:sync`.** Look for `Skill: contree:sync` in the tool-call list. If absent, the sync skill's discoverability has regressed (`skills/sync/SKILL.md` frontmatter description should contain loose phrasings: *"audit", "check for drift", "something feels off", "propose fixes"*).
- **Phase 3 must NOT resolve drift unilaterally.** Claude should present options and stop. If you see an Edit/rm against `shortcode.js` in phase 3 without a prior "which do you want?" moment, the sync skill's RESOLVE DRIFT step has regressed.
- **Mutation testing must complete.** Look for `npm run test:mutate` followed by a score (e.g. *"100% mutation score — 13 killed"*). If it says Stryker aborted, the Dockerfile may have lost `procps`.
- **Bi-directional tree↔file rule.** No System test file without a System tree; no tree without a test file. Check the CLAUDE.md trees Claude wrote against the test files created.
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

- `contree/test/functional/docker-run.sh` — runs the Docker harness
- `contree/test/functional/docker-entrypoint.sh` — the scenario (three phases + drift injection)
- `contree/test/functional/Dockerfile` — test image (must include `procps` for Stryker)
- `contree/test/fixtures/greenfield/` — the fixture the scenario seeds
- `contree/test/functional/full-workflow-transcript.jsonl` — produced output
- `contree/test/functional/full-workflow-verify.txt` — produced instructions pointing at the trees
- `contree/CLAUDE.md` `## Test Trees` — the checklist
- `contree/test/functional/analyse-transcripts.sh` — lightweight tool-call summariser (optional)

## Don't

- Don't paraphrase the trees into a separate checklist in the verify file or report — the trees ARE the checklist. Any restatement creates drift between the trees and the VERIFY.
- Don't invent scenarios Claude "should have" exercised. If a tree path is genuinely unreachable by this scenario, it's N/A, not FAIL.
- Don't claim PASS without a concrete quotation of transcript evidence.
- Don't run mutation testing, bats, or other suites *as a substitute* for the functional test — bats covers structure, not behaviour.
