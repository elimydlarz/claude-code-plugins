#!/usr/bin/env bash
set -euo pipefail

# Runs a contree journey case against a coding-agent harness.
# Works both inside Docker (called by docker-run.sh) and directly on the host.
#
# Expects:
#   - For claude: ANTHROPIC_API_KEY or DEEPSEEK_API_KEY (via docker-run.sh DeepSeek env vars)
#   - For codex:  CODEX_API_KEY or ~/.codex/auth.json
#   - $1 is the test name (layered-workflow | mental-model-validator-smoke | describe-it-drift | diff-images | second-opinion | second-opinion-live)
#   - $2 is the harness  (claude | codex), default claude

TEST_NAME="${1:?Usage: docker-entrypoint.sh <test-name> [claude|codex]}"
HARNESS="${2:-claude}"
case "$HARNESS" in claude|codex) ;; *) echo "Unknown harness: $HARNESS (use claude or codex)" >&2; exit 1;; esac

if [ -d "/work/contree" ]; then
  CONTREE_ROOT="/work/contree"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

ENV_FILE="$CONTREE_ROOT/test/journey/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi
FIXTURES="$CONTREE_ROOT/test/fixtures"
PROJECT_DIR="/tmp/contree-test-project"
CODEX_TEST_HOME="$PROJECT_DIR/.codex-home"
OUTPUT_DIR="$CONTREE_ROOT/test/journey"
if [ -d "/output" ]; then
  OUTPUT_DIR="/output"
fi
TRANSCRIPT_FILE="$OUTPUT_DIR/${TEST_NAME}-${HARNESS}-transcript.jsonl"
VERIFY_FILE="$OUTPUT_DIR/${TEST_NAME}-${HARNESS}-verify.txt"

rm -f "$TRANSCRIPT_FILE"

# --- Helpers ---

seed_project() {
  local fixture_name="$1"
  local fixture_dir="/fixtures/$fixture_name"
  [ -d "$fixture_dir" ] || fixture_dir="$FIXTURES/$fixture_name"

  rm -rf "$PROJECT_DIR"
  cp -r "$fixture_dir" "$PROJECT_DIR"
  [ -f "$FIXTURES/$fixture_name/CLAUDE.md" ] && cp "$FIXTURES/$fixture_name/CLAUDE.md" "$PROJECT_DIR/"
  (cd "$PROJECT_DIR" && git init -q && git config user.email "test@test" && git config user.name "test" && git add -A && git commit -q -m "seed")
}

CODEX_PRIMED=0

prime_codex_plugin() {
  # Codex reads cached plugins from ~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/
  # plus a config.toml entry that enables the plugin and the under-development
  # plugin_hooks feature (without it, hook scripts in hooks.json are ignored).
  # See codex-rs/core/src/plugins/manager_tests.rs::plugins_for_config_reloads_when_plugin_hooks_enablement_changes.
  [ "$CODEX_PRIMED" -eq 1 ] && return 0
  CODEX_PRIMED=1

  rm -rf "$CODEX_TEST_HOME"
  mkdir -p "$CODEX_TEST_HOME"
  if [ -f "$HOME/.codex/auth.json" ]; then
    cp "$HOME/.codex/auth.json" "$CODEX_TEST_HOME/auth.json"
  fi

  local cache_dir="$CODEX_TEST_HOME/plugins/cache/local-marketplace/contree/local"
  rm -rf "$cache_dir"
  mkdir -p "$(dirname "$cache_dir")"
  cp -r "$CONTREE_ROOT" "$cache_dir"

  mkdir -p "$PROJECT_DIR/.codex"
  cat > "$PROJECT_DIR/.codex/post-tool-use-contree.sh" <<CONFIG
#!/usr/bin/env bash
export CLAUDE_PLUGIN_ROOT="$cache_dir"
INPUT=\$(cat)
printf '%s\n' "\$INPUT" >> "$PROJECT_DIR/.codex/post-tool-use-input.jsonl"
OUTPUT=\$(printf '%s' "\$INPUT" | bash "$cache_dir/hooks/post-update-check.sh")
if [ -n "\$OUTPUT" ]; then
  printf '%s\n' "\$OUTPUT" >> "$PROJECT_DIR/.codex/post-tool-use-output.jsonl"
  printf '%s\n' "\$OUTPUT"
fi
CONFIG
  chmod +x "$PROJECT_DIR/.codex/post-tool-use-contree.sh"

  cat > "$PROJECT_DIR/.codex/hooks.json" <<CONFIG
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|apply_patch",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$PROJECT_DIR/.codex/post-tool-use-contree.sh\""
          }
        ]
      }
    ]
  }
}
CONFIG
  {
    echo ".codex/"
    echo ".codex-home/"
  } >> "$PROJECT_DIR/.git/info/exclude"

  cat > "$CODEX_TEST_HOME/config.toml" <<'CONFIG'
