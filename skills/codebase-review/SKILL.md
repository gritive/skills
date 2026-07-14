---
name: codebase-review
description: "Use when the user asks for a codebase review, code health check, architecture audit, or says '코드 리뷰', '코드베이스 점검', 'codebase review', 'health check', 'code quality'. 6개 병렬 리뷰 에이전트(아키텍처, 리팩토링, 데드코드, 성능, 보안, 프론트엔드)로 base branch 대비 변경분을 종합 점검하고 우선순위 리포트 생성. 전체 코드베이스 스캔은 'full' 인자를 명시할 때만 수행한다."
---

# Codebase Review

6개 리뷰 에이전트를 병렬 실행하여 코드를 종합 점검하는 스킬.

**기본 대상은 base branch 대비 변경분이다.** 전체 코드베이스 스캔은 `full`을 명시했을 때만 수행한다.

## 산출물 규칙

**리뷰 산출물을 대상 프로젝트에 남기지 않는다.** 리포트는 대화로 출력한다. 파일로 저장하는 것은
사용자가 명시적으로 요청할 때, **사용자가 지정한 경로에만** 한다 — 경로를 받지 못했으면 물어본다
(Phase 5). 스킬 이름을 딴 디렉토리(`codebase-review/` 등)를 대상 저장소에 만들지 않는다.

여기서 '산출물'은 **리뷰가 만들어내는 부산물**(리포트·로그)을 말한다. 사용자가 요청한 코드 수정과
그에 딸린 테스트 파일은 산출물이 아니라 작업 결과이므로 이 규칙의 대상이 아니다.

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
> 설정은 선택 사항이다 — CLAUDE.md에 규칙이 없어도 리뷰는 동작한다.

## Workflow

### Phase 1: 인자 파싱

**리뷰 모드 (택 1, 기본은 base-diff)**

| 인자          | 모드        | 대상                                                    |
| ------------- | ----------- | ------------------------------------------------------- |
| (없음)        | `base-diff` | base branch 대비 변경 파일 (**기본**)                   |
| `full`        | `full`      | 코드베이스 전체 — **명시할 때만** 실행                  |
| `<git-rev>`   | `base-diff` | 지정한 git revision 표현식의 diff                       |
| `--working`   | `base-diff` | 커밋되지 않은 변경분 (스테이징 + 워킹트리 + untracked)  |
| `--staged`    | `base-diff` | 스테이징된 변경분만                                     |

**`<git-rev>` 판별 규칙**

1. `--domain` 등 플래그가 소비하는 값 토큰은 위치 인자가 아니다. 판별 대상에서 제외한다.
2. 남은 위치 인자 중 `full` / `backend` / `frontend` / `all`은 **예약어**다. 항상 키워드로 해석한다.
3. 그 외의 위치 인자는 git revision 표현식으로 간주한다: `main..HEAD`, `develop...HEAD`, `abc123`, `v1.0..v1.1`.
4. **`full`과 `<git-rev>`를 함께 주면 오류**로 중단한다 (모드가 상충한다). `--working` / `--staged`도 마찬가지다.
5. **표에 없는 `--` 플래그가 오면 오류로 중단한다.** 특히 구버전 `--full` / `--changed` / `--since-last`는
   인식하지 않는다. `full` / `--working`을 안내하되 **자동 변환하지 않는다** — `--full`을 `full`로
   추측 변환하면 사용자가 의도하지 않은 전체 스캔이 실행된다.

> **예약어와 같은 이름의 브랜치**(`backend`, `frontend`, `full`, `all`)를 리뷰하려면
> `..`를 포함한 범위 표현식으로 준다: `/codebase-review backend..HEAD`.
> `..`가 있으면 예약어 검사를 건너뛰므로 모호성이 없다.

**자연어로 "전체"를 요청한 경우**(예: "전체 리뷰 해줘"): `full` 모드는 비용이 크므로
**사용자에게 확인받고 진행한다.** 확인 없이 `full`로 실행하지 않는다.

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
- scope=`frontend`이면 Frontend 외 도메인도 실행하되, `files`가 프론트엔드 파일로만 채워진다
- **`scope`는 `files`를 필터링할 뿐이다.** 에이전트에게 "백엔드 점검 항목을 건너뛰라"고 지시하지
  않는다 — 대상 파일이 프론트엔드뿐이면 백엔드 항목은 자연히 걸리지 않는다. 에이전트가 `scope`를
  하드 게이트로 다시 검사하면 `--domain` 강제 호출과 충돌하므로 그렇게 하지 않는다.
- `--domain`이 있으면 지정된 도메인의 에이전트만 실행한다 (scope 기반 자동 제외를 덮어쓴다)
- **`--domain`은 어떤 에이전트를 띄울지만 정한다. 어떤 파일을 줄지는 `scope`가 정한다.**
  둘은 직교한다. 도메인을 좁혀도 대상 파일 범위는 넓어지지 않는다.
