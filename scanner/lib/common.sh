#!/usr/bin/env bash

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"

escape_json_string() {
  printf '%s' "$1" | jq -Rs '.'
}

parse_frontmatter() {
  local file="$1"
  local field="$2"
  sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null \
    | grep "^${field}:" \
    | head -1 \
    | sed "s/^${field}: *//" \
    | sed 's/[[:space:]]*$//' \
    | tr -d '"'\''`'
}

safe_realpath() {
  local path="$1"
  if command -v realpath &>/dev/null; then
    realpath "$path" 2>/dev/null || echo "$path"
  elif [[ -d "$path" ]]; then
    (cd "$path" 2>/dev/null && pwd) || echo "$path"
  elif [[ -f "$path" ]]; then
    local dir file
    dir="$(dirname "$path")"
    file="$(basename "$path")"
    echo "$(cd "$dir" 2>/dev/null && pwd)/$file"
  else
    echo "$path"
  fi
}
