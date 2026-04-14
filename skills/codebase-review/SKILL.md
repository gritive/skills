---
name: codebase-review
description: "Use when the user asks for a codebase review, code health check, architecture audit, or says '코드 리뷰', '코드베이스 점검', '전체 리뷰', 'codebase review', 'health check', 'code quality'. 6개 병렬 리뷰 에이전트(아키텍처, 리팩토링, 데드코드, 성능, 보안, 프론트엔드)로 코드베이스를 종합 점검하고 우선순위 리포트 생성."
---

# Codebase Review

6개 리뷰 에이전트를 병렬 실행하여 코드베이스를 종합 점검하는 스킬.

## 리뷰 도메인

| 도메인       | 에이전트              | 점검 항목                                            |
| ------------ | --------------------- | ---------------------------------------------------- |
| Architecture | `arch-reviewer`       | 계층 위반, 순환 의존, 관심사 분리, 모듈 구조         |
| Refactoring  | `refactor-reviewer`   | 코드 중복, 복잡도, 코드 스멜, 네이밍                 |
| Dead Code    | `deadcode-reviewer`   | 미사용 함수, 고아 파일, 미사용 의존성                |
| Performance  | `perf-reviewer`       | N+1 쿼리, 메모리 릭, 번들 크기, 캐싱                 |
| Security     | `security-reviewer`   | 인증/인가, 입력 검증, 주입 공격, 시크릿 노출         |
| Frontend     | `frontend-reviewer`   | 타입 안전성, 컴포넌트 품질, a11y, 상태 관리, SSR 호환성 |

## CLAUDE.md 연동

모든 에이전트는 범용 점검 항목을 기본으로 수행하되, **프로젝트 CLAUDE.md를 읽고 Critical Rules, 보안/아키텍처 원칙을 자동 반영**한다.

- 예시: CLAUDE.md에 `workspace_id 필수` 규칙이 있으면 → Security 에이전트가 쿼리별 필터링 누락 점검
- 예시: CLAUDE.md에 `soft delete` 규칙이 있으면 → Architecture/Security 에이전트가 물리 삭제 사용 탐지
- 예시: CLAUDE.md에 특정 프레임워크 패턴이 있으면 → 해당 도메인 에이전트가 패턴 준수 여부 점검

> 프로젝트 CLAUDE.md 설정 가이드: `references/claude-md-setup.md` 참조.
> 자동 설정은 `/setup --review` 으로 실행.

## 리뷰 이력

리뷰 완료 시 프로젝트 루트에 `.codebase-review.jsonl`을 append하여 이력을 관리한다.

**엔트리 형식**:
```json
{"ts":"2026-04-15T14:30:00+09:00","commit":"e57e40d8","scope":"all","domains":["arch","refactor","deadcode","perf","security","frontend"],"issues":{"critical":0,"high":3,"medium":12,"low":5},"files_reviewed":42}
```

**이력 활용**:
- 기본 동작: 이력이 있으면 마지막 리뷰의 `commit` 이후 변경 파일만 리뷰 (since-last)
- 이력이 없으면 전체 리뷰 (첫 실행)
- Phase 4 리포트에 "이전 리뷰 대비" 트렌드 표시 (이력이 2건 이상일 때)

## Workflow

### Phase 1: 범위 확인

사용자에게 리뷰 범위를 확인한다.

**파일 범위 (기본: since-last)**:

| 옵션        | 설명                                                            |
| ----------- | --------------------------------------------------------------- |
| (기본)      | 이력 있으면 마지막 리뷰 이후 변경분만, 이력 없으면 전체         |
| `--full`    | 이력 무시하고 전체 코드베이스 리뷰                              |
| `--changed` | git diff HEAD 기준 커밋되지 않은 변경 파일만                    |

**코드 범위**:

| 옵션              | 설명                                                          |
| ----------------- | ------------------------------------------------------------- |
| `all` (기본)      | 백엔드 + 프론트엔드 전체                                     |
| `backend`         | 백엔드만 (프로젝트 구조에서 자동 탐지)                        |
| `frontend`        | 프론트엔드만 (프로젝트 구조에서 자동 탐지)                    |
| `--domain <name>` | 특정 도메인만 (arch, refactor, deadcode, perf, security, frontend). 콤마로 복수 |

범위가 명확하면 확인 없이 바로 진행.

**도메인 필터링 규칙**:
- `--domain`이 없으면 scope에 따라 관련 도메인 전부 실행
- scope=`backend`이면 Frontend 도메인 자동 제외
- scope=`frontend`이면 Architecture, Security 중 백엔드 전용 점검 제외
- `--domain`이 있으면 scope 무관하게 지정된 도메인만 실행
- **`--domain` 지정 시 since-last 무시**: 해당 도메인의 전체 파일 대상

### Phase 2: 변경 범위 수집

파일 범위를 결정한다. **기본 동작은 since-last**.

**기본 동작 (since-last)**:
```bash
# 1. 이력 파일에서 마지막 리뷰 커밋 읽기
LAST_COMMIT=$(tail -1 .codebase-review.jsonl | jq -r '.commit')
# 2. 해당 커밋이 현재 브랜치에 존재하는지 확인
git merge-base --is-ancestor $LAST_COMMIT HEAD
# 3. 변경 파일 수집
git diff --name-only $LAST_COMMIT...HEAD
```

