#!/usr/bin/env bash
set -euo pipefail

# Runs a contree journey case against a coding-agent harness.
# Works both inside Docker (called by docker-run.sh) and directly on the host.
#
# Expects:
#   - For claude: DEEPSEEK_API_KEY (via docker-run.sh DeepSeek env vars)
#   - For codex:  DEEPSEEK_API_KEY
#   - $1 is the test name (layered-workflow | describe-it-drift | diff-images | second-opinion | second-opinion-live)
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
CODEX_DEEPSEEK_PROXY_PORT=8783
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
CODEX_DEEPSEEK_PROXY_PID=0

prime_codex_plugin() {
  # Codex reads cached plugins from ~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/
  # plus a config.toml entry that enables the plugin and the under-development
  # plugin_hooks feature (without it, hook scripts in hooks.json are ignored).
  # See codex-rs/core/src/plugins/manager_tests.rs::plugins_for_config_reloads_when_plugin_hooks_enablement_changes.
  [ "$CODEX_PRIMED" -eq 1 ] && return 0
  CODEX_PRIMED=1

  rm -rf "$CODEX_TEST_HOME"
  mkdir -p "$CODEX_TEST_HOME"

  local cache_dir="$CODEX_TEST_HOME/plugins/cache/local-marketplace/contree/local"
  rm -rf "$cache_dir"
  mkdir -p "$(dirname "$cache_dir")"
  cp -r "$CONTREE_ROOT" "$cache_dir"

  mkdir -p "$PROJECT_DIR/.codex"
  {
    echo ".codex/"
    echo ".codex-home/"
  } >> "$PROJECT_DIR/.git/info/exclude"

  cat > "$CODEX_TEST_HOME/config.toml" <<CONFIG
model = "deepseek-chat"
model_provider = "deepseek"
model_reasoning_effort = "low"

[features]
hooks = true
plugin_hooks = true

[shell_environment_policy]
inherit = "all"

[plugins."contree@local-marketplace"]
enabled = true

[model_providers.deepseek]
name = "DeepSeek"
base_url = "http://127.0.0.1:$CODEX_DEEPSEEK_PROXY_PORT/v1"
env_key = "DEEPSEEK_API_KEY"
wire_api = "responses"
CONFIG

  cat >> "$CODEX_TEST_HOME/config.toml" <<CONFIG

[projects."$PROJECT_DIR"]
trust_level = "trusted"

[projects."/private${PROJECT_DIR}"]
trust_level = "trusted"
CONFIG

  export CODEX_HOME="$CODEX_TEST_HOME"

  if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
    echo "Codex harness requires DEEPSEEK_API_KEY" >&2
    exit 1
  fi

  CODEX_DEEPSEEK_PROXY_PORT="$CODEX_DEEPSEEK_PROXY_PORT" node "$CONTREE_ROOT/test/journey/codex-deepseek-responses-proxy.mjs" &
  CODEX_DEEPSEEK_PROXY_PID=$!
  trap 'kill "$CODEX_DEEPSEEK_PROXY_PID" 2>/dev/null || true' EXIT
  for _ in $(seq 1 50); do
    curl -fsS "http://127.0.0.1:$CODEX_DEEPSEEK_PROXY_PORT/health" >/dev/null 2>&1 && break
    sleep 0.1
  done
  curl -fsS "http://127.0.0.1:$CODEX_DEEPSEEK_PROXY_PORT/health" >/dev/null
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

}

write_verify() {
  cat > "$VERIFY_FILE"
  echo ""
  cat "$VERIFY_FILE"
}

