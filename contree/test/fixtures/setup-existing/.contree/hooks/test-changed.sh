#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
if printf '%s' "$input" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then
  printf '{}\n'
  exit 0
fi
cd "$(git rev-parse --show-toplevel)"
set +e
npm run test-changed
status=$?
set -e
if [ "$status" -ne 0 ]; then
  exit 2
fi
printf '{}\n'
