# 이슈 범위 계약

`project loop #N`이 전달한 `active scope`에서만 적용한다. 전역 loop에는 적용하지 않는다.

## 범위 계산

- 먼저 동일 저장소의 open/closed 이슈 전체에서 번호·상태·native 관계와 본문 관계 표기를 읽어 구조화 관계
  인덱스를 만든다. 본문 기반 `부모:`·`선행:`·related edge는 `build.md` 0.5단계의 작성자 권한 검증을 통과한
  이슈에서만 채택한다. seed `#N`에서 이 인덱스의 parent/sub-issue, blocks/blocked-by, 선행, related edge를
  양방향으로 따라 재귀 폐쇄를 만든다.
- 단순 본문 언급, 댓글·PR·커밋 cross-reference, 공통 라벨·마일스톤·프로젝트, 외부 저장소 링크는 관계가 아니다.
- 닫힌 이슈는 관계 연결점으로만 유지하고 build 후보에서는 제외한다. `(from, to, relation_type, evidence)`를
  기록하는 worklist로 탐색한다. 방문한 모든 이슈에서 각 관계원을 조회했고 worklist가 비어야 폐쇄 계산 완료다.
  실행 순서를 정할 수 없는 dependency cycle은 `stopped`다.
- build split/follow-up과 scoped gap·design·persona 발견이 만든 이슈, 중복 판정으로 접힌 기존 열린 이슈는
  원인 이슈와 관계 근거를 남기고 scope에 편입한다. 각 Phase 뒤 폐쇄를 다시 계산한다.

## 실행 불변식

- 모든 후보 선정·우선순위·묶음은 active scope 안에서만 한다. 관계 없는 이슈를 같은 PR에 묶지 않는다.
- gap은 scope의 요구사항과 구현 영역, design은 scoped build가 바꾼 UI, persona는 관련 사용자 흐름만 검사한다.
- Phase 반환은 `scope_additions: [{issue, related_to, relation_type, evidence}]`를 포함한다. 새 생성 수가 아니라
  이번 라운드에 처음 편입된 빌드가능 고유 번호 수가 scoped queue다.
- scoped queue가 0, active scope의 미완료 buildable 이슈가 0, persona가 실제 실행된 라운드에서 수렴한다.
  scope 안에 build 제외 클래스가 남으면 `stopped`로 번호·사유를 보고한다.
- build 완료 보고는 `scope: issue-closure:#N`을 포함한다. `drained`와 `excluded_only`는 이 scope 기준이다.
