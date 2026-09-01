---
name: codebase-review
description: "Use when the user asks for a codebase review, architecture audit, health check, or code quality pass — '코드 리뷰', '코드베이스 점검'."
---

# Codebase Review

도메인별 리뷰어로 코드를 종합 점검하는 스킬.
리뷰어는 플러그인 에이전트가 아니라 `reviewers/*.md` 지침 문서다(Phase 3).

**원문 전달**: 지침 문서는 경로를, 기준 문서는 참조 또는 전문을 넘긴다. 계약 전문은 Phase 3에 있다.

## 리뷰 도메인

점검 항목은 각 지침 문서가 정의한다.

각 도메인의 **리포트 헤더 줄**은 아래 표의 문자열 그대로다. dispatch 프롬프트와 Phase 4 반환물
검증은 둘 다 이 표의 리터럴 문자열을 쓴다 — 도메인 토큰(`backend` 등)을 헤더에 대입하지 않는다.

| 도메인      | 지침 문서                  | 리포트 헤더 줄        |
| ----------- | -------------------------- | --------------------- |
| backend     | `reviewers/backend.md`     | `## 백엔드 리뷰 결과`     |
| frontend    | `reviewers/frontend.md`    | `## 프론트엔드 리뷰 결과` |
| security    | `reviewers/security.md`    | `## 보안 리뷰 결과`       |
| conformance | `reviewers/conformance.md` | `## 기준 대조 리뷰 결과`  |

`backend`·`frontend`는 데드코드·중복·문서 staleness 렌즈의 공통 규약을 `reviewers/shared-lenses.md`에서,
코드 스멜 베이스라인을 `reviewers/smell-baseline.md`에서 읽는다.
`backend`·`frontend`·`security`는 발견의 근거 인용 규칙을 `reviewers/evidence-gate.md`에서 읽는다.

## CLAUDE.md 연동

모든 에이전트는 범용 점검 항목을 기본으로 수행하되, **프로젝트 CLAUDE.md를 읽고 Critical Rules, 보안/아키텍처 원칙을 자동 반영**한다.

각 리뷰어가 무엇을 반영하는지는 그 문서의 「프로젝트 규칙 로딩」 절이 정한다.

> 프로젝트 CLAUDE.md 설정 가이드: `references/claude-md-setup.md` 참조.
> 설정은 선택 사항이다 — CLAUDE.md에 규칙이 없어도 리뷰는 동작한다.

## Workflow

### Phase 1: 인자 파싱

**인자 문법(모드 표, revision 판별, 예약어, 모드 충돌, `scope`와 `--domain`의 관계, 실행 예시)은
`references/args.md`를 읽는다.**

인자가 없으면 `base-diff` 모드에 scope `all`, 도메인 전원이다 — base branch 대비 변경 파일이 대상이다.

