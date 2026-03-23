#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 설치되어 있지 않습니다. 'brew install jq' 또는 'apt install jq'로 설치하세요." >&2
  exit 1
fi

AGENTS_DIR="${HOME}/.claude/agents"

escape_json_string() {
  local str="$1"
  printf '%s' "$str" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
}

parse_agent_file() {
  local agent_file="$1"
  local scope="$2"
  local file_basename
  file_basename=$(basename "$agent_file" .md)

  local name description model
  name=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^name:" | head -1 | sed 's/^name: *//')
  description=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^description:" | head -1 | sed 's/^description: *//' | tr -d '"')
  model=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^model:" | head -1 | sed 's/^model: *//')

  if [[ -z "$name" ]]; then
    name="$file_basename"
  fi

  if [[ -z "$model" ]]; then
    model="default"
  fi

  local name_escaped desc_escaped model_escaped id_escaped
  name_escaped=$(escape_json_string "$name")
  desc_escaped=$(escape_json_string "$description")
  model_escaped=$(escape_json_string "$model")
  id_escaped=$(escape_json_string "agent:${name}")

  printf '{"id":%s,"type":"agent","name":%s,"description":%s,"scope":"%s","enabled":true,"categories":[],"keywords":[],"invocation":%s,"model":%s}\n' \
    "$id_escaped" "$name_escaped" "$desc_escaped" "$scope" "$name_escaped" "$model_escaped"
}

all_results=""

if [[ -d "$AGENTS_DIR" ]]; then
  for agent_file in "$AGENTS_DIR"/*.md; do
    if [[ ! -f "$agent_file" ]]; then
      continue
    fi
    entry=$(parse_agent_file "$agent_file" "global")
    if [[ -n "$all_results" ]]; then
      all_results="${all_results}"$'\n'"${entry}"
    else
      all_results="${entry}"
    fi
  done
fi

if [[ -d ".claude/agents" ]]; then
  for agent_file in ".claude/agents"/*.md; do
    if [[ ! -f "$agent_file" ]]; then
      continue
    fi
    entry=$(parse_agent_file "$agent_file" "project")
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
