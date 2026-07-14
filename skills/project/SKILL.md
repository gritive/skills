---
name: project
description: Use when bootstrapping a new project from an RFP / 과업지시서 — turning an RFP into PRD·design-guide·CLAUDE.md·README, breaking a PRD into dependency-ordered GitHub issues, reconciling a project's CLAUDE.md/README against the shared skill templates, checking RFP/PRD/design-guide requirements against actual implementation and UI exposure, or burning down the GitHub issue backlog fully autonomously (no per-PR merge confirmation). Triggers on "/project setup", "project prd-to-issue", "project sync", "project gap", "project build", RFP-to-project bootstrap, implementation gap analysis, autonomous issue backlog processing.
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
| `build` | GitHub 이슈 백로그를 **사람 개입 없이** 이슈 선택→구현→PR→merge/deploy→다음 이슈로 완전 자율 처리(PR마다 머지 재확인 없음) | `build.md` |

## 실행 규칙

1. 첫 인자를 읽는다.
2. `setup`/`prd-to-issue`/`sync`/`gap`/`build` 중 하나면 이 스킬 디렉터리의 동명 `.md`(예: `setup.md`)를 Read로 읽고 **그 지침을 그대로 수행**한다. `setup`은 두 번째 인자(RFP 경로)를, `build`는 두 번째 인자(있으면 처리할 이슈 수 상한)를 그 워크플로우에 전달한다.
3. 인자가 없거나 다섯 중 하나가 아니면 아래 usage를 출력하고 멈춘다:

```
사용법: /project <서브커맨드>
  setup <RFP-path>   RFP에서 PRD·디자인가이드·CLAUDE.md·README 생성
  prd-to-issue       PRD를 의존성 순서 GitHub 이슈로 분해
  sync               공유 템플릿으로 프로젝트 CLAUDE.md/README 보강
  gap                RFP·PRD·design/UX 가이드 대비 실제 구현 gap + UI 노출 여부 분석
  build [상한]       이슈 백로그를 완전 자율로 burndown(PR마다 머지 재확인 없음)
```

알 수 없는 인자면 usage 앞에 `알 수 없는 서브커맨드: <입력>` 한 줄을 덧붙인다.

## 전제조건 — 외부 스킬·도구 의존

이 스킬은 **오케스트레이터**다. 실제 작업의 상당 부분을 아래 외부 스킬·도구에 위임하므로, 그것들이
설치돼 있어야 해당 서브커맨드가 동작한다. gritive 플러그인은 이들을 함께 배포하지 않는다.

| 서브커맨드 | 의존 대상 | 출처 |
|---|---|---|
| `setup` | `deep-research` 스킬 | 별도 설치 필요 (Claude Code 기본 제공이 **아니다**) |
| `prd-to-issue`, `build` | `gh` CLI (인증된 상태) | GitHub CLI |
| `build` | `land-and-deploy` 스킬 | [gstack](https://github.com/gstack-sh/gstack) |
| `build` | `investigate`, `feature-pipeline` (구현 위임 시, 선택) | gstack |

**의존 대상이 없으면 그 서브커맨드를 흉내 내지 말고 멈춘다.** 예를 들어 `build`가 `land-and-deploy`를
찾지 못하면, 머지·배포 절차를 임의로 재구현하지 말고 "gstack의 `land-and-deploy`가 필요하다"고
알리고 중단한다. 자율 머지 루프에서 게이트를 자체 구현하는 것은 위험하다.

`setup`은 `deep-research`가 없으면 연구 루프를 자체 구현하지 말고 사용자에게 설치를 안내하고 멈춘다.

`gap`은 Agent 툴만 쓰므로 추가 의존이 없다. `sync`는 이 스킬 디렉터리의 `templates/`만 쓴다.

## 설계 메모

- 이 스킬은 규칙을 강제하는 discipline 스킬이 아니라 **workflow recipe**다. 각 서브커맨드는 "무엇을 어떤 순서로"만 지시하고, 판단은 실행 에이전트에 맡긴다.
- 이슈 컨벤션·아키텍처 원칙 같은 프로젝트 규칙은 **대상 프로젝트의 CLAUDE.md에서 읽어 따른다**. 특정 org/보드 이름을 이 스킬에 하드코딩하지 않는다.
