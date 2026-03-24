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

AGENTS_DIR="${HOME}/.claude/agents"

parse_agent_file() {
  local agent_file="$1"
  local scope="$2"
  local file_basename
  file_basename=$(basename "$agent_file" .md)

  local name description model
  name=$(parse_frontmatter "$agent_file" "name")
  description=$(parse_frontmatter "$agent_file" "description")
  model=$(parse_frontmatter "$agent_file" "model")

  if [[ -z "$name" ]]; then
    name="$file_basename"
  fi

  if [[ -z "$model" ]]; then
    model="default"
  fi

  local name_escaped desc_escaped model_escaped id_escaped source_escaped
  name_escaped=$(escape_json_string "$name")
  desc_escaped=$(escape_json_string "$description")
  model_escaped=$(escape_json_string "$model")
  id_escaped=$(escape_json_string "agent:${name}")
  source_escaped=$(escape_json_string "$agent_file")

  printf '{"id":%s,"type":"agent","name":%s,"description":%s,"scope":"%s","enabled":true,"categories":[],"keywords":[],"invocation":%s,"model":%s,"source":%s}\n' \
    "$id_escaped" "$name_escaped" "$desc_escaped" "$scope" "$name_escaped" "$model_escaped" "$source_escaped"
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
