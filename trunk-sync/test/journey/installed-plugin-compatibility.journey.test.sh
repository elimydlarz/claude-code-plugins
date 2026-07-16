#!/usr/bin/env bash
set -euo pipefail

exec bash "$(dirname "$0")/agent-hook-compatibility.journey.test.sh" "${1:?harness is required}" installed
