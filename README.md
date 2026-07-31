# Gritive

코드베이스 종합 리뷰, 클린까지 반복하는 리뷰 루프, 페르소나 기반 UX 테스트, RFP 기반 프로젝트
부트스트랩을 위한 Claude Code / Codex 플러그인.

## Features

### Codebase Review (`/codebase-review`)

6개 전문 리뷰 에이전트를 병렬 실행하여 코드를 종합 점검합니다.

**기본 대상은 base branch 대비 변경분입니다.** 전체 코드베이스 스캔은 `full`을 명시했을 때만 수행합니다.

| 도메인       | 에이전트            | 점검 항목                                                  |
| ------------ | ------------------- | ---------------------------------------------------------- |
| Architecture | `arch-reviewer`     | 계층 위반, 순환 의존, 관심사 분리, 모듈 구조               |
| Refactoring  | `refactor-reviewer` | 코드 중복, 복잡도, 코드 스멜, 네이밍                       |
| Dead Code    | `deadcode-reviewer` | 미사용 함수, 고아 파일, 미사용 의존성                      |
| Performance  | `perf-reviewer`     | N+1 쿼리, 메모리 릭, Core Web Vitals, 번들 크기            |
| Security     | `security-reviewer` | 인증/인가, 입력 검증, 주입 공격, 공급망, OWASP Top 10:2025 |
| Frontend     | `frontend-reviewer` | 타입 안전성, 컴포넌트 품질, a11y(WCAG 2.2), 상태 관리      |

```
/codebase-review                          # base branch 대비 변경분, 6개 도메인 (기본)
/codebase-review full                     # 전체 코드베이스, 6개 도메인
/codebase-review main..HEAD               # 지정 diff (git revision 표현식 그대로)
/codebase-review abc123                   # abc123...HEAD diff
/codebase-review --working                # 미커밋 변경분
/codebase-review --staged                 # 스테이징된 변경분
/codebase-review backend                  # base diff 중 백엔드 파일만, Frontend 도메인 제외
/codebase-review --domain perf,security   # base diff 대상, 특정 도메인만
```

base branch는 `origin/HEAD` → `origin/main` → `origin/master` → `main` → `master` 순으로 탐지합니다.

**가드레일 — 어떤 경우에도 전체 스캔으로 폴백하지 않습니다.** 아래는 전부 중단하고 안내합니다:
base branch 탐지 실패, `git diff` 실패(shallow clone의 `no merge base` 등), 대상 파일 0개,
scope 필터링 후 0개, git 저장소가 아님. 대상이 500개를 넘으면 확인 후 진행합니다.

리포트는 대화로 출력합니다. 파일로 저장하는 것은 요청 시 지정한 경로에만 하며, 대상 저장소에
리뷰 산출물을 남기지 않습니다.

**인자 규칙**

- `full` / `backend` / `frontend` / `all`은 **예약어**입니다. 같은 이름의 브랜치를 리뷰하려면
  `..`를 포함한 범위로 주세요: `/codebase-review backend..HEAD`.
- `full`과 git revision(또는 `--working` / `--staged`)을 **함께 주면 오류**입니다. 모드가 상충합니다.
- `--domain`은 **어떤 에이전트를 띄울지**만 정하고, `backend`/`frontend`는 **어떤 파일을 줄지**만
  정합니다. 둘은 직교하므로 도메인을 좁혀도 대상 파일 범위가 넓어지지 않습니다.

> **0.1.0에서 올라오는 경우**: `--full` → `full` (플래그가 아니라 위치 인자),
> `--changed` → `--working`로 바뀌었습니다. `.codebase-review.jsonl` 이력과 since-last 모드는
> 제거됐습니다. 구버전 플래그는 **자동 변환하지 않고 오류로 중단**합니다 — `--full`을 `full`로
> 추측 변환하면 의도치 않은 전체 스캔이 실행되기 때문입니다.

### Review Forever (`/gritive:review-forever`)

**리뷰 스킬을 감싸서 고칠 것이 없어질 때까지 리뷰-수정-검증을 반복합니다.** 이 스킬 자체는 리뷰하지
않습니다 — 다른 리뷰 스킬을 실행하고 그 발견을 고칩니다.

> **반드시 `gritive:` 접두사를 붙이세요.** 접두사 없는 `/review-forever`는 **다른 스킬**입니다.
> user space(`~/.claude/skills/review-forever/`)에 같은 이름의 원본이 있고, 그쪽에는 아래의
> 수렴 안전장치가 하나도 없습니다.

```bash
/gritive:review-forever                          # gstack review (기본)
/gritive:review-forever code-review              # 내장 code-review (작업 중인 diff)
/gritive:review-forever codebase-review          # gritive의 6개 에이전트 병렬 리뷰
/gritive:review-forever codebase-review --domain security   # 감싼 스킬의 인자를 그대로 전달
/gritive:review-forever plan-eng-review          # 다른 플러그인·유저 스킬도 감쌀 수 있음
/gritive:review-forever --max-passes 3           # 패스 상한 (기본 5)
```

