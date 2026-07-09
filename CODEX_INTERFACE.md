# Codex Integration Surface

This file records what this repo relies on when its plugins run under Codex CLI.
It is intentionally about the agent/plugin boundary, not plugin business logic.

## Plugin Packaging

- Codex plugins use `.codex-plugin/plugin.json`.
- The Contree manifest declares shared skills with `"skills": "./skills/"` and shared hooks with `"hooks": "./hooks/hooks.json"`.
- Codex can install local plugins through a marketplace/cache location such as `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/`.
- The same plugin source directory can serve Claude Code and Codex when both manifests point at shared `skills/` and `hooks/`.

## Required Codex Config

- Hooks must be enabled for the Codex installation that runs the plugin.
- Current Contree functional harness enables both keys in isolated `CODEX_HOME`:

```toml
[features]
hooks = true
plugin_hooks = true

[shell_environment_policy]
inherit = "all"
```

- `shell_environment_policy.inherit = "all"` is required when hook scripts need the same PATH and toolchain that the interactive shell has. This fixed the original `node` not found / hook exit 127 class of failures.
- Dockerized Codex journeys use `DEEPSEEK_API_KEY` from `.env` as the shared functional-test credential.
- The harness writes an isolated `CODEX_HOME/config.toml` with a custom `deepseek` model provider, `wire_api = "responses"`, `env_key = "DEEPSEEK_API_KEY"`, and `base_url` pointing at the harness-local Responses boundary.
- Current Codex rejects `wire_api = "chat"` and requires `wire_api = "responses"` for custom providers. DeepSeek does not expose `/v1/responses`, so Contree's functional harness starts `test/journey/codex-deepseek-responses-proxy.mjs` and points Codex at `http://127.0.0.1:<port>/v1`.
- The local boundary forwards model calls to `https://api.deepseek.com/v1/chat/completions` with the same `DEEPSEEK_API_KEY` and maps the chat-completions message/tool-call shape back to the Responses event stream Codex expects.
- Codex can emit Responses tool schemas that DeepSeek's chat-completions validator rejects, including tools with missing or null object schema fields. The harness boundary normalizes those schemas to object-shaped JSON Schema before forwarding.
- Codex sends tool results back through Responses `input` items. The harness boundary feeds those results into the next DeepSeek chat-completions request as user context and skips prior assistant `function_call` input items so DeepSeek does not reject the conversation for unmatched `tool_calls`.
- The harness fails fast when `DEEPSEEK_API_KEY` is missing instead of falling back to a Codex app/session account, `CODEX_API_KEY`, `OPENAI_API_KEY`, or copied `~/.codex/auth.json`.

## Hook Environment

- Codex sets `CLAUDE_PLUGIN_ROOT` for plugin-bundled hook commands. Contree also treats `PLUGIN_ROOT` as available where relevant, but shared scripts use `CLAUDE_PLUGIN_ROOT`.
- Codex hook commands run with the session cwd as the project directory.
- Codex hook stdin includes:
  - `session_id`
  - `turn_id`
  - `transcript_path`
  - `cwd`
  - `hook_event_name`
  - `tool_name`
  - `tool_input`
  - `tool_response`
  - `tool_use_id`
- Codex does not always provide `CLAUDE_PROJECT_DIR`. Shared hooks that need a project root should default it from `PWD` and export it for child scripts.

## Tool Names And Edit Payloads

- Codex file edits arrive at `PostToolUse` as `tool_name: "apply_patch"`.
- The edited files are inside `tool_input.command` as apply-patch headers:
  - `*** Add File: <path>`
  - `*** Update File: <path>`
  - `*** Delete File: <path>`
- Contree therefore matches `Edit|Write|MultiEdit|apply_patch` and parses patch headers in `hooks/post-update-check.sh`.
- Claude-style `tool_input.file_path` is still supported by the same hook for Claude Code.

## Hook Output

- Codex accepts Claude-style JSON hook output:

```json
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"..."}}
```

- In Codex internal session transcripts, that `additionalContext` appears as developer-context messages after the tool call.
- `codex exec --json` does not emit those internal hook-context messages in its stdout stream. Functional tests that need to assert hook context must append Codex's internal session transcript and/or explicit hook stdin/stdout logs.

## Functional Harness Notes

- Contree's Codex journey harness uses an isolated `CODEX_HOME` under the fixture project so tests do not overwrite the user's real `~/.codex/config.toml`.
- The harness does not copy account auth from `~/.codex/auth.json`; all Codex functional runs use the isolated DeepSeek provider config plus the harness-local Responses boundary.
- The harness primes the plugin cache, enables hooks, and trusts both `/tmp/...` and `/private/tmp/...` project paths because macOS may surface either path in Codex transcripts.
- Plugin-bundled `Stop` and `SessionStart` hooks are visible in Codex sessions.
- For `PostToolUse`, the harness installs a project-local shim that invokes the plugin's real `post-update-check.sh`, because this path is directly observable and gives deterministic stdin/stdout logs for functional assertions.
- Hook runner failures are treated as functional failures by scanning transcripts for explicit hook-runner phrases such as `<HookEvent> hook (failed)`, `hook exited with code`, and `exec: ... not found`.
- Transcript scanners must avoid broad patterns like `hook .*failed` or bare `command not found`: Codex stores command output as JSON string fields, so a single line can contain ordinary test-framework text such as `Hook timed out` plus unrelated `failed` counts.
- When a functional journey forbids executing an expensive tool such as Stryker, state that in every phase prompt that could trigger it. Setup may configure mutation testing and still be tempted to verify by running it unless the setup prompt says not to.
- API-backed skill journeys route deterministic stubs through explicit base URL variables such as `OPENAI_BASE_URL` and `ZAI_BASE_URL`. Do not rely on a PATH-shadowed `curl` shim for Codex subprocesses; Codex shell execution may call the real endpoint even when the parent harness prepended a shim directory.
