# 리뷰 게이트 — 실행·상태값·발견 처리·PR 생성

`build.md` 9.5단계에서 읽고 수행한다. **이 문서가 리뷰 게이트의 유일한 정의다** — 실행 여부, 상태값,
발견 처리, 패스 예산, PR 본문이 전부 여기 있다. `<base>`는 `build.md` 0단계가 확정한 base branch다.

`--skip-review`이면 리뷰를 호출하지 않고 `gate_status`를 `skipped`로 두며, PR 본문과 완료 보고에
`skipped (--skip-review)`를 기록한다. 구현 검증·CI와 다른 중단 조건은 어느 경로에서도 유지한다.

**그 밖에는 이 세션이 리뷰어를 직접 dispatch한다 — `gritive:codebase-review` 스킬을 거치지 않는다.**
리뷰어를 이 세션의 **자식으로 직접** 띄운다. 코드 본문과 diff는 자식 컨텍스트에서 끝나고 이 세션에는
발견 목록만 들어온다.

1. 리뷰 대상 파일을 수집한다.

```bash
cd "$(git rev-parse --show-toplevel)"
git diff --name-only --diff-filter=d origin/<base>...HEAD
```

   **명령의 종료 상태를 확인한다.** 0이 아니면(얕은 클론, merge base 부재 등) 목록이 비어 있어도
   대상 없음이 아니다 — `review_status`를 `aborted (리뷰 대상 수집 실패: <명령 출력>)`로 두고 7번으로
   간다. 종료 상태가 0이고 목록이 비었을 때만 `no-target`으로 두고 7번으로 간다.
   **목록이 500개를 넘으면** 그대로 띄우지 않는다 — `review_status`를 `aborted (리뷰 대상 과다: <개수>)`로
   두고 7번으로 간다. 이 경우 `aborted`의 재시도(같은 명령을 다시 돌림)는 같은 결과를 내므로,
   `gate_status` 표대로 두 번째 `aborted`에서 중단하고 사용자에게 범위 축소를 보고한다.

2. backend·frontend·security 리뷰어를 **한 메시지에서 동시에** dispatch한다. Agent 툴에는
   `description`·`subagent_type`·`prompt`만 주고 `name`은 주지 않는다. dispatch는 비동기이므로
   **세 도메인의 완료 알림을 전부 받은 뒤에** 3번으로 간다 — 스폰 호출의 반환값은 리포트가 아니다.
   `../../codebase-review/SKILL.md`의 Phase 3에서 **가져오는 것은 dispatch 프롬프트 양식, 범위 계약,
   반환(리포트) 규약뿐이다.** **Phase 1의 신호 게이팅 표는 적용하지 않는다** — 프론트엔드 파일이
   0개여도 frontend를 띄운다. 그 스킬에서 `--domain`으로 강제 호출한 도메인을 게이팅하지 않는 것과
   같은 취급이고, 게이팅을 적용하면 3번이 안 띄운 도메인을 무응답으로 세어 멀쩡한 이슈에서 루프가
   멈춘다. 리뷰어 지침 문서는 `../../codebase-review/reviewers/backend.md`·`frontend.md`·`security.md`이고
   경로를 그대로 넘긴다. `mode: base-diff`, `base: origin/<base>...HEAD`, `files:`는 1번의 목록이다.
3. 리뷰어별 반환을 모아 `review_status`를 확정한다. 전부 리포트를 반환했으면 `ran`. 하나라도 반환하지
   않았으면 `aborted (리뷰어 무응답: <도메인>)`.
4. `ran`이면 범위 안 발견을 확정한다. **이 최초 큐가 재검증 대상으로 고정된다.** 보류와 범위 밖
   발견은 수정 큐에서 제외하되 기록한다.
   **보류(`held`)는 `../hard-gates.md`의 결정이 필요한 발견만이다.** 이 루프는 사람에게 물을 수 없으므로
   "판단이 어렵다"는 보류 사유가 아니다 — 심각도가 높든 낮든 그 밖의 모든 범위 안 발견은 수정 큐에
   들어간다.
