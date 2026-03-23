#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin"

TOOL_ID="${1:-}"
TOOL_NAME="${2:-}"

if [[ -z "$TOOL_ID" || -z "$TOOL_NAME" ]]; then
  exit 0
fi

if ! command -v jq &>/dev/null; then
  exit 0
fi

CACHE_DIR="$HOME/.claude/cache/claude-radar"
USAGE_FILE="$CACHE_DIR/usage.json"
TMP_FILE=$(mktemp "$CACHE_DIR/usage.json.tmp.XXXXXX")

mkdir -p -m 700 "$CACHE_DIR"

if [[ ! -f "$USAGE_FILE" ]] && [[ ! -L "$USAGE_FILE" ]]; then
  (set -o noclobber; printf '{"version":1,"lastUpdated":"","tools":{}}\n' > "$USAGE_FILE") 2>/dev/null || true
fi

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

CURRENT_COUNT="$(jq -r --arg id "$TOOL_ID" '.tools[$id].count // 0' "$USAGE_FILE")"
NEW_COUNT=$((CURRENT_COUNT + 1))

jq \
  --arg id "$TOOL_ID" \
  --arg name "$TOOL_NAME" \
  --argjson count "$NEW_COUNT" \
  --arg now "$NOW" \
  '.lastUpdated = $now | .tools[$id] = {"name": $name, "count": $count, "lastUsed": $now}' \
  "$USAGE_FILE" > "$TMP_FILE"

if [[ -L "$USAGE_FILE" ]]; then
  rm -f "$TMP_FILE"
  echo "Error: $USAGE_FILE is a symbolic link. Aborting." >&2
  exit 1
fi

mv "$TMP_FILE" "$USAGE_FILE"
