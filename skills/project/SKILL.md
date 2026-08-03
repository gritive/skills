---
name: project
description: Use when working on a project driven by an RFP / 과업지시서 — bootstrapping it, turning its requirements into issues, reconciling its docs against the shared templates, checking what is actually implemented against them, or burning down its backlog autonomously. Triggers on "/project" and its subcommands (setup, prd-to-issue, sync, gap, build, loop), bare "/project", RFP-to-project bootstrap, implementation gap analysis, autonomous issue backlog processing.
---

# project

RFP 한 장에서 프로젝트의 기획 문서·기준 문서·이슈를 부트스트랩하고, 그 백로그를 자율적으로 처리하는 워크플로우 스킬. 여섯 서브커맨드를 라우팅한다.

## 라우팅 (첫 인자로 분기)

| 첫 인자            | 하는 일                                                                                                                                     | 지침 파일         |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| `setup <RFP-path>` | RFP → 리서치 → PRD → design/UX 가이드 → gap 보강 → CLAUDE.md/README 생성                                                             | `setup.md`        |
| `prd-to-issue`     | PRD를 에픽으로 분해해 의존성 순서로 GitHub 이슈 생성                                                                                        | `prd-to-issue.md` |
| `sync`             | 공유 baseline 대비 프로젝트 CLAUDE.md + design-guide 인터랙션 규약의 누락분 보강 (additive-only)                                            | `sync.md`         |
| `gap`              | RFP·PRD·design/UX 가이드 대비 **실제 구현**의 gap을 fresh eye로 분석하고, 구현된 기능의 UI 노출 여부까지 확인                               | `gap.md`          |
| `build [--demo]`   | GitHub 이슈 백로그를 **사람 개입 없이** 이슈 선택→구현→PR→merge/deploy→다음 이슈로 완전 자율 처리(PR마다 머지 재확인 없음). `--demo`는 **범위·깊이·리뷰 경로·발견 처분**을 데모용으로 바꾼다 | `build.md`        |
| `loop [--demo]` (기본) | `build`→`gap`→`build`→`persona-test`→`build`를 **새 빌드가능 이슈가 안 나올 때까지** 라운드로 반복. 인자 없이 `/project`만 쳐도 여기로 온다 | `loop.md`         |

## 실행 규칙

1. 첫 인자를 읽는다.
2. `setup`/`prd-to-issue`/`sync`/`gap`/`build`/`loop` 중 하나면 이 스킬 디렉터리의 동명 `.md`(예: `setup.md`)를 Read로 읽고 **그 지침을 그대로 수행**한다. `setup`은 두 번째 인자(RFP 경로)를, `build`는 이슈 수 상한을, `loop`는 라운드 상한을, `build`·`loop`는 `--demo` 여부를 그 워크플로우에 전달한다.
3. **인자가 없으면 `loop`로 라우팅한다** — `loop.md`를 읽고 수행한다. `/project`만 친 것은 `/project loop`와 같다.
4. 인자가 있는데 여섯 중 하나가 아니면 usage 앞에 `알 수 없는 서브커맨드: <입력>` 한 줄을 덧붙여 출력하고 멈춘다:

```
사용법: /project [서브커맨드]
  (인자 없음)            loop 과 동일 — build→gap→persona-test 자율 반복
  setup <RFP-path>       RFP에서 PRD·디자인가이드·CLAUDE.md·README 생성
  prd-to-issue           PRD를 의존성 순서 GitHub 이슈로 분해
  sync                   공유 baseline으로 CLAUDE.md + design-guide 인터랙션 규약 보강
  gap                    RFP·PRD·design/UX 가이드 대비 실제 구현 gap + UI 노출 여부 분석
  build [--demo] [상한]  이슈 백로그를 완전 자율로 burndown(PR마다 머지 재확인 없음)
  loop [--demo] [라운드상한]
                         build→gap→build→persona-test→build를 수렴까지 반복
  --demo                 데모 우선 모드 — 핵심 사용자 흐름 이슈만, happy path 우선 구현,
                         미룬 것과 리뷰 발견(정본: build.md "리뷰 게이트" 절)은
                         demo-debt 이슈로 등록
```

## `build`·`loop`의 인자 파싱

`build`의 나머지 인자는 **처리할 이슈 수 상한(정수)** 과 **`--demo` 플래그**, `loop`의 나머지 인자는
**라운드 수 상한(정수)** 과 **`--demo` 플래그**다. 정수와 플래그는 순서에 관계없이 조합할 수 있다
(`/project build --demo 3`, `/project loop --demo 2`). 위에 없는 토큰은 알 수 없는 인자로 보고 usage를
출력하고 멈춘다.

