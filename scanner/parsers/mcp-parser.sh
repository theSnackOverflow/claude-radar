#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 설치되어 있지 않습니다. 'brew install jq' 또는 'apt install jq'로 설치하세요." >&2
  exit 1
fi

MCP_FILE="${HOME}/.claude/mcp.json"

infer_categories() {
  local name="$1"
  local categories="[]"

  case "$name" in
    *playwright*|*puppeteer*|*selenium*|*browser*|*chrome*)
      categories='["browser-automation","testing"]' ;;
    *figma*|*design*|*sketch*|*adobe*)
      categories='["design","ui"]' ;;
    *shrimp*|*task*|*todo*|*jira*|*linear*|*asana*)
      categories='["task-management","productivity"]' ;;
    *context7*|*docs*|*documentation*)
      categories='["documentation","knowledge"]' ;;
    *shadcn*|*ui*|*component*)
      categories='["ui","component-library"]' ;;
    *github*|*gitlab*|*git*)
      categories='["version-control","devops"]' ;;
    *slack*|*discord*|*telegram*|*chat*)
      categories='["communication","messaging"]' ;;
    *postgres*|*mysql*|*sqlite*|*mongo*|*db*|*database*)
      categories='["database","storage"]' ;;
    *aws*|*gcp*|*azure*|*cloud*)
      categories='["cloud","infrastructure"]' ;;
    *search*|*google*|*bing*|*brave*)
      categories='["search","web"]' ;;
    *file*|*fs*|*filesystem*)
      categories='["filesystem","storage"]' ;;
    *email*|*gmail*|*smtp*)
      categories='["email","communication"]' ;;
    *calendar*|*notion*|*obsidian*)
      categories='["productivity","notes"]' ;;
    *)
      categories='["general"]' ;;
  esac

  echo "$categories"
}

escape_json_string() {
  local str="$1"
  printf '%s' "$str" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
}

parse_mcp_file() {
  local file="$1"
  local scope="$2"

  if [[ ! -f "$file" ]]; then
    echo "[]"
    return
  fi

  jq -r '.mcpServers // {} | keys[]' "$file" 2>/dev/null | while IFS= read -r server_name; do
    local categories
    categories=$(infer_categories "$server_name")

    local server_type
    server_type=$(jq -r ".mcpServers[\"$server_name\"].type // \"stdio\"" "$file")

    local command_str
    command_str=$(jq -r ".mcpServers[\"$server_name\"].command // \"\"" "$file")
    local url_str
    url_str=$(jq -r ".mcpServers[\"$server_name\"].url // \"\"" "$file")

    local invocation
    if [[ -n "$url_str" && "$url_str" != "null" ]]; then
      invocation=$(escape_json_string "$url_str")
    elif [[ -n "$command_str" && "$command_str" != "null" ]]; then
      local args
      args=$(jq -r ".mcpServers[\"$server_name\"].args // [] | join(\" \")" "$file")
      invocation=$(escape_json_string "$command_str $args")
    else
      invocation=$(escape_json_string "$server_name")
    fi

    local name_escaped
    name_escaped=$(escape_json_string "$server_name")

    printf '{"id":"mcp:%s","type":"mcp","name":%s,"description":null,"scope":"%s","enabled":true,"categories":%s,"keywords":[],"invocation":%s}\n' \
      "$server_name" "$name_escaped" "$scope" "$categories" "$invocation"
  done
}

global_results=$(parse_mcp_file "$MCP_FILE" "global")

project_mcp=""
if [[ -f ".claude/mcp.json" ]]; then
  project_mcp=$(parse_mcp_file ".claude/mcp.json" "project")
fi

all_results=""
if [[ -n "$global_results" && -n "$project_mcp" ]]; then
  all_results=$(printf '%s\n%s' "$global_results" "$project_mcp")
elif [[ -n "$global_results" ]]; then
  all_results="$global_results"
elif [[ -n "$project_mcp" ]]; then
  all_results="$project_mcp"
fi

if [[ -z "$all_results" ]]; then
  echo "[]"
else
  echo "$all_results" | jq -s '.'
fi
