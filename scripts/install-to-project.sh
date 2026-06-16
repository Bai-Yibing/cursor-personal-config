#!/usr/bin/env bash
# Merge personal rules/skills from git clone into current project .cursor/
# Usage: install-to-project.sh [PROJECT_ROOT]
set -euo pipefail

CONFIG_DIR="${CURSOR_PERSONAL_CONFIG:-$HOME/.cursor-personal-config}"
PROJECT_ROOT="${1:-$(pwd)}"
MANIFEST="$CONFIG_DIR/sync-manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: sync-manifest not found. Clone repo first:" >&2
  echo "  git clone <repo_url> $CONFIG_DIR" >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/.cursor/rules" "$PROJECT_ROOT/.cursor/skills" "$PROJECT_ROOT/.cursor/scripts"

# git pull if this is a git checkout
if [[ -d "$CONFIG_DIR/.git" ]]; then
  git -C "$CONFIG_DIR" pull -q --rebase 2>/dev/null || git -C "$CONFIG_DIR" pull -q 2>/dev/null || true
fi

copy_rule() {
  local name="$1"
  local src="$CONFIG_DIR/rules/$name"
  local dst="$PROJECT_ROOT/.cursor/rules/$name"
  [[ -f "$src" ]] && cp -f "$src" "$dst" && echo "  rule: $name"
}

copy_skill() {
  local name="$1"
  local src="$CONFIG_DIR/skills/$name"
  local dst="$PROJECT_ROOT/.cursor/skills/$name"
  if [[ -d "$src" ]]; then
    rm -rf "$dst"
    cp -a "$src" "$dst"
    echo "  skill: $name"
  fi
}

echo "Installing personal Cursor config -> $PROJECT_ROOT/.cursor"
echo "Source: $CONFIG_DIR"

# Parse manifest with python3 (jq may be missing)
mapfile -t RULES < <(python3 -c "import json; print('\n'.join(json.load(open('$MANIFEST'))['rules']))")
mapfile -t SKILLS < <(python3 -c "import json; print('\n'.join(json.load(open('$MANIFEST'))['skills']))")

for r in "${RULES[@]}"; do copy_rule "$r"; done
for s in "${SKILLS[@]}"; do copy_skill "$s"; done

# Project hook: pull on each Agent session
HOOK_SRC="$CONFIG_DIR/scripts/project-hooks.json"
PULL_SRC="$CONFIG_DIR/scripts/pull-cursor-config.sh"
if [[ -f "$PULL_SRC" ]]; then
  cp -f "$PULL_SRC" "$PROJECT_ROOT/.cursor/scripts/pull-cursor-config.sh"
  chmod +x "$PROJECT_ROOT/.cursor/scripts/pull-cursor-config.sh"
fi
if [[ -f "$HOOK_SRC" ]] && [[ ! -f "$PROJECT_ROOT/.cursor/hooks.json" ]]; then
  cp -f "$HOOK_SRC" "$PROJECT_ROOT/.cursor/hooks.json"
  echo "  hooks.json installed (first time only)"
fi

python3 -c "
import json, datetime
m = json.load(open('$MANIFEST'))
out = {
  'synced_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
  'source': '$CONFIG_DIR',
  'mode': 'git',
  'rules': m['rules'],
  'skills': m['skills']
}
json.dump(out, open('$PROJECT_ROOT/.cursor/global-sync-manifest.json', 'w'), indent=2)
"

echo "Done. Project rules (e.g. project-overview) are NOT removed."