model_reasoning_effort = "low"

[features]
hooks = true
plugin_hooks = true

[shell_environment_policy]
inherit = "all"

[plugins."contree@local-marketplace"]
enabled = true
CONFIG

  cat >> "$CODEX_TEST_HOME/config.toml" <<CONFIG

[projects."$PROJECT_DIR"]
trust_level = "trusted"

[projects."/private${PROJECT_DIR}"]
trust_level = "trusted"
CONFIG

  export CODEX_HOME="$CODEX_TEST_HOME"

  if [ ! -f "$CODEX_TEST_HOME/auth.json" ] && [ -z "${CODEX_API_KEY:-}" ]; then
    echo "Codex harness requires either ~/.codex/auth.json or CODEX_API_KEY" >&2
    exit 1
  fi
}

AGENT_CALL_COUNT=0

run_agent() {
  local prompt="$1"
  AGENT_CALL_COUNT=$((AGENT_CALL_COUNT + 1))

  if [ "$HARNESS" = "claude" ]; then
    local continue_flag=()
    [ "$AGENT_CALL_COUNT" -gt 1 ] && continue_flag=(-c)
    (cd "$PROJECT_DIR" && claude -p "$prompt" \
      "${continue_flag[@]}" \
      --plugin-dir "$CONTREE_ROOT" \
      --dangerously-skip-permissions \
      --model sonnet \
      --max-budget-usd 2.00 \
      --output-format stream-json \
      --verbose \
      2>&1) | tee -a "$TRANSCRIPT_FILE" || true
    return
  fi

  prime_codex_plugin
  if [ "$AGENT_CALL_COUNT" -eq 1 ]; then
    if ! (cd "$PROJECT_DIR" && codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      --dangerously-bypass-hook-trust \
      --skip-git-repo-check \
      --json \
      -m gpt-5.4-mini \
      -C "$PROJECT_DIR" \
      "$prompt" 2>&1) | tee -a "$TRANSCRIPT_FILE"; then
      append_codex_artifacts
      exit 1
    fi
    append_codex_artifacts
  else
    if ! (cd "$PROJECT_DIR" && codex exec resume --last \
      --dangerously-bypass-approvals-and-sandbox \
      --dangerously-bypass-hook-trust \
      --skip-git-repo-check \
      --json \
      -m gpt-5.4-mini \
      "$prompt" 2>&1) | tee -a "$TRANSCRIPT_FILE"; then
      append_codex_artifacts
      exit 1
    fi
    append_codex_artifacts
  fi

  if grep -Eq '"type":"turn\.failed"|"(message|text)":"[^"]*(usage limit|rate limit)' "$TRANSCRIPT_FILE"; then
    echo "Codex agent failure found in $TRANSCRIPT_FILE:" >&2
    grep -En '"type":"turn\.failed"|"(message|text)":"[^"]*(usage limit|rate limit)' "$TRANSCRIPT_FILE" >&2
    exit 1
  fi
}

append_codex_artifacts() {
  [ "$HARNESS" = "codex" ] || return 0

  local session_file
  session_file="$(find "$CODEX_TEST_HOME/sessions" -type f -name '*.jsonl' 2>/dev/null | sort | tail -n 1 || true)"
  if [ -n "$session_file" ] && [ -f "$session_file" ]; then
    {
      echo ""
      echo "=== codex internal session transcript: $session_file ==="
      cat "$session_file"
    } >> "$TRANSCRIPT_FILE"
  fi

  if [ -f "$PROJECT_DIR/.codex/post-tool-use-input.jsonl" ]; then
    {
      echo ""
      echo "=== codex PostToolUse hook stdin ==="
      cat "$PROJECT_DIR/.codex/post-tool-use-input.jsonl"
    } >> "$TRANSCRIPT_FILE"
  fi

  if [ -f "$PROJECT_DIR/.codex/post-tool-use-output.jsonl" ]; then
    {
      echo ""
      echo "=== codex PostToolUse hook stdout ==="
      cat "$PROJECT_DIR/.codex/post-tool-use-output.jsonl"
    } >> "$TRANSCRIPT_FILE"
  fi
}

