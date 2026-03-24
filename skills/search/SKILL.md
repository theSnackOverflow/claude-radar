---
name: search
description: 현재 프로젝트의 기술 스택을 분석하여 GitHub에서 아직 설치하지 않은 Claude Code 도구(MCP 서버, 플러그인, 스킬 등)를 검색하여 제안합니다. "도구 검색", "새 도구 찾기", "MCP 검색", "search tools", "find plugins", "find MCP", "추천 플러그인 검색", "기술 스택에 맞는 도구", "어떤 도구를 설치할 수 있어" 패턴의 요청에 응답합니다.
---

사용자가 현재 프로젝트에 맞는 새 Claude Code 도구를 찾고 싶을 때 아래 단계를 따른다.

## Step 1: 프로젝트 기술 스택 분석

Bash 도구로 `echo $HOME`을 실행해 홈 디렉토리 절대 경로를 확인하고, `pwd`로 현재 작업 디렉토리(CWD)를 확인한다.

Glob 도구로 CWD에서 다음 설정 파일들을 탐색한다.

- `package.json`, `tsconfig.json` (Node.js / TypeScript)
- `pyproject.toml`, `requirements.txt`, `setup.py` (Python)
- `Cargo.toml` (Rust)
- `go.mod` (Go)
- `Gemfile` (Ruby)
- `composer.json` (PHP)
- `pom.xml`, `build.gradle` (Java / Kotlin)
- `Dockerfile`, `docker-compose.yml`
- `.github/workflows/*.yml`

감지된 설정 파일을 Read 도구로 읽어 의존성과 기술 스택을 추출한다.

- `package.json`: `dependencies`, `devDependencies`에서 프레임워크와 주요 라이브러리 추출
- `pyproject.toml`: `[project.dependencies]` 또는 `[tool.poetry.dependencies]` 추출
- 나머지 파일도 동일 방식으로 주요 의존성 추출
- `package-lock.json`, `yarn.lock`, `poetry.lock` 등 lock 파일은 건너뛴다

이어서 Grep 도구로 CWD의 소스 코드에서 import 패턴을 샘플링하여 설정 파일에 없는 라이브러리를 추가로 파악한다.

- 대상 디렉토리: `src/`, `lib/`, `app/`, `pages/`, `components/` (없으면 CWD 루트)
- `*.ts`, `*.tsx`, `*.js`, `*.jsx`: `^import .+ from` 패턴 (최대 20개 파일)
- `*.py`: `^import `, `^from .+ import` 패턴 (최대 20개 파일)
- `node_modules/`, `.venv/`, `target/`, `vendor/`, `dist/` 디렉토리는 무시

분석 결과를 다음 형식으로 요약한다.

- 언어: (예: TypeScript, Python)
- 프레임워크: (예: Next.js, FastAPI)
- 주요 라이브러리: (예: Prisma, Tailwind CSS)
- 개발 도구: (예: Docker, GitHub Actions)

설정 파일이 전혀 없으면 다음과 같이 질문한다.

```
현재 디렉토리에서 프로젝트 설정 파일을 찾지 못했습니다.
어떤 언어나 프레임워크를 사용 중인가요?
```

## Step 2: 설치된 도구 목록 확보

Read 도구로 `{HOME}/.claude/cache/claude-radar/inventory.json`을 읽는다. `~` 기호는 Read 도구의 file_path에 사용할 수 없으므로 반드시 절대 경로를 사용한다.

파일이 없어도 Step 3으로 진행한다. 단, 다음 안내를 출력한다.

```
(인벤토리 파일이 없어 설치된 도구와의 중복 확인을 건너뜁니다.)
```

파일이 있으면 `tools` 배열에서 각 항목의 `id`, `name`, `source` 필드를 추출하여 설치된 도구 목록을 구성한다.

## Step 3: GitHub 검색

Step 1에서 파악한 기술 스택을 기반으로 WebSearch 도구를 **2~3회** 실행한다.

