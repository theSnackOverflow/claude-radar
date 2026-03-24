# Changelog

All notable changes to claude-radar are documented here.

## [0.1.0] - 2026-03-24

### Added

- **Marketplace support**: `.claude-plugin/marketplace.json` 추가로 `/plugin marketplace add theSnackOverflow/claude-radar` 설치 지원

- **Phase 1 - Inventory Scanner**: Detects all installed Claude Code tools at session start
  - 7 parsers: MCP servers, plugins, skills, agents, commands, hooks, output styles
  - Cache-aware scanning with mtime-based invalidation
  - Atomic writes via mktemp + mv to prevent partial inventory files
  - `CLAUDE_RADAR_DEBUG=1` for verbose parser output

- **Phase 2 - Recommendation Engine**
  - `discover` skill: lists all installed tools as a formatted markdown table
  - `recommend` skill: suggests relevant tools based on current task context
  - `tool-info` skill: shows detailed information and source file for a specific tool

- **Phase 3 - Auto Execution**
  - `tool-executor` agent: executes recommended tools with user confirmation
  - Usage frequency tracking via `usage-tracker.sh`

- **Cross-platform support**
  - `run-hook.cmd`: polyglot wrapper (Windows batch + bash) for hook execution
  - `.gitattributes`: enforces LF line endings for .sh files, CRLF for .cmd
  - `safe_realpath()`: fallback for systems without the `realpath` command

### Security

- Path traversal prevention in `run-hook.cmd` (rejects `..`, `/`, `\` in script names)
- Symlink attack prevention before all atomic writes
- Secret masking in MCP server invocation strings via `mask_secrets()`
- jq `--arg` pattern used throughout to prevent JSON injection
- Cache directory created with mode 700

### Fixed

- Removed python3 dependency; JSON escaping now uses `jq -Rs`
- Preserved existing PATH instead of overwriting it (`${PATH:-}` suffix)
- Added `source` field to all parser outputs for tool-info skill compatibility
- Corrected `usage-tracker.sh` call path in `tool-executor` agent
