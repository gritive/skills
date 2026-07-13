---
name: codebase-review
description: "Use when the user asks for a codebase review, code health check, architecture audit, or says '코드 리뷰', '코드베이스 점검', '전체 리뷰', 'codebase review', 'health check', 'code quality'. 6개 병렬 리뷰 에이전트(아키텍처, 리팩토링, 데드코드, 성능, 보안, 프론트엔드)로 base branch 대비 변경분을 종합 점검하고 우선순위 리포트 생성."
---

# Codebase Review

6개 리뷰 에이전트를 병렬 실행하여 코드를 종합 점검하는 스킬.

**기본 대상은 base branch 대비 변경분이다.** 전체 코드베이스 스캔은 `full`을 명시했을 때만 수행한다.

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

## Workflow

### Phase 1: 인자 파싱

**리뷰 모드 (택 1, 기본은 base-diff)**

| 인자          | 모드        | 대상                                                    |
| ------------- | ----------- | ------------------------------------------------------- |
| (없음)        | `base-diff` | base branch 대비 변경 파일 (**기본**)                   |
| `full`        | `full`      | 코드베이스 전체 — **명시할 때만** 실행                  |
| `<git-rev>`   | `base-diff` | 지정한 git revision 표현식의 diff                       |
| `--working`   | `base-diff` | 커밋되지 않은 변경분 (스테이징 + 워킹트리)              |
| `--staged`    | `base-diff` | 스테이징된 변경분만                                     |

`<git-rev>`는 git이 이해하는 표현식을 그대로 받는다: `main..HEAD`, `develop...HEAD`, `abc123`, `v1.0..v1.1`.
`full` / `backend` / `frontend` / `all`이 아니면서 `--`로 시작하지 않는 위치 인자는 git revision으로 간주한다.

**코드 범위**

| 옵션              | 설명                                                                            |
| ----------------- | ------------------------------------------------------------------------------- |
| `all` (기본)      | 백엔드 + 프론트엔드 전체                                                        |
| `backend`         | 백엔드만 (프로젝트 구조에서 자동 탐지)                                          |
| `frontend`        | 프론트엔드만 (프로젝트 구조에서 자동 탐지)                                      |
| `--domain <name>` | 특정 도메인만 (arch, refactor, deadcode, perf, security, frontend). 콤마로 복수 |

**도메인 필터링 규칙**
- `--domain`이 없으면 scope에 따라 관련 도메인 전부 실행
- scope=`backend`이면 Frontend 도메인 자동 제외
- scope=`frontend`이면 Architecture, Security 중 백엔드 전용 점검 제외
- `--domain`이 있으면 scope 무관하게 지정된 도메인만 실행
- **`--domain`은 리뷰 모드와 직교한다.** 도메인을 좁혀도 대상 파일 범위는 넓어지지 않는다.

### Phase 2: 대상 파일 수집

**`full` 모드**: 파일 목록을 수집하지 않는다. Phase 3으로 진행.

**`base-diff` 모드 (기본)**:

1. base branch 탐지 (인자로 revision이 주어지지 않은 경우)

```bash
# 순서대로 시도, 처음 성공하는 것 사용
git symbolic-ref --quiet --short refs/remotes/origin/HEAD   # → origin/main
git rev-parse --verify origin/main
git rev-parse --verify origin/master
git rev-parse --verify main
git rev-parse --verify master
```

2. 변경 파일 수집 (삭제된 파일은 제외 — 리뷰 대상이 없다)

```bash
# 기본 (base branch 대비)
git diff --name-only --diff-filter=d <base>...HEAD

# 지정 revision — 사용자가 준 표현식을 그대로 전달
git diff --name-only --diff-filter=d <git-rev>          # A..B, A...B 형태
git diff --name-only --diff-filter=d <ref>...HEAD       # 단일 ref 형태

# --working
git diff --name-only --diff-filter=d HEAD

# --staged
git diff --name-only --diff-filter=d --cached
```

3. **가드레일 — 전체 스캔으로 폴백하지 않는다**

| 상황                              | 처리                                                                       |
| --------------------------------- | -------------------------------------------------------------------------- |
| base branch를 못 찾음             | 중단. 탐지 실패를 알리고 revision을 직접 지정하거나 `full`을 쓰라고 안내    |
| 대상 파일 0개                     | 중단. "리뷰할 변경분 없음"을 보고하고 `--working` 또는 `full` 사용을 제안   |
| 대상 파일이 500개 초과            | 사용자에게 확인 후 진행 (범위가 의도한 것인지 검증)                        |
| git 저장소가 아님                 | 중단. `full` 사용 여부를 사용자에게 확인                                    |

