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
- A Codex app/session account is not automatically available to child `codex exec` processes launched by tests. Functional journeys need authentication material visible to the CLI through `CODEX_HOME` or `CODEX_API_KEY`.
- Account-backed Codex runs can use `~/.codex/auth.json`. Do not set a dummy `CODEX_API_KEY`; Codex treats it as a real API key and fails authentication.
- A mounted `auth.json` can still be unusable when the refresh token has been revoked; Codex then fails before plugin behavior starts with `refresh_token_invalidated` / `token_revoked`, and the remedy is to log in again or provide a valid `CODEX_API_KEY`.
- Dockerized Codex journeys either pass `CODEX_API_KEY` when `OPENAI_API_KEY` is set, or mount the host `~/.codex/auth.json` read-only into `/home/testuser/.codex/auth.json` for account-backed auth.

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
- The harness copies account auth from `~/.codex/auth.json` when present.
- The harness primes the plugin cache, enables hooks, and trusts both `/tmp/...` and `/private/tmp/...` project paths because macOS may surface either path in Codex transcripts.
- Plugin-bundled `Stop` and `SessionStart` hooks are visible in Codex sessions.
- For `PostToolUse`, the harness installs a project-local shim that invokes the plugin's real `post-update-check.sh`, because this path is directly observable and gives deterministic stdin/stdout logs for functional assertions.
- Hook runner failures are treated as functional failures by scanning transcripts for explicit hook-runner phrases such as `<HookEvent> hook (failed)`, `hook exited with code`, and `exec: ... not found`.
- Transcript scanners must avoid broad patterns like `hook .*failed` or bare `command not found`: Codex stores command output as JSON string fields, so a single line can contain ordinary test-framework text such as `Hook timed out` plus unrelated `failed` counts.
- When a functional journey forbids executing an expensive tool such as Stryker, state that in every phase prompt that could trigger it. Setup may configure mutation testing and still be tempted to verify by running it unless the setup prompt says not to.
- API-backed skill journeys route deterministic stubs through explicit base URL variables such as `OPENAI_BASE_URL` and `ZAI_BASE_URL`. Do not rely on a PATH-shadowed `curl` shim for Codex subprocesses; Codex shell execution may call the real endpoint even when the parent harness prepended a shim directory.
