# Gritive Plugin

코드베이스 종합 리뷰, 클린까지 반복하는 리뷰 루프, 페르소나 기반 UX 테스트, RFP 기반 프로젝트
부트스트랩 플러그인.

## Structure

- `agents/` — 6개 리뷰 에이전트 (arch, refactor, deadcode, perf, security, frontend)
- `skills/codebase-review/` — 에이전트 오케스트레이션 스킬
- `skills/review-forever/` — 리뷰 스킬을 감싸 **실행 큐가 빌 때까지** 반복하는 루프 (자체 리뷰 로직 없음)
- `skills/persona-test/` — 페르소나 기반 서비스 테스트 스킬
- `skills/project/` — RFP → PRD·이슈 부트스트랩 + 백로그 자율 처리 (6개 서브커맨드 라우터: setup/prd-to-issue/sync/gap/build/loop).
  `build`는 세 파일이다: `build.md`(오케스트레이터 — 선정·자격증명/question 이슈·머지),
  `build-issue.md`(subagent — split·Coverage Plan·구현·검증·Audit), `ship-pr.md`(subagent —
  `/ship` 호출로 커밋·리뷰·PR). 긴 세션에서 지침이 유실되므로 이슈마다 fresh subagent에 위임한다 —
  아래 "긴 세션에서의 지침 유실" 참조.
  **`ship-pr.md`(9.5단계)의 목적은 PR이 아니라 리뷰다.** `/ship`의 pre-landing review와 adversarial
  review가 이 루프의 **유일한 PR 전 코드 리뷰**이고, 10단계 land-and-deploy의 inline review는 그
  뒤의 두 번째 겹이다. 오케스트레이터가 `gh pr create`를 직접 치면 앞 겹이 통째로 사라진다 —
  실측으로 재현됐다(개정 전 baseline 3/3이 ship을 부르지 않고 PR을 직접 만들었다). 이 위임을
  "diff가 작으니까"로 우회 가능하게 만들지 마라.
  **인터랙션 규약의 정본은 `setup.md` 6단계 하나다** — `sync.md` 4단계는 그 표를 복제하지 않고 읽어서
  쓴다. `build-issue.md`·`gap.md`는 규약 절의 **존재**를 조건으로 삼으므로, 조건이 거짓일 때 조용히
  넘어가지 않고 "`/project sync` 필요"를 보고하는 분기를 반드시 유지한다 — 그 분기가 없으면 규약이
  없는 프로젝트에서 Storybook 정본 story backfill이 영영 발동하지 않는다(실측으로 재현됨)
- `scripts/push.sh` — 버전 bump + push (`git release` alias)
- `.claude-plugin/` — Claude Code용 `plugin.json` + `marketplace.json`
- `.codex-plugin/` — Codex용 `plugin.json`
- `.agents/plugins/marketplace.json` — Codex용 marketplace 등록 정보
- 버전은 `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`에
  따로 있으므로 항상 함께 bump

`skills/project/`는 `~/.claude/skills/prototype`(user space)에서 가져온 사본이다. 원본은 그대로
남아 있으므로 **양쪽이 갈라진다.** 한쪽만 고치고 동기화됐다고 가정하지 마라.

`skills/review-forever/`는 `~/.claude/skills/review-forever`(user space 스킬. gstack 트리 안에 있지
않다)에서 가져왔지만 **사본이 아니다.** codex/agy 폴백을 걷어냈고, 원본에 없던 수렴 안전장치(패스
상한, 실행 큐 기반 정체 감지, 발견 동일성 키, "중단 ≠ 발견 0건" 구분)를 넣었다. 원본과 동기화할
대상이 아니다.

**모든 판정은 원시 발견 수가 아니라 실행 큐로 잰다** — `발견 − 범위 밖 레거시 − 기각한 오탐 − 보류`.
감싼 리뷰 스킬은 패스 간 기억이 없어서 고치지 않기로 한 것을 매 패스 다시 보고하므로, 원시 발견 수로
완료·정체를 재면 루프가 지시를 완벽히 따르고도 영영 끝나지 않는다. 이 스킬을 고칠 때 이 불변식을
깨지 마라 — 리뷰 3회에 걸쳐 이 자리에서만 CRITICAL이 네 번 나왔다.

**이름이 원본과 충돌한다 — 접두사가 유일한 방어선이다.** 이 스킬은 `gritive:review-forever`이고,
접두사 없는 `/review-forever`는 **원본**(안전장치 없음)으로 간다. `prototype`을 `project`로 개명해
충돌을 피했던 것과 달리 여기서는 이름을 유지했으므로, **문서·안내·자기 참조에서 접두사를 절대
빠뜨리면 안 된다.** 빠뜨리면 사용자는 우리가 약속한 안전장치가 없는 루프를 돌리게 된다.

