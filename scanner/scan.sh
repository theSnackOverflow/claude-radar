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
CACHE_FILE="${HOME}/.claude/cache/claude-radar/inventory.json"

FORCE_RESCAN=false
for arg in "$@"; do
  if [[ "$arg" == "--force" ]]; then
    FORCE_RESCAN=true
  fi
done

WATCH_FILES=(
  "${HOME}/.claude/mcp.json"
  "${HOME}/.claude/settings.json"
  "${HOME}/.claude/plugins/installed_plugins.json"
)

WATCH_DIRS=(
  "${HOME}/.claude/agents"
  "${HOME}/.claude/commands"
  "${HOME}/.claude/skills"
  "${HOME}/.claude/output-styles"
)

needs_rescan() {
  if [[ "$FORCE_RESCAN" == "true" ]]; then
    echo "강제 재스캔 요청됨" >&2
    return 0
  fi

  if [[ ! -f "$CACHE_FILE" ]]; then
    echo "캐시 파일이 없음, 스캔 필요" >&2
    return 0
  fi

  for watch_file in "${WATCH_FILES[@]}"; do
    if [[ -f "$watch_file" ]]; then
      if [[ "$watch_file" -nt "$CACHE_FILE" ]]; then
        echo "변경 감지: $watch_file" >&2
        return 0
      fi
    fi
  done

  for dir in "${WATCH_DIRS[@]}"; do
    if [[ -d "$dir" ]] && [[ "$dir" -nt "$CACHE_FILE" ]]; then
      echo "변경 감지: $dir" >&2
      return 0
    fi
  done

  return 1
}

if needs_rescan; then
  echo "스캔 시작..." >&2
  result=$(bash "${SCRIPT_DIR}/index-builder.sh")
  echo "$result"
else
  echo "캐시 유효, 기존 인벤토리 사용" >&2
  echo "$CACHE_FILE"
fi
