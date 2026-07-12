---
name: setup-architecture-linter
description: "Set up executable hexagonal-boundary linting, CI enforcement, and coding-agent Stop feedback. TRIGGER when: an operator asks to add, configure, improve, or verify architecture linting or dependency boundaries."
---

# Setup Architecture Linter

Turn the project's intended hexagonal boundaries into fast executable feedback, then run that feedback and repair every violation.

## 1. Map and agree

Read `MENTAL_MODEL.md`, manifests, source, tests, imports, existing lint configuration, CI, and coding-harness hooks. Map the actual source layout: every domain, use-case, port, adapter, infrastructure, and composition root location. Identify the single composition root from running code rather than assuming a conventional filename.

Present the complete map and proposed enforced boundaries to the operator. Agree the map with the operator before changing files because a wrong boundary changes the architecture rather than merely configuring feedback.

The required rules are:

- Domain code is synchronous and depends on no framework, I/O, external package, application code, or adapter.
- Use-cases depend only on domain code, plain data, and ports, never frameworks, I/O, external packages, or concrete adapters.
- Concrete adapters are imported only by the composition root.
- Dependencies point inward.
- Circular dependencies are rejected.

Read current official documentation for the selected architecture tool before writing its configuration.

## 2. Configure every boundary

Choose a maintained ecosystem tool capable of enforcing every rule. For JavaScript and TypeScript install `dependency-cruiser` alongside ESLint.

Merge this domain async rule into `eslint.config.mjs`, replacing its file globs with the mapped domain locations:

```javascript
{
  name: 'contree/domain-no-async',
  files: ['src/domain/**/*.{js,jsx,ts,tsx}', 'src/**/domain/**/*.{js,jsx,ts,tsx}'],
  rules: {
    'no-restricted-syntax': [
      'error',
      {
        selector: ':matches(FunctionDeclaration, FunctionExpression, ArrowFunctionExpression)[async=true]',
        message: 'Domain code must be synchronous.',
      },
    ],
  },
}
```

Create `.dependency-cruiser.cjs` from the mapped locations. These rule names and meanings are required:

```javascript
module.exports = {
  forbidden: [
    {
      name: 'domain-pure',
      severity: 'error',
      from: { path: '(^|/)domain/' },
      to: { path: '(^|/)(application|use-cases?|adapters?|infrastructure)/' },
    },
    {
      name: 'domain-no-external-dependencies',
      severity: 'error',
      from: { path: '(^|/)domain/' },
      to: { dependencyTypes: ['core', 'npm', 'npm-dev', 'npm-optional', 'npm-peer', 'npm-bundled', 'npm-no-pkg', 'npm-unknown'] },
    },
    {
      name: 'use-case-no-external-dependencies',
      severity: 'error',
      from: { path: '(^|/)(application|use-cases?)/' },
      to: { dependencyTypes: ['core', 'npm', 'npm-dev', 'npm-optional', 'npm-peer', 'npm-bundled', 'npm-no-pkg', 'npm-unknown'] },
    },
    {
      name: 'use-case-only-domain-data-and-ports',
      severity: 'error',
      from: { path: '(^|/)(application|use-cases?)/' },
      to: {
        dependencyTypes: ['local', 'localmodule'],
        pathNot: '(^|/)(domain|ports?|data|types)(/|$)',
      },
    },
    {
      name: 'adapters-only-from-composition-root',
      severity: 'error',
      from: { pathNot: '^src/composition-root\\.[cm]?[jt]sx?$' },
      to: { path: '(^|/)(adapters?|infrastructure)/' },
    },
    {
      name: 'no-circular',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
  ],
  options: { tsConfig: { fileName: 'tsconfig.json' } },
}
```

Replace every example path with the actual mapped path. Remove the TypeScript option for projects without a TypeScript configuration.

If the project's ecosystem cannot enforce every required boundary, Fail visibly. Do not claim architecture feedback is configured. Do not substitute advisory rules.

## 3. Create native and CI feedback

Create executable `.contree/scripts/lint-architecture.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
eslint_status=0
depcruise_status=0
pnpm exec eslint . || eslint_status=$?
pnpm exec depcruise src --config .dependency-cruiser.cjs --output-type err-long || depcruise_status=$?
if [ "$eslint_status" -ne 0 ] || [ "$depcruise_status" -ne 0 ]; then
  exit 1
fi
```

Use the project's package manager and mapped source roots. Create the native `lint:arch` command, combine it with the project lint command, and make the combined lint command a required CI gate. Merge all existing commands and CI steps.

## 4. Install Stop feedback

Create executable `.contree/hooks/architecture-on-stop.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
if printf '%s' "$input" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then
  printf '{}\n'
  exit 0
fi
cd "$(git rev-parse --show-toplevel)"
if output=$(pnpm lint:arch 2>&1); then
  printf '{}\n'
  exit 0
fi
printf '%s\n' "$output" >&2
exit 2
```

Use the project's native architecture command. Check `stop_hook_active` before invoking architecture lint so the hook's follow-up Stop task exits silently without a feedback loop. Preserve the complete execution error on stderr and exit 2 whenever the linter cannot run or reports a violation.

Merge a synchronous Stop entry invoking `.contree/hooks/architecture-on-stop.sh` into both `.claude/settings.json` and `.codex/hooks.json` without replacing existing settings or hooks. The project Stop hooks must run every architecture rule from the project root before the coding agent finishes.

## 5. Run and repair

Run the native architecture command across every mapped source root. Do not report completion before every rule has run.

If it reports violations, invoke `contree:fix-architecture` with the complete architecture-linter output. After that skill returns, rerun the native architecture command and combined lint command. Continue until both pass. Verify the Stop hook with an actual Stop turn before reporting completion.
