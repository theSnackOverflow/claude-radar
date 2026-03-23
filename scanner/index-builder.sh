#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 설치되어 있지 않습니다. 'brew install jq' 또는 'apt install jq'로 설치하세요." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSERS_DIR="${SCRIPT_DIR}/parsers"
OUTPUT_DIR="${HOME}/.claude/cache/claude-radar"
OUTPUT_FILE="${OUTPUT_DIR}/inventory.json"

mkdir -p "$OUTPUT_DIR"

run_parser() {
  local parser="$1"
  local result
  if result=$(bash "$parser" 2>/dev/null); then
    if echo "$result" | jq -e 'type == "array"' &>/dev/null; then
      echo "$result"
      return
    fi
  fi
  echo "[]"
}

echo "파서 실행 중..." >&2

mcp_tools=$(run_parser "${PARSERS_DIR}/mcp-parser.sh")
plugin_tools=$(run_parser "${PARSERS_DIR}/plugin-parser.sh")
skill_tools=$(run_parser "${PARSERS_DIR}/skill-parser.sh")
agent_tools=$(run_parser "${PARSERS_DIR}/agent-parser.sh")
command_tools=$(run_parser "${PARSERS_DIR}/command-parser.sh")
hook_tools=$(run_parser "${PARSERS_DIR}/hook-parser.sh")
output_style_tools=$(run_parser "${PARSERS_DIR}/output-style-parser.sh")

all_tools=$(jq -s 'add' \
  <(echo "$mcp_tools") \
  <(echo "$plugin_tools") \
  <(echo "$skill_tools") \
  <(echo "$agent_tools") \
  <(echo "$command_tools") \
  <(echo "$hook_tools") \
  <(echo "$output_style_tools") \
  2>/dev/null)

if [[ -z "$all_tools" || "$all_tools" == "null" ]]; then
  all_tools="[]"
fi

total=$(echo "$all_tools" | jq 'length')
count_mcp=$(echo "$mcp_tools" | jq 'length')
count_plugin=$(echo "$plugin_tools" | jq '[.[] | select(.type == "plugin")] | length')
count_skill=$(echo "$all_tools" | jq '[.[] | select(.type == "skill")] | length')
count_agent=$(echo "$agent_tools" | jq 'length')
count_command=$(echo "$all_tools" | jq '[.[] | select(.type == "command")] | length')
count_hook=$(echo "$hook_tools" | jq 'length')
count_output_style=$(echo "$output_style_tools" | jq 'length')

scanned_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n \
  --argjson version 1 \
  --arg scannedAt "$scanned_at" \
  --argjson total "$total" \
  --argjson mcp "$count_mcp" \
  --argjson plugin "$count_plugin" \
  --argjson skill "$count_skill" \
  --argjson agent "$count_agent" \
  --argjson command "$count_command" \
  --argjson hook "$count_hook" \
  --argjson outputStyle "$count_output_style" \
  --argjson tools "$all_tools" \
  '{
    version: $version,
    scannedAt: $scannedAt,
    summary: {
      total: $total,
      byType: {
        mcp: $mcp,
        plugin: $plugin,
        skill: $skill,
        agent: $agent,
        command: $command,
        hook: $hook,
        "output-style": $outputStyle
      }
    },
    tools: $tools
  }' > "$OUTPUT_FILE"

echo "인벤토리 빌드 완료: $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