인자가 없으면 **gstack의 `review`** 를 씁니다. 이름이 같은 personal 스킬이 내장 스킬을 덮어쓰기
때문에 `review`는 내장이 아니라 gstack 것으로 해석됩니다. 의도된 동작입니다 — gstack `review`는
작업 중인 diff를 보는 pre-landing 리뷰라 이 루프에 맞습니다.

**리뷰 에이전트와 달리 이 스킬은 코드를 고칩니다.** 6개 리뷰 에이전트는 읽기 전용이고, 루프가
수정합니다 — **에이전트가 찾고, 루프가 고칩니다.** 다만 리포트·로그 같은 부산물은 대상 프로젝트에
남기지 않습니다.

수정 전에 각 발견을 소스에서 검증합니다. 리뷰 스킬은 틀릴 수 있고, **오탐을 달래려고 코드를 바꾸는
것이 가장 나쁩니다.** 틀린 발견은 기각하고 근거를 남겨 다음 패스에서 재사용합니다.

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
- 스크린샷·리포트 등 산출물은 프로젝트에 남기지 않습니다 — 세션 임시 디렉토리를 쓰고,
  파일 저장은 요청 시 지정한 경로에만 합니다

```
/persona-test           # 인터페이스별 시나리오 실행
/persona-test --cross   # 인터페이스 간 크로스 시나리오도 실행
```

### Project (`/project`)

RFP(과업지시서) 한 장에서 프로젝트의 기획·기준 문서와 이슈 백로그를 부트스트랩하고, 그 백로그를
자율적으로 처리합니다.

```
/project                    # 인자 없음 → loop 와 동일
/project setup <RFP-path>   # RFP → PRD · design-guide · CLAUDE.md · README 생성
/project prd-to-issue       # PRD를 의존성 순서 GitHub 이슈로 분해
/project sync               # 공유 템플릿으로 프로젝트 CLAUDE.md/README 보강 (additive-only)
/project gap                # RFP·PRD 대비 실제 구현 gap + UI 노출 여부 분석
/project build [상한]       # 이슈 백로그를 완전 자율로 burndown (PR마다 머지 재확인 없음)
/project loop [라운드상한]  # build→gap→build→persona-test→build를 수렴까지 반복
```

**`loop`** — 백로그를 태우는 것을 넘어 **더 만들 것이 없어질 때까지** 일감을 스스로 찾습니다. 한
라운드는 `build`(백로그 소진) → `gap`(문서 대비 gap을 이슈로) → `build` → `persona-test`(고객 관점
문제를 이슈로) → `build`이고, **한 라운드가 새 빌드가능 이슈를 하나도 만들지 못하면** 수렴·종료합니다.
인자 없이 `/project`만 쳐도 `loop`로 갑니다.

수렴 안전장치(`review-forever`와 같은 불변식):

- **완료·정체는 원시 발견 수가 아니라 "새로 만든 빌드가능 이슈"로 잽니다** — gap/persona는 라운드 간
  기억이 없어 이미 이슈로 있는 것을 매번 다시 발견하므로, 원시 수로 재면 루프가 끝나지 않습니다.
- **빌드 제외 클래스**(`question`·`credential`·에픽·blocked)는 큐에서 뺍니다 — 사람·고객의 몫이지
  루프의 몫이 아닙니다.
- **build가 중단 조건(보안 결함 등)으로 멈추면 루프도 멈춥니다** — gap/persona로 넘어가지 않습니다(중단 ≠ 수렴).
- **persona는 실행 중인 서비스를 요구**합니다. 못 띄우면 그 라운드 persona는 "미검증"이 되어 **수렴
  종료 신호로 쓰이지 못합니다** — 검사 안 한 것을 "발견 0"으로 세지 않습니다.
- **전제조건: 이슈 관리 방식**(gh + CLAUDE.md "이슈 관리")이 있어야 합니다. 없으면 build가 소비할
  백로그가 안 만들어지므로 흉내 내지 않고 멈춥니다.

**이 스킬은 오케스트레이터입니다 — 외부 스킬·도구에 의존합니다.**

