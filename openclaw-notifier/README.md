# openclaw-notifier

A Claude Code plugin that notifies [OpenClaw](https://openclaw.dev) when a subagent completes a task.

## How it works

The plugin registers a **SubagentStop** hook. Each time a subagent finishes, Claude Code pipes the completion event into `scripts/notify.sh`, which extracts the agent info (`agent_type`, `agent_id`, `reason`) and POSTs a message to your OpenClaw gateway's `/hooks/agent` endpoint. This wakes the parent agent session so it can act on the completed subagent's results.

The notification is **fire-and-forget** — failures are logged to stderr but never block the agent. The hook always exits 0.

## Installation

Add the `susu-eng` marketplace and install the plugin:

```bash
claude plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install openclaw-notifier
```

## Configuration

Two environment variables control behaviour:

| Variable | Required | Description |
|---|---|---|
| `OPENCLAW_URL` | Yes | Base URL of the OpenClaw gateway (e.g. `http://localhost:18789`) |
| `OPENCLAW_TOKEN` | No | The hooks bearer token (`hooks.token` in OpenClaw config). This is NOT the gateway auth token — OpenClaw enforces they are different. |

When `OPENCLAW_URL` is unset the hook is a silent no-op, so the plugin is safe to install in sessions that don't use OpenClaw.

### Endpoint

The hook POSTs to `${OPENCLAW_URL}/hooks/agent` with:

- `Content-Type: application/json`
- `Authorization: Bearer ${OPENCLAW_TOKEN}` (only when the token is set)
- Body: `{"message": "Subagent <type> completed: agent_id=<id> reason=<reason>", "name": "subagent-complete"}`

The `message` field is extracted from the SubagentStop event via `jq`. The `name` field identifies the hook source in OpenClaw logs.

### Timeouts

The request uses a 5-second connect timeout and 10-second total timeout.

## Testing

```bash
pnpm test                # structural tests (bats) — manifest validity, hook registration, bash syntax
pnpm run test:functional # functional tests (node) — real HTTP behaviour against a capture server
```
