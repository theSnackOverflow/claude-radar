#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is not installed." >&2
  echo "  macOS:   brew install jq" >&2
  echo "  Ubuntu:  sudo apt install jq" >&2
  echo "  Windows: choco install jq  (or: scoop install jq  /  winget install jqlang.jq)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSERS_DIR="${SCRIPT_DIR}/parsers"
OUTPUT_DIR="${HOME}/.claude/cache/claude-radar"
OUTPUT_FILE="${OUTPUT_DIR}/inventory.json"

mkdir -p -m 700 "$OUTPUT_DIR"

LOCK_FILE="${OUTPUT_DIR}/scan.lock"
if command -v flock &>/dev/null; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    echo "Another scan is already running. Skipping." >&2
    echo "$OUTPUT_FILE"
    exit 0
  fi
fi

run_parser() {
  local parser_name="$1"
  local parser_path="${PARSERS_DIR}/${parser_name}"
  if [[ ! -f "$parser_path" ]]; then
    [[ "${CLAUDE_RADAR_DEBUG:-}" == "1" ]] && echo "Warning: Parser not found: $parser_path" >&2
    echo "[]"
    return
  fi
  if [[ "${CLAUDE_RADAR_DEBUG:-}" == "1" ]]; then
    echo "Running parser: $parser_name" >&2
    bash "$parser_path"
  else
    bash "$parser_path" 2>/dev/null
  fi
}

echo "파서 실행 중..." >&2

mcp_tools=$(run_parser "mcp-parser.sh")
plugin_tools=$(run_parser "plugin-parser.sh")
skill_tools=$(run_parser "skill-parser.sh")
agent_tools=$(run_parser "agent-parser.sh")
command_tools=$(run_parser "command-parser.sh")
hook_tools=$(run_parser "hook-parser.sh")
output_style_tools=$(run_parser "output-style-parser.sh")

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

TMP_FILE=$(mktemp "${OUTPUT_DIR}/inventory.json.tmp.XXXXXX") || {
  echo "Error: Failed to create temporary file in ${OUTPUT_DIR}. Disk may be full." >&2
  exit 1
}
trap 'rm -f "$TMP_FILE"' EXIT

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
  }' > "$TMP_FILE"

if [[ -L "$OUTPUT_FILE" ]]; then
  echo "Error: $OUTPUT_FILE is a symbolic link. Aborting." >&2
  exit 1
fi

mv "$TMP_FILE" "$OUTPUT_FILE"
chmod 600 "$OUTPUT_FILE"
trap - EXIT

echo "인벤토리 빌드 완료: $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