write_verify() {
  cat > "$VERIFY_FILE"
  echo ""
  cat "$VERIFY_FILE"
}

assert_no_hook_runner_errors() {
  local matches
  matches="$(grep -Ein "hook .*failed|hook exited with code|hook.*command not found|exec: .*: not found" "$TRANSCRIPT_FILE" || true)"
  if [ -n "$matches" ]; then
    echo "Hook runner error found in $TRANSCRIPT_FILE:" >&2
    printf '%s\n' "$matches" >&2
    exit 1
  fi
}

install_curl_shim() {
  # Route a skill's curl recipe at a local stub by shadowing curl with a shim
  # earlier on PATH. The container runs as non-root testuser, so the shim lives
  # in a writable dir (not /usr/local/bin) and PATH is prepended for the agent.
  # $from is the match pattern with slashes escaped (so the first / does not end
  # the pattern); $to is the plain replacement URL. Used as bash ${a//from/to}.
  local from="$1" to="$2"
  local shimdir="/tmp/curl-shim"
  mkdir -p "$shimdir"
  local real_curl; real_curl="$(command -v curl)"
  cat > "$shimdir/curl" <<EOF
#!/usr/bin/env bash
args=()
for a in "\$@"; do args+=("\${a//$from/$to}"); done
exec "$real_curl" "\${args[@]}"
EOF
  chmod +x "$shimdir/curl"
  export PATH="$shimdir:$PATH"
}

OPENAI_STUB_PID=0

start_openai_image_stub() {
  # Mock OpenAI's images generations endpoint so /diff can run without a real
  # (billable, non-deterministic) gpt-image-2 call. Serves a canned b64_json
  # image. The skill's curl recipe honours OPENAI_BASE_URL, so the journey points
  # it at this local stub.
  local port=8771
  local stub="/tmp/openai-image-stub.js"
  STUB_MARKER="CONTREE-MOCK-IMAGE-BYTES"
  STUB_HITS="/tmp/openai-stub-hits.log"
  : > "$STUB_HITS"
  cat > "$stub" <<'JS'
const fs = require('fs')
const http = require('http')
const image = Buffer.from(process.env.STUB_MARKER).toString('base64')
http.createServer((req, res) => {
  let body = ''
  req.on('data', (c) => (body += c))
  req.on('end', () => {
    if (req.method === 'POST' && req.url.includes('/images/generations')) {
      fs.appendFileSync(process.env.STUB_HITS, `${req.method} ${req.url} ${body}\n`)
      if (body.includes('response_format')) {
        res.writeHead(400, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify({ error: { message: "Unknown parameter: 'response_format'.", type: 'invalid_request_error', param: 'response_format', code: 'unknown_parameter' } }))
        return
      }
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ data: [{ b64_json: image }] }))
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' })
      res.end('{}')
    }
  })
}).listen(process.env.STUB_PORT, () => console.error('openai-image-stub listening'))
JS
  STUB_PORT="$port" STUB_MARKER="$STUB_MARKER" STUB_HITS="$STUB_HITS" node "$stub" &
  OPENAI_STUB_PID=$!

  export OPENAI_API_KEY="test-key-mock"
  export OPENAI_BASE_URL="http://127.0.0.1:$port/v1"
}

ZAI_STUB_PID=0

