# Gritive

코드베이스 종합 리뷰, 클린까지 반복하는 리뷰 루프, 페르소나 기반 UX 테스트, RFP 기반 프로젝트
부트스트랩을 위한 Claude Code / Codex 플러그인.

## Features

### Codebase Review (`/codebase-review`)

도메인별 전문 리뷰어로 코드를 종합 점검합니다.

**기본 대상은 base branch 대비 변경분입니다.** 전체 코드베이스 스캔은 `full`을 명시했을 때만 수행합니다.

| 도메인   | 지침 문서               | 점검 항목                                                                                    |
| -------- | ------------------- | -------------------------------------------------------------------------------------------- |
| Backend  | `reviewers/backend.md`  | 구조(계층·순환 의존) / 리팩토링(중복·복잡도·코드 스멜·네이밍) / 데드코드 / 성능(N+1·인덱스·메모리·동시성) / 문서 staleness |
| Frontend | `reviewers/frontend.md` | 구조·품질(컴포넌트·타입·상태·a11y WCAG 2.2·SSR·i18n) / 리팩토링(중복·복잡도·코드 스멜) / 데드코드 / 성능(CWV·번들·렌더링) / 문서 staleness |
| Security | `reviewers/security.md` | 인증/인가, 입력 검증, 주입 공격, 공급망, 시크릿, OWASP Top 10:2025                            |
| Conformance | `reviewers/conformance.md` | **기준 문서 대조** — 요구 충족 / design-guide 규약 준수 / 흐름 연속성 / 문구와 사실 / 요구 범위 이탈 |

`backend`·`frontend`는 데드코드·중복·문서 staleness 렌즈의 공통 규약을 `reviewers/shared-lenses.md`에서,
코드 스멜 목록을 `reviewers/smell-baseline.md`에서 읽습니다. `backend`·`frontend`·`security`는 발견의
근거 인용 규칙을 `reviewers/evidence-gate.md`에서 읽습니다.

> 리뷰어는 **플러그인 에이전트가 아니라 `codebase-review` 하위 문서**입니다 — dispatch된 subagent가
> Read해서 수행합니다. Codex 배포본은 `skills`만 싣기 때문에, 에이전트로 두면 그쪽에서 dispatch
> 단계에서 죽습니다.

```
/codebase-review                          # base branch 대비 변경분 (기본)
/codebase-review full                     # 전체 코드베이스
/codebase-review main..HEAD               # 지정 diff (git revision 표현식 그대로)
/codebase-review abc123                   # abc123...HEAD diff
/codebase-review --working                # 미커밋 변경분
/codebase-review --staged                 # 스테이징된 변경분
/codebase-review backend                  # base diff 중 백엔드 파일만, Frontend 도메인 제외
/codebase-review --domain backend,security # base diff 대상, 특정 도메인만
/codebase-review --issue 123              # conformance의 1차 기준이 될 이슈 참조
```

base branch는 `origin/HEAD` → `origin/main` → `origin/master` → `main` → `master` 순으로 탐지합니다.

**가드레일 — 어떤 경우에도 전체 스캔으로 폴백하지 않습니다.** 아래는 전부 중단하고 안내합니다:
base branch 탐지 실패, `git diff` 실패(shallow clone의 `no merge base` 등), 대상 파일 0개,
scope 필터링 후 0개, git 저장소가 아님. 대상이 500개를 넘으면 확인 후 진행합니다.

리포트는 대화로 출력합니다.

**인자 규칙**

- `full` / `backend` / `frontend` / `all`은 **예약어**입니다. 같은 이름의 브랜치를 리뷰하려면
  `..`를 포함한 범위로 주세요: `/codebase-review backend..HEAD`.
