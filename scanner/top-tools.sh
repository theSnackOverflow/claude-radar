#!/usr/bin/env bash
set -euo pipefail

N="${1:-5}"

USAGE_FILE="$HOME/.claude/cache/claude-radar/usage.json"

if [[ ! -f "$USAGE_FILE" ]]; then
  exit 0
fi

if ! command -v jq &>/dev/null; then
  exit 0
fi

jq -r --argjson n "$N" '
  .tools
  | to_entries
  | sort_by(-.value.count)
  | .[:$n]
  | .[].key
' "$USAGE_FILE" 2>/dev/null || true
