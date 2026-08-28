# Gritive Plugin

## Architecture

- `skills/codebase-review/reviewers/*.md`는 dispatch되는 읽기 전용 reviewer 지침이다. skill이나 plugin agent가 아니다. 그 디렉터리의 `shared-lenses.md`·`smell-baseline.md`·`evidence-gate.md`는 dispatch 대상이 아니라 reviewer가 Read하는 공유 규약이며, 각 문서 첫 줄이 자기 독자를 밝힌다.
- project workflow는 `skills/project/SKILL.md`가 서브커맨드별 파일로 라우팅한다. 각 파일 첫 문단이 자기 담당 범위를 정한다.
- `skills/project/templates/`는 대상 프로젝트에 생성할 `CLAUDE.md`·`README.md` 템플릿이며 이 저장소의 지침이 아니다.
- `codebase-review`의 인자 문법만 `references/args.md`에 있다.

## Editing invariants

- 런타임 규칙은 그것을 실행하거나 관측하는 actor의 문서 한 곳에 둔다. 다른 문서는 그 문서를 가리킨다. 변경 후 검색으로 남은 사본을 제거한다.
- 규칙은 긍정형으로 쓴다. 금지형은 긍정으로 표현할 수 없는 하드 가드레일에만 쓰고, 그때도 목표 행동을 함께 적는다.
- 매 실행에 필요한 것만 SKILL 본문에 두고, 일부 경로만 도달하는 참조는 `references/`나 형제 문서로 내린다.
- 지침 문서는 경로로, 이슈 본문·검증 출력·중단 사유는 전문으로 넘긴다(**원문 전달**). 요약본은 지침 유실이다.
- 역사·실험 기록은 runtime 지침에서 제거하고 현재 행동을 바꾸는 근거만 남긴다.
- 중단 조건은 관측 actor가 소유하며 호출자는 반환 상태만 판정한다.
- 대상 프로젝트 규칙은 그 프로젝트의 `AGENTS.md`·`CLAUDE.md`에서 읽는다. org, board, deploy 명령을 이 저장소에 하드코딩하지 않는다.
- 사용자 실행에 필요한 규칙은 해당 `skills/*` 문서에 둔다 — 루트 CLAUDE.md는 배포되지 않는다.

## Actor boundaries

- `codebase-review` reviewer는 발견만 반환하고 대상 저장소에 파일을 쓰지 않는다.
- `review-forever`는 reviewer 발견을 수정하고 재검증한다.
- `persona-test`는 test hook의 임시 변경을 원복한다.
- `project build`는 이슈별 구현을 fresh subagent에 맡기고 review·PR·merge를 직접 수행한다.
- `project loop`는 build를 inline으로 실행하고 gap·design-review·persona-test만 fresh subagent에 맡긴다.

Reviewer를 추가·수정할 때 `skills/codebase-review/SKILL.md`를 읽는다. Reviewer interface, 심각도, base-diff 범위, domain 연결은 그 문서와 `reviewers/*.md`를 기준으로 유지한다.

## Release

`scripts/push.sh`가 patch를 bump하고 아래 세 파일을 함께 갱신한 뒤 커밋·push한다.

- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `.codex-plugin/plugin.json`

직전 커밋 메시지가 `chore: bump version`으로 시작할 때만 bump를 건너뛴다. 손으로 version을 올리고 push.sh를 돌리면 한 번 더 올라가므로 patch bump는 push.sh에 맡긴다.

minor·major 변경은 세 파일을 직접 고치고 `chore: bump version to X.Y.Z`로 커밋한 뒤 push.sh를 돌린다.
