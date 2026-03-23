---
name: tool-info
description: 특정 도구의 상세 정보를 표시합니다. "playwright가 뭐야", "commit skill 자세히", "tool-info playwright", "X 도구 설명", "X가 어떻게 작동해", "X 사용법", "tell me about X tool", "what does X do", "how to use X" 패턴의 요청에 응답합니다.
---

사용자가 특정 도구에 대한 상세 정보를 요청할 때 아래 단계를 따른다.

## Step 1: 도구 이름 파악

사용자 메시지에서 도구 이름을 추출한다.

추출 패턴 예시:
- "playwright가 뭐야" → playwright
- "commit skill 자세히" → commit
- "tool-info playwright" → playwright
- "X 도구 설명" → X
- "X가 어떻게 작동해" → X
- "X 사용법" → X
- "tell me about X tool" → X
- "what does X do" → X
- "how to use X" → X

도구 이름을 명확히 파악할 수 없으면 다음과 같이 질문한다.

```
어떤 도구에 대해 알고 싶으신가요?
```

## Step 2: 인벤토리에서 도구 검색

Bash 도구로 `echo $HOME`을 실행해 홈 디렉토리 절대 경로를 확인한 뒤, Read 도구로 `{HOME}/.claude/cache/claude-radar/inventory.json`을 읽는다. `~` 기호는 Read 도구의 file_path에 사용할 수 없으므로 반드시 절대 경로를 사용한다.

파일을 읽는 데 실패하거나 파일이 없으면 다음을 출력한다.

```
inventory.json 파일이 없습니다.

claude-radar 스캐너를 먼저 실행해 주세요:
  새 Claude Code 세션을 시작하면 자동으로 스캔됩니다.
```

파일을 읽은 후 tools 배열에서 도구를 다음 순서로 검색한다.

1. name 완전 일치
2. id 완전 일치
3. name 부분 일치 (예: "playwright"로 "mcp:playwright" 매칭)
4. id 부분 일치

검색 결과가 여러 개이면 목록을 표시하고 선택을 요청한다.

```
"{입력값}"과 일치하는 도구가 여러 개 있습니다:

1. {id1} ({type1})
2. {id2} ({type2})
3. {id3} ({type3})

번호로 선택해 주세요.
```

도구를 찾지 못하면 다음을 출력한다.

```
"{입력값}" 도구를 찾을 수 없습니다.

`claude-radar:discover` skill로 전체 목록을 확인해보세요.
```

## Step 3: 기본 정보 표시

도구를 찾으면 유형별로 레이블을 변환해 기본 정보 테이블을 출력한다.

유형 레이블 변환:
- mcp → MCP 서버
- skill → Skill
- agent → Agent
- plugin → Plugin
- command → Command
- hook → Hook
- output-style → Output Style

상태 변환:
- enabled: true → 활성
- enabled: false → 비활성

```
## {name}

| 항목 | 값 |
|------|-----|
| 유형 | {유형 레이블} |
| 상태 | {상태} |
| 범위 | {scope} |
| 카테고리 | {categories 쉼표 구분, 없으면 "-"} |
| 설명 | {description, 없으면 "-"} |
| 호출 방법 | {invocation, 없으면 "-"} |
| 출처 | {source, 없으면 "-"} |
```

plugin 항목이 있으면 테이블에 다음 행을 추가한다.

```
| 플러그인 | {plugin} |
```

model 항목이 있으면 테이블에 다음 행을 추가한다.

```
| 모델 | {model} |
```

## Step 4: 상세 내용 표시 (도구 유형별)

### MCP 서버 (type: mcp)

invocation 값이 있으면 다음 형식으로 실행 명령을 표시한다.

```
### 실행 명령

{invocation}
```

### Skill (type: skill)

source 경로가 있으면 Read 도구로 해당 파일을 읽어 전체 내용을 표시한다. source 경로에 `~`가 포함된 경우 `$HOME`의 절대 경로로 치환해 Read 도구에 전달한다.

```
### SKILL.md 내용

{파일 전체 내용}
```

