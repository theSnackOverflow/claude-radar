# claude-radar

Automatically discovers and recommends your installed Claude Code tools.

## Problem

As your Claude Code setup grows, it becomes easy to forget what tools you have installed. You may have dozens of MCP servers, skills, agents, and plugins configured — but if they are not top of mind, you simply will not use them. claude-radar solves this by scanning your environment and surfacing the right tools at the right time.

## Features

- **Automatic scanning**: Detects all installed MCP servers, skills, agents, and plugins from your Claude Code configuration.
- **Context-based recommendations**: Analyzes your current task and suggests the most relevant tools available to you.
- **Session-start injection**: Hooks into the `SessionStart` lifecycle event to automatically surface tool summaries when you begin a new session.

## Requirements

- [jq](https://jqlang.github.io/jq/) — used for JSON parsing and generation
  - macOS: `brew install jq`
  - Ubuntu/Debian: `sudo apt install jq`
  - Windows: `choco install jq` or `scoop install jq` or `winget install jqlang.jq`

## Platform Support

| OS | Status | Notes |
|---|---|---|
| macOS | Fully supported | Intel and Apple Silicon |
| Linux | Fully supported | GNU/Linux distributions |
| Windows (WSL) | Supported | Run inside WSL2 with bash and jq installed |
| Windows (native) | Partial | Requires Git for Windows (Git Bash); Claude Code Windows support may vary |

## Installation

Install claude-radar as a Claude Code plugin via the marketplace:

```
/install-plugin claude-radar
```

Or install directly from the repository:

```
/install-plugin https://github.com/theSnackOverflow/claude-radar
```

Once installed, claude-radar activates automatically on session start.

## Usage

### Discover all installed tools

```
/discover
```

Lists every MCP server, skill, agent, and plugin currently installed in your Claude Code environment.

### Get context-aware recommendations

```
/recommend
```

Analyzes your current working context and recommends the most relevant tools from your installed set.

## How it works

1. **SessionStart hook**: When a new Claude Code session begins, the `hooks/session-start` hook fires automatically.
2. **Scanner**: The scanner reads your Claude Code configuration files (`~/.claude/settings.json`, `.claude/`, etc.) and parses each tool category using dedicated parsers in `scanner/parsers/`.
3. **Recommendation engine**: The collected inventory is cross-referenced against the current project context to produce a ranked list of recommended tools.
4. **Output injection**: The summary is injected into the session context so it is immediately available without any manual steps.

## Debugging

Set `CLAUDE_RADAR_DEBUG=1` to enable verbose output from the scanner:

```bash
CLAUDE_RADAR_DEBUG=1 bash ~/.claude/plugins/*/claude-radar/*/scanner/scan.sh --force
```

## License

MIT