- `full`과 git revision(또는 `--working` / `--staged`)을 **함께 주면 오류**입니다. 모드가 상충합니다.
- `--domain`은 **어떤 에이전트를 띄울지**만 정하고, `backend`/`frontend`는 **어떤 파일을 줄지**만
  정합니다. 둘은 직교하므로 도메인을 좁혀도 대상 파일 범위가 넓어지지 않습니다.
- `--issue <ref>`는 `conformance`의 **1차 기준**입니다. 이슈 번호·URL을 넘기면 리뷰어가 직접 조회해
  전문을 읽습니다 — 이 세션이 요약하거나 발췌해 넘기지 않습니다. 주지 않으면 `conformance`를 띄우는
  실행에 한해 커밋 메시지에서 참조를 추출합니다(`--working`·`--staged`처럼 커밋이 없는 실행은 건너뜁니다).
  1차 기준을 끝내 못 얻으면 `conformance`는 **요구 충족·흐름 연속성·요구 범위 이탈**을 판정하지 않고
  규약 준수·문구와 사실만 수행합니다. 저장소 문서(PRD)를 1차 기준으로 승격하지 않습니다.

### Review Forever (`/gritive:review-forever`)

**리뷰 스킬을 감싸서 고칠 것이 없어질 때까지 리뷰-수정-검증을 반복합니다.** 이 스킬 자체는 리뷰하지
않습니다 — 다른 리뷰 스킬을 실행하고 그 발견을 고칩니다.

> **반드시 `gritive:` 접두사를 붙이세요.** 접두사 없는 `/review-forever`는 **다른 스킬**입니다.
> user space(`~/.claude/skills/review-forever/`)에 같은 이름의 원본이 있고, 그쪽에는 아래의
> 수렴 안전장치가 하나도 없습니다.

```bash
/gritive:review-forever                          # gstack review (기본)
/gritive:review-forever code-review              # 내장 code-review (작업 중인 diff)
/gritive:review-forever codebase-review          # gritive의 도메인별 리뷰
/gritive:review-forever codebase-review --domain security   # 감싼 스킬의 인자를 그대로 전달
/gritive:review-forever plan-eng-review          # 다른 플러그인·유저 스킬도 감쌀 수 있음
/gritive:review-forever --max-passes 3           # 패스 상한 (기본 5)
```

인자가 없으면 **gstack의 `review`** 를 씁니다. 이름이 같은 personal 스킬이 내장 스킬을 덮어쓰기
때문에 `review`는 내장이 아니라 gstack 것으로 해석됩니다. 의도된 동작입니다 — gstack `review`는
작업 중인 diff를 보는 pre-landing 리뷰라 이 루프에 맞습니다.

**리뷰어와 달리 이 스킬은 코드를 고칩니다.** 리뷰어는 읽기 전용이고, 루프가
수정합니다 — **에이전트가 찾고, 루프가 고칩니다.** 패스별 리포트·로그는 대화로 출력합니다.

수정 전에 각 발견을 소스에서 검증합니다. 리뷰 스킬은 틀릴 수 있고, **오탐을 달래려고 코드를 바꾸는
것이 가장 나쁩니다.** 틀린 발견은 기각하고 근거를 남겨 다음 패스에서 재사용합니다.

**리포트의 `미검증 관찰`은 클린 판정 전에 한 번 더 봅니다.** 클린을 선언하기 전에 각 관찰의 근거
인용을 다시 시도해서, 성공하면 고칠 것과 보고만 할 것으로 가르고 또 실패하면 완료 보고에 전문으로
싣습니다. 인용이 어렵다는 이유로 발견이 조용히 사라지지 않게 하는 자리입니다.

**"검사하지 않음"을 "발견 0건"으로 착각하지 않습니다.** 감싼 스킬이 "리뷰할 변경분 없음"이나
"대상 없음"으로 중단하면 그것은 클린이 아닙니다. 한 줄도 리뷰하지 않고 "클린 달성"을 선언하는 것이
이 루프의 최악의 실패이기 때문입니다.

