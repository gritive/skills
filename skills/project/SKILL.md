---
name: project
description: Use when bootstrapping a new project from an RFP / 과업지시서 — turning an RFP into PRD·design-guide·CLAUDE.md·README, breaking a PRD into dependency-ordered GitHub issues, reconciling a project's CLAUDE.md/README against the shared skill templates, checking RFP/PRD/design-guide requirements against actual implementation and UI exposure, or burning down the GitHub issue backlog fully autonomously (no per-PR merge confirmation) — at production depth or, with --demo, at demo depth. Triggers on "/project setup", "project prd-to-issue", "project sync", "project gap", "project build", "project build --demo", "데모 수준으로 빌드", RFP-to-project bootstrap, implementation gap analysis, autonomous issue backlog processing.
---

# project

RFP 한 장에서 프로젝트의 기획 문서·기준 문서·이슈를 부트스트랩하고, 그 백로그를 자율적으로 처리하는 워크플로우 스킬. 다섯 서브커맨드를 라우팅한다.

## 라우팅 (첫 인자로 분기)

| 첫 인자 | 하는 일 | 지침 파일 |
|---|---|---|
| `setup <RFP-path>` | RFP → deep-research → PRD → design/UX 가이드 → gap 보강 → CLAUDE.md/README 생성 | `setup.md` |
| `prd-to-issue` | PRD를 에픽으로 분해해 의존성 순서로 GitHub 이슈 생성 | `prd-to-issue.md` |
| `sync` | 공유 템플릿 대비 프로젝트 CLAUDE.md/README의 누락 scaffold 보강 (additive-only) | `sync.md` |
| `gap` | RFP·PRD·design/UX 가이드 대비 **실제 구현**의 gap을 fresh eye로 분석하고, 구현된 기능의 UI 노출 여부까지 확인 | `gap.md` |
| `build [--demo]` | GitHub 이슈 백로그를 **사람 개입 없이** 이슈 선택→구현→PR→merge/deploy→다음 이슈로 완전 자율 처리(PR마다 머지 재확인 없음). `--demo`면 production이 아니라 **데모 가능한 깊이**로 구현한다 | `build.md` |

## 실행 규칙

1. 첫 인자를 읽는다.
2. `setup`/`prd-to-issue`/`sync`/`gap`/`build` 중 하나면 이 스킬 디렉터리의 동명 `.md`(예: `setup.md`)를 Read로 읽고 **그 지침을 그대로 수행**한다. `setup`은 두 번째 인자(RFP 경로)를, `build`는 이슈 수 상한과 데모 모드 여부를 그 워크플로우에 전달한다.
3. 인자가 없거나 다섯 중 하나가 아니면 아래 usage를 출력하고 멈춘다:

```
사용법: /project <서브커맨드>
  setup <RFP-path>       RFP에서 PRD·디자인가이드·CLAUDE.md·README 생성
  prd-to-issue           PRD를 의존성 순서 GitHub 이슈로 분해
  sync                   공유 템플릿으로 프로젝트 CLAUDE.md/README 보강
  gap                    RFP·PRD·design/UX 가이드 대비 실제 구현 gap + UI 노출 여부 분석
  build [--demo] [상한]  이슈 백로그를 완전 자율로 burndown(PR마다 머지 재확인 없음)
                         --demo: production이 아니라 데모 가능한 깊이로 구현
```

알 수 없는 인자면 usage 앞에 `알 수 없는 서브커맨드: <입력>` 한 줄을 덧붙인다.

## `build`의 인자 파싱

`build`의 나머지 인자는 **순서에 의존하지 않는다.** 각 토큰을 이렇게 해석한다:

- `--demo` → 데모 모드 on
- 정수 → 처리할 이슈 수 상한
- 그 외 → 알 수 없는 인자로 보고 usage를 출력하고 멈춘다

즉 `/project build --demo 3`과 `/project build 3 --demo`는 같다.

**데모 모드는 플래그 없이 문장으로도 켜진다.** "데모 수준으로 빌드", "데모 가능한 정도로만 만들어",
"프로덕션 말고 데모로" 같은 요청은 `--demo`와 **동일하게** 해석한다. 반대로 "production 수준으로",
"제대로 만들어" 같은 요청이나 아무 언급이 없으면 데모 모드는 **off**다 — 기본값은 production이다.

**데모 여부는 루프 전체에 유지되는 상태다.** 이슈마다 다시 판단하지 않는다. `build.md`에 그대로
전달하고, 완료 보고에도 어느 모드로 돌았는지 남긴다.

## 전제조건 — 외부 스킬·도구 의존

이 스킬은 **오케스트레이터**다. 실제 작업의 상당 부분을 아래 외부 스킬·도구에 위임하므로, 그것들이
설치돼 있어야 해당 서브커맨드가 동작한다. gritive 플러그인은 이들을 함께 배포하지 않는다.

| 서브커맨드 | 의존 대상 | 출처 |
|---|---|---|
| `setup` | `deep-research` 스킬 | Claude Code 기본 제공 |
| `prd-to-issue`, `build` | `gh` CLI (인증된 상태) | GitHub CLI |
| `build` | `land-and-deploy` 스킬 | [gstack](https://github.com/gstack-sh/gstack) |
| `build` | `investigate`, `feature-pipeline` (구현 위임 시, 선택) | gstack |

`setup`이 쓰는 `deep-research`는 **Claude Code 기본 제공 스킬**이라 추가 설치가 필요 없다. 같은 이름의
서드파티 스킬이 깔려 있을 수 있으나, 이 스킬이 부르는 건 기본 제공 쪽이다.

**의존 대상이 없으면 그 서브커맨드를 흉내 내지 말고 멈춘다.** 예를 들어 `build`가 `land-and-deploy`를
찾지 못하면, 머지·배포 절차를 임의로 재구현하지 말고 "gstack의 `land-and-deploy`가 필요하다"고
알리고 중단한다. 자율 머지 루프에서 게이트를 자체 구현하는 것은 위험하다.

`gap`은 Agent 툴만 쓰므로 추가 의존이 없다. `sync`는 이 스킬 디렉터리의 `templates/`만 쓴다.

## 설계 메모

- 이 스킬은 규칙을 강제하는 discipline 스킬이 아니라 **workflow recipe**다. 각 서브커맨드는 "무엇을 어떤 순서로"만 지시하고, 판단은 실행 에이전트에 맡긴다.
- 이슈 컨벤션·아키텍처 원칙 같은 프로젝트 규칙은 **대상 프로젝트의 CLAUDE.md에서 읽어 따른다**. 특정 org/보드 이름을 이 스킬에 하드코딩하지 않는다.
