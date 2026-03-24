# Contributing to claude-radar

Thank you for your interest in contributing.

## Development Environment

Requirements:
- bash 4.0 or later (macOS ships with bash 3.2; install bash via `brew install bash`)
- [jq](https://jqlang.github.io/jq/) 1.6 or later
- [shellcheck](https://www.shellcheck.net/) for linting shell scripts (recommended)

## Project Structure

```
claude-radar/
  .claude-plugin/plugin.json   Plugin metadata
  hooks/                       Claude Code hook scripts
    run-hook.cmd               Cross-platform wrapper (bash + Windows batch polyglot)
    session-start              SessionStart hook script
  scanner/
    scan.sh                    Cache-aware scan orchestrator
    index-builder.sh           Builds inventory.json from all parsers
    usage-tracker.sh           Records tool usage frequency
    top-tools.sh               Queries top-N tools by usage
    lib/common.sh              Shared utilities (escape, frontmatter, realpath)
    parsers/                   One parser per tool type
      mcp-parser.sh
      plugin-parser.sh
      skill-parser.sh
      agent-parser.sh
      command-parser.sh
      hook-parser.sh
      output-style-parser.sh
  skills/                      Claude Code skills
  agents/                      Claude Code agents
  data/categories.json         Category definitions
```

## Code Style

- Indentation: 2 spaces
- All shell scripts must pass `shellcheck`
- Use `set -euo pipefail` at the top of every script
- Use `jq --arg` for all jq variable interpolation (prevents injection)
- Use `escape_json_string()` from `common.sh` for all string values written into JSON
- No inline comments in code

## Making Changes

1. Fork the repository and create a branch from `main`
2. Make your changes and run shellcheck on modified scripts:
   ```bash
   shellcheck scanner/**/*.sh hooks/session-start
   ```
3. Test your changes locally:
   ```bash
   CLAUDE_RADAR_DEBUG=1 bash scanner/scan.sh --force
   bash hooks/session-start
   ```
4. Open a pull request with a clear description of what changed and why

## Reporting Issues

Open an issue at https://github.com/theSnackOverflow/claude-radar/issues with:
- Your OS and version
- Output of `bash --version` and `jq --version`
- Steps to reproduce the problem
- Expected vs actual behavior