쿼리 구성 시 주의사항:
- 가장 특징적인 키워드 2~3개를 선택한다 (javascript, python 같은 범용 키워드보다 구체적인 프레임워크/라이브러리명 우선)
- 첫 검색 결과가 부족하면 키워드를 줄여 재검색한다

기본 검색 쿼리 패턴:

- 쿼리 1: `site:github.com mcp-server {주요 프레임워크/언어}` (예: `site:github.com mcp-server nextjs typescript`)
- 쿼리 2: `site:github.com claude-code plugin OR skill {주요 프레임워크/언어}` (예: `site:github.com claude-code plugin react`)
- 쿼리 3 (핵심 라이브러리가 있는 경우): `site:github.com claude MCP {주요 라이브러리}` (예: `site:github.com claude MCP prisma`)

각 검색 결과에서 다음 정보를 추출한다.

- 레포지토리 이름 (owner/repo 형식)
- 설명
- URL
- 스타 수 (표시된 경우)

## Step 4: 필터링 및 결과 표시

다음 기준으로 결과를 필터링한다.

1. 중복 레포지토리 제거 (동일 URL 기준)
2. Step 2에서 확보한 설치된 도구 목록과 비교하여 이미 설치된 것 제외 (레포 이름이 설치된 도구의 `name` 또는 `source` 경로에 포함되는 경우)
3. 실제 Claude Code 도구인지 확인 (설명에 MCP, Claude Code, plugin, skill, claude-code 등의 키워드가 포함된 경우만 포함)
4. archived 또는 deprecated 레포지토리 제외

필터링 후 다음 기준으로 관련도 순 정렬한다.

- 프로젝트 기술 스택과의 직접 관련성 (가장 중요)
- 스타 수 및 최근 활성도 (보조 기준)
- 도구 유형 (MCP 서버 > 플러그인 > 기타)

상위 5~10개를 선정하여 다음 형식으로 출력한다.

```
## 프로젝트 기술 스택 분석

{언어} + {프레임워크} + {주요 라이브러리}

## 추천 도구 검색 결과 ({n}개)

{제외된 설치 도구 수}개의 관련 도구가 이미 설치되어 있어 제외되었습니다.

| 순위 | 이름 | 유형 | 설명 | 관련 기술 |
|------|------|------|------|-----------|
| 1 | [{owner/repo}]({url}) | MCP 서버 | {설명} | {관련 기술} |
| 2 | [{owner/repo}]({url}) | 플러그인 | {설명} | {관련 기술} |

### 설치 방법

**MCP 서버**: `claude mcp add {name} -- npx {package}`
**Claude Code 플러그인**: `/plugin install {url}`
```

검색 결과가 없거나 모두 필터링된 경우 다음을 출력한다.

```
현재 기술 스택({기술 요약})에 맞는 새로운 도구를 찾지 못했습니다.

다음을 시도해 보세요:
- 특정 키워드로 직접 요청: "{키워드} MCP 서버 찾아줘"
- 이미 설치된 도구 확인: `claude-radar:discover`
```

## Step 5: 추가 액션 안내

결과 표시 후 다음 문장을 출력한다.

```
관심 있는 도구가 있으면 이름을 말씀해주세요. 상세 정보를 확인하거나 설치를 도와드리겠습니다.
```

## 주의사항

- Read 도구의 file_path에는 반드시 절대 경로를 사용한다 (`~` 사용 불가).
- WebSearch 호출은 최소 2회, 최대 3회로 제한한다.
- `site:github.com` 접두사로 GitHub 레포지토리 결과만 필터링한다.
- 블로그, 문서, StackOverflow 등 GitHub가 아닌 URL은 제외한다.
- lock 파일(`package-lock.json`, `yarn.lock`, `poetry.lock` 등)은 읽지 않는다.
- import 분석 시 `node_modules/`, `.venv/`, `target/`, `vendor/`, `dist/` 디렉토리 내 파일은 무시한다.
