# CLAUDE.md

## Mental Model

A Claude Code plugin that notifies OpenClaw when a subagent completes a task. The SubagentStop hook extracts agent info from the event payload, wraps it into a `/hooks/agent` message (via `jq`), and POSTs it to the OpenClaw gateway. This wakes the parent agent session so it can act on the completed subagent's results. Fire-and-forget — notification failures never block the agent.

Two env vars control behaviour: `OPENCLAW_URL` (required, gateway base URL) and `OPENCLAW_TOKEN` (optional, the `hooks.token` Bearer token — NOT the gateway auth token). When `OPENCLAW_URL` is unset the hook is a silent no-op, so the plugin is safe to install in non-OpenClaw sessions.

## Repo Map

- `CLAUDE.md` — this file
- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `hooks/hooks.json` — SubagentStop hook registration
- `scripts/notify.sh` — notification script (curl POST, fire-and-forget)
- `package.json` — dev dependencies (bats) and test scripts
- `test/plugin.bats` — structural tests: manifest validity, hook registration, bash syntax
- `test/functional/capture-server.mjs` — Node.js HTTP capture server for functional tests
- `test/functional/run.mjs` — functional test runner: real HTTP assertions

## Testing

```bash
pnpm test                # unit tests (bats) — structural validity
pnpm run test:functional # functional tests (node) — real HTTP behaviour
```

## Requirements

### SubagentNotification

```
SubagentNotification
  when OPENCLAW_URL is set and a subagent completes
    then POSTs a message to OPENCLAW_URL/hooks/agent with name "subagent-complete"
    and the message contains agent_type, agent_id, and reason
    and exits 0
  when OPENCLAW_URL is not set
    then exits 0 without making any HTTP request
  when OPENCLAW_TOKEN is set
    then includes Authorization Bearer header in the request
  when OPENCLAW_TOKEN is not set
    then sends the request without an Authorization header
  when the HTTP request fails (network error)
    then logs the failure to stderr
    and exits 0
  when the server returns a non-2xx status
    then logs the status code to stderr
    and exits 0
```

### PluginManifest

```
PluginManifest
  plugin.json
    then contains name "openclaw-notifier"
    and contains a valid semver version
    and contains a description
  hooks.json
    then registers a SubagentStop hook
    and the hook command points to scripts/notify.sh
```