파일을 읽는 데 실패하면 다음을 출력한다.

```
### SKILL.md 내용

파일을 읽을 수 없습니다: {source}
```

### Agent (type: agent)

source 경로가 있으면 Read 도구로 해당 파일을 읽어 전체 내용을 표시한다. source 경로에 `~`가 포함된 경우 `$HOME`의 절대 경로로 치환한다.

```
### Agent 정의 내용

{파일 전체 내용}
```

파일을 읽는 데 실패하면 다음을 출력한다.

```
### Agent 정의 내용

파일을 읽을 수 없습니다: {source}
```

### Plugin (type: plugin)

inventory.json의 tools 배열에서 해당 plugin 이름과 연결된 하위 skill, agent, command를 찾아 표시한다. 하위 도구는 `plugin` 필드가 `{pluginName}` 또는 `{pluginName}@{scope}` 형태로 매칭되는 항목이다.

```
### 포함된 도구

**Skills ({count}개)**
| 이름 | 설명 |
|------|------|
| {name} | {description} |

**Commands ({count}개)**
| 이름 | 설명 |
|------|------|
| {name} | {description} |

**Agents ({count}개)**
| 이름 | 설명 |
|------|------|
| {name} | {description} |
```

해당 유형의 하위 도구가 없으면 해당 섹션을 생략한다.

### Command (type: command)

source 경로가 있으면 Read 도구로 해당 파일을 읽어 전체 내용을 표시한다. source 경로에 `~`가 포함된 경우 `$HOME`의 절대 경로로 치환한다.

```
### Command 정의 내용

{파일 전체 내용}
```

파일을 읽는 데 실패하면 다음을 출력한다.

```
### Command 정의 내용

파일을 읽을 수 없습니다: {source}
```

## Step 5: 사용 팁

도구 유형에 맞는 사용 방법을 아래 형식으로 표시한다.

```
### 사용 팁
```

유형별 사용 팁:

**MCP 서버**:
- Claude Code에서 `mcp__{name}__{도구명}` 형태로 자동 노출된다.
- 사용 가능한 도구 목록은 세션 시작 시 자동으로 로드된다.

**Skill**:
- 대화 중 "{invocation}" 키워드로 이 skill을 실행할 수 있다.
- Skill tool을 통해 직접 호출할 수도 있다.

**Agent**:
- Task 에이전트로 실행된다: `@{name}` 또는 Skill tool로 호출.
- model 값이 지정된 경우 해당 모델을 사용한다.

**Plugin**:
- 플러그인이 활성화되어 있으면 하위 도구들이 자동으로 사용 가능하다.
- 플러그인 내 개별 도구는 각각 별도 invocation으로 호출한다.

**Command**:
- `/` 슬래시 커맨드로 실행한다: `/{invocation}`

**Hook**:
- 특정 이벤트 발생 시 자동으로 실행된다.

**Output Style**:
- 출력 형식을 지정하는 스타일이다. 요청 시 자동으로 적용된다.

키워드가 있으면 관련 키워드도 표시한다.

```
관련 키워드: {keywords 쉼표 구분}
```

keywords 배열이 비어 있으면 이 줄을 생략한다.

inventory.json의 tools 배열에서 동일한 카테고리를 가진 다른 도구가 있으면 "함께 쓰면 좋은 도구" 섹션을 추가한다. 최대 3개까지만 표시한다.

```
### 함께 쓰면 좋은 도구

| 이름 | 유형 | 설명 |
|------|------|------|
| {name} | {type} | {description} |
```

## 주의사항

- Read 도구의 file_path에는 반드시 절대 경로를 사용한다 (`~` 사용 불가).
- source 경로가 있고 파일을 실제로 읽을 수 있을 때만 상세 내용을 표시한다.
- source 경로의 `~`는 반드시 `$HOME` 절대 경로로 치환한 뒤 Read 도구에 전달한다.
- description이 null이거나 빈 값이면 "-"으로 표시한다.
- categories 배열이 비어 있으면 "-"으로 표시한다.
