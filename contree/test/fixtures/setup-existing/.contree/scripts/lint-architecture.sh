#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
npx depcruise src --config .dependency-cruiser.cjs --output-type err-long --no-config 2>/dev/null