start_zai_review_stub() {
  # Mock Z.AI's chat completions endpoint so /contree:second-opinion can run
  # without a real (billable, non-deterministic) GLM 5.2 call. Serves a canned
  # review carrying a recognisable marker. The skill's curl recipe honours
  # ZAI_BASE_URL, so the journey points it at this local stub.
  local port=8772
  local stub="/tmp/zai-review-stub.js"
  ZAI_MARKER="CONTREE-MOCK-GLM-REVIEW"
  ZAI_HITS="/tmp/zai-stub-hits.log"
  : > "$ZAI_HITS"
  cat > "$stub" <<'JS'
const fs = require('fs')
const http = require('http')
const review = `${process.env.ZAI_MARKER}: the change satisfies the test-tree contract; one nit: name things for what they do.`
http.createServer((req, res) => {
  let body = ''
  req.on('data', (c) => (body += c))
  req.on('end', () => {
    if (req.method === 'POST' && req.url.includes('/chat/completions')) {
      fs.appendFileSync(process.env.ZAI_HITS, `${req.method} ${req.url} ${body}\n`)
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ choices: [{ message: { role: 'assistant', content: review } }] }))
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' })
      res.end('{}')
    }
  })
}).listen(process.env.ZAI_PORT, () => console.error('zai-review-stub listening'))
JS
  ZAI_PORT="$port" ZAI_MARKER="$ZAI_MARKER" ZAI_HITS="$ZAI_HITS" node "$stub" &
  ZAI_STUB_PID=$!

  export ZAI_API_KEY="test-key-mock"
  export ZAI_BASE_URL="http://127.0.0.1:$port/api/paas/v4"
}

# --- Test cases ---

case "$TEST_NAME" in
  mental-model-validator-smoke)
    seed_project "greenfield"

    cat > "$PROJECT_DIR/MENTAL_MODEL.md" <<'MM'
## Core Domain Identity

- placeholder

## World-to-Code Mapping

- placeholder

## Ubiquitous Language

- placeholder

## Bounded Contexts

- placeholder

## Invariants

- placeholder

## Decision Rationale

- placeholder

## Rogue Extra Section

- this heading is not one of the seven
MM
    (cd "$PROJECT_DIR" && git add -A && git commit -q -m "seed: malformed MENTAL_MODEL.md")

    run_agent \
      "Read MENTAL_MODEL.md and add one placeholder bullet to the Invariants section. Save the file. Do nothing else."

    write_verify << 'VERIFY'
Evaluate the transcript against the `post-update-hook` and `mental-model-validator` trees.

The scenario: MENTAL_MODEL.md was seeded malformed (missing the Temporal View
section; contains an extra "Rogue Extra Section" heading that is not one of
the seven named sections). The agent then edits the file. The PostToolUse hook
must fire, invoke the validator, and surface its findings via additionalContext
JSON. Under Codex, `codex exec --json` does not emit hook context entries, so
the harness appends Codex's internal session transcript plus the project-local
hook stdin/stdout logs to make the hook evidence visible.

Expected signals in the transcript:

  - a Codex hook stdin entry whose hook_event_name is "PostToolUse" or hook stdout whose hookEventName is "PostToolUse"
  - additionalContext naming the missing "Temporal View" section
  - additionalContext naming the rogue "Rogue Extra Section" heading
  - Codex's internal session contains the findings as developer context after the apply_patch call

For each `when/then` path in `post-update-hook` and `mental-model-validator`,
return PASS / FAIL / N/A with quoted evidence. Report counts at the end.
VERIFY
    ;;

  layered-workflow)
    # The single end-to-end journey: setup → workflow → drift+sync against an
    # HTTP API fixture that exercises Journey, System, Adapter (driving + driven),
    # Use-case, Domain, ports, and in-memory adapters. Run under both harnesses.
    seed_project "bookmarks-api"

    echo ""
    echo "=== Phase 1: setup ==="
    run_agent \
      "This project has no code yet — read CLAUDE.md for the Mental Model, then run /contree:setup to configure the test framework and generate test trees. This project has HTTP endpoints and a persistence port, so expect trees at multiple layers."

    echo ""
    echo "=== Phase 2: workflow (change → sync → tdd) ==="
    run_agent \
      "Now implement the project. Use /contree:workflow to set expected behaviour in trees and drive the implementation outside-in. The project has a BookmarkRepository port — remember to build an in-memory adapter and a shared port contract suite alongside the file-based production adapter. Skip mutation testing for this run — configure it if setup tells you to, but do not execute Stryker."

    echo ""
    echo "=== Phase 3: drift injection + sync ==="
    HANDLER_FILE="$(find "$PROJECT_DIR/src" -maxdepth 3 \( -name '*.ts' -o -name '*.js' \) -not -name '*.test.*' -not -name '*.spec.*' -print0 | xargs -0 grep -l 'router\|app\.\(get\|post\|delete\|put\)' 2>/dev/null | head -n 1)"
    if [ -n "$HANDLER_FILE" ] && [ -f "$HANDLER_FILE" ]; then
      cat >> "$HANDLER_FILE" <<'DRIFT'