**기본 리뷰 스킬은 gstack의 `review`다.** personal 스킬이 bundled를 덮어쓰므로 `review`는 Claude Code
내장 review가 아니라 gstack 것으로 해석된다. 이는 의도된 선택이다 — 착각이 아니라 결정이므로
"내장 review로 고쳐야 한다"고 되돌리지 마라.

## Output Contract

**리뷰·테스트 스킬(`codebase-review`, `persona-test`)은 대상 프로젝트에 산출물(파일)을 남기지 않는다.**
리포트는 대화로 출력하고, 스크린샷·로그는 세션 임시 디렉토리에 둔다. 파일로 저장하는 것은 사용자가
명시적으로 요청할 때, **사용자가 지정한 경로에만** 한다. 스킬 이름을 딴 디렉토리를 대상 저장소에
만들지 않는다.

'산출물'은 리뷰/테스트의 **부산물(스크린샷·로그·리포트 파일)**이다. **`persona-test`는 코드를 직접
고치지 않는다** — 발견을 `gap`과 똑같이 **이슈로 등록한다**(이슈 관리 방식이 있으면; 없으면 리포트로
폴백). GitHub 이슈는 저장소에 남는 파일이 아니고 이 스킬의 결과물이므로 위 규칙의 대상이 아니다.
persona-test의 `plugin` 인터페이스가 hook을 띄우려고 파일을 고치는 것은 테스트 조작이므로 허용하되 원복한다.

**`review-forever`는 코드를 고친다.** 이것이 그 스킬의 본업이므로 위 규칙과 충돌하지 않는다 —
수정은 결과물이지 부산물이 아니다. 다만 패스별 리포트·로그는 부산물이므로 대화로만 출력하고,
`review-forever/` 같은 디렉토리를 대상 저장소에 만들지 않는다. 리뷰 에이전트가 읽기 전용인 것과
루프가 수정하는 것은 층이 다르다: **에이전트가 찾고, 루프가 고친다.**

`project`는 대상이 아니다 — PRD·design-guide·IA·research 노트(`docs/research/*.md`)·CLAUDE.md·README·
이슈·PR을 만드는 것이 이 스킬의 **본업**이다. PRD가 인용하는 근거 문서이므로 research 노트도 산출물이
아니라 결과물이다. `project gap`은 실행 가능한 gap을 **이 프로젝트의 이슈 관리 방식에 따라 이슈로
등록한다** — 이슈는 이 스킬의 본업이므로 산출물이 아니다. 이슈 관리 방식이 없을 때만 리포트로 폴백하며,
이때의 분석 리포트는 부산물이므로 파일로 남기려면 사용자에게 먼저 확인한다(`gap.md`의 완료 보고 참조).

`project loop`는 자체 로직 없이 `build`→`gap`→`build`→`persona-test`→`build`를 **새 빌드가능 이슈가
안 나올 때까지** 반복하는 오케스트레이터다. `review-forever`와 같은 수렴 불변식을 쓴다: **완료·정체를
원시 발견 수가 아니라 "새로 만든 빌드가능 이슈"(= gap+persona 이슈 − 중복 − 제외 클래스[`question`·
`credential`·에픽·blocked])로 잰다.** 이 불변식을 깨면 gap/persona가 매 라운드 같은 것을 다시 발견해
루프가 영영 끝나지 않는다. build가 중단 조건으로 멈추면 gap/persona로 넘어가지 말고 **루프도 멈춘다**
(중단 ≠ 수렴). persona가 서비스 기동 실패로 안 돈 라운드의 "발견 0"은 **수렴 신호가 아니다.**
`build`의 `--demo`/데모 모드/demo-debt는 제거됐다 — build는 항상 production 깊이다.

### 이 파일은 배포되지 않는다

