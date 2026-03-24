#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is not installed." >&2
  echo "  macOS:   brew install jq" >&2
  echo "  Ubuntu:  sudo apt install jq" >&2
  echo "  Windows: choco install jq  (or: scoop install jq  /  winget install jqlang.jq)" >&2
  exit 1
fi

OUTPUT_STYLES_DIR="${HOME}/.claude/output-styles"
SETTINGS_FILE="${HOME}/.claude/settings.json"

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
  name=$(parse_frontmatter "$style_file" "name")
  description=$(parse_frontmatter "$style_file" "description")

  if [[ -z "$name" ]]; then
    name="$file_basename"
  fi

  local enabled="false"
  if [[ "$file_basename" == "$active_style" || "$name" == "$active_style" ]]; then
    enabled="true"
  fi

  local name_escaped desc_escaped id_escaped source_escaped
  name_escaped=$(escape_json_string "$name")
  desc_escaped=$(escape_json_string "$description")
  id_escaped=$(escape_json_string "output-style:${file_basename}")
  source_escaped=$(escape_json_string "$style_file")

  printf '{"id":%s,"type":"output-style","name":%s,"description":%s,"scope":"global","enabled":%s,"categories":["style","output"],"keywords":[],"invocation":null,"source":%s}\n' \
    "$id_escaped" "$name_escaped" "$desc_escaped" "$enabled" "$source_escaped"
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
