#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
set +e
npm run test-changed
status=$?
set -e
if [ "$status" -ne 0 ]; then
  exit 2
fi
printf '{}\n'