- 이력이 없거나 마지막 커밋을 찾을 수 없으면 **전체 리뷰로 폴백**
- 리포트 헤더에 모드 표시

### Phase 3: 에이전트 병렬 실행

**필터링된 에이전트를 동시에 실행한다.** 각 에이전트에 scope, 대상 파일 목록, CLAUDE.md 참조 지시를 전달.

```
Agent(subagent_type="arch-reviewer", prompt="
  scope: {scope}. 대상: {파일 목록 or 전체}.
  반드시 CLAUDE.md를 먼저 읽고 프로젝트의 아키텍처 원칙과 Critical Rules를 반영하라.
")
Agent(subagent_type="refactor-reviewer", prompt="
  scope: {scope}. 대상: {파일 목록 or 전체}.
  반드시 CLAUDE.md를 먼저 읽고 프로젝트의 코딩 규칙을 반영하라.
")
Agent(subagent_type="deadcode-reviewer", prompt="
  scope: {scope}. 대상: {파일 목록 or 전체}.
  반드시 CLAUDE.md를 먼저 읽고 프로젝트 구조와 규칙을 반영하라.
")
Agent(subagent_type="perf-reviewer", prompt="
  scope: {scope}. 대상: {파일 목록 or 전체}.
  반드시 CLAUDE.md를 먼저 읽고 프로젝트의 성능 관련 규칙을 반영하라.
")
Agent(subagent_type="security-reviewer", prompt="
  scope: {scope}. 대상: {파일 목록 or 전체}.
  반드시 CLAUDE.md를 먼저 읽고 프로젝트의 보안 원칙과 Critical Rules를 반영하라.
")
Agent(subagent_type="frontend-reviewer", prompt="
  scope: {scope}. 대상: {파일 목록 or 전체}.
  반드시 CLAUDE.md를 먼저 읽고 프로젝트의 프론트엔드 프레임워크와 규칙을 파악하라.
")
```

`--domain` 옵션으로 특정 도메인만 지정된 경우 해당 에이전트만 실행.

**에이전트 부재 시**: 에이전트가 존재하지 않으면 해당 도메인을 건너뛰고 리포트에 '미실행' 표시. 최소 1개 에이전트가 실행되면 리포트를 생성한다.

**중요**: 에이전트는 **리서치만** 수행한다. 코드 수정은 하지 않는다.

### Phase 4: 결과 종합

에이전트의 결과를 종합하여 아래 형식으로 리포트.

```markdown
# Codebase Review Report

**범위**: {scope} | **날짜**: {date} | **대상 파일**: {N}개 | **도메인**: {실행된 도메인 목록}
**모드**: 전체 / --changed / --since-last ({last_commit}...HEAD, {N}일 전)

## 이전 리뷰 대비 (이력 2건 이상일 때만 표시)

| 지표        | 이전 리뷰   | 이번 리뷰   | 변화 |
| ----------- | ----------- | ----------- | ---- |
| Critical    |             |             |      |
| High        |             |             |      |
| Medium      |             |             |      |
| Low         |             |             |      |

## 요약 대시보드

| 도메인       | 발견 수 | Critical | High | Medium | Low |
| ------------ | ------- | -------- | ---- | ------ | --- |
| Architecture |         |          |      |        |     |
| Refactoring  |         |          |      |        |     |
| Dead Code    |         |          |      |        |     |
| Performance  |         |          |      |        |     |
| Security     |         |          |      |        |     |
| Frontend     |         |          |      |        |     |
| **합계**     |         |          |      |        |     |

(실행되지 않은 도메인은 테이블에서 제외)

## Top 10 우선순위 이슈

| #   | 도메인 | 심각도 | 파일:라인 | 설명 | 개선 방안 |
| --- | ------ | ------ | --------- | ---- | --------- |

## 도메인별 상세
(실행된 도메인만 섹션 포함)

## 액션 플랜

### 즉시 수정 (이번 스프린트)
### 단기 개선 (1-2주)
### 장기 리팩토링 (백로그)
```

### Phase 5: 이력 기록

리포트 생성 후, `.codebase-review.jsonl`에 이번 리뷰 결과를 append한다.

- `.gitignore`에 포함 여부는 팀 판단에 맡긴다
- 이력은 최대 50건 유지 (초과 시 오래된 엔트리 제거)

### Phase 6: 후속 조치 (선택)

사용자가 요청하면:
1. 발견된 이슈를 태스크 관리 도구에 등록
2. 특정 이슈를 바로 수정 (TDD 원칙에 따라)
3. 리포트를 파일로 저장

## 실행 예시

```
/codebase-review                          → since-last (이력 없으면 전체), 6개 도메인
/codebase-review --full                   → 전체 코드베이스, 6개 도메인
/codebase-review backend                  → 백엔드 since-last, Frontend 제외 5개
/codebase-review frontend                 → 프론트엔드 since-last, 4개 도메인
/codebase-review --domain perf,security   → since-last 무시, 전체 대상, 2개 도메인만
/codebase-review --changed                → 미커밋 변경분만, 6개 도메인
```

## 주의사항

- 에이전트는 **읽기 전용**. 코드를 수정하지 않는다.
- 오탐(false positive) 가능성이 있으면 확신도를 명시한다.
- 리포트가 너무 길면 Top 10 + 도메인별 Top 5로 요약한다.