**모든 판정은 "실행 큐"로 잽니다.** 실행 큐는 감싼 스킬의 발견에서 범위 밖 레거시 이슈와 기각한
오탐을 뺀 것 — 즉 **루프가 실제로 고치기로 한 것**입니다. 원시 발견 수로 재면 루프가 끝나지 않습니다.
감싼 스킬은 패스 간 기억이 없어서, 고치지 않기로 한 레거시와 이미 기각한 오탐을 매 패스 다시
보고하거든요. 그것들을 세면 발견 수는 절대 0이 되지 않습니다.

**수렴하지 않으면 멈춥니다.** 패스 상한(기본 5)에 닿거나, **실행 큐가 두 패스 연속 줄지 않거나**
(큐가 비어 있지 않은 상태에서), **같은 큐 항목이 3회 반복**되면 중단하고 왜 수렴하지 않는지
보고합니다. 반복 판정도 큐 항목만 셉니다 — 큐 밖으로 뺀 레거시와 기각한 오탐은 감싼 스킬이 매 패스
다시 보고하므로, 그것까지 세면 정상 진행이 "반복"으로 죽습니다.

`codebase-review`를 감쌀 때는 **사용자 작업이 커밋됐는지에 따라 방식이 갈립니다.** 커밋된 브랜치라면
루프의 수정도 패스마다 커밋해야 합니다 — `codebase-review`의 기본 대상이 커밋 기반 diff(`{base}...HEAD`)
라, 미커밋 수정은 다음 패스의 리뷰 대상에 들어가지 않기 때문입니다. 반대로 작업이 미커밋이면
`--working`으로 감싸야 하고, 이때는 루프의 수정도 자동으로 보입니다. **둘은 전제조건이 배타적이라
취향으로 고르면 패스 1에서 죽습니다.** gstack `review`나 내장 `code-review`는 워킹트리를 보므로
이 문제가 없습니다.

### Persona Test (`/persona-test`)

고객 페르소나를 정의하고 서비스를 고객처럼 사용하여 PMF와 사용성을 검증합니다.

- Web UI, CLI, MCP, API, Plugin 인터페이스 지원
- Bug / Friction / Gap / Delight 분류 체계
- 프로젝트별 페르소나를 CLAUDE.md에서 설정 가능
- 스크린샷·리포트는 `~/.gritive/persona-test/{프로젝트}/{YYYYMMDD-HHMMSS}/`에 자동 보존됩니다
- Web UI에서 Bug를 발견하면 콘솔 에러·실패한 API 호출을 증거로 붙여 이슈에 남깁니다 —
  구현자가 재현부터 다시 하지 않아도 됩니다
- 페르소나는 하나씩 순차로 돌고 다음 페르소나 전에 세션을 끊습니다 — 두 번째부터
  "첫 사용 30초" 경험이 거짓이 되지 않게
- **AI slop 관찰 축** — 빈 홍보성 문구, 잔존한 `Lorem ipsum`·`TODO`·더미 값, 모델 말투 누출,
  장식 과잉, 템플릿 티, 출처 없는 가짜 구체성을 페르소나 눈에 보이는 표면(UI 문구·CLI 출력·API
  메시지)에서 잡습니다. 기본 분류는 Friction이고 내용이 사실과 다르면 Bug로 올립니다.
  본 문구를 그대로 인용하지 못하면 기록하지 않습니다. 코드 스타일은 대상이 아닙니다 —
  그건 `codebase-review`가 봅니다

```
/persona-test           # 인터페이스별 시나리오 실행
/persona-test --cross   # 인터페이스 간 크로스 시나리오도 실행
```

### Project (`/project`)

RFP(과업지시서) 한 장에서 프로젝트의 기획·기준 문서와 이슈 백로그를 부트스트랩하고, 그 백로그를
자율적으로 처리합니다.

