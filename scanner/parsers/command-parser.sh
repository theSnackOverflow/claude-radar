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

COMMANDS_DIR="${HOME}/.claude/commands"

parse_command_file() {
  local cmd_file="$1"
  local scope="$2"
  local file_basename
  file_basename=$(basename "$cmd_file" .md)

  local name description
  name=$(parse_frontmatter "$cmd_file" "name")
  description=$(parse_frontmatter "$cmd_file" "description")

  if [[ -z "$name" ]]; then
    name="$file_basename"
  fi

  local name_escaped desc_escaped invocation_escaped id_escaped source_escaped
  name_escaped=$(escape_json_string "$name")
  desc_escaped=$(escape_json_string "$description")
  invocation_escaped=$(escape_json_string "/$name")
  id_escaped=$(escape_json_string "command:${name}")
  source_escaped=$(escape_json_string "$cmd_file")

  printf '{"id":%s,"type":"command","name":%s,"description":%s,"scope":"%s","enabled":true,"categories":[],"keywords":[],"invocation":%s,"source":%s}\n' \
    "$id_escaped" "$name_escaped" "$desc_escaped" "$scope" "$invocation_escaped" "$source_escaped"
}

all_results=""

if [[ -d "$COMMANDS_DIR" ]]; then
  for cmd_file in "$COMMANDS_DIR"/*.md; do
    if [[ ! -f "$cmd_file" ]]; then
      continue
    fi
    entry=$(parse_command_file "$cmd_file" "global")
    if [[ -n "$all_results" ]]; then
      all_results="${all_results}"$'\n'"${entry}"
    else
      all_results="${entry}"
    fi
  done
fi

if [[ -d ".claude/commands" ]]; then
  for cmd_file in ".claude/commands"/*.md; do
    if [[ ! -f "$cmd_file" ]]; then
      continue
    fi
    entry=$(parse_command_file "$cmd_file" "project")
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
