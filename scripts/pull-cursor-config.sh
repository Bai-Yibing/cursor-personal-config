#!/usr/bin/env bash
# Called from project .cursor/hooks.json on sessionStart (runs on remote Linux)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="${CURSOR_PERSONAL_CONFIG:-$HOME/.cursor-personal-config}"
if [[ ! -d "$CONFIG" ]]; then
  exit 0
fi
exec "$CONFIG/scripts/install-to-project.sh" "$ROOT"