// Drift injected by the journey harness — this endpoint is NOT in the trees.
app.delete('/bookmarks/:id', (req, res) => {
  res.status(204).end()
})
DRIFT
      (cd "$PROJECT_DIR" && git add -A && git commit -q -m "inject drift: DELETE endpoint")
      echo "[harness] Injected drift into $HANDLER_FILE (added DELETE /bookmarks/:id)."
    else
      echo "[harness] WARNING: could not find a route handler to drift. Phase 3 may not see drift."
    fi

    run_agent \
      "Something feels off in this project — please audit for drift between the trees and the implementation, then propose fixes."

    write_verify << VERIFY
Evaluate the transcript against every tree in the plugin's
\`contree/CLAUDE.md\` \`## Test Trees\` section.

Harness under test: **$HARNESS**.

Focus areas:
  - change-decomposes-across-layers (Journey → System → inner-layer decomposition; port decomposition, in-memory + real adapters, shared contract)
  - change-writes-trees (Domain/Use-case/Port-contract trees code-shaped; Journey/System/Adapter trees use consumer vocabulary)
  - outside-in-tdd (outermost failing test pulls inner layers in — a Journey test for a new arc, else System; the Journey is curated and kept under 5 minutes; Use-case wired with in-memory adapters; Adapter runs shared contract; describe/it mirrors trees verbatim; inner units get their own ground-level failing test before code — journey/functional coverage is not coverage)
  - composable-testing (file naming conventions, port contract suite)
  - dual-harness-compatibility (when run under codex: SessionStart rules visible in transcript; PostToolUse hook fires after edits)

Specific layer-shape checks:
  - Inspect TEST_TREES.md — at least one Domain/Use-case/Port-contract tree has top-level nodes named after the unit's functions/methods/operations.
  - Inspect the corresponding test file — describe/it mirrors the tree verbatim.
  - Journey/System/Adapter trees use consumer vocabulary, describe principles not enumerated cases.

Out of scope for this scenario (mark these tree paths N/A, not FAIL):
  - outside-in-tdd: "when all trees for a slice have passing tests then run mutation testing" — the prompt instructs the agent to skip Stryker execution to stay within budget. Stryker should be CONFIGURED (phase 1 setup) but NOT EXECUTED. If the transcript shows the agent ran Stryker anyway, that is a FAIL of obedience to the user instruction, not a tree FAIL.

For each \`when/then\` path in each tree, return one of:

  PASS — transcript demonstrates the assertion (quote evidence)
  FAIL — transcript contradicts the assertion (quote evidence)
  N/A  — the scenario did not exercise this assertion

The trees ARE the checklist. Report results grouped by tree, then a final summary
of PASS / FAIL / N/A counts across all trees.
VERIFY
    ;;

  diff-images)
    # Verifies the user-invoked /contree:diff-for-humans skill end to end against a mocked
    # gpt-image-2 endpoint. Codex model calls use CODEX_HOME auth or CODEX_API_KEY,
    # so the skill can still override OPENAI_API_KEY for the image-generation stub.
    seed_project "greenfield"

    # Introduce an uncommitted, staged change for /diff to depict.
    cat > "$PROJECT_DIR/index.js" <<'JS'
export function add(a, b) {
  return a + b
}
JS
    (cd "$PROJECT_DIR" && git add index.js)

    start_openai_image_stub

    run_agent \
      "Run /contree:diff-for-humans to generate an image of the current change. Use the skill's curl/OpenAI images API recipe exactly so the local mocked gpt-image-2 endpoint is exercised. Do not use any built-in image-generation tool or generated_images mechanism."

    kill "$OPENAI_STUB_PID" 2>/dev/null || true

    # Deterministic verification — no AI eval. We assert the two observable
    # mechanical outcomes: the mocked gpt-image-2 endpoint was called, and the
    # returned image bytes were written to a file in the project.
    pass=1
    if grep -q "images/generations" "$STUB_HITS" && grep -q "gpt-image-2" "$STUB_HITS"; then
      called="PASS — mocked gpt-image-2 images/generations call recorded"
    else
      called="FAIL — no mocked gpt-image-2 images/generations call recorded"
      pass=0
    fi
    if grep -rlF "$STUB_MARKER" "$PROJECT_DIR" --exclude-dir=.git >/dev/null 2>&1; then
      saved="PASS — the returned image bytes were saved to a file in the project"
    else
      saved="FAIL — no file containing the returned image bytes was found"
      pass=0
    fi

    write_verify <<VERIFY
diff-images — deterministic verification (no AI eval):

  $called
  $saved

These cover the diff-images-the-change paths for the gpt-image-2 generation call and
the saved image. The remaining paths — derives the change from git diff; chooses
subject from nature/details/audience; surfaces choices for review; fails loudly —
are covered by the unit test test/diff-images-the-change.bats.
VERIFY

    [ "$pass" -eq 1 ] || { echo "diff-images: FAILED deterministic checks" >&2; exit 1; }
    ;;

  second-opinion)
    # Verifies the user-invoked /contree:second-opinion skill end to end against a
    # mocked Z.AI GLM 5.2 endpoint. Nothing real is billed.
    seed_project "greenfield"

    # A test-tree contract for the skill to send as the review's context.
    cat > "$PROJECT_DIR/TEST_TREES.md" <<'TT'
## adder

```
adder (src: index.js; domain: none)
  when add is called with two numbers
    then their sum is returned
