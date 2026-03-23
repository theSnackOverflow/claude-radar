#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 설치되어 있지 않습니다. 'brew install jq' 또는 'apt install jq'로 설치하세요." >&2
  exit 1
fi

OUTPUT_STYLES_DIR="${HOME}/.claude/output-styles"
SETTINGS_FILE="${HOME}/.claude/settings.json"

escape_json_string() {
  local str="$1"
  printf '%s' "$str" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
}

get_active_style() {
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo ""
    return
  fi
  jq -r '.outputStyle // ""' "$SETTINGS_FILE" 2>/dev/null
}

active_style=$(get_active_style)

parse_output_style_file() {
  local style_file="$1"
  local file_basename
  file_basename=$(basename "$style_file" .md)

  local name description
  name=$(sed -n '/^---$/,/^---$/p' "$style_file" | grep "^name:" | head -1 | sed 's/^name: *//')
  description=$(sed -n '/^---$/,/^---$/p' "$style_file" | grep "^description:" | head -1 | sed 's/^description: *//' | tr -d '"')

  if [[ -z "$name" ]]; then
    name="$file_basename"
  fi

  local enabled="false"
  if [[ "$file_basename" == "$active_style" || "$name" == "$active_style" ]]; then
    enabled="true"
  fi

  local name_escaped desc_escaped id_escaped
  name_escaped=$(escape_json_string "$name")
  desc_escaped=$(escape_json_string "$description")
  id_escaped=$(escape_json_string "output-style:${file_basename}")

  printf '{"id":%s,"type":"output-style","name":%s,"description":%s,"scope":"global","enabled":%s,"categories":["style","output"],"keywords":[],"invocation":null}\n' \
    "$id_escaped" "$name_escaped" "$desc_escaped" "$enabled"
}

all_results=""

if [[ -d "$OUTPUT_STYLES_DIR" ]]; then
  for style_file in "$OUTPUT_STYLES_DIR"/*.md; do
    if [[ ! -f "$style_file" ]]; then
      continue
    fi
    entry=$(parse_output_style_file "$style_file")
    if [[ -n "$all_results" ]]; then
      all_results="${all_results}"$'\n'"${entry}"
    else
      all_results="${entry}"
    fi
  done
fi

if [[ -z "$all_results" ]]; then
  echo "[]"
else
  echo "$all_results" | jq -s '.'
fi
