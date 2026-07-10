# CLAUDE.md

## Mental Model

A pure JavaScript utility for generating URL-safe short codes.

The project keeps changed-test selection in a maintained native runner. Contree setup owns its package-command and coding-harness integration.

## Repo Map

- `MENTAL_MODEL.md` — project mental model
- `TEST_TREES.md` — behaviour contract
- `package.json` — project manifest
- `.contree/scripts/test-changed.mjs` — native changed-test runner
- `.contree/hooks/test-changed.sh` — synchronous Stop wrapper that translates failure to exit 2