- 따라서 `backend --domain frontend`처럼 상충하는 조합은 오류가 아니다.
  frontend-reviewer가 실행되지만 `files`에 프론트엔드 파일이 없으므로 "대상 없음"으로 종료한다.

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

2. 변경 파일 수집

**모든 git 명령은 저장소 루트에서 실행한다.** 서브디렉토리에서 실행하면 명령마다 경로 기준이
달라져 에이전트가 파일을 못 읽는다.

```bash
cd "$(git rev-parse --show-toplevel)"
```

수집 시 **삭제된 파일은 리뷰 대상에서 제외**한다 (읽을 내용이 없다).

```bash
# 기본 (base branch 대비)
git diff --name-only --diff-filter=d <base>...HEAD

# --staged
git diff --name-only --diff-filter=d --cached
```

**`--diff-filter=d`(소문자)는 삭제된 파일을 제외한다.** 대문자 `D`는 삭제된 파일'만' 남기므로 쓰지 않는다.

**지정 revision**: `<git-rev>`에 `..`가 포함되어 있는지로 판별한다.

```bash
# `..` 포함 → 사용자가 준 범위 표현식을 그대로 전달
git diff --name-only --diff-filter=d <git-rev>       # main..HEAD, v1.0...v1.1

# `..` 미포함 (단일 ref) → 반드시 `...HEAD`를 붙인다
git diff --name-only --diff-filter=d <ref>...HEAD    # abc123 → abc123...HEAD
```

단일 ref를 그대로 `git diff <ref>`로 넘기면 **워킹트리와 비교**되어 커밋되지 않은 변경까지 섞인다.
의도한 것은 커밋 범위의 diff이므로 `...HEAD`를 반드시 붙인다.

**`--working`**: `git diff HEAD`는 **추적되지 않는 신규 파일을 누락한다.** 아직 `git add`하지 않은
새 파일이야말로 리뷰가 가장 필요한 대상이므로, untracked 파일을 합쳐서 수집한다.

```bash
{ git diff --name-only --diff-filter=d HEAD
  git ls-files --others --exclude-standard --full-name; } | sort -u
```

`--full-name`이 없으면 `ls-files`는 **cwd 기준** 경로를, `diff`는 **저장소 루트 기준** 경로를
내보내 목록에 두 종류 경로가 섞인다. `--exclude-standard`는 `.gitignore`를 존중하므로 빌드 산출물은
들어오지 않는다.

3. 수집한 목록을 scope(`backend`/`frontend`)로 필터링한다.

4. **가드레일 — 전체 스캔으로 폴백하지 않는다**

**가드레일은 scope 필터링 이후에 판정한다.** 필터링 전에 판정하면 "수집 30개 → scope 필터 후 0개"인
경우를 놓쳐, 6개 에이전트가 빈 목록으로 돌고 **전부 0인 '깨끗한' 리포트**가 나온다.

| 상황                                  | 처리                                                                                    |
| ------------------------------------- | --------------------------------------------------------------------------------------- |
| git 저장소가 아님                     | 중단. `full` 사용 여부를 사용자에게 확인                                                |
| base branch를 못 찾음                 | 중단. 탐지 실패를 알리고 revision을 직접 지정하거나 `full`을 쓰라고 안내                |
| **git diff 명령이 실패**              | 중단. shallow clone(`--unshallow` 필요), orphan branch, unrelated histories에서 `no merge base`로 죽는다. **추측해서 `full`이나 `--working`으로 대체하지 않는다.** |
| 수집 결과 0개                         | 중단. "리뷰할 변경분 없음"을 보고하고 `--working` 또는 `full` 사용을 제안               |
| **scope 필터링 후 0개**               | 중단. "변경 파일 N개가 모두 `{scope}` 밖"이라고 **명확히 구분해서** 보고하고 scope 변경을 제안. 빈 목록으로 에이전트를 실행하지 않는다 |
| 대상 파일 500개 초과                  | 사용자에게 확인 후 진행 (범위가 의도한 것인지 검증)                                     |

전체 코드베이스 스캔은 비용이 크고 노이즈가 많다. **어떤 경우에도 자동으로 `full`로 확장하지 않는다.**
git 명령이 실패하거나 목록이 예상보다 크다는 것은 `full`로 전환할 이유가 **아니다**.

### Phase 3: 에이전트 병렬 실행

**필터링된 에이전트를 동시에 실행한다.** 각 에이전트에 아래 계약을 그대로 전달한다.

`subagent_type`은 **플러그인 이름을 접두사로 붙인 `gritive:` 형태**여야 한다. 접두사 없이
`arch-reviewer`로 부르면 `Agent type not found`로 실패한다.