5. 큐의 발견을 우선순위대로 수정한다. 수정마다 관련 lint·build·test를 실행하고 논리 단위로 커밋한다.
6. 고정한 큐를 재검증한다. **수정→재검증은 최대 2패스다.** 2패스를 돌고도 남은 발견은 조건 없이
   `unresolved`로 두고, 후속 이슈(`../followup-issues.md`의 `리뷰 잔여`)로 넘기고 진행한다 —
   2패스째가 또 수정을 불러도 그 수정은 하지 않고 `unresolved`로 떨어뜨린다.
   **중단은 재검증 명령 자체가 실패했을 때만이다**(lint·build·test 오류로 재검증을 끝내지 못한 경우.
   자동 진행 중단 조건).
7. 아래 항목을 채워 이 단계의 판정 근거로 삼는다(PR 본문·완료 보고가 이것을 인용한다).

| 필드 | 내용 |
| --- | --- |
| `review_status` | 원시 상태 `ran`, `no-target`, `aborted` |
| `gate_status` | `skipped`, `no-target`, `aborted`, `completed` |
| `queue_by_pass` | 최초 큐 → 재검증 후 큐 |
| `unresolved` | 2패스 뒤 남은 발견의 심각도·파일·요지 |
| `held` | 보류 발견 전문(`../hard-gates.md` 결정이 필요한 것만) |
| `out_of_scope` | 범위 밖 발견 전문 |
| `unverified` | 리뷰어 리포트의 `미검증 관찰` 절 전문 |
| `code_changed` | 리뷰 수정 여부 |
| `stop_reason` | 잔여가 있으면 `재리뷰 후 잔여`, 아니면 `없음` |

`gate_status`는 다음과 같이 확정한다.

| `gate_status` | 조건과 처리 |
| --- | --- |
| `skipped` | `--skip-review`일 때만. PR로 진행 |
| `no-target` | 리뷰 대상 파일 없음. 사유를 기록하고 PR로 진행 |
| `aborted` | 무응답 도메인만 한 번 다시 dispatch하고, 다시 무응답이면 중단 |
| `completed` | 원시 `ran`이 수정·재검증과 발견 등록까지 끝냈을 때만 전이. PR로 진행 |

리뷰가 코드를 고쳤으면 변경 파일의 자동 검증을 다시 실행한다.

**리뷰어가 리포트를 반환하지 않아 `aborted`가 나오면 그 사실을 완료 보고에 그대로 적는다.** 침묵은
무결함이 아니다 — "리뷰어가 조용했으니 깨끗하다"로 넘어가는 순간 게이트가 사라진다.

## 발견 처리

- `unresolved`와 `held`는 각각 후속 이슈로 등록하고 원 이슈·PR을 연결한다. 등록하면 merge를 진행한다.
- `out_of_scope`와 `unverified`는 새 이슈를 만들지 않고 PR 본문과 완료 보고에 전부 기록한다.
- **발견 자체는 진행을 막지 않는다.** 리뷰 미실행, 발견 등록 실패, 리뷰 수정 검증 실패가 진행을 막는다.
- 리뷰 뒤에 도착한 발견도 이 절이 처리한다 — 9단계가 "PR 전"이라는 것은 건너뛸 근거가 아니다.

## PR 생성

현재 이슈 범위의 커밋과 리뷰 수정만 포함됐는지 확인한다. PR 본문에는 다음을 기록한다.

- 원 이슈와 Coverage Audit 결과
- 검증 명령과 결과
- 리뷰 상태 또는 `skipped (--skip-review)`
- 수정·미해결·보류·범위 밖·미검증 관찰 발견
- 생성한 후속 이슈

Coverage Audit이 모두 `done`일 때만 `Closes #N`을 사용한다. 묶음이면 이슈마다 `Closes`를 적는다 —
변경이 같아서 요구 충족이 동시에 성립한다. 그 뒤 PR을 만들고 `build.md` 10단계로 간다.