**플러그인 루트의 CLAUDE.md는 사용자 프로젝트에 컨텍스트로 로드되지 않는다.** 플러그인은
skills / agents / hooks 로만 컨텍스트를 기여하고, `plugin.json`에는 공통 지시문을 싣는 필드가 없다
([공식 문서](https://code.claude.com/docs/en/plugins-reference#file-locations-reference)).

즉 여기 쓴 규칙은 **이 저장소를 개발할 때만** 유효하다. 런타임에 실제로 강제하려면 규칙을 각
`skills/*/SKILL.md`(또는 `agents/*.md`)에 **복제해야 한다.** 위 Output Contract도 그래서 세 스킬
문서에 각각 들어가 있다. 새 공통 규칙을 만들 때는 반드시 배포되는 문서에도 넣어라 — 여기에만
쓰면 아무 효력이 없다.

## Agent Contract

리뷰 에이전트 공통 규칙:

- 모든 에이전트는 프롬프트에서 `mode` (base-diff/full), `scope` (backend/frontend/all),
  `base` (git diff에 넘길 리뷰 기준 인자), `files` (대상 파일 목록, base-diff일 때만)를 받는다
- `files`는 **파일 목록이지 diff가 아니다.** 변경 내용이 필요하면 `git diff {base} -- {files}`로 본다.
  리뷰 단위는 '변경된 파일' 전체이지 '변경된 라인'이 아니다
- **기본은 `base-diff`다.** 전체 코드베이스 스캔은 `mode=full`일 때만 한다
- `base-diff`에서 발견 사항은 `files` 안에 위치해야 한다. 문맥 파악을 위해 코드베이스 전체를
  읽는 것은 허용된다 — **읽는 범위 ≠ 보고 범위**
- `files`가 비면 "대상 없음"으로 종료한다. **전체 스캔으로 폴백하지 않는다**
- `scope`는 스킬이 `files`를 필터링할 때만 쓴다. 에이전트가 `scope`를 하드 게이트로 재검사하면
  `--domain` 강제 호출과 충돌하므로 그렇게 하지 않는다
- 시작 시 반드시 프로젝트의 CLAUDE.md를 읽고 규칙을 반영한다
- 심각도 체계: CRITICAL / HIGH / MEDIUM / LOW
- 코드 수정은 하지 않는다 — 발견 사항만 보고한다
- **대상 프로젝트에 파일을 쓰지 않는다** — 리포트는 응답 텍스트로만 돌려준다. 에이전트는 `Bash`를
  갖고 있으므로 "코드 수정 금지"만으로는 리포트 파일 쓰기가 막히지 않는다. 위 Output Contract 참조
- 출력은 구조화된 마크다운 테이블 형식이다

전역 그래프가 필요한 항목(순환 의존, 번들 크기, 미사용 의존성, 고아 파일 전수조사 등)은
각 에이전트가 `base-diff` 모드에서의 축소 규칙을 자기 파일에 정의한다.

**계약의 유일한 예외**: `deadcode-reviewer`는 이 변경이 마지막 호출을 제거해 고아가 된 심볼을
`files` 밖이어도 보고한다 (근거 명시 필수, **1홉까지만**). SKILL.md의 Phase 4 검증도 이 예외를
살려둔다 — 그러지 않으면 예외가 리포트 단계에서 죽는다.

## Development

에이전트 추가/수정 시:

- `agents/` 디렉토리에 `.md` 파일 생성
- frontmatter에 `name`, `description`, `effort`, `tools` 포함. `tools`는 **콤마 구분 문자열**이다
  (`tools: Read, Grep, Glob, Bash`). YAML 배열은 `.md` 에이전트의 문서화된 형식이 아니다
- **`model`은 명시하지 않는다** — 기본값 `inherit`으로 세션 모델을 상속한다. `model: sonnet`으로
  고정하면 Opus 세션에서도 전원 Sonnet으로 강등된다. 리뷰 깊이는 모델 등급이 아니라 `effort`로
  차등한다 (`security`/`arch` = `high`, 나머지 = `medium`). 비용·품질은 사용자가 세션 모델로 제어한다
- 플러그인 에이전트는 `hooks` / `mcpServers` / `permissionMode`를 **지원하지 않는다**
  ([plugins-reference](https://code.claude.com/docs/en/plugins-reference#agents)). 읽기 전용 강제를
  hook으로 거는 방법은 쓸 수 없으므로, "파일 쓰기 금지"는 프롬프트 규약으로만 유지된다
- **스킬에서 호출할 때는 `subagent_type="gritive:<name>"`으로 플러그인 이름을 접두사로 붙인다.**
  접두사 없이 `arch-reviewer`로 부르면 `Agent type not found`로 실패한다
- 에이전트 정의를 고쳐도 **실행 중인 세션에는 반영되지 않는다.** 세션은 설치된 사본
  (`~/.claude/plugins/cache/`)을 쓴다. 실제 동작 확인은 플러그인 업데이트 후에 해야 한다
- 공통 인터페이스 계약 준수 (mode/scope/base/files, CLAUDE.md 로딩, 심각도 통일, 읽기 전용, 테이블 출력)
- 전역 스캔이 필요한 점검 항목이 있으면 `base-diff` 모드에서의 축소 규칙을 반드시 명시
- `codebase-review/SKILL.md`의 도메인 테이블에 추가

## 문서가 커지는 이유와 줄이는 법

스킬 문서는 **정책축 × 절축의 곱**으로 부푼다. 정책 하나를 추가하면 원칙·전용 절·해당 단계·중단
조건·완료 보고·Rationalization Table에 각각 한 번씩 들어가 한 줄이 아니라 **한 열**이 늘어난다.
실측: 압축 전 `build.md`에서 자격 증명·고객 협의 정책이 9개 절에 47회 재진술됐다.

세 가지 규칙으로 막는다:

- **정책마다 정본 절을 하나 정하고 다른 절은 그것을 가리킨다.** 인터랙션 규약(`setup.md` 6단계),
  자격 증명·고객 협의(오케스트레이터 쪽은 `build.md`의 전용 절, 전문은 `build-issue.md`)가 그 예다.
- **중단 조건·검사 목록은 그것을 직접 관측하는 액터의 문서에만 둔다.** 오케스트레이터는 subagent가
  `stopped`를 돌려준 것을 볼 뿐 그 조건을 직접 재지 않으므로, 목록을 복제하면 죽은 사본이 된다.
- **평행 구조 두 블록은 공통 절차 + 차이 표로 접는다.** `build.md` 9단계의 자격 증명 이슈·협의 이슈가
  그 사례다(392→250단어, 동작 회귀 없음).

**줄이기 전에 반드시 baseline을 잰다.** 장황함의 일부는 실측으로 얻어낸 것이고 일부는 그냥 쌓인
것인데, 문서만 봐서는 구분되지 않는다. 시나리오를 subagent에 돌려 준수율을 재고, 압축 후 같은
시나리오로 회귀를 확인한다 — 이것이 writing-skills의 REFACTOR 국면이다. 실제로 이 방법으로
"두 겹 리뷰" Rationalization 행이 10단계 본문과 중복임을 확인해 삭제했다(삭제 후 3/3 유지).

## 긴 세션에서의 지침 유실 (`project build`, `project loop`)

`build`가 한 세션에서 이슈를 연달아 처리하면 **컨텍스트가 길어질수록 지침 준수도가 무너진다.**
실측: 깨끗한 컨텍스트에서 split을 시키면 원 이슈의 `## 참조`(design-guide 링크)를 3/3 상속하지만,
실제 burndown 기록에서는 `## 참조` 상속이 **0/15**였고 서브이슈 본문이 시간순으로 581바이트 →
72바이트까지 단조 감소했다. 얇은 이슈 → 얇은 Coverage Plan → 얇은 구현 → Audit은 그 얇은 R1..Rn만
검사하므로 정상 통과한다.

그래서 `build.md` 3.5단계가 이슈마다 fresh subagent에 `build-issue.md`를 위임한다. **이 위임을
"작은 이슈니까"로 우회 가능하게 만들지 마라** — 본문이 72바이트로 줄어든 이슈들도 그때는 작아 보였다.

**세 파일은 역할로 갈렸지 중복이 아니다.** 자격 증명·고객 협의 정책의 전문은 `build-issue.md`에
있고(구현하는 쪽이 쓴다), `build.md`에는 선정에 필요한 요약만 있다. `ship-pr.md`에는 `/ship`의
질문 처리 정책이 있다. Rationalization Table도 14(오케스트레이터)/8(`build-issue`)/7(`ship-pr`)로
갈라 세 파일에 나눠 뒀다 — **같은 행을 양쪽에 두지 마라.** 오케스트레이터 쪽 행은 "위임할지"를,
subagent 쪽 행은 "위임받고 무엇을 할지"를 다룬다.

**`loop`도 같은 처방을 쓴다 — 다만 이번엔 `build`가 아니라 loop 세션 자신이 가장 오래 산다.** loop은
라운드마다 build 오케스트레이터 + gap 등록 + persona 전체를 인라인으로 호스팅하므로 세션이 build보다도
길어진다. 그래서 `loop.md` Phase B·C는 gap·persona-test를 **라운드마다 fresh subagent에 위임**하고(build가
이슈마다 위임하는 것과 같은 이유), loop 세션은 dispatch와 큐 회계만 한다. gap은 이미 `gap.md` 2단계에서
분석을 자기 subagent에 위임하므로, loop이 gap을 감싸면 **중첩 dispatch**가 된다 — `gap.md` 2단계에 "이미
fresh subagent면 내부 dispatch 생략" 분기를 두어 이를 막았다. 이 위임을 "가벼운 라운드니까"로 우회
가능하게 만들지 마라 — build에서 반증된 판단이다.