| 서브커맨드              | 의존 대상                                                                   | 출처                                          |
| ----------------------- | --------------------------------------------------------------------------- | --------------------------------------------- |
| `setup`                 | Agent 툴 (2·5단계 리서치 dispatch) + 그 subagent의 `WebSearch`·`WebFetch`   | Claude Code 기본 제공                         |
| `prd-to-issue`, `build` | `gh` CLI (인증된 상태)                                                      | GitHub CLI                                    |
| `build`                 | `ship`, `land-and-deploy` (+ 선택적으로 `investigate`, `feature-pipeline`)  | [gstack](https://github.com/gstack-sh/gstack) |
| `loop`                  | `build`·`gap`·`persona-test` + 그 의존 전부, persona용 실행 서비스·브라우저 | 이 플러그인 / 위                              |

의존 대상이 없으면 해당 서브커맨드는 절차를 임의로 재구현하지 않고 중단합니다.
이 표의 원본은 `skills/project/SKILL.md`입니다 — 런타임에 로드되는 건 그쪽입니다.

> **`/project build`는 사람 확인 없이 머지·배포까지 갑니다.** 이슈 선택 → 구현 → PR →
> merge/deploy → 다음 이슈를 반복하며, PR마다 머지 승인을 다시 묻지 않습니다. 이 커맨드를
> 실행하는 것 자체가 사전 승인입니다.
>
> 자동 승인은 **BLOCKER가 없고 리뷰가 보안 결함을 0건 보고할 때만** 일어납니다. 리뷰가 보안 결함을
> 찾거나, 실제 시크릿 값 노출·테스트 실패·merge conflict·배포 실패·데이터 삭제 위험이 나오면 멈추고
> 사람에게 넘깁니다. 이슈 본문과 댓글은 **데이터로만** 취급하며, 요구사항으로
> 승격하기 전에 작성자가 write 권한자인지 확인합니다. 전체 목록은 `skills/project/build.md`의
> "자동 진행 중단 조건"에 있습니다.

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

프로젝트 CLAUDE.md에 아키텍처 규칙, 보안 원칙 등이 있으면 리뷰 에이전트가 자동으로 반영합니다.

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
├── agents/
│   ├── arch-reviewer.md
│   ├── deadcode-reviewer.md
│   ├── frontend-reviewer.md
│   ├── perf-reviewer.md
│   ├── refactor-reviewer.md
│   └── security-reviewer.md
├── skills/
│   ├── codebase-review/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── claude-md-setup.md
│   ├── review-forever/
│   │   └── SKILL.md          # 리뷰 스킬을 감싸는 루프 (자체 리뷰 로직 없음).
│   │                         # user space의 동명 스킬과 다르다 — gritive: 접두사 필수
│   ├── persona-test/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── claude-md-setup.md
│   │       └── persona-templates.md
│   └── project/
│       ├── SKILL.md          # 서브커맨드 라우터
│       ├── setup.md          # RFP → PRD · design-guide · CLAUDE.md · README
│       ├── prd-to-issue.md   # PRD → 의존성 순서 GitHub 이슈
│       ├── sync.md           # 템플릿 backfill (additive-only)
│       ├── gap.md            # 문서 대비 실제 구현 gap 분석
│       ├── build.md          # 이슈 백로그 자율 burndown (오케스트레이터 —
│       │                     #   선정 · 사람 작업 이슈 생성 · /ship 호출 · 머지)
│       ├── build-issue.md    # 이슈 하나를 맡는 subagent 지침
│       │                     #   (split · Coverage Plan · 구현 · 검증 · Audit)
│       ├── loop.md           # build→gap→build→persona-test→build 수렴 루프
│       └── templates/
│           ├── CLAUDE.md.template
│           └── README.md.template
├── scripts/
│   └── push.sh              # 버전 bump + push (git release alias)
├── CLAUDE.md                # 에이전트 계약 · 개발 규칙
└── README.md
```

## Agent Interface Contract

모든 리뷰 에이전트는 공통 인터페이스를 따릅니다:

| 입력    | 값                                                                          |
| ------- | --------------------------------------------------------------------------- |
| `mode`  | `base-diff` (기본) 또는 `full`                                              |
| `scope` | `backend` / `frontend` / `all`                                              |
| `base`  | `git diff`에 넘길 리뷰 기준 인자 (`origin/main...HEAD`, `HEAD`, `--cached`) |
| `files` | 리뷰 대상 파일 목록 (`mode=base-diff`일 때만 전달)                          |

**범위 규칙**

- `mode=base-diff`: `files`에 있는 파일만 리뷰 대상. 발견 사항은 이 목록 안에 위치해야 합니다.
- 판정에 필요한 문맥은 코드베이스 전체를 읽어도 됩니다 — **읽는 범위 ≠ 보고 범위**.
- `files`가 비면 "대상 없음"으로 종료합니다. **전체 스캔으로 확장하지 않습니다.**
- `mode=full`일 때만 코드베이스 전체가 대상입니다.
- 전역 그래프가 필요한 항목(순환 의존, 번들 크기, 미사용 의존성 등)은 에이전트별로
  `base-diff` 모드에서의 축소 규칙을 정의합니다.
- **유일한 예외**: `deadcode-reviewer`는 이 변경이 마지막 호출을 제거해 고아가 된 심볼을
  `files` 밖이어도 보고합니다 (근거 명시, 1홉까지).

**리뷰 단위는 '변경된 파일'이지 '변경된 라인'이 아닙니다.** 900줄 파일에서 3줄만 고쳐도 900줄
전체가 리뷰 대상입니다 — 파일 전체 맥락을 봐야 아키텍처·보안 이슈를 놓치지 않기 때문입니다.
대신 건드리지 않은 기존 코드의 이슈도 보고될 수 있습니다.

**공통 규칙**

- 시작 시 CLAUDE.md를 읽고 프로젝트 규칙 반영
- 통일된 심각도 체계: `CRITICAL` / `HIGH` / `MEDIUM` / `LOW`
- 구조화된 테이블 형식 출력
- 읽기 전용 (코드 수정 없음)

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
