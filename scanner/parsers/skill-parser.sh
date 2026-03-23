#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 설치되어 있지 않습니다. 'brew install jq' 또는 'apt install jq'로 설치하세요." >&2
  exit 1
fi

SKILLS_DIR="${HOME}/.claude/skills"

parse_skill_file() {
  local skill_file="$1"
  local scope="$2"
  local skill_dir
  skill_dir=$(dirname "$skill_file")
  local dir_name
  dir_name=$(basename "$skill_dir")

  local name description
  name=$(parse_frontmatter "$skill_file" "name")
  description=$(parse_frontmatter "$skill_file" "description")

  if [[ -z "$name" ]]; then
    name="$dir_name"
  fi

  local name_escaped desc_escaped id_escaped
  name_escaped=$(escape_json_string "$name")
  desc_escaped=$(escape_json_string "$description")
  id_escaped=$(escape_json_string "skill:${name}")

  printf '{"id":%s,"type":"skill","name":%s,"description":%s,"scope":"%s","enabled":true,"categories":[],"keywords":[],"invocation":%s}\n' \
    "$id_escaped" "$name_escaped" "$desc_escaped" "$scope" "$name_escaped"
}

all_results=""

if [[ -d "$SKILLS_DIR" ]]; then
  while IFS= read -r skill_file; do
    if [[ ! -f "$skill_file" ]]; then
      continue
    fi
    entry=$(parse_skill_file "$skill_file" "global")
    if [[ -n "$all_results" ]]; then
      all_results="${all_results}"$'\n'"${entry}"
    else
      all_results="${entry}"
    fi
  done < <(find "$SKILLS_DIR" -name "SKILL.md" -maxdepth 2 2>/dev/null)
fi

if [[ -d ".claude/skills" ]]; then
  while IFS= read -r skill_file; do
    if [[ ! -f "$skill_file" ]]; then
      continue
    fi
    entry=$(parse_skill_file "$skill_file" "project")
    if [[ -n "$all_results" ]]; then
      all_results="${all_results}"$'\n'"${entry}"
    else
      all_results="${entry}"
    fi
  done < <(find ".claude/skills" -name "SKILL.md" -maxdepth 2 2>/dev/null)
fi

if [[ -z "$all_results" ]]; then
  echo "[]"
else
  echo "$all_results" | jq -s '.'
fi
