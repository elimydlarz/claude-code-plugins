---
name: setup-linter
description: "Set up fast conventional code linting, automatic repair, CI enforcement, and synchronous coding-agent feedback. TRIGGER when: an operator asks to add, configure, improve, or fix linting or code-quality feedback."
---

# Setup Linter

Install a strong conventional linter, repair the existing project, and make the same repair run after every coding-agent save.

## 1. Inspect and agree

Inspect the ecosystem, manifests, CI, source layout, existing lint configuration, and project hook configuration. Preserve the project's established package manager and native command conventions.

Choose the ecosystem's strong conventional rules and agree the strong conventional rules with the operator before changing files. Present the evidence, exact rules, files, commands, and hook changes. Resolve consequential conflicts such as an existing CI reporter or project-owned rule whose meaning would change.

Use these defaults:

| Ecosystem | Linter | Strong rules and command |
|---|---|---|
| JavaScript | ESLint | `@eslint/js` recommended; `eslint .` |
| TypeScript | ESLint | `@eslint/js` recommended plus `typescript-eslint` `strictTypeChecked`, `parserOptions.projectService: true`, and the TypeScript compiler |
| Elixir | Credo | `mix credo --strict` |
| Go | golangci-lint | `standard` plus `errorlint`, `exhaustive`, `gosec`, `nilerr`, `nilnil`, and `wrapcheck`; `golangci-lint run` |

Read the current official documentation for the selected tool before using its API or configuration format.

## 2. Install and merge

Install the conventional linter with the project's package manager. Merge into existing configuration. Never replace project-owned rules, plugins, ignores, formatters, reporters, commands, CI steps, or hooks.

For JavaScript, install `eslint` and `@eslint/js`, then merge `js.configs.recommended` into `eslint.config.mjs`. For TypeScript, also install `typescript-eslint`, merge `tseslint.configs.strictTypeChecked`, set `parserOptions.projectService: true`, and include compiler checking in `lint:code`. For Elixir, add Credo to the development and test dependencies and generate `.credo.exs`. For Go, write or merge `.golangci.yml` with the listed linters enabled.

Create native project commands. In a JavaScript or TypeScript project these are:

```json
{
  "scripts": {
    "lint:code": "eslint .",
    "lint:code:fix": "eslint . --fix"
  }
}
```

Use the equivalent native project command for other ecosystems. Add the non-fixing command as a required CI gate using the existing CI system and merge it without replacing other gates.

## 3. Install save-time feedback

Create executable `.contree/hooks/lint-on-save.sh`. Select the exact autofix command for the detected ecosystem rather than placing alternatives in the generated script.

JavaScript and TypeScript:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if output=$(pnpm lint:code:fix 2>&1); then
  exit 0
fi
printf '%s\n' "$output" >&2
exit 2
```

Use the project's package manager in place of `pnpm`. Elixir runs `mix format` followed by `mix credo --strict`. Go runs `golangci-lint run --fix`.

Merge this synchronous `PostToolUse` group into both `.claude/settings.json` and `.codex/hooks.json` without replacing existing settings or hook entries:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.contree/hooks/lint-on-save.sh\"",
            "statusMessage": "Fixing lint"
          }
        ]
      }
    ]
  }
}
```

Keep the hook synchronous so automatic changes and failures reach the coding agent before it continues. If save-time autofix cannot complete, preserve the complete linter output, write it to stderr, and exit 2.

## 4. Repair and verify

Run autofix across the whole existing project. Then run the non-fixing lint command across the whole project.

Fix remaining violations directly. Do not merely list them or transfer the repair work to the operator. Preserve intended behavior and project-owned rules. Rerun lint after every repair batch until it passes.

Verify the CI gate and verify the hook through an actual coding-agent edit. Do not report completion until lint passes and the save-time feedback path has been exercised successfully.
