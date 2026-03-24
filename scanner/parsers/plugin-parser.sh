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

INSTALLED_PLUGINS_FILE="${HOME}/.claude/plugins/installed_plugins.json"
SETTINGS_FILE="${HOME}/.claude/settings.json"

is_plugin_enabled() {
  local plugin_key="$1"
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "true"
    return
  fi
  local enabled
  enabled=$(jq -r --arg key "$plugin_key" '.enabledPlugins[$key] // false' "$SETTINGS_FILE" 2>/dev/null)
  echo "$enabled"
}

scan_plugin_skills() {
  local install_path="$1"
  local plugin_key="$2"

  local skills_dir="${install_path}/skills"
  if [[ ! -d "$skills_dir" ]]; then
    return
  fi

  for skill_dir in "$skills_dir"/*/; do
    local skill_file="${skill_dir}SKILL.md"
    if [[ ! -f "$skill_file" ]]; then
      continue
    fi

    local skill_name description
    skill_name=$(parse_frontmatter "$skill_file" "name")
    description=$(parse_frontmatter "$skill_file" "description")

    if [[ -z "$skill_name" ]]; then
      skill_name=$(basename "$skill_dir")
    fi

    local name_escaped desc_escaped plugin_key_escaped id_escaped
    name_escaped=$(escape_json_string "$skill_name")
    desc_escaped=$(escape_json_string "$description")
    plugin_key_escaped=$(escape_json_string "$plugin_key")
    id_escaped=$(escape_json_string "skill:plugin:${plugin_key}:${skill_name}")

    printf '{"id":%s,"type":"skill","name":%s,"description":%s,"scope":"plugin","enabled":true,"categories":[],"keywords":[],"invocation":%s,"plugin":%s}\n' \
      "$id_escaped" "$name_escaped" "$desc_escaped" "$name_escaped" "$plugin_key_escaped"
  done
}

scan_plugin_agents() {
  local install_path="$1"
  local plugin_key="$2"

  local agents_dir="${install_path}/agents"
  if [[ ! -d "$agents_dir" ]]; then
    return
  fi

  for agent_file in "$agents_dir"/*.md; do
    if [[ ! -f "$agent_file" ]]; then
      continue
    fi

    local agent_name description
    agent_name=$(parse_frontmatter "$agent_file" "name")
    description=$(parse_frontmatter "$agent_file" "description")

    if [[ -z "$agent_name" ]]; then
      agent_name=$(basename "$agent_file" .md)
    fi

    local name_escaped desc_escaped plugin_key_escaped id_escaped
    name_escaped=$(escape_json_string "$agent_name")
    desc_escaped=$(escape_json_string "$description")
    plugin_key_escaped=$(escape_json_string "$plugin_key")
    id_escaped=$(escape_json_string "agent:plugin:${plugin_key}:${agent_name}")

    printf '{"id":%s,"type":"plugin-agent","name":%s,"description":%s,"scope":"plugin","enabled":true,"categories":[],"keywords":[],"invocation":%s,"plugin":%s}\n' \
      "$id_escaped" "$name_escaped" "$desc_escaped" "$name_escaped" "$plugin_key_escaped"
  done
}

scan_plugin_commands() {
  local install_path="$1"
  local plugin_key="$2"

  local commands_dir="${install_path}/commands"
  if [[ ! -d "$commands_dir" ]]; then
    return
  fi

  for cmd_file in "$commands_dir"/*.md; do
    if [[ ! -f "$cmd_file" ]]; then
      continue
    fi

    local cmd_name description
    cmd_name=$(parse_frontmatter "$cmd_file" "name")
    description=$(parse_frontmatter "$cmd_file" "description")

    if [[ -z "$cmd_name" ]]; then
      cmd_name=$(basename "$cmd_file" .md)
    fi

    local name_escaped desc_escaped plugin_key_escaped id_escaped
    name_escaped=$(escape_json_string "$cmd_name")
    desc_escaped=$(escape_json_string "$description")
    plugin_key_escaped=$(escape_json_string "$plugin_key")
    id_escaped=$(escape_json_string "command:plugin:${plugin_key}:${cmd_name}")

    printf '{"id":%s,"type":"command","name":%s,"description":%s,"scope":"plugin","enabled":true,"categories":[],"keywords":[],"invocation":%s,"plugin":%s}\n' \
      "$id_escaped" "$name_escaped" "$desc_escaped" "$name_escaped" "$plugin_key_escaped"
  done
}

if [[ ! -f "$INSTALLED_PLUGINS_FILE" ]]; then
  echo "[]"
  exit 0
fi

plugin_keys=$(jq -r '.plugins // {} | keys[]' "$INSTALLED_PLUGINS_FILE" 2>/dev/null)

if [[ -z "$plugin_keys" ]]; then
  echo "[]"
  exit 0
fi

all_results=""

while IFS= read -r plugin_key; do
  enabled=$(is_plugin_enabled "$plugin_key")

  install_path=$(jq -r --arg key "$plugin_key" '.plugins[$key] // [] | if type == "array" then .[0].installPath else .installPath end // ""' "$INSTALLED_PLUGINS_FILE" 2>/dev/null)

  if [[ -z "$install_path" || "$install_path" == "null" ]]; then
    continue
  fi

  real_path=$(safe_realpath "$install_path")
  if [[ -z "$real_path" ]] || [[ "$real_path" != "${HOME}/.claude/plugins/"* ]]; then
    continue
  fi
  install_path="$real_path"

  plugin_json_file="${install_path}/.claude-plugin/plugin.json"

  local_name="" local_description="" local_keywords="[]"
  if [[ -f "$plugin_json_file" ]]; then
    local_name=$(jq -r '.name // ""' "$plugin_json_file" 2>/dev/null)
    local_description=$(jq -r '.description // ""' "$plugin_json_file" 2>/dev/null)
    local_keywords=$(jq -c '.keywords // []' "$plugin_json_file" 2>/dev/null)
  fi

  if [[ -z "$local_name" ]]; then
    local_name="${plugin_key%%@*}"
  fi

  name_escaped=$(escape_json_string "$local_name")
  desc_escaped=$(escape_json_string "$local_description")
  key_escaped=$(escape_json_string "$plugin_key")
  plugin_id_escaped=$(escape_json_string "plugin:${plugin_key}")
  source_escaped=$(escape_json_string "$plugin_json_file")

  plugin_entry=$(printf '{"id":%s,"type":"plugin","name":%s,"description":%s,"scope":"global","enabled":%s,"categories":[],"keywords":%s,"invocation":null,"source":%s}' \
    "$plugin_id_escaped" "$name_escaped" "$desc_escaped" "$enabled" "$local_keywords" "$source_escaped")

  if [[ -n "$all_results" ]]; then
    all_results="${all_results}"$'\n'"${plugin_entry}"
  else
    all_results="${plugin_entry}"
  fi

  sub_results=$(scan_plugin_skills "$install_path" "$plugin_key")
  if [[ -n "$sub_results" ]]; then
    all_results="${all_results}"$'\n'"${sub_results}"
  fi

  agent_results=$(scan_plugin_agents "$install_path" "$plugin_key")
  if [[ -n "$agent_results" ]]; then
    all_results="${all_results}"$'\n'"${agent_results}"
  fi

  cmd_results=$(scan_plugin_commands "$install_path" "$plugin_key")
  if [[ -n "$cmd_results" ]]; then
    all_results="${all_results}"$'\n'"${cmd_results}"
  fi

done <<< "$plugin_keys"

if [[ -z "$all_results" ]]; then
  echo "[]"
else
  echo "$all_results" | jq -s '.'
fi