```
TT
    # Completed work for the skill to review.
    cat > "$PROJECT_DIR/index.js" <<'JS'
export function add(a, b) {
  return a + b
}
JS
    (cd "$PROJECT_DIR" && git add -A)
    # An untracked new file, left unstaged — the skill must include files not yet
    # tracked by git in the work it reviews, so this marker must reach the request.
    UNTRACKED_MARKER="CONTREE-UNTRACKED-MARKER"
    cat > "$PROJECT_DIR/subtract.js" <<JS
export function subtract(a, b) {
  return a - b // $UNTRACKED_MARKER
}
JS

    start_zai_review_stub

    run_agent \
      "Use the contree:second-opinion skill to get an independent review of the current change. Read the skill's SKILL.md and follow its Z.AI GLM 5.2 curl recipe exactly: gather git diff plus untracked files, include TEST_TREES.md as the contract, call the chat/completions endpoint with model glm-5.2, and surface GLM 5.2's returned review. Do not perform your own local review instead."

    kill "$ZAI_STUB_PID" 2>/dev/null || true

    # Deterministic verification — no AI eval. Two observable outcomes: the
    # mocked GLM 5.2 chat/completions endpoint was called with the glm-5.2 model,
    # and the review it returned surfaced in the agent's output.
    pass=1
    if grep -q "chat/completions" "$ZAI_HITS" && grep -q "glm-5.2" "$ZAI_HITS"; then
      called="PASS — mocked GLM 5.2 chat/completions call recorded"
    else
      called="FAIL — no mocked GLM 5.2 chat/completions call recorded"
      pass=0
    fi
    if grep -qF "$ZAI_MARKER" "$TRANSCRIPT_FILE"; then
      surfaced="PASS — GLM 5.2's returned review surfaced in the agent output"
    else
      surfaced="FAIL — GLM 5.2's returned review did not surface in the agent output"
      pass=0
    fi
    if grep -qF "$UNTRACKED_MARKER" "$ZAI_HITS"; then
      untracked="PASS — the untracked new file reached the GLM 5.2 review request"
    else
      untracked="FAIL — the untracked new file did not reach the GLM 5.2 review request"
      pass=0
    fi

    write_verify <<VERIFY
second-opinion — deterministic verification (no AI eval):

  $called
  $surfaced
  $untracked

These cover the second-opinion-reviews-completed-work paths for the GLM 5.2 review
call, the surfaced review, and that the work it gathers includes new files not yet
tracked by git. The remaining paths — determines the work from any natural-language
indication; absent one reviews the last non-trivial, naturally grouped changes;
reads the test trees as the contract; stops without calling the API when there are
no non-trivial changes; fails loudly — are covered by the unit test
test/second-opinion-reviews-completed-work.bats.
VERIFY

    [ "$pass" -eq 1 ] || { echo "second-opinion: FAILED deterministic checks" >&2; exit 1; }
    ;;

  second-opinion-live)
    # LIVE — real GLM 5.2 inference against the real Z.AI API (no stub). Billable
    # and non-deterministic, so it is NOT in the auto MATRIX; run manually with a
    # real ZAI_API_KEY. Plants a deliberate bug that contradicts the test-tree
    # contract and checks the real review caught it.
    : "${ZAI_API_KEY:?second-opinion-live needs a real ZAI_API_KEY in the environment}"
    seed_project "greenfield"

    cat > "$PROJECT_DIR/TEST_TREES.md" <<'TT'
## adder

```
adder (src: index.js; domain: none)
  when add is called with two numbers
    then their sum is returned
