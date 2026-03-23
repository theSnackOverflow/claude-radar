#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 설치되어 있지 않습니다. 'brew install jq' 또는 'apt install jq'로 설치하세요." >&2
  exit 1
fi

INSTALLED_PLUGINS_FILE="${HOME}/.claude/plugins/installed_plugins.json"
SETTINGS_FILE="${HOME}/.claude/settings.json"

escape_json_string() {
  local str="$1"
  printf '%s' "$str" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
}

is_plugin_enabled() {
  local plugin_key="$1"
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "true"
    return
  fi
  local enabled
  enabled=$(jq -r ".enabledPlugins[\"$plugin_key\"] // false" "$SETTINGS_FILE" 2>/dev/null)
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
    skill_name=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^name:" | head -1 | sed 's/^name: *//')
    description=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^description:" | head -1 | sed 's/^description: *//' | tr -d '"')

    if [[ -z "$skill_name" ]]; then
      skill_name=$(basename "$skill_dir")
    fi

    local name_escaped desc_escaped plugin_key_escaped
    name_escaped=$(escape_json_string "$skill_name")
    desc_escaped=$(escape_json_string "$description")
    plugin_key_escaped=$(escape_json_string "$plugin_key")

    printf '{"id":"skill:plugin:%s:%s","type":"skill","name":%s,"description":%s,"scope":"plugin","enabled":true,"categories":[],"keywords":[],"invocation":%s,"plugin":%s}\n' \
      "$plugin_key" "$skill_name" "$name_escaped" "$desc_escaped" "$name_escaped" "$plugin_key_escaped"
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
    agent_name=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^name:" | head -1 | sed 's/^name: *//')
    description=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^description:" | head -1 | sed 's/^description: *//' | tr -d '"')

    if [[ -z "$agent_name" ]]; then
      agent_name=$(basename "$agent_file" .md)
    fi

    local name_escaped desc_escaped plugin_key_escaped
    name_escaped=$(escape_json_string "$agent_name")
    desc_escaped=$(escape_json_string "$description")
    plugin_key_escaped=$(escape_json_string "$plugin_key")

    printf '{"id":"agent:plugin:%s:%s","type":"plugin-agent","name":%s,"description":%s,"scope":"plugin","enabled":true,"categories":[],"keywords":[],"invocation":%s,"plugin":%s}\n' \
      "$plugin_key" "$agent_name" "$name_escaped" "$desc_escaped" "$name_escaped" "$plugin_key_escaped"
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
    cmd_name=$(sed -n '/^---$/,/^---$/p' "$cmd_file" | grep "^name:" | head -1 | sed 's/^name: *//')
    description=$(sed -n '/^---$/,/^---$/p' "$cmd_file" | grep "^description:" | head -1 | sed 's/^description: *//' | tr -d '"')

    if [[ -z "$cmd_name" ]]; then
      cmd_name=$(basename "$cmd_file" .md)
    fi

    local name_escaped desc_escaped plugin_key_escaped
    name_escaped=$(escape_json_string "$cmd_name")
    desc_escaped=$(escape_json_string "$description")
    plugin_key_escaped=$(escape_json_string "$plugin_key")

    printf '{"id":"command:plugin:%s:%s","type":"command","name":%s,"description":%s,"scope":"plugin","enabled":true,"categories":[],"keywords":[],"invocation":%s,"plugin":%s}\n' \
      "$plugin_key" "$cmd_name" "$name_escaped" "$desc_escaped" "$name_escaped" "$plugin_key_escaped"
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

  install_path=$(jq -r ".plugins[\"$plugin_key\"] // [] | if type == \"array\" then .[0].installPath else .installPath end // \"\"" "$INSTALLED_PLUGINS_FILE" 2>/dev/null)

  if [[ -z "$install_path" || "$install_path" == "null" ]]; then
    continue
  fi

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

  plugin_entry=$(printf '{"id":"plugin:%s","type":"plugin","name":%s,"description":%s,"scope":"global","enabled":%s,"categories":[],"keywords":%s,"invocation":null}' \
    "$plugin_key" "$name_escaped" "$desc_escaped" "$enabled" "$local_keywords")

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
