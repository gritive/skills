---
name: setup
description: "Use when the user asks to set up or configure the gritive plugin for their project, or says 'gritive 설정', 'gritive setup', '플러그인 셋업', 'codebase-review 설정', 'persona-test 설정', '--setup'. Analyzes the project and configures CLAUDE.md for optimal use of codebase-review and persona-test skills."
---

# Gritive Plugin Setup

프로젝트를 분석하여 gritive 플러그인(codebase-review, persona-test)에 최적화된 CLAUDE.md 설정을 자동 생성하는 스킬.

## 인자 처리

| 인자        | 동작                                       |
| ----------- | ------------------------------------------ |
| (없음)      | 전체 설정 (codebase-review + persona-test) |
| `--review`  | codebase-review 설정만                     |
| `--persona` | persona-test 설정만                        |

## Phase 1: 프로젝트 분석

### 1-1. 기술 스택 탐지

아래 파일을 순서대로 확인하여 기술 스택을 파악한다:

| 파일                                  | 정보                                                          |
| ------------------------------------- | ------------------------------------------------------------- |
| `go.mod`                              | Go 버전, 프레임워크 (echo, gin, fiber 등)                     |
| `package.json`                        | Node.js, 프레임워크 (next, svelte, vue 등), 테스트 라이브러리 |
| `Cargo.toml`                          | Rust 버전, 프레임워크                                         |
| `pyproject.toml` / `requirements.txt` | Python 버전, 프레임워크 (django, fastapi 등)                  |
| `tsconfig.json`                       | TypeScript 설정, strict 여부                                  |
| `docker-compose.yml`                  | 데이터베이스, 인프라 서비스                                   |

### 1-2. 아키텍처 패턴 탐지

디렉토리 구조를 분석하여 아키텍처 패턴을 추론한다:

- `cmd/`, `internal/`, `pkg/` → Go 표준 레이아웃
- `src/routes/`, `src/lib/` → SvelteKit
- `app/`, `pages/` → Next.js
- `handlers/` 또는 `controllers/` → MVC/계층 구조
- `domain/`, `infrastructure/` → Clean Architecture / DDD

### 1-3. 기존 CLAUDE.md 확인

현재 CLAUDE.md를 읽고:
- 이미 `## Codebase Review` 또는 `## Persona Test` 섹션이 있는지 확인
- 기존 아키텍처 원칙, 보안 규칙, 코딩 컨벤션이 있는지 확인
- 있으면 기존 내용을 보존하고 gritive 섹션만 추가/병합

### 1-4. 인터페이스 탐지 (persona-test용)

프로젝트에서 제공하는 인터페이스를 탐지한다:

| 단서                                         | 인터페이스 |
| -------------------------------------------- | ---------- |
| `src/routes/`, `pages/`, `app/` (프론트엔드) | web        |
| `cmd/` + `cobra`, `urfave/cli`               | cli        |
| `.mcp.json`, MCP 서버 설정                   | mcp        |
| `openapi.yaml`, `/api/` 라우트               | api        |
| `hooks/hooks.json`, plugin 설정              | plugin     |

## Phase 2: 설정 초안 생성

분석 결과를 기반으로 CLAUDE.md에 추가할 섹션 초안을 생성한다.

### Codebase Review 섹션 (`--review` 또는 기본)

```markdown
## Codebase Review

### 기술 스택
- Backend: {탐지된 언어/프레임워크}
- Frontend: {탐지된 프레임워크}
- Database: {탐지된 DB}
- 테스트: {탐지된 테스트 프레임워크}

### 아키텍처 원칙
{디렉토리 구조에서 추론한 계층/패턴}

### 보안 규칙
{기존 CLAUDE.md에서 추출 또는 기본 권장사항}

### 코딩 규칙
{기존 CLAUDE.md에서 추출 또는 기본 권장사항}

### 성능 규칙
{기본 권장사항}
```

### Persona Test 섹션 (`--persona` 또는 기본)

```markdown
## Persona Test

### 인터페이스
| 인터페이스 | URL/명령어 | 확인 방법 |
| ---------- | ---------- | --------- |
{탐지된 인터페이스별 행}

### 테스트 계정
- 위치: {추정 경로 또는 "설정 필요"}

### 제품 스펙
- {docs/ 내 스펙 문서 경로 또는 "설정 필요"}
```

> 상세 설정 가이드: `references/` 디렉토리 내 각 스킬의 `claude-md-setup.md` 참조

## Phase 3: 사용자 확인 및 적용

1. 생성된 초안을 사용자에게 보여준다
2. 수정 요청이 있으면 반영한다
3. 확인 후 CLAUDE.md에 추가한다:
   - 기존 CLAUDE.md가 있으면 하단에 섹션 추가
   - 기존에 동일 섹션이 있으면 병합 (기존 내용 우선)
   - CLAUDE.md가 없으면 새로 생성

### 적용 규칙

- 기존 CLAUDE.md의 다른 섹션은 **절대 수정하지 않는다**
- `## Codebase Review`와 `## Persona Test` 섹션만 추가/업데이트한다
- 이미 해당 섹션이 있으면 사용자에게 덮어쓸지 확인한다
- 탐지하지 못한 항목은 `{설정 필요}`로 표시하여 사용자가 채우도록 안내한다

## Phase 4: 결과 보고

```markdown
## Gritive Setup 완료

### 탐지된 기술 스택
- ...

### CLAUDE.md에 추가된 섹션
- [x/] Codebase Review
- [x/] Persona Test

### 수동 설정 필요 항목
- [ ] {설정 필요로 표시된 항목들}

### 다음 단계
- `/codebase-review` 로 첫 리뷰 실행
- `/persona-test` 로 첫 페르소나 테스트 실행
```
