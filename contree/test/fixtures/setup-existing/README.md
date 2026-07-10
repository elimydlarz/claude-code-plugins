# shortcode

A prepared JavaScript project used to verify Contree setup integration.

## Install

Run `npm install`.

## Test

- `npm test` runs normal tests.
- `npm run test:functional` runs System and Journey tests.
- Contree setup adds the native changed-test command and coding-harness hooks.

## Configuration

Vitest, ESLint, mutation testing, and architecture lint configuration live at the project root. The maintained changed-test runner and Stop wrapper live at `.contree/scripts/test-changed.mjs` and `.contree/hooks/test-changed.sh`.