**`loop --demo`는 build 호출과 큐 회계 양쪽에 같은 범위를 적용해야 한다** — 한쪽만 좁히면 수렴이
불가능해진다(`loop.md`의 "데모 범위" 절).

**`--demo`는 수정 루프 대신 1패스 리뷰를 쓴다 — 리뷰 자체를 건너뛰는 옵션이 아니다.** 리뷰 발견은
고치는 대신 `demo-debt` 이슈로 등록하고 진행한다. **어느 리뷰가 도는지, 어떤 발견이 등록 대상인지의
정본은 `build.md`의 "리뷰 게이트" 절이다** — 여기 값을 옮겨 적지 않는다. 리뷰가 실행되지 않으면
머지하지 않는다.

## 전제조건 — 스킬·도구 의존

이 스킬은 **오케스트레이터**다. 실제 작업의 상당 부분을 아래에 위임하므로, 그것들이 있어야 해당
서브커맨드가 동작한다.

| 서브커맨드              | 의존 대상                                                           | 출처                                          |
| ----------------------- | ------------------------------------------------------------------- | --------------------------------------------- |
| `setup`                 | Agent 툴 + `general-purpose` (3단계 통합 리서치 dispatch. **없으면 중단**) | Claude Code 기본 제공                       |
| `setup`                 | 그 subagent의 `WebSearch`·`WebFetch` (**없으면 중단이 아니라 강등**)   | Claude Code 기본 제공                       |
| `prd-to-issue`, `build` | `gh` CLI (인증된 상태)                                              | GitHub CLI                                    |
| `build` (일반 모드)     | `gritive:review-forever` (9.5단계 — PR 전 리뷰)                     | 이 플러그인                                   |
| `build` (`--demo`)      | `gritive:codebase-review` (9.5단계 — 1패스 리뷰)                    | 이 플러그인                                   |
| `loop`                  | `build`·`gap`·`persona-test` 서브스킬 전부 + 그것들의 의존(위 전부) | 이 플러그인 / 위                              |
| `loop`                  | 실행 가능한 서비스(persona 단계) + 브라우저(`Playwright MCP`)       | 대상 프로젝트 / MCP                           |

**의존 대상이 없으면 그 서브커맨드를 흉내 내지 말고 멈춘다.** 판정은 그것을 실제로 관측하는
서브커맨드가 한다 — 리뷰 스킬 존재 확인은 `build.md` 0단계다. PR·머지·배포는 `build`가 `gh`로 직접
수행하므로 스킬 의존이 없다.

**`setup`의 웹 툴만 예외다 — 없어도 멈추지 않고 강등한다.** 리서치 노트 머리에 웹 접근이 없었다고
밝히고, 이후 문서의 신뢰도 표기를 `[소스]`가 아니라 `[관례]`로 단다(`setup.md` 3단계). 근거 없는
항목을 지어내는 것은 강등이 아니라 위반이다.

`gap`은 Agent 툴만 쓰므로 추가 의존이 없다. `sync`는 이 스킬 디렉터리의 `templates/`와 `setup.md`
5단계(인터랙션 규약 baseline의 정본)를 읽는다 — 그 표를 `sync.md`에 복제하지 않는다.

`loop`는 자체 리뷰·구현 로직이 없다 — `build`/`gap`/`persona-test`를 순서대로 호출하고 그 결과로
수렴을 판정할 뿐이다. `loop`는 이슈 관리 방식(gh + 대상 CLAUDE.md의 "이슈 관리" 섹션)이 있어야
동작한다 — 없으면 gap/persona가 이슈를 못 만들고 build가 소비할 백로그가 없으므로, 흉내 내지 말고
"이슈 관리 방식이 필요하다"고 알리고 멈춘다.

## 설계 메모

- 이 스킬은 규칙을 강제하는 discipline 스킬이 아니라 **workflow recipe**다. 각 서브커맨드는 "무엇을 어떤 순서로"만 지시하고, 판단은 실행 에이전트에 맡긴다.
- 이슈 컨벤션·아키텍처 원칙 같은 프로젝트 규칙은 **대상 프로젝트의 CLAUDE.md에서 읽어 따른다**. 특정 org/보드 이름을 이 스킬에 하드코딩하지 않는다.
