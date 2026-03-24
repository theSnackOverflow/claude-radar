---
name: discover
description: List installed tools, MCP servers, plugins, skills, agents, commands, hooks, and output styles from the claude-radar inventory. Triggered by requests like "list tools", "what MCPs do I have", "show plugins", "skill list", "agent list", "MCP server list", "도구 목록", "MCP 목록", "플러그인 목록", "스킬 목록", "에이전트 목록".
---

사용자가 설치된 도구, MCP 서버, 플러그인, 스킬, 에이전트 목록을 요청할 때 아래 단계를 따른다.

## Step 1: inventory.json 읽기

Read 도구로 다음 경로의 파일을 읽는다.

경로: `/Users/{username}/.claude/cache/claude-radar/inventory.json`

실제 username은 환경 변수 `HOME`의 값을 기반으로 결정한다. Bash 도구로 `echo $HOME` 을 먼저 실행해 절대 경로를 확인한 뒤 Read 도구에 전달한다. `~` 기호는 Read 도구의 file_path에 사용할 수 없으므로 반드시 절대 경로를 사용한다.

예시 순서:
1. Bash 도구: `echo $HOME` 실행하여 홈 디렉토리 확인
2. Read 도구: `{HOME 결과}/.claude/cache/claude-radar/inventory.json` 읽기

## Step 2: 파일이 없는 경우

파일을 읽는 데 실패하거나 파일이 존재하지 않으면 다음 안내를 출력한다.

```
inventory.json 파일이 없습니다.

claude-radar 스캐너를 먼저 실행해 주세요:

  새 Claude Code 세션을 시작하면 자동으로 스캔됩니다.
  또는 수동으로 실행하려면:
  ~/.claude/plugins/claude-radar/scan.sh

스캔이 완료되면 다시 시도해 주세요.
```

## Step 3: 필터링 확인

사용자의 요청에 특정 유형 필터가 포함된 경우 해당 유형만 표시한다.

필터 키워드 매핑 (tools 배열의 type 필드 기준):
- "MCP", "mcp", "--type mcp" → `type == "mcp"` 항목만
- "플러그인", "plugin", "--type plugin" → `type == "plugin"` 항목만
- "스킬", "skill", "--type skill" → `type == "skill"` 항목만
- "에이전트", "agent", "--type agent" → `type == "agent"` 항목만
- "커맨드", "command", "--type command" → `type == "command"` 항목만
- "훅", "hook", "--type hook" → `type == "hook"` 항목만
- "출력 스타일", "output style", "--type output-style" → `type == "output-style"` 항목만

필터가 없으면 모든 섹션을 표시한다.

## Step 4: 새로고침 요청 처리

사용자가 "새로고침", "다시 스캔", "--refresh", "refresh", "rescan" 을 요청하면 다음 안내를 출력한다.

```
인벤토리를 새로고침하려면:

1. 새 Claude Code 세션을 시작합니다 (자동 스캔 실행됨).
2. 또는 수동으로 스캔합니다:
   ~/.claude/plugins/claude-radar/scan.sh

완료 후 다시 도구 목록을 요청해 주세요.
```

## Step 5: 데이터 표시

inventory.json 의 데이터를 읽어 아래 형식으로 출력한다.

inventory.json 의 실제 구조:
```json
{
  "version": 1,
  "scannedAt": "2026-03-24T00:00:00Z",
  "summary": {
    "total": 15,
    "mcp": 5,
    "plugin": 2,
    "skill": 3,
    "agent": 2,
    "command": 1,
    "hook": 1,
    "output-style": 1
  },
  "tools": [
    { "id": "mcp:context7", "type": "mcp", "name": "context7", "description": null, "scope": "global", "enabled": true, "categories": ["documentation"], "invocation": "npx @context7/mcp", "source": "/Users/user/.claude/mcp.json" },
    { "id": "skill:discover", "type": "skill", "name": "discover", "description": "List installed tools", "scope": "global", "enabled": true, "invocation": "discover", "source": "/Users/user/.claude/skills/discover/SKILL.md" }
  ]
}
```

모든 도구는 `tools` 단일 배열에 포함되며 `type` 필드로 구분된다. 필드가 없으면 "-" 로 표시한다.

### 출력 형식

```
## 설치된 도구 목록 (총 {전체 합산 수}개)

스캔 시각: {scannedAt}

### MCP 서버 ({count}개)
| 이름 | 설명 | 상태 |
|------|------|------|
| {name} | {description} | {status} |

### Plugins ({count}개)
| 이름 | 버전 | 상태 |
|------|------|------|
| {name} | {version} | {status} |

### Skills ({count}개)
| 이름 | 출처 | 설명 |
|------|------|------|
| {name} | {source} | {description} |

### Agents ({count}개)
| 이름 | 설명 |
|------|------|
| {name} | {description} |

### Commands ({count}개)
| 이름 | 설명 |
|------|------|
| {name} | {description} |

### Hooks ({count}개)
| 이름 | 이벤트 | 설명 |
|------|--------|------|
| {name} | {event} | {description} |

### Output Styles ({count}개)
| 이름 | 설명 |
|------|------|
| {name} | {description} |
```

각 섹션의 아이템이 0개이면 해당 섹션은 생략한다.

필터가 적용된 경우에는 해당 섹션만 출력하고 상단에 다음을 추가한다.

```
(필터 적용: {필터 유형})
```

## 주의사항

- Read 도구의 file_path에는 반드시 절대 경로를 사용한다 (`~` 사용 불가).
- inventory.json 의 실제 필드명이 예상 구조와 다를 수 있으므로 읽은 JSON의 실제 키를 기반으로 렌더링한다.
- 숫자 카운트는 각 배열의 실제 length 값을 사용한다.
- 총 합산 수는 표시되는 모든 섹션의 아이템 수를 합산한다.
