# codebase-review 인자 문법

`SKILL.md` Phase 1이 인자를 해석할 때 읽는다. 인자가 없거나 표의 첫 열과 정확히 일치하는 실행이면
`SKILL.md`의 요약만으로 충분하다.

## 리뷰 모드 (택 1, 기본은 base-diff)

| 인자        | 모드        | 대상                                                   |
| ----------- | ----------- | ------------------------------------------------------ |
| (없음)      | `base-diff` | base branch 대비 변경 파일 (**기본**)                  |
| `full`      | `full`      | 코드베이스 전체                                        |
| `<git-rev>` | `base-diff` | 지정한 git revision 표현식의 diff                      |
| `--working` | `base-diff` | 커밋되지 않은 변경분 (스테이징 + 워킹트리 + untracked) |
| `--staged`  | `base-diff` | 스테이징된 변경분만                                    |

모드 인자는 하나만 받는다. `full`·`<git-rev>`·`--working`·`--staged` 중 둘 이상이 오면 오류로 중단한다.

## `<git-rev>` 판별

1. `--domain` 등 플래그가 소비하는 값 토큰은 위치 인자에서 제외한다.
2. 남은 위치 인자 중 `full` / `backend` / `frontend` / `all`은 **예약어**이며 항상 키워드로 해석한다.
3. 그 외의 위치 인자는 git revision 표현식으로 간주한다: `main..HEAD`, `develop...HEAD`, `abc123`, `v1.0..v1.1`.
4. 표에 없는 `--` 플래그는 오류로 중단하고 이 표의 인자를 안내한다. 입력을 표의 인자로 교정하는 판단은
   사용자가 한다.

예약어와 같은 이름의 브랜치(`backend`, `frontend`, `full`, `all`)는 `..`를 포함한 범위 표현식으로 준다:
`/codebase-review backend..HEAD`. `..`가 있으면 예약어 검사를 건너뛴다.

## 코드 범위

| 옵션              | 설명                                                     |
| ----------------- | -------------------------------------------------------- |
| `all` (기본)      | 백엔드 + 프론트엔드 전체                                 |
| `backend`         | 백엔드만 (프로젝트 구조에서 자동 탐지)                   |
| `frontend`        | 프론트엔드만 (프로젝트 구조에서 자동 탐지)               |
| `--domain <name>` | 특정 도메인만 (backend, frontend, security, conformance). 콤마로 복수 |

## 이슈 기준

| 옵션             | 설명                                                                        |
| ---------------- | --------------------------------------------------------------------------- |
| `--issue <ref>`  | `conformance`의 1차 기준. 이슈 번호·URL을 넘기면 리뷰어가 직접 조회한다      |

주지 않으면 `SKILL.md` Phase 2가 커밋 메시지에서 참조를 추출한다. 거기서도 못 찾으면 `conformance`가
요구 충족·요구 범위 이탈 판정을 생략한다.

이슈 **본문**을 붙여넣어도 되지만, 그때는 그것이 기준 전부다. 발췌해서 주면 발췌하지 않은 요구는
판정되지 않는다.

## `scope`와 `--domain`은 직교한다

- **`--domain`은 어떤 에이전트를 띄울지 정하고, `scope`는 각 에이전트에 어떤 파일을 줄지 정한다.**
  도메인을 좁혀도 대상 파일 범위는 그대로다.
- `--domain`이 없으면 scope에 따라 관련 도메인 전부 실행하고 신호 게이팅을 적용한다(`SKILL.md`).
- `--domain`이 있으면 지정된 도메인만 실행하며 scope 기반 자동 제외와 신호 게이팅을 모두 덮어쓴다.
- scope=`backend`이면 Frontend 도메인을 자동 제외한다.
- scope=`frontend`이면 다른 도메인도 실행하되 `files`가 프론트엔드 파일로만 채워진다.
- `scope`는 `files`를 필터링하는 역할에 한정한다. 에이전트에게 점검 항목을 건너뛰라고 지시하지 않는다 —
  대상 파일이 프론트엔드뿐이면 백엔드 항목은 자연히 걸리지 않는다.
- 따라서 `backend --domain frontend` 같은 조합도 유효하다. frontend 리뷰어가 실행되고 `files`에
  프론트엔드 파일이 없으므로 "대상 없음"으로 종료한다.

## 실행 예시

```
/codebase-review                          → base branch 대비 변경분 (기본)
/codebase-review full                     → 전체 코드베이스
/codebase-review main..HEAD               → 지정 diff
/codebase-review abc123                   → abc123...HEAD diff
/codebase-review --working                → 미커밋 변경분
/codebase-review --staged                 → 스테이징된 변경분
/codebase-review backend                  → base diff 중 백엔드 파일만, Frontend 도메인 제외
/codebase-review --domain backend,security → base diff 대상, 2개 도메인만
/codebase-review full --domain security   → 전체 코드베이스, 보안 도메인만
```