전체 코드베이스 스캔은 비용이 크고 노이즈가 많다. **어떤 경우에도 자동으로 `full`로 확장하지 않는다.**

4. 수집한 목록을 scope(`backend`/`frontend`)로 필터링한다.

### Phase 3: 에이전트 병렬 실행

**필터링된 에이전트를 동시에 실행한다.** 각 에이전트에 아래 계약을 그대로 전달한다.

```
Agent(subagent_type="<domain>-reviewer", prompt="
  mode: {base-diff | full}
  scope: {backend | frontend | all}
  files:
  {대상 파일 목록 — mode=base-diff일 때만. 한 줄에 하나씩}

  ## 리뷰 범위 계약
  - mode=base-diff: 위 `files` 목록에 있는 파일만 리뷰 대상이다. 발견 사항은 반드시
    이 목록 안의 파일에 위치해야 한다. 목록 밖 파일의 이슈는 보고하지 않는다.
  - 단, 판정에 필요한 문맥(호출부, 타입 정의, 스키마, 설정 등)은 코드베이스 전체를
    자유롭게 읽어도 된다. **읽는 범위 != 보고 범위.**
  - files가 비어 있으면 '대상 없음'을 보고하고 즉시 종료한다. 전체 스캔으로 확장하지 않는다.
  - mode=full일 때만 코드베이스 전체가 대상이다.

  반드시 CLAUDE.md를 먼저 읽고 {도메인별 지시}를 반영하라.
")
```

도메인별 지시:
- `arch-reviewer` — 프로젝트의 아키텍처 원칙과 Critical Rules
- `refactor-reviewer` — 프로젝트의 코딩 규칙과 네이밍 컨벤션
- `deadcode-reviewer` — 프로젝트 구조와 특수 진입점
- `perf-reviewer` — 프로젝트의 성능 관련 규칙
- `security-reviewer` — 프로젝트의 보안 원칙과 Critical Rules
- `frontend-reviewer` — 프로젝트의 프론트엔드 프레임워크와 규칙

`--domain` 옵션으로 특정 도메인만 지정된 경우 해당 에이전트만 실행.

**에이전트 부재 시**: 에이전트가 존재하지 않으면 해당 도메인을 건너뛰고 리포트에 '미실행' 표시. 최소 1개 에이전트가 실행되면 리포트를 생성한다.

**중요**: 에이전트는 **리서치만** 수행한다. 코드 수정은 하지 않는다.

### Phase 4: 결과 종합

에이전트의 결과를 종합하여 아래 형식으로 리포트.

```markdown
# Codebase Review Report

**모드**: base-diff (`{base}...HEAD`) / full / `{git-rev}` / --working / --staged
**범위**: {scope} | **날짜**: {date} | **대상 파일**: {N}개 | **도메인**: {실행된 도메인 목록}

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

**검증**: `base-diff` 모드에서 대상 파일 목록 밖의 파일이 리포트에 등장하면 해당 항목을 제거한다. 에이전트가 범위를 이탈한 것이다.

### Phase 5: 후속 조치 (선택)

사용자가 요청하면:
1. 발견된 이슈를 태스크 관리 도구에 등록
2. 특정 이슈를 바로 수정 (TDD 원칙에 따라)
3. 리포트를 파일로 저장

## 실행 예시

```
/codebase-review                          → base branch 대비 변경분, 6개 도메인 (기본)
/codebase-review full                     → 전체 코드베이스, 6개 도메인
/codebase-review main..HEAD               → 지정 diff
/codebase-review abc123                   → abc123...HEAD diff
/codebase-review --working                → 미커밋 변경분
/codebase-review --staged                 → 스테이징된 변경분
/codebase-review backend                  → base diff 중 백엔드 파일만, Frontend 도메인 제외
/codebase-review --domain perf,security   → base diff 대상, 2개 도메인만
/codebase-review full --domain security   → 전체 코드베이스, 보안 도메인만
```

## 주의사항

- **기본은 diff 리뷰다.** 전체 스캔(`full`)은 사용자가 명시할 때만 실행한다.
- 에이전트는 **읽기 전용**. 코드를 수정하지 않는다.
- 오탐(false positive) 가능성이 있으면 확신도를 명시한다.
- 리포트가 너무 길면 Top 10 + 도메인별 Top 5로 요약한다.
