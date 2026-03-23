#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 설치되어 있지 않습니다. 'brew install jq' 또는 'apt install jq'로 설치하세요." >&2
  exit 1
fi

COMMANDS_DIR="${HOME}/.claude/commands"

escape_json_string() {
  local str="$1"
  printf '%s' "$str" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
}

parse_command_file() {
  local cmd_file="$1"
  local scope="$2"
  local file_basename
  file_basename=$(basename "$cmd_file" .md)

  local name description
  name=$(sed -n '/^---$/,/^---$/p' "$cmd_file" | grep "^name:" | head -1 | sed 's/^name: *//')
  description=$(sed -n '/^---$/,/^---$/p' "$cmd_file" | grep "^description:" | head -1 | sed 's/^description: *//' | tr -d '"')

  if [[ -z "$name" ]]; then
    name="$file_basename"
  fi

  local name_escaped desc_escaped invocation_escaped id_escaped
  name_escaped=$(escape_json_string "$name")
  desc_escaped=$(escape_json_string "$description")
  invocation_escaped=$(escape_json_string "/$name")
  id_escaped=$(escape_json_string "command:${name}")

  printf '{"id":%s,"type":"command","name":%s,"description":%s,"scope":"%s","enabled":true,"categories":[],"keywords":[],"invocation":%s}\n' \
    "$id_escaped" "$name_escaped" "$desc_escaped" "$scope" "$invocation_escaped"
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
