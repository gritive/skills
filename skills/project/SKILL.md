---
name: project
description: Use for RFP-driven project work — /project with setup, prd-to-issue, sync, gap, build, or loop. Bootstraps a PRD and issues from an RFP, analyzes implementation gaps, and burns the backlog down to merge.
---

# project

RFP에서 프로젝트 문서와 이슈를 만들고 백로그를 자율 처리한다. 권장 순서는 `setup` → `prd-to-issue` → `loop`다.

## 라우팅

| 첫 인자 | 읽고 수행할 파일 |
| --- | --- |
| `setup <RFP-path>` | `setup.md` |
| `prd-to-issue` | `prd-to-issue.md` |
| `sync` | `sync.md` |
| `gap` | `gap.md` |
| `build [#이슈번호] [상한] [--skip-review]` | `build.md` |
| `loop [#이슈번호] [라운드상한] [--skip-review]` 또는 인자 없음 | `loop.md` |
| `#이슈번호` | `loop.md` (`loop #이슈번호`의 단축형) |

해당 파일을 읽고 나머지 인자를 그대로 전달한다. 각 subcommand가 자신의 의존성과 중단 조건을 검사한다.

## 인자 문법

- `setup`: RFP 경로 하나를 요구한다.
- `build`·`loop`: `#`이 붙은 양의 이슈 번호 최대 하나, 정수 상한 최대 하나(build는 이슈 수, loop는 라운드 수),
  `--skip-review`를 순서와 무관하게 받는다.
- 첫 인자가 `#<양의 정수>`면 `loop #<양의 정수>`로 정규화한다. 예: `/project #10` = `/project loop #10`.
- 중복된 `--skip-review`는 하나로 취급한다.
- 허용되지 않은 토큰, 이슈 번호가 둘 이상이거나 정수가 둘 이상이면 usage를 출력하고 멈춘다.

`--skip-review`의 효과는 `build.md` 9.5단계가 정의한다. `loop`는 이 플래그를 모든 내부 `build` 호출에 그대로 전달한다.

알 수 없는 subcommand에는 `알 수 없는 서브커맨드: <입력>`을 먼저 출력한 뒤 다음 usage를 출력한다.

```text
사용법: /project [서브커맨드]
  setup <RFP-path>
  prd-to-issue
  sync
  gap
  build [#이슈번호] [상한] [--skip-review]
  loop [#이슈번호] [라운드상한] [--skip-review]  # 기본
  #이슈번호                                      # loop #이슈번호 단축형
```