**`full` 모드는 문자열 `full`을 명시한 실행에서만 켠다.** 자연어로 "전체"를 요청한 경우(예: "전체 리뷰
해줘")에는 비용을 알리고 사용자 확인을 받은 뒤 켠다. git 명령 실패, 목록 크기, 수집 결과 0개는
`full`로 폴백하지 않고 Phase 2 가드레일의 중단 경로로 처리한다.

#### 신호 게이팅 — 볼 대상이 없는 에이전트는 띄우지 않는다

`--domain`이 **없을 때만** 적용한다. Phase 2가 `files`를 확정한 뒤 판정한다(그 전에 판정하면
scope 필터로 빠질 파일을 세게 된다).

| 도메인   | 게이팅 조건                                                                                                                        |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **전원** | `files`가 **문서·텍스트 전용**이면 전부 띄우지 않고 `REVIEW_STATUS: no-target`으로 끝낸다 — **중단이 아니라 정상 종료다**(Phase 4) |
| Frontend | 프론트엔드 파일(컴포넌트·스타일·클라이언트 진입점)이 0개면 skip                                                                    |
| Backend  | 항상 띄운다                                                                                                                        |
| Security | 항상 띄운다                                                                                                                        |
| Conformance | 항상 띄운다 — 백엔드 변경도 PRD 요구를 안 채울 수 있다. 기준 문서가 없으면 리뷰어가 그 사실을 보고하고 스스로 종료한다           |

**판정 기준:**

- **문서·텍스트 전용** = `files` 전부가 문서(`.md`, `.txt`, `LICENSE`, `docs/` 등)인 경우.
  설정·매니페스트·CI 파일은 코드로 취급한다.
- **프론트엔드 파일** = 컴포넌트·스타일·클라이언트 진입점. 확장자 목록 대신 프로젝트 구조에서 판단한다.
- 애매하면 **띄운다.** 게이팅의 실패는 비용이고, 안 띄운 것의 실패는 놓친 결함이다.

띄우지 않은 도메인의 리포트 표기는 `references/report-format.md`의 대시보드 상태 표를 따른다 — 0건과 구분한다.

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

**지정 revision**: `<git-rev>`에 `..`가 포함되어 있는지로 판별한다.

```bash
# `..` 포함 → 사용자가 준 범위 표현식을 그대로 전달
git diff --name-only --diff-filter=d <git-rev>       # main..HEAD, v1.0...v1.1

# `..` 미포함 (단일 ref) → 반드시 `...HEAD`를 붙인다
git diff --name-only --diff-filter=d <ref>...HEAD    # abc123 → abc123...HEAD
```

단일 ref를 `git diff <ref>`로 넘기면 워킹트리와 비교되어 커밋되지 않은 변경까지 섞인다. 의도한 것은
커밋 범위의 diff이므로 `...HEAD`를 붙인다.

**`--working`**: untracked 파일을 합쳐서 수집한다. `git diff HEAD`만으로는 아직 `git add`하지 않은
새 파일이 빠지는데, 그 파일이야말로 리뷰가 가장 필요한 대상이다.

```bash
{ git diff --name-only --diff-filter=d HEAD
  git ls-files --others --exclude-standard --full-name; } | sort -u
```

`--full-name`은 `ls-files` 경로를 `diff`와 같은 저장소 루트 기준으로 맞춘다. `--exclude-standard`는
`.gitignore`를 존중하므로 빌드 산출물은 들어오지 않는다.

3. 수집한 목록을 scope(`backend`/`frontend`)로 필터링한다.

4. **이슈 참조 추출** — `conformance`를 띄우는 실행에서만 한다.

사용자가 인자로 이슈 번호·URL을 줬으면 그것을 쓴다. 없으면 커밋 메시지에서 찾는다.

`<base-ref>`는 Phase 2-1이 탐지한 **base branch ref**다(`git diff` 인자가 아니다).
인자로 revision을 받은 실행에서는 그 revision을 쓴다 — 범위 표현식(`main..HEAD`)이면 좌변이다.
`--working`·`--staged`처럼 커밋이 아직 없는 모드에서는 검사할 커밋 메시지가 없으므로 추출을 건너뛴다.

```bash
git log <base-ref>..HEAD --format=%B
```

출력에서 이슈 참조(`#123`, `Closes #45`, `GH-12`, 트래커 URL 등)를 찾는다. 여러 개면 전부 넘긴다.
**참조 문자열만 넘기고 조회는 리뷰어가 한다**(Phase 3).

찾지 못하면 참조 없이 진행한다. 중단 사유가 아니다.

5. **가드레일 — 전체 스캔으로 폴백하지 않는다**

**가드레일은 scope 필터링 이후에 판정한다.** 필터링 전에 판정하면 "수집 30개 → scope 필터 후 0개"인
경우를 놓쳐 에이전트가 빈 목록으로 돌고 전부 0인 '깨끗한' 리포트가 나온다.

| 상황                     | 처리                                                                                          |
| ------------------------ | --------------------------------------------------------------------------------------------- |
| git 저장소가 아님        | 중단. `full` 사용 여부를 사용자에게 확인                                                       |
| base branch를 못 찾음    | 중단. 탐지 실패를 알리고 revision 지정 또는 `full` 사용을 안내                                 |
| **git diff 명령이 실패** | 중단. shallow clone(`--unshallow` 필요), orphan branch, unrelated histories에서 `no merge base`로 죽는다 |
| 수집 결과 0개            | 중단. "리뷰할 변경분 없음"을 보고하고 `--working` 또는 `full` 사용을 제안                      |
| **scope 필터링 후 0개**  | 중단. "변경 파일 N개가 모두 `{scope}` 밖"이라고 구분해서 보고하고 scope 변경을 제안            |
| **문서·텍스트 전용**     | Phase 1 「신호 게이팅」의 **전원** 행대로 처리한다                                             |
| 대상 파일 500개 초과     | 사용자에게 확인 후 진행 (범위가 의도한 것인지 검증)                                            |

### Phase 3: 에이전트 병렬 실행

**띄우기 전에 Phase 1의 "신호 게이팅" 표를 적용한다.** 검사할 파일이 없는 에이전트를 띄우면 비용만
쓰고, 리포트에는 0건으로 남아 "그 축도 봤는데 깨끗하다"로 읽힌다. **선택 결과를 한 줄로 출력한다:**
`실행: {도메인 목록} / 대상 없음: {도메인 목록}`.

`--domain`으로 강제 호출한 도메인은 게이팅하지 않는다 — 띄우고 리뷰어가 "대상 없음"으로 종료한다.

**남은 도메인을 한 메시지에서 동시에 dispatch한다.** 각 subagent에 아래를 그대로 전달한다.
Agent 툴에는 `description`·`subagent_type`·`prompt`만 준다. `description`은 `<도메인> 리뷰 (<모드>)`
형식으로 쓴다(예: `backend 리뷰 (base-diff)`) — 진행 중 사용자에게 보이는 것은 이 한 줄뿐이라 어느
리뷰어가 도는지 구분되어야 한다.

**`name`은 주지 않는다.** `name`을 주면 프롬프트가 메일박스 경로로 전달되어 리뷰어가 지침을 실행하지
않은 채 idle로 끝나는 것이 관측됐다. 이름 없이 띄우면 프롬프트가 그대로 실행된다.

**dispatch는 비동기다 — 스폰 호출의 반환값은 리포트가 아니다.** 리포트는 나중에 완료 알림으로
도착한다. **띄운 도메인 전부의 완료 알림을 받은 뒤에 Phase 4로 간다.** 알림을 기다리지 않고 종합하면
손에 리포트가 하나도 없어 Phase 4의 반환물 검증이 전 도메인을 무응답으로 판정하고, 멀쩡히 도는
리뷰어를 두고 `aborted`가 나간다.

**리뷰어는 플러그인 에이전트가 아니라 이 디렉터리의 문서다** — `reviewers/backend.md`,
`reviewers/frontend.md`, `reviewers/security.md`, `reviewers/conformance.md`. subagent에 **경로를 넘기고
Read해서 그대로 수행하게 한다**(원문 전달).

`subagent_type`은 `general-purpose`를 쓴다. 리뷰는 코드를 읽고 판정하는 일이라 탐색 전용
에이전트(Claude Code의 `Explore` 등)로는 수행되지 않는다 — 그런 에이전트는 위치를 찾아 돌려줄 뿐
리뷰·감사를 하지 않으므로 리포트 없이 끝난다. **읽기 전용성은 에이전트 타입이 아니라 프롬프트로
건다**(아래 `수정 금지` 줄).

```
Agent(subagent_type="general-purpose", prompt="
  아래 지침 문서를 Read로 읽고 그대로 수행하라: {리뷰어 문서 경로}
  (요약본이 아니라 그 파일 전문을 읽어라. 이 프롬프트는 입력값일 뿐 지침이 아니다.)

  ## 입력값
  mode: {base-diff | full}
  scope: {backend | frontend | all} — 참고용. 이 값으로 files는 이미 걸러져 있다
  base: {실제 사용한 git diff 인자 — 예: origin/main...HEAD (기본), HEAD (--working), --cached (--staged)}
  files:
  {대상 파일 목록 — mode=base-diff일 때만. 저장소 루트 기준 경로. 한 줄에 하나씩}
  이슈 참조: {이슈 번호·URL. conformance에만 의미가 있고 나머지는 무시한다. 없으면 이 줄을 뺀다}
  이슈 본문: {사용자가 본문을 직접 붙여넣은 경우에만 그대로. 그 외에는 이 줄을 뺀다}

  ## 리뷰 범위 계약
  - mode=base-diff: 리뷰 대상은 `git diff {base} -- {files}`의 **변경 hunk**다.
    먼저 그 diff를 떠서 hunk를 전부 정독하는 것으로 리뷰를 시작한다.
  - 발견 사항은 hunk가 추가·수정한 줄, 또는 hunk가 그 줄을 통해 만든 결함에 위치해야 한다.
    hunk 밖 기존 코드의 결함은 보고하지 않는다.
  - 판정에 필요한 문맥(호출부, 래퍼, 타입 정의, 스키마, 설정, 대상 파일의 나머지 부분)은
    코드베이스 전체를 자유롭게 읽는다. **읽는 범위 != 보고 범위.**
    대상 파일 전체 Read는 hunk 판정에 그 맥락이 필요할 때 한다 — 전체를 훑는 것이 기본이 아니다.
  - hunk 밖에서 판정을 뒤집는 사실(예: 호출부가 이미 검증한다)을 찾으면 발견을 내린다.
  - 대상 여부는 files가 정한다. files가 비어 있으면 '대상 없음'을 보고하고 즉시 종료하고,
    files가 있으면 scope를 재검사하지 말고 그 목록을 리뷰한다.
  - mode=full일 때만 코드베이스 전체가 대상이다. mode가 없으면 base-diff로 간주한다.

  반드시 대상 프로젝트의 CLAUDE.md를 먼저 읽고 {도메인별 지시}를 반영하라.

  ## 반환 계약
  - 네 최종 메시지 자체가 리포트다. 지침 문서의 `## 출력 형식` 절에 있는 마크다운을
    그대로 채워서 반환하라. 첫 줄은 정확히 `{리포트 헤더 줄}`이다(「리뷰 도메인」 표의 문자열을
    그대로 대입해서 넘긴다 — 예: backend이면 `## 백엔드 리뷰 결과`).
  - 발견이 0건이어도 헤더와 빈 표를 갖춘 리포트를 반환한다. 호출자는 리포트의 부재를
    '무결함'이 아니라 '리뷰 미수행'으로 판정한다.
  - 리포트는 최종 메시지 텍스트로만 반환한다. 진행 상황 서술이나 요약이 아니라 전문을 낸다.
  - 대상 저장소는 읽기만 한다 — 리포트 파일도 임시 파일도 그 저장소에 만들지 않는다.
")
```

**`conformance`에게 추가로 전달하는 것 — 기준을 요약해서 넘기지 않는다.**

**`이슈 참조`가 기본 경로다.** Phase 2가 추출한 참조(또는 사용자가 인자로 준 이슈 번호·URL)를
그대로 한 줄로 넘긴다. 이슈 전문을 읽어 요구 항목을 추리는 것은 **리뷰어의 일이다** —
근거는 그 문서의 「1차 기준을 스스로 조회한다」 절에 있다.

**빌더의 Coverage Plan·Audit 표는 넘기지 않는다** — 넘기면 독립 평가가 자기채점으로 돌아간다
(그 문서의 "기준은 둘이고 층이 다르다" 절).

**`이슈 본문`은 사용자가 본문을 직접 붙여넣은 경우에만 넘긴다** — 그건 사용자가 정한 기준이다.
이 세션이 조회해서 요약하거나 발췌해 채우지 않는다.

참조도 본문도 없으면(인자 없는 실행에서 추출 실패, `review-forever` 호출) 두 줄을 다 빼고,
리뷰어는 저장소 문서(PRD·design-guide)만으로 판정한다.

**대상 파일 목록은 전부 전달한다.** 목록이 프롬프트에 다 들어가지 않을 만큼 크면 중단하고 사용자에게
범위 축소를 요청한다.

도메인별 지시:

- `reviewers/backend.md` — 아키텍처 원칙, Critical Rules, 코딩·네이밍 컨벤션, 특수 진입점, 성능 제약
- `reviewers/frontend.md` — 프론트엔드 프레임워크와 **버전**, 컴포넌트·상태 관리·CSS 규칙, i18n 시스템
- `reviewers/security.md` — 프로젝트의 보안 원칙과 Critical Rules
- `reviewers/conformance.md` — 기준 문서(PRD·design-guide·이슈 본문)의 위치와 인터랙션 규약

**dispatch 직전에 `git status --porcelain` 출력을 찍어 둔다.** Phase 4의 읽기 전용 확인이 이 값을
기준으로 삼는다.

**리뷰어 문서를 못 읽으면 그 도메인은 실행되지 않은 것이므로 `REVIEW_STATUS: aborted (리뷰어 문서 없음:
{경로})`로 끝낸다.** '미실행' 표기는 사용자가 `--domain`으로 제외한 경우 전용이다.

### Phase 4: 결과 종합

**리포트 양식·대시보드 상태 표기·도메인 교차 발견 처리는 `references/report-format.md`를 읽고 따른다.**

**`REVIEW_STATUS` 줄은 이 스킬을 감싸는 쪽을 위한 것이다.** 세 값만 쓴다:

| 값                        | 조건                                                       |
| ------------------------- | ---------------------------------------------------------- |
| `ran ({실행}/{고려})`     | 에이전트를 하나 이상 띄웠고 모든 리뷰어 문서를 읽었다      |
| `no-target ({사유})`      | 게이팅으로 하나도 띄우지 않았다 (정상 종료)                |
| `aborted ({사유})`        | Phase 2 가드레일에서 중단했거나, 리뷰어 문서를 못 읽었거나, 리뷰어가 리포트를 반환하지 않았다 |

**`aborted`가 `ran`을 이긴다.** 리뷰어 문서를 못 읽었거나 리포트를 반환하지 않은 도메인이 하나라도
있으면 다른 도메인이 돌았더라도 `aborted`로 낸다. 그러지 않으면 `security` 문서가 없어도 `ran (3/4)`이
나가고 보안 리뷰가 통과로 읽힌다.

**반환물 검증 — 침묵을 0건으로 세지 않는다.** 종합 전에 도메인별 반환물이 지침 문서의 `## 출력 형식`
헤더 줄로 시작하는 리포트인지 확인한다. 비교 대상은 「리뷰 도메인」 표의 **리포트 헤더 줄** 문자열
그대로다. 헤더가 다르거나 반환물이
비어 있거나 리포트 대신 진행 서술만 왔으면 그 도메인은 **실행되지 않은 것**이다.

- 그 도메인은 대시보드에 `무응답`으로 남긴다(`references/report-format.md`). `0`으로 세지 않는다.
- 전체 상태는 `REVIEW_STATUS: aborted (리뷰어 무응답: {도메인 목록})`으로 낸다.
- 무응답 도메인은 같은 dispatch로 한 번 재시도할 수 있다. 재시도도 무응답이면 `aborted`로 확정한다.

**읽기 전용 확인 — 워킹 트리가 그대로인지 본다.** 모든 완료 알림을 받은 뒤 `git status --porcelain`을
다시 실행해 Phase 3에서 찍어 둔 출력과 비교한다. 리뷰어는 대상 저장소를 읽기만 하므로 두 출력은 같다.

- 두 출력이 같으면 그대로 종합을 진행한다.
- 달라졌으면 리뷰어가 워킹 트리를 건드린 것이다. 그 dispatch에 포함된 도메인을 `aborted`로 판정하고,
  `REVIEW_STATUS: aborted (리뷰어가 워킹 트리 변경: {도메인 목록})`으로 낸다. **달라진 항목 전문을
  사용자에게 그대로 보고한다** — 되돌리는 것은 사용자가 결정한다.

리뷰어가 발견 0건으로 낸 리포트와 리뷰어가 아무것도 안 낸 것은 다른 사건이다. 앞은 `ran`이고 뒤는
`aborted`다. 둘을 합치면 리뷰가 안 돈 변경분이 통과로 나간다.

소비자는 둘이다 — `review-forever` Phase 2와 `project build` 9.5단계의 반환 계약 `review_status`.
**표기를 바꾸더라도 이 세 값은 유지한다.**

**검증**: `base-diff` 모드에서 변경 hunk 밖에 위치한 발견이 리포트에 등장하면 해당 항목을 제거한다.
에이전트가 범위를 이탈한 것이다.

**단 하나의 예외**: `reviewers/shared-lenses.md`가 정한 데드코드 근거 문구를 명시한 항목은 hunk
밖이어도 **유지한다.** 근거가 없으면 제거한다.

### Phase 5: 후속 조치 (선택)

사용자가 요청하면:

1. 발견된 이슈를 태스크 관리 도구에 등록
2. 특정 이슈를 바로 수정 (TDD 원칙에 따라)
3. 리포트를 **사용자가 지정한 경로**에 저장 — 경로를 받지 못했으면 물어본다. 저장 요청이 없으면
   리포트는 대화 출력으로만 남긴다

## 주의사항

- **`base-diff`의 보고 단위는 변경 hunk다.** 손대지 않은 기존 코드의 부채는 이 모드에서 나오지
  않는다 — 코드베이스 전반의 부채를 보려면 `--full`을 쓴다.