```
Agent(subagent_type="gritive:<domain>-reviewer", prompt="
  mode: {base-diff | full}
  scope: {backend | frontend | all}
  base: {실제 사용한 git diff 인자 — 예: origin/main...HEAD (기본), HEAD (--working), --cached (--staged)}
  files:
  {대상 파일 목록 — mode=base-diff일 때만. 저장소 루트 기준 경로. 한 줄에 하나씩}

  ## 리뷰 범위 계약
  - mode=base-diff: 위 `files` 목록에 있는 파일만 리뷰 대상이다. 발견 사항은 반드시
    이 목록 안의 파일에 위치해야 한다. 목록 밖 파일의 이슈는 보고하지 않는다.
  - 단, 판정에 필요한 문맥(호출부, 타입 정의, 스키마, 설정 등)은 코드베이스 전체를
    자유롭게 읽어도 된다. **읽는 범위 != 보고 범위.**
  - 실제 변경 내용이 필요하면 `git diff {base} -- {files}`로 확인하라.
    `files`는 '변경된 파일'이지 '변경된 라인'이 아니다. 파일 전체가 리뷰 대상이다.
  - files가 비어 있으면 '대상 없음'을 보고하고 즉시 종료한다. 전체 스캔으로 확장하지 않는다.
  - mode=full일 때만 코드베이스 전체가 대상이다.

  반드시 CLAUDE.md를 먼저 읽고 {도메인별 지시}를 반영하라.
")
```

**`deadcode-reviewer`에게만 추가로 전달하는 예외**:

```
  ## 데드코드 예외 (deadcode-reviewer 전용)
  이 변경이 어떤 심볼의 **마지막 호출을 제거**했다면, 그 심볼이 `files` 밖에 있어도 보고하라.
  이 변경이 직접 유발한 데드코드이기 때문이다.
  - 근거를 반드시 명시한다: "{대상 파일}이 마지막 호출을 제거함"
  - **1홉만 보고한다.** 그 심볼이 죽었다는 이유로 그 심볼의 피호출자까지 연쇄 보고하지 않는다.
  - 삭제된 파일은 `files`에 없다. `git diff --name-only --diff-filter=D {base}`로 확인하라.
```

**대상 파일 목록을 임의로 잘라내지 않는다.** 목록이 프롬프트에 다 들어가지 않을 만큼 크면
중단하고 사용자에게 범위 축소를 요청한다. **목록이 크다는 이유로 `full`로 전환하지 않는다** —
그건 정반대 방향이다.

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

**세 가지 상태를 구분한다:**

| 상태          | 표기                    | 의미                                          |
| ------------- | ----------------------- | --------------------------------------------- |
| 이슈 없음     | `0`                     | 에이전트가 대상 파일을 리뷰했고 발견 사항 없음 |
| 대상 없음     | `N/A (대상 파일 없음)`  | `files`에 해당 도메인 파일이 없어 리뷰 안 함  |
| 미실행        | 테이블에서 제외         | 에이전트를 띄우지 않음 (`--domain` 필터 등)   |

**`대상 없음`을 `0`으로 표기하지 않는다.** 둘 다 "깨끗함"처럼 보이지만 전혀 다르다 —
하나는 검사했고, 하나는 검사조차 안 했다.

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

**검증**: `base-diff` 모드에서 대상 파일 목록 밖의 파일이 리포트에 등장하면 해당 항목을 제거한다.
에이전트가 범위를 이탈한 것이다.

**단 하나의 예외**: `deadcode-reviewer`가 "{대상 파일}이 마지막 호출을 제거함" 근거를 명시한 항목은
`files` 밖이어도 **유지한다.** 이 변경이 직접 유발한 데드코드이므로 정당한 발견이다.
근거가 없으면 제거한다.

### Phase 5: 후속 조치 (선택)

사용자가 요청하면:
1. 발견된 이슈를 태스크 관리 도구에 등록
2. 특정 이슈를 바로 수정 (TDD 원칙에 따라)
3. 리포트를 **사용자가 지정한 경로**에 저장 — 경로를 받지 못했으면 물어본다. 저장 요청이 없으면
   리포트는 대화 출력으로만 남긴다

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
- **`base-diff`는 '변경된 파일' 단위지 '변경된 라인' 단위가 아니다.** 900줄 파일에서 3줄만 고쳐도
  900줄 전체가 리뷰 대상이다. 파일 전체 맥락을 봐야 아키텍처·보안 이슈를 놓치지 않기 때문이다.
  대신 **내가 건드리지 않은 기존 코드의 이슈도 보고될 수 있다.** 리포트를 읽을 때 감안한다.
- 에이전트는 **읽기 전용**. 코드를 수정하지 않는다.
- 오탐(false positive) 가능성이 있으면 확신도를 명시한다.
- 리포트가 너무 길면 Top 10 + 도메인별 Top 5로 요약한다.