assert_no_hook_runner_errors() {
  local matches
  matches="$(grep -Ein "(SessionStart|Stop|PreToolUse|PostToolUse|UserPromptSubmit|Notification) hook \(failed\)|hook exited with code|exec: .*: not found" "$TRANSCRIPT_FILE" || true)"
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
  setup)
    seed_project "setup-existing"

    setup_prompt="Run /contree:setup for the comprehensive luxury setup of this existing pure JavaScript project. The operator agrees that the existing Vitest choice, documented hexagonal architecture, current short-code behaviour, and mutation break threshold of 50 are the intended consequential decisions. Dynamically run every missing focused setup skill, including setup-mental-model and setup-test-trees through bootstrap-test-trees. Use the required discovery and implementation subagent waves, bootstrap the current production behaviour into test trees and tests, and progressively expand both coding harnesses with project-local SessionStart, PostToolUse, and Stop steering for the mental model, test trees, impacted tests, lint, architecture, and relevant incremental mutation feedback. Run and fix every configured feedback command including mutation testing. Do not create Docker configuration."
    run_agent "$setup_prompt"

    bootstrap_pass=1
    bootstrapped_tests="$(find "$PROJECT_DIR/src" "$PROJECT_DIR/test" -type f \( -name '*.test.*' -o -name '*.spec.*' \) -print 2>/dev/null || true)"
    if [ -z "$bootstrapped_tests" ] || ! grep -Eq '^(Journey|System|Component|Adapter|Use-case|Domain|Port): ' "$PROJECT_DIR/TEST_TREES.md"; then
      echo "Comprehensive setup did not bootstrap the existing behaviour into trees and tests" >&2
      bootstrap_pass=0
    fi
    if [ "$HARNESS" = "claude" ] && ! grep -q '"name":"Task"' "$TRANSCRIPT_FILE"; then
      echo "Comprehensive setup did not use required subagent waves" >&2
      bootstrap_pass=0
    fi
    if [ "$HARNESS" = "codex" ] && ! grep -Eq 'spawn_agent|"name":"collaboration.spawn_agent"' "$TRANSCRIPT_FILE"; then
      echo "Comprehensive setup did not use required subagent waves" >&2
      bootstrap_pass=0
    fi
    if ! (cd "$PROJECT_DIR" && npm test && npm run test:functional && npm run test:mutate); then
      echo "Comprehensive setup did not leave normal, functional, and mutation feedback green" >&2
      bootstrap_pass=0
    fi

    mkdir -p "$PROJECT_DIR/src" "$PROJECT_DIR/test/system"
    printf '%s\n' "export const alpha = () => 'alpha'" > "$PROJECT_DIR/src/alpha.js"
    printf '%s\n' "export const beta = () => 'beta'" > "$PROJECT_DIR/src/beta.js"
    printf '%s\n' \
      "import { describe, expect, it } from 'vitest'" \
      "import { alpha } from './alpha.js'" \
      "describe('alpha impact probe', () => {" \
      "  it('returns alpha', () => {" \
      "    expect(alpha()).toBe('alpha')" \
      "  })" \
      "})" > "$PROJECT_DIR/src/alpha.unit.test.js"
    printf '%s\n' \
      "import { describe, expect, it } from 'vitest'" \
      "import { beta } from './beta.js'" \
      "describe('beta impact probe', () => {" \
      "  it('returns beta', () => {" \
      "    expect(beta()).toBe('beta')" \
      "  })" \
      "})" > "$PROJECT_DIR/src/beta.unit.test.js"
    printf '%s\n' \
      "import { describe, expect, it } from 'vitest'" \
      "describe('functional exclusion probe', () => {" \
      "  it('stays outside changed normal tests', () => {" \
      "    expect(true).toBe(true)" \
      "  })" \
      "})" > "$PROJECT_DIR/test/system/excluded.system.test.js"

    changed_test_script="$(jq -r 'if .scripts["test-changed"] then "test-changed" elif .scripts["test:changed"] then "test:changed" else "" end' "$PROJECT_DIR/package.json")"
    baseline_output="$PROJECT_DIR/test-changed-baseline.txt"
    impact_output="$PROJECT_DIR/test-changed-impact.txt"
    failure_output="$PROJECT_DIR/test-changed-failure.txt"
    pass="$bootstrap_pass"

    if [ -z "$changed_test_script" ] || ! (cd "$PROJECT_DIR" && npm run "$changed_test_script") > "$baseline_output" 2>&1; then
      echo "test-changed did not establish its baseline through the normal test command" >&2
      [ -f "$baseline_output" ] && cat "$baseline_output" >&2
      pass=0
    elif ! grep -q 'alpha impact probe' "$baseline_output" || ! grep -q 'beta impact probe' "$baseline_output" || grep -q 'functional exclusion probe' "$baseline_output"; then
      echo "test-changed baseline did not run exactly the normal tests" >&2
      cat "$baseline_output" >&2
      pass=0
    fi

    printf '%s\n' "export const alpha = () => ['alpha'].join('')" > "$PROJECT_DIR/src/alpha.js"
    if [ -n "$changed_test_script" ] && (cd "$PROJECT_DIR" && npm run "$changed_test_script") > "$impact_output" 2>&1; then
      if ! grep -q 'alpha impact probe' "$impact_output" || grep -q 'beta impact probe' "$impact_output" || grep -q 'functional exclusion probe' "$impact_output"; then
        echo "test-changed did not select only the impacted normal test since its baseline" >&2
        cat "$impact_output" >&2
        pass=0
      fi
    else
      echo "test-changed failed after one source file changed" >&2
      [ -f "$impact_output" ] && cat "$impact_output" >&2
      pass=0
    fi

    printf '%s\n' "export const alpha = () => 'wrong'" > "$PROJECT_DIR/src/alpha.js"
    set +e
    (cd "$PROJECT_DIR" && bash .contree/hooks/test-changed.sh) > "$failure_output" 2>&1
    failure_status=$?
    set -e
    if [ "$failure_status" -ne 2 ] || ! grep -Eq 'FAIL|AssertionError|expected.*alpha' "$failure_output"; then
      echo "test-changed save hook did not preserve failure output and exit 2" >&2
      cat "$failure_output" >&2
      pass=0
    fi
    printf '%s\n' "export const alpha = () => ['alpha'].join('')" > "$PROJECT_DIR/src/alpha.js"

    if [ "$HARNESS" = "codex" ]; then
      if [ "$pass" -eq 0 ]; then
        AGENT_CALL_COUNT=0
        run_agent "Run /contree:setup now without creating a plan or todo list. Repair only package.json and merged PostToolUse entries in .claude/settings.json and .codex/hooks.json. Do not modify the maintained .contree/scripts/test-changed.mjs runner or .contree/hooks/test-changed.sh wrapper, install dependencies, stage or restore files, or create tests or documentation. The package command must invoke the existing runner and both PostToolUse configs must invoke the existing wrapper after Edit or Write. This verification has alpha and beta probes: the clean first call must print both; after only alpha.js changes the second call must print alpha and must not print beta. Verify exactly that behavior before ending."
      fi
      AGENT_CALL_COUNT=0
      hook_verification_prompt="Do not inspect or read project files. First state the distinctive six-character short-code invariant supplied by the freshly loaded project steering. Then use file-editing tools to set package.json description to exactly 'Contree setup hook verification' and make one semantics-preserving formatting edit to src/shortcode.js. Immediately stop so the freshly loaded project save and Stop hooks run. Do not invoke hook scripts manually and make no other changes."
    elif [ "$pass" -eq 1 ]; then
      hook_verification_prompt="Do not inspect or read project files. First state the distinctive six-character short-code invariant supplied by the freshly loaded project steering. Then use file-editing tools to set package.json description to exactly 'Contree setup hook verification' and make one semantics-preserving formatting edit to src/shortcode.js. Immediately stop so the freshly loaded project save and Stop hooks run. Do not invoke hook scripts manually and do not create tests."
    else
      hook_verification_prompt="The functional setup verification found that test-changed did not correctly establish or use its machine-local baseline. Diagnose and fix that setup output. Then verify the project save hooks through an actual edit: use a file-editing tool to set package.json description to exactly 'Contree setup hook verification' and confirm the freshly loaded save hooks run before continuing. Do not create tests."
    fi
    run_agent "$hook_verification_prompt"

    find "$PROJECT_DIR/.contree" -type f ! -path "$PROJECT_DIR/.contree/hooks/*" ! -path "$PROJECT_DIR/.contree/scripts/*" -delete
    printf '%s\n' "export const alpha = () => 'alpha'" > "$PROJECT_DIR/src/alpha.js"
    pass=1

    if ! (cd "$PROJECT_DIR" && npm run "$changed_test_script") > "$baseline_output" 2>&1; then
      echo "repaired test-changed did not establish its baseline through the normal test command" >&2
      cat "$baseline_output" >&2
      pass=0
    elif ! grep -q 'alpha impact probe' "$baseline_output" || ! grep -q 'beta impact probe' "$baseline_output" || grep -q 'functional exclusion probe' "$baseline_output"; then
      echo "repaired test-changed baseline did not run exactly the normal tests" >&2
      cat "$baseline_output" >&2
      pass=0
    fi

    printf '%s\n' "export const alpha = () => ['alpha'].join('')" > "$PROJECT_DIR/src/alpha.js"
    if (cd "$PROJECT_DIR" && npm run "$changed_test_script") > "$impact_output" 2>&1; then
      if ! grep -q 'alpha impact probe' "$impact_output" || grep -q 'beta impact probe' "$impact_output" || grep -q 'functional exclusion probe' "$impact_output"; then
        echo "repaired test-changed did not select only the impacted normal test since its baseline" >&2
        cat "$impact_output" >&2
        pass=0
      fi
    else
      echo "repaired test-changed failed after one source file changed" >&2
      cat "$impact_output" >&2
      pass=0
    fi

    printf '%s\n' "export const alpha = () => 'wrong'" > "$PROJECT_DIR/src/alpha.js"
    set +e
    (cd "$PROJECT_DIR" && bash .contree/hooks/test-changed.sh) > "$failure_output" 2>&1
    failure_status=$?
    set -e
    if [ "$failure_status" -ne 2 ] || ! grep -Eq 'FAIL|AssertionError|expected.*alpha' "$failure_output"; then
      echo "repaired test-changed save hook did not preserve failure output and exit 2" >&2
      cat "$failure_output" >&2
      pass=0
    fi

    rm -f "$PROJECT_DIR/src/alpha.js" "$PROJECT_DIR/src/beta.js" "$PROJECT_DIR/src/alpha.unit.test.js" "$PROJECT_DIR/src/beta.unit.test.js" "$PROJECT_DIR/test/system/excluded.system.test.js" "$baseline_output" "$impact_output" "$failure_output"

    for path in TEST_TREES.md MENTAL_MODEL.md .claude/settings.json .codex/hooks.json .contree/hooks/test-changed.sh .contree/hooks/lint-on-save.sh .contree/hooks/architecture-on-stop.sh .contree/hooks/load-mental-model.sh .contree/hooks/reconcile-mental-model.sh .contree/hooks/test-trees-session-start.sh .contree/hooks/test-trees-on-stop.sh .contree/hooks/mutation-on-stop.sh; do
      if [ ! -f "$PROJECT_DIR/$path" ]; then
        echo "Missing setup output: $path" >&2
        pass=0
      fi
    done

    for path in .contree/hooks/test-changed.sh .contree/hooks/lint-on-save.sh .contree/hooks/architecture-on-stop.sh .contree/hooks/load-mental-model.sh .contree/hooks/reconcile-mental-model.sh .contree/hooks/test-trees-session-start.sh .contree/hooks/test-trees-on-stop.sh .contree/hooks/mutation-on-stop.sh; do
      if [ ! -x "$PROJECT_DIR/$path" ]; then
        echo "Setup output is not executable: $path" >&2
        pass=0
      fi
    done

    if ! jq -e '
      .description == "Contree setup hook verification" and
      (.scripts.test | type == "string") and
      (.scripts["test:functional"] | type == "string") and
      ((.scripts["test-changed"] // .scripts["test:changed"]) | type == "string") and
      (.scripts["test:mutate"] | type == "string") and
      (.scripts["test:mutate:changed"] | type == "string") and
      (.scripts["lint"] | type == "string") and
      (.scripts["lint:code"] | type == "string") and
      (.scripts["lint:code:fix"] | type == "string") and
      (.scripts["lint:arch"] | type == "string")
    ' "$PROJECT_DIR/package.json" >/dev/null; then
      echo "Setup did not create the required native project commands or the hook verification edit was not preserved" >&2
      pass=0
    fi

    for config in .claude/settings.json .codex/hooks.json; do
      if [ -f "$PROJECT_DIR/$config" ] && ! jq -e '
        ([.hooks.PostToolUse[]?.hooks[]?.command] | any(contains(".contree/hooks/lint-on-save.sh"))) and
        ([.hooks.PostToolUse[]? | select(.matcher == "Edit|Write") | .hooks[]?.command] | any(contains(".contree/hooks/test-changed.sh"))) and
        ([.hooks.Stop[]?.hooks[]?.command] | any(contains(".contree/hooks/architecture-on-stop.sh")))
      ' "$PROJECT_DIR/$config" >/dev/null; then
        echo "Setup did not configure every project hook in $config" >&2
        pass=0
      fi
    done

    expected_mental_model_headings=$'## Core Domain Identity\n## World-to-Code Mapping\n## Ubiquitous Language\n## Bounded Contexts\n## Invariants\n## Decision Rationale\n## Temporal View'
    actual_mental_model_headings="$(grep '^## ' "$PROJECT_DIR/MENTAL_MODEL.md" 2>/dev/null || true)"
    if [ "$actual_mental_model_headings" != "$expected_mental_model_headings" ]; then
      echo "Setup did not create the seven mental-model sections in order" >&2
      pass=0
    fi

    created_tests="$(find "$PROJECT_DIR" \( -path "$PROJECT_DIR/node_modules" -o -path "$PROJECT_DIR/.codex-home" -o -path "$PROJECT_DIR/.git" \) -prune -o -type f \( -name '*.test.*' -o -name '*.spec.*' \) -print)"
    if [ -z "$created_tests" ]; then
      echo "Setup did not retain bootstrapped test files:" >&2
      pass=0
    fi

    if find "$PROJECT_DIR" -maxdepth 2 -type f \( -name 'docker-compose.yml' -o -name 'compose.yml' \) | grep -q .; then
      echo "Setup created Docker configuration for a pure in-process project" >&2
      pass=0
    fi

    assert_no_hook_runner_errors

    write_verify <<VERIFY
setup — deterministic functional verification under $HARNESS:

  project preparation: $([ "$pass" -eq 1 ] && echo PASS || echo FAIL)
  test-changed baseline and impact selection: $([ "$pass" -eq 1 ] && echo PASS || echo FAIL)
  failing impacted test output and exit 2: $([ "$pass" -eq 1 ] && echo PASS || echo FAIL)
  actual edit after loading project hooks: $(jq -r '.description' "$PROJECT_DIR/package.json" 2>/dev/null || echo FAIL)
  normal command: $(jq -r '.scripts.test // "FAIL"' "$PROJECT_DIR/package.json" 2>/dev/null)
  functional command: $(jq -r '.scripts["test:functional"] // "FAIL"' "$PROJECT_DIR/package.json" 2>/dev/null)
  changed-test command: $(jq -r '.scripts["test-changed"] // .scripts["test:changed"] // "FAIL"' "$PROJECT_DIR/package.json" 2>/dev/null)
  Claude Code hooks: $([ -f "$PROJECT_DIR/.claude/settings.json" ] && echo configured || echo FAIL)
  Codex hooks: $([ -f "$PROJECT_DIR/.codex/hooks.json" ] && echo configured || echo FAIL)
  bootstrapped test files: $([ -n "$created_tests" ] && echo present || echo FAIL)
  unnecessary Docker configuration: $([ ! -f "$PROJECT_DIR/docker-compose.yml" ] && [ ! -f "$PROJECT_DIR/compose.yml" ] && echo none || echo FAIL)
VERIFY

    [ "$pass" -eq 1 ] || { echo "setup: FAILED deterministic checks" >&2; exit 1; }
    ;;

  layered-workflow)
    # The single end-to-end journey: setup → change-without-me → drift+sync against an
    # HTTP API fixture that exercises Journey, System, Adapter (driving + driven),
    # Use-case, Domain, ports, and in-memory adapters. Run under both harnesses.
    seed_project "bookmarks-api"

    echo ""
    echo "=== Phase 1: setup ==="
    run_agent \
      "This project has no code yet — read CLAUDE.md for the Mental Model, then run /contree:setup to configure the test framework and create TEST_TREES.md when needed. This project has HTTP endpoints and a persistence port. Configure mutation testing if setup calls for it, but do not execute Stryker in this run."

    echo ""
    echo "=== Phase 2: change-without-me (change → sync → tdd) ==="
    run_agent \
      "Now implement the project. Use /contree:change-without-me to set expected behaviour in trees and drive the implementation outside-in. The project has a BookmarkRepository port — remember to build an in-memory adapter and a shared port contract suite alongside the file-based production adapter. Skip mutation testing for this run — configure it if setup tells you to, but do not execute Stryker."

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
  - change-writes-trees (every layer is consumer-driven; inner trees describe what the outer consumer needs from the unit it forced into existence)
  - outside-in-tdd (outermost failing test pulls inner layers in — a Journey test for a new arc, else System; the Journey is curated and kept under 5 minutes; Use-case wired with in-memory adapters; Adapter runs shared contract; describe/it mirrors trees verbatim; inner units get their own ground-level failing test before code — journey/functional coverage is not coverage)
  - composable-testing (file naming conventions, port contract suite)
  - dual-harness-compatibility (when run under codex: SessionStart rules visible in transcript)

Specific consumer-driven checks:
  - Inspect TEST_TREES.md — Domain/Use-case/Port-contract trees describe what the outer consumer needs to observe from the unit it forced into existence.
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
    # gpt-image-2 endpoint. Codex model calls use DEEPSEEK_API_KEY,
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
      "Run only /contree:diff-for-humans for the current staged change. This is not setup, change-without-me, sync, tdd, second-opinion, or project implementation work. Do not install packages, do not create TEST_TREES.md, do not create README.md, do not create MENTAL_MODEL.md, and do not change source code except writing the returned image file. Read skills/diff-for-humans/SKILL.md, gather the staged git diff, call the skill's curl/OpenAI images API recipe exactly against OPENAI_BASE_URL with model gpt-image-2-2026-04-21, decode data[0].b64_json, save the png, and stop."

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
    if grep -rlF "$STUB_MARKER" "$PROJECT_DIR" --exclude-dir=.git --exclude-dir=.codex --exclude-dir=.codex-home --exclude='docker-entrypoint.sh' >/dev/null 2>&1; then
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
      "Run sync on this project. Resolve every drift issue you find using TEST_TREES.md as the operator contract and your own judgment. Modify the project as needed, verify the result, and ask only if a consequential choice is genuinely under-determined."

    pass=1
    if grep -Eiq "(/contree:sync|sync process|drift between the test trees|drift detected)" "$TRANSCRIPT_FILE"; then
      follows_sync="PASS — transcript follows the sync/drift process"
    else
      follows_sync="FAIL — transcript does not show sync/drift process"
      pass=0
    fi
    if grep -Eiq "describe/it.*drift|describe.*it.*does not (mirror|match)|hierarchy.*drift" "$TRANSCRIPT_FILE"; then
      identifies_drift="PASS — transcript identifies describe/it hierarchy drift"
    else
      identifies_drift="FAIL — transcript does not identify describe/it hierarchy drift"
      pass=0
    fi
    if grep -q "describe('parseUrl'" "$PROJECT_DIR/src/bookmark.domain.test.js" \
      && grep -q "describe('when called with an https URL'" "$PROJECT_DIR/src/bookmark.domain.test.js" \
      && grep -q "it('then the canonical form is returned'" "$PROJECT_DIR/src/bookmark.domain.test.js" \
      && grep -q "describe('if called with a non-URL string'" "$PROJECT_DIR/src/bookmark.domain.test.js" \
      && grep -q "it('then InvalidUrl is thrown'" "$PROJECT_DIR/src/bookmark.domain.test.js"; then
      mirrors_tree="PASS — test hierarchy now mirrors the tree"
    else
      mirrors_tree="FAIL — test hierarchy does not mirror the tree"
      pass=0
    fi
    if grep -q "expect" "$PROJECT_DIR/src/bookmark.domain.test.js" \
      && grep -Eq "toBe|toEqual" "$PROJECT_DIR/src/bookmark.domain.test.js" \
      && grep -Eq "toThrow|InvalidUrl" "$PROJECT_DIR/src/bookmark.domain.test.js"; then
      tests_intention="PASS — tests assert the intention expressed by both leaves"
    else
      tests_intention="FAIL — tests do not assert the intention expressed by both leaves"
      pass=0
    fi
    if grep -Eiq "which side is authoritative|should I align the test file|update the tree to match|request_user_input is unavailable" "$TRANSCRIPT_FILE"; then
      acts_without_asking="FAIL — transcript asks the operator to resolve deterministic drift"
      pass=0
    else
      acts_without_asking="PASS — deterministic drift is resolved without asking the operator"
    fi

    write_verify <<VERIFY
describe-it-drift — deterministic verification (no AI eval):

  $follows_sync
  $identifies_drift
  $mirrors_tree
  $tests_intention
  $acts_without_asking

These cover the describe/it drift path from sync-audits-and-resolves for this
functional fixture: the agent follows sync, identifies structural test drift,
uses the tree as the operator contract, and proactively makes the tests fulfil it.
VERIFY

    [ "$pass" -eq 1 ] || { echo "describe-it-drift: FAILED deterministic checks" >&2; exit 1; }
    ;;

  *)
    echo "Unknown test: $TEST_NAME" >&2
    echo ""
    echo "Available tests:"
    echo "  setup                         — setup configures and verifies a project under both coding harnesses"
    echo "  layered-workflow              — HTTP API: setup → change-without-me → drift → sync (every tree, every layer)"
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
