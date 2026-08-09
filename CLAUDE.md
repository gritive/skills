# Gritive Plugin

코드베이스 리뷰, 반복 리뷰, 페르소나 테스트, RFP 기반 프로젝트 실행을 제공하는 Claude Code·Codex 플러그인이다.

## Architecture

- `skills/codebase-review/reviewers/*.md`는 dispatch된 읽기 전용 reviewer 지침이다. skill이나 plugin agent가 아니다.
- 리뷰 orchestration의 정본은 `skills/codebase-review/SKILL.md`다.
- `review-forever`는 review 결과를 수정·재검증하는 독립 loop다.
- persona 경계와 산출물 계약의 정본은 `skills/persona-test/SKILL.md`다.
- project workflow의 actor별 정본:
  - orchestration·review·PR·merge: `skills/project/build.md`
  - 이슈 하나의 구현·검증·audit: `skills/project/build-issue.md`
  - 수렴·위임 envelope: `skills/project/loop.md`

사용자 공간의 동명 skill과 이 저장소의 skill은 독립적으로 변경된다.

## Editing invariants

- 런타임 규칙은 그것을 실행하거나 관측하는 actor의 문서 한 곳에 둔다. 다른 문서는 그 정본을 가리킨다.
- 정책의 정의·예외·완료 조건을 복제하지 않는다. 변경 후 검색으로 남은 사본을 제거한다.
- 역사·실험 기록은 runtime 지침에서 제거하고 현재 행동을 바꾸는 근거만 남긴다.
- 중단 조건은 관측 actor가 소유하며 호출자는 반환 상태만 판정한다.
- 대상 프로젝트 규칙은 그 프로젝트의 `AGENTS.md`·`CLAUDE.md`에서 읽는다. org, board, deploy 명령을 이 저장소에 하드코딩하지 않는다.

루트 CLAUDE.md는 plugin 사용자의 프로젝트에 배포되지 않는다. 사용자 실행에 필요한 규칙은 해당 `skills/*` 문서에 둔다.

## Actor boundaries

- `codebase-review` reviewer는 발견만 반환하고 대상 저장소에 파일을 쓰지 않는다.
- `review-forever`는 reviewer 발견을 수정하고 재검증한다.
- `persona-test`는 제품 코드를 수정하지 않으며 test hook의 임시 변경을 원복한다.
- `project build`는 이슈별 구현을 fresh subagent에 맡기고 review·PR·merge를 직접 수행한다.
- `project loop`는 build를 inline으로 실행하고 gap·design-review·persona-test만 fresh subagent에 맡긴다.
- 완료·정체는 원시 발견 수가 아니라 각 skill의 실행 큐와 반환 상태로 판정한다.

Reviewer를 추가·수정할 때 `skills/codebase-review/SKILL.md`를 읽는다. Reviewer interface, 심각도, base-diff 범위, domain 연결은 그 문서와 `reviewers/*.md`를 정본으로 유지한다.

## Release

version은 다음 세 파일에서 항상 함께 변경한다.

- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `.codex-plugin/plugin.json`
