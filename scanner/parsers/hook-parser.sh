#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 설치되어 있지 않습니다. 'brew install jq' 또는 'apt install jq'로 설치하세요." >&2
  exit 1
fi

SETTINGS_FILE="${HOME}/.claude/settings.json"

escape_json_string() {
  local str="$1"
  printf '%s' "$str" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
}

if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo "[]"
  exit 0
fi

has_hooks=$(jq 'has("hooks")' "$SETTINGS_FILE" 2>/dev/null)
if [[ "$has_hooks" != "true" ]]; then
  echo "[]"
  exit 0
fi

all_results=""

while IFS= read -r event_type; do
  hook_count=$(jq -r --arg evt "$event_type" '.hooks[$evt] | length' "$SETTINGS_FILE" 2>/dev/null)

  for ((i=0; i<hook_count; i++)); do
    matcher=$(jq -r --arg evt "$event_type" --argjson idx "$i" '.hooks[$evt][$idx].matcher // ""' "$SETTINGS_FILE" 2>/dev/null)
    inner_hooks=$(jq -r --arg evt "$event_type" --argjson idx "$i" '.hooks[$evt][$idx].hooks | length' "$SETTINGS_FILE" 2>/dev/null)

    for ((j=0; j<inner_hooks; j++)); do
      hook_type=$(jq -r --arg evt "$event_type" --argjson idx "$i" --argjson jdx "$j" '.hooks[$evt][$idx].hooks[$jdx].type // "command"' "$SETTINGS_FILE" 2>/dev/null)
      command=$(jq -r --arg evt "$event_type" --argjson idx "$i" --argjson jdx "$j" '.hooks[$evt][$idx].hooks[$jdx].command // ""' "$SETTINGS_FILE" 2>/dev/null)
      async=$(jq -r --arg evt "$event_type" --argjson idx "$i" --argjson jdx "$j" '.hooks[$evt][$idx].hooks[$jdx].async // false' "$SETTINGS_FILE" 2>/dev/null)
      if [[ "$async" != "true" ]] && [[ "$async" != "false" ]]; then async="false"; fi

      local_id="${event_type}:${i}:${j}"
      if [[ -n "$matcher" ]]; then
        local_id="${event_type}:${matcher}:${j}"
      fi

      event_escaped=$(escape_json_string "$event_type")
      matcher_escaped=$(escape_json_string "$matcher")
      cmd_escaped=$(escape_json_string "$command")
      hook_type_escaped=$(escape_json_string "$hook_type")
      id_escaped=$(escape_json_string "hook:${local_id}")

      entry=$(printf '{"id":%s,"type":"hook","name":%s,"description":null,"scope":"global","enabled":true,"categories":["automation"],"keywords":[],"invocation":%s,"event":%s,"matcher":%s,"hookType":%s,"async":%s}' \
        "$id_escaped" "$event_escaped" "$cmd_escaped" "$event_escaped" "$matcher_escaped" "$hook_type_escaped" "$async")

      if [[ -n "$all_results" ]]; then
        all_results="${all_results}"$'\n'"${entry}"
      else
        all_results="${entry}"
      fi
    done
  done

done < <(jq -r '.hooks // {} | keys[]' "$SETTINGS_FILE" 2>/dev/null)

if [[ -z "$all_results" ]]; then
  echo "[]"
else
  echo "$all_results" | jq -s '.'
fi
