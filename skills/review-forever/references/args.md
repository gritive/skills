# review-forever 인자 문법

`SKILL.md` 시작 시 읽는다 — 감쌀 스킬 이름 해석과 `--max-passes`가 여기서 결정된다.

감쌀 리뷰 스킬을 첫 인자로 받는다.

```
/gritive:review-forever                          → gstack review 스킬 (기본)
/gritive:review-forever code-review              → Claude Code 내장 code-review
/gritive:review-forever codebase-review          → gritive의 도메인별 리뷰어
/gritive:review-forever codebase-review --domain security   → 감싼 스킬의 인자를 그대로 전달
/gritive:review-forever plan-eng-review          → 다른 플러그인·유저 스킬도 감쌀 수 있다
/gritive:review-forever --max-passes 3           → 첫 인자가 플래그면 기본 스킬 + 플래그로 해석
```

**첫 인자가 `--`로 시작하지 않으면 리뷰 스킬 이름이다.** `--`로 시작하면 스킬 이름이 생략된 것이므로
기본 스킬을 쓴다. 스킬 이름 뒤의 나머지 인자는 **감싼 스킬에 그대로 넘긴다.** 단 `--max-passes N`은
루프가 소비한다 — 모르는 플래그를 받으면 중단하는 스킬이 있다.

## 기본 스킬은 gstack의 `review`다

인자가 없으면 `review`를 호출한다. **이 이름은 Claude Code 내장 `review`가 아니라 gstack의 `review`로
해석된다** — personal 스킬이 bundled 스킬을 덮어쓰기 때문이다. 이는 의도된 것이다. gstack `review`는
작업 중인 diff(워킹트리 포함)를 보므로 이 루프에 맞는다.

내장 스킬을 명시적으로 쓰려면 이름을 직접 준다 — `code-review`(작업 중인 diff).

## 스킬 이름 해석

- **이 스킬 자신** — `/gritive:review-forever`다. 접두사 없는 `/review-forever`는 user space
  (`~/.claude/skills/review-forever/`)의 **다른 스킬**이며 아래 수렴 안전장치가 없다.
  문서·안내·자기 참조에서 항상 접두사를 붙인다
- **gritive 플러그인 스킬** — `gritive:` 접두사를 붙여 호출한다. 사용자가 `codebase-review`로 써도
  호출은 `gritive:codebase-review`다
- **다른 플러그인 스킬** — 그 플러그인의 접두사가 필요하다. 접두사는 **사용 가능한 스킬 목록에서
  확인한 것만 쓴다.** 못 찾으면 중단한다
- **내장·유저 스킬** — 접두사가 없다

인자로 받은 이름이 리뷰/평가 워크플로가 아니거나 존재하지 않으면 **중단하고 그 사실을 알린다.**

## 감쌀 수 없는 것 — `full` 스캔

루프에는 base 대비 변경 범위가 필요하다. 실행 큐가 "이 변경이 유발한 것"과 "원래 있던 것"의 경계에서
나오기 때문이다. `codebase-review full`처럼 그 경계가 없는 전체 스캔을 주면 **중단하고 안내한다**:
전체 스캔은 `/gritive:codebase-review full`로 한 번 돌리고, 그 리포트에서 고칠 것을 정한 뒤,
그 변경분에 대해 이 루프를 돌리면 된다.