```
TT
    # Deliberate bug: the contract says "their sum is returned", the code subtracts.
    cat > "$PROJECT_DIR/index.js" <<'JS'
export function add(a, b) {
  return a - b
}
JS
    (cd "$PROJECT_DIR" && git add -A)

    run_agent \
      "Run /contree:second-opinion to get an independent review of the current change."

    echo ""
    echo "=== GLM 5.2 review (extracted from transcript) ==="
    jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
      "$TRANSCRIPT_FILE" 2>/dev/null | tail -60

    write_verify <<'VERIFY'
second-opinion-live — real GLM 5.2 inference (manual judgement):

The fixture plants a deliberate bug — TEST_TREES.md says `add` returns the SUM, but
index.js returns `a - b` (subtraction). The skill sent the diff + the trees to the
real Z.AI GLM 5.2 endpoint. Read the extracted review above (and the full transcript)
and judge: did GLM 5.2 catch that the implementation contradicts the contract?
VERIFY
    ;;

  describe-it-drift)
    seed_project "describe-it-drift"

    run_agent \
      "Check this project for drift between the test trees and the test files. When you find describe/it drift, present both sides and ask which side is authoritative. Do not silently choose a side, and do not modify files."

    write_verify << 'VERIFY'
Evaluate the transcript against the `sync-audits-and-resolves` tree,
specifically the describe/it drift case.

The fixture: one tree named `Bookmark` with paths
  `parseUrl / when called with an https URL / then the canonical form is returned`
  `parseUrl / if called with a non-URL string / then InvalidUrl is thrown`
and a test file `src/bookmark.domain.test.js` whose describe/it hierarchy is
  `Bookmark / URL handling / returns canonical https form`
  `Bookmark / URL handling / throws for garbage input`
The code and the tree agree — only the test file's structure has drifted.

Expected signals in the transcript:

  - the agent invokes /contree:sync or follows the sync process
  - the agent identifies describe/it drift — the test file's describe/it hierarchy
    does not mirror the tree verbatim
  - the agent presents BOTH the tree paths AND the test file's describe/it structure
    to the user
  - the agent asks the user which side is authoritative — does NOT silently pick

For each expected signal, return PASS / FAIL / N/A with quoted evidence.
Report counts at the end.
VERIFY
    ;;

  *)
    echo "Unknown test: $TEST_NAME" >&2
    echo ""
    echo "Available tests:"
    echo "  layered-workflow              — HTTP API: setup → workflow → drift → sync (every tree, every layer)"
    echo "  mental-model-validator-smoke  — one-shot: malformed MM + agent edit → verifies PostToolUse hook + validator"
    echo "  describe-it-drift             — one-shot: pre-seeded describe/it mismatch → verifies sync flags it"
    echo "  diff-images                   — one-shot: staged change + mocked gpt-image-2 → verifies /contree:diff-for-humans generates an image of the change"
    echo "  second-opinion                — one-shot: staged change + mocked GLM 5.2 → verifies /contree:second-opinion reviews the change"
    echo "  second-opinion-live           — LIVE (billable, manual): planted bug + real GLM 5.2 → checks the real review catches it"
    echo ""
    echo "Harness (2nd arg): claude | codex (default claude)"
    exit 1
    ;;
esac

assert_no_hook_runner_errors

echo ""
echo "Transcript: $TRANSCRIPT_FILE"
echo "Verify:     $VERIFY_FILE"