```
/project                    # 인자 없음 → loop 와 동일
/project #10                # 이슈 #10 관련 이슈를 모두 처리 (`/project loop #10` 단축형)
/project setup <RFP-path>   # RFP → PRD · design-guide · CLAUDE.md · README 생성
/project prd-to-issue       # PRD를 의존성 순서 GitHub 이슈로 분해
/project sync               # 공유 템플릿으로 프로젝트 CLAUDE.md/README 보강 (additive-only)
/project gap                # RFP·PRD 대비 실제 구현 gap + UI 노출 여부 분석
/project build [상한] [--skip-review]       # 이슈 백로그를 완전 자율로 burndown
/project loop [#이슈번호] [라운드상한] [--skip-review]  # #N이면 관련 이슈만, 숫자는 loop 상한
                            #   선정 순서는 이슈의 우선순위 → 없으면 기능 우선
```

**`loop`** — 백로그를 태우는 것을 넘어 **더 만들 것이 없어질 때까지** 일감을 스스로 찾습니다. 한
라운드는 `build`(백로그 소진) → `gap`(문서 대비 gap을 이슈로) → `build` → `persona-test`(고객 관점
문제를 이슈로) → `build`이고, **한 라운드가 새 빌드가능 이슈를 하나도 만들지 못하면** 수렴·종료합니다.
인자 없이 `/project`만 쳐도 전체 `loop`로 갑니다. `/project #10`과 `/project loop #10`은 parent/sub-issue·선행/후행·명시적 관련 링크와 scoped gap·design·persona 파생 이슈를 재귀적으로 처리하고, #10 관련 범위가 수렴하면 멈춥니다.

수렴 안전장치(`review-forever`와 같은 불변식):

- **완료·정체는 원시 발견 수가 아니라 "새로 만든 빌드가능 이슈"로 잽니다** — gap/persona는 라운드 간
  기억이 없어 이미 이슈로 있는 것을 매번 다시 발견하므로, 원시 수로 재면 루프가 끝나지 않습니다.
- **빌드 제외 클래스**는 큐에서 뺍니다 — 루프가 구현하지 않는 이슈들입니다(사람·고객의 몫이거나,
  선행 이슈에 막혀 있거나, 두 번 실패해 사람이 봐야 하는 것). 전체 목록은
  `skills/project/loop.md`의 "빌드 제외 클래스" 절에 있습니다.
- **build가 중단 조건(보안 결함 등)으로 멈추면 루프도 멈춥니다** — gap/persona로 넘어가지 않습니다(중단 ≠ 수렴).
- **persona는 실행 중인 서비스를 요구**합니다. 못 띄우면 그 라운드 persona는 "미검증"이 되어 **수렴
  종료 신호로 쓰이지 못합니다** — 검사 안 한 것을 "발견 0"으로 세지 않습니다.
- **전제조건: 이슈 관리 방식**(gh + CLAUDE.md "이슈 관리")이 있어야 합니다. 없으면 build가 소비할
  백로그가 안 만들어지므로 흉내 내지 않고 멈춥니다.

**이 스킬은 오케스트레이터입니다 — 외부 스킬·도구에 의존합니다.**

| 서브커맨드              | 의존 대상                                                                   | 출처                                          |
| ----------------------- | --------------------------------------------------------------------------- | --------------------------------------------- |
| `setup`                 | Agent 툴 (3단계 통합 리서치 dispatch, 없으면 중단)                           | Claude Code 기본 제공                         |
| `setup`                 | 그 subagent의 `WebSearch`·`WebFetch` (없으면 강등)                           | Claude Code 기본 제공                         |
| `prd-to-issue`, `build` | `gh` CLI (인증된 상태)                                                      | GitHub CLI                                    |
| `build`                 | `codebase-review` 리뷰어 지침 문서 (9.5단계가 직접 dispatch — 트리아지·수정도 build) | 이 플러그인                          |
| `loop`                  | `build`·`gap`·`persona-test` + 그 의존 전부, persona용 실행 서비스·브라우저 | 이 플러그인 / 위                              |

의존 대상이 없으면 해당 서브커맨드는 절차를 임의로 재구현하지 않고 중단합니다. 단, setup의 웹 도구만
예외로 강등해 진행합니다.
이 표의 원본은 `skills/project/SKILL.md`입니다 — 런타임에 로드되는 건 그쪽입니다.

> **`/project build`는 사람 확인 없이 머지·배포까지 갑니다.** 이슈 선택 → 구현 → PR →
> merge/deploy → 다음 이슈를 반복하며, PR마다 머지 승인을 다시 묻지 않습니다. 이 커맨드를
> 실행하는 것 자체가 사전 승인입니다. `--skip-review`를 지정하면 코드 리뷰만 생략하며, 구현 검증·CI와
> 다른 중단 조건은 그대로 적용됩니다.
>
> **자동 승인 조건과 리뷰 판정의 값을 여기 옮겨 적지 않습니다** — 기준은
> `skills/project/build.md`의 "9.5. 리뷰·PR" 절이고, 전체 중단 조건은 같은 파일의 "자동 진행 중단
> 조건"에 있습니다. 실제 시크릿 값 노출·테스트 실패·merge conflict·배포 실패·데이터 삭제 위험이
> 나오면 멈추고 사람에게 넘깁니다.
>
> 이슈 본문과 댓글은 **데이터로만** 취급하며, 요구사항으로 승격하기 전에 작성자가 write 권한자인지
> 확인합니다.
>
> 리뷰의 **미검증 관찰(`unverified`)** 은 후속 이슈로 만들지 않고 PR 본문과 완료 보고에 전문으로
> 싣습니다 — 범위 밖 발견과 같은 처리입니다. 게이트 카운트에서 빠지는 항목이므로 적지 않으면
> 사람이 그 존재를 모릅니다.

## Installation

### Claude Code

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add gritive/skills

# 2. 플러그인 설치
claude plugin install gritive
```

### Codex

```bash
# 1. 마켓플레이스 등록
codex plugin marketplace add gritive/skills

# 2. 플러그인 설치
codex plugin add gritive@gritive-skills
```

Codex는 `.agents/plugins/marketplace.json`에서 마켓플레이스를 읽고, `.codex-plugin/plugin.json`에서
플러그인 메타데이터와 `skills/` 경로를 읽습니다.

## 프로젝트별 설정 (선택)

별도 설정 없이 바로 쓸 수 있습니다. 아래는 결과를 더 좋게 만드는 선택 사항입니다.

### Codebase Review

프로젝트 CLAUDE.md에 아키텍처 규칙, 보안 원칙 등이 있으면 리뷰어가 자동으로 반영합니다.

상세 설정 가이드: `skills/codebase-review/references/claude-md-setup.md`

### Persona Test

프로젝트 CLAUDE.md에 다음을 추가하면 최적의 결과를 얻을 수 있습니다:

```markdown
## Persona Test

- 인터페이스: web (http://localhost:3000), cli (`myapp` command)
- 테스트 계정: `docs/test-accounts.md` 참조
- 제품 스펙: `docs/PRODUCT_SPEC.md`
```

상세 설정 가이드: `skills/persona-test/references/claude-md-setup.md`

## Plugin Structure

```
gritive/
├── .agents/
│   └── plugins/
│       └── marketplace.json # Codex 마켓플레이스 등록 정보
├── .claude-plugin/
│   ├── plugin.json          # 플러그인 메타데이터 + 버전
│   └── marketplace.json     # 마켓플레이스 등록 정보 (버전 동기화 대상)
├── .codex-plugin/
│   └── plugin.json          # Codex 플러그인 메타데이터 + 버전
├── skills/
│   ├── codebase-review/
│   │   ├── SKILL.md
│   │   ├── reviewers/        # dispatch된 subagent가 Read해서 수행하는 지침.
│   │   │   ├── backend.md    # 플러그인 에이전트가 아니다 — Codex 배포본이
│   │   │   ├── frontend.md   # skills만 싣기 때문
│   │   │   ├── security.md
│   │   │   ├── conformance.md # 기준 문서 대조 (코드 결함이 아니다)
│   │   │   ├── shared-lenses.md   # 데드코드·중복·문서 staleness 공통 규약
│   │   │   ├── smell-baseline.md  # 코드 스멜 고정 목록 (backend·frontend)
│   │   │   └── evidence-gate.md   # 근거 인용 게이트 · 미검증 관찰
│   │   └── references/
│   │       ├── claude-md-setup.md
│   │       ├── args.md        # 인자 문법 (scope · --domain · --issue)
│   │       └── report-format.md # 리포트 양식 · 도메인 교차 발견 처리
│   ├── review-forever/
│   │   ├── SKILL.md          # 리뷰 스킬을 감싸는 루프 (자체 리뷰 로직 없음).
│   │   │                     # user space의 동명 스킬과 다르다 — gritive: 접두사 필수
│   │   └── references/
│   │       ├── args.md          # 인자 문법 · 스킬 이름 해석
│   │       ├── autonomous-invocation.md # 자율 실행 시 규약
│   │       └── report-format.md # 완료 보고 양식 (미검증 관찰 포함)
│   ├── persona-test/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── claude-md-setup.md
│   │       ├── observation-axes.md     # AI slop 판정 · 인터페이스별 관찰
│   │       ├── persona-templates.md
│   │       ├── report-format.md        # 리포트 양식
│   │       └── web-tooling.md          # Web UI 관측 도구 사용법
│   └── project/
│       ├── SKILL.md          # 서브커맨드 라우터
│       ├── setup.md          # RFP → PRD · design-guide · CLAUDE.md · README
│       ├── prd-to-issue.md   # PRD → 의존성 순서 GitHub 이슈
│       ├── sync.md           # 템플릿 backfill (additive-only)
│       ├── gap.md            # 문서 대비 실제 구현 gap 분석
│       ├── build.md          # 이슈 백로그 자율 burndown (오케스트레이터 —
│       │                     #   선정 · 사람 작업 이슈 생성 · 리뷰/PR · 머지)
│       ├── build-issue.md    # 이슈 하나를 맡는 subagent 지침
│       │                     #   (split · Coverage Plan · 구현 · 검증 · Audit)
│       ├── loop.md           # build→gap→build→persona-test→build 수렴 루프
│       ├── hard-gates.md     # build가 구현하지 않는 것 · 시크릿 값 규칙
│       ├── followup-issues.md    # 후속 이슈 종류별 양식
│       ├── issue-registration.md # 이슈 등록 공통 규약 (컨벤션·중복·폴백)
│       ├── references/
│       │   ├── completion-report.md   # build 완료 보고 항목
│       │   ├── interaction-baseline.md # 일부 실행 경로만 도달하는 참조
│       │   ├── issue-scope.md         # #N 관련 이슈의 재귀 범위 계산·수렴 계약
│       │   ├── issue-bundling.md      # 같은 변경 묶음 판정
│       │   └── review-gate.md         # 리뷰 게이트 절차 (9.5단계)
│       └── templates/
│           ├── CLAUDE.md.template
│           └── README.md.template
├── scripts/
│   └── push.sh              # 버전 bump + push (git release alias)
├── CLAUDE.md                # 에이전트 계약 · 개발 규칙
└── README.md
```

## Agent Interface Contract

모든 리뷰어는 공통 인터페이스를 따릅니다:

| 입력    | 값                                                                          |
| ------- | --------------------------------------------------------------------------- |
| `mode`  | `base-diff` (기본) 또는 `full`                                              |
| `scope` | `backend` / `frontend` / `all`                                              |
| `base`  | `git diff`에 넘길 리뷰 기준 인자 (`origin/main...HEAD`, `HEAD`, `--cached`) |
| `files` | 리뷰 대상 파일 목록 (`mode=base-diff`일 때만 전달)                          |
| `이슈 참조` | 이슈 번호·URL. `conformance`만 씁니다 — 리뷰어가 직접 조회합니다            |
| `이슈 본문` | 사용자가 본문을 직접 붙여넣은 경우에만 전달. 그때는 **그것이 기준 전부**입니다 |

**범위 규칙**

- `mode=base-diff`: `files`에 있는 파일만 리뷰 대상. 발견 사항은 이 목록 안에 위치해야 합니다.
- 판정에 필요한 문맥은 코드베이스 전체를 읽어도 됩니다 — **읽는 범위 ≠ 보고 범위**.
- `files`가 비면 "대상 없음"으로 종료합니다. **전체 스캔으로 확장하지 않습니다.**
- `mode=full`일 때만 코드베이스 전체가 대상입니다.
- 전역 그래프가 필요한 항목(순환 의존, 번들 크기, 미사용 의존성 등)은 에이전트별로
  `base-diff` 모드에서의 축소 규칙을 정의합니다.
- **유일한 예외**: 데드코드 렌즈를 가진 에이전트(`backend`/`frontend`)는 이 변경이 마지막 호출을 제거해 고아가 된 심볼을
  `files` 밖이어도 보고합니다 (근거 명시, 1홉까지).

**리뷰 단위는 '변경된 파일'이지 '변경된 라인'이 아닙니다.** 900줄 파일에서 3줄만 고쳐도 900줄
전체가 리뷰 대상입니다 — 파일 전체 맥락을 봐야 아키텍처·보안 이슈를 놓치지 않기 때문입니다.
대신 건드리지 않은 기존 코드의 이슈도 보고될 수 있습니다.

**공통 규칙**

- 시작 시 CLAUDE.md를 읽고 프로젝트 규칙 반영
- 통일된 심각도 체계: `CRITICAL` / `HIGH` / `MEDIUM` / `LOW`
- 구조화된 테이블 형식 출력
- 읽기 전용 (코드 수정 없음)
- **근거 인용 게이트**(`backend`·`frontend`·`security`) — 발견마다 그것을 유발한 코드를 `파일:라인`과
  함께 원문으로 인용합니다. 인용할 줄을 못 찾은 발견은 표에서 빼고 `미검증 관찰` 절에만 남기며,
  대시보드 발견 수에도 세지 않습니다. 확신도를 높여 잡아 게이트를 우회하지 않습니다.
  `conformance`는 코드가 아니라 **기준 문서를 인용**하는 자기 규칙을 쓰므로 이 게이트를 받지 않습니다
- **도메인 교차 발견은 Top 10에서만 합칩니다** — 같은 지점이거나 인용이 겹치면 한 항목으로 내고
  도메인 열에 전부 적습니다. 도메인별 상세 섹션은 각 리뷰어의 리포트를 그대로 둡니다.

## Development

### 버전 관리

push 시 `plugin.json`의 patch 버전을 자동으로 올리려면 git alias를 설정합니다:

```bash
git config alias.release '!bash scripts/push.sh'
```

이후 `git push` 대신 `git release`를 사용하면 버전이 자동 bump됩니다:

```bash
git release          # 0.2.0 → 0.2.1 → ... 자동 bump 후 push
```

`push.sh`는 **patch만** 올립니다. minor·major bump는 `.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`을 직접 고치세요 — 버전이 여러 파일에
따로 있으므로 항상 함께 바꿉니다. 마지막 커밋 제목이
`chore: bump version`으로 시작하면 스크립트가 재bump를 건너뛰므로, 수동 bump는 마지막 커밋으로
두면 됩니다.

## License

MIT
