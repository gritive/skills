# Gritive Plugin

코드베이스 종합 리뷰 및 페르소나 기반 UX 테스트 플러그인.

## Structure

- `agents/` — 6개 리뷰 에이전트 (arch, refactor, deadcode, perf, security, frontend)
- `skills/codebase-review/` — 에이전트 오케스트레이션 스킬
- `skills/persona-test/` — 페르소나 기반 서비스 테스트 스킬

## Agent Contract

리뷰 에이전트 공통 규칙:
- 모든 에이전트는 프롬프트에서 `mode` (base-diff/full), `scope` (backend/frontend/all),
  `base` (리뷰 기준 revision), `files` (대상 파일 목록, base-diff일 때만)를 받는다
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
- 출력은 구조화된 마크다운 테이블 형식이다

전역 그래프가 필요한 항목(순환 의존, 번들 크기, 미사용 의존성, 고아 파일 전수조사 등)은
각 에이전트가 `base-diff` 모드에서의 축소 규칙을 자기 파일에 정의한다.

**계약의 유일한 예외**: `deadcode-reviewer`는 이 변경이 마지막 호출을 제거해 고아가 된 심볼을
`files` 밖이어도 보고한다 (근거 명시 필수, **1홉까지만**). SKILL.md의 Phase 4 검증도 이 예외를
살려둔다 — 그러지 않으면 예외가 리포트 단계에서 죽는다.

## Development

에이전트 추가/수정 시:
- `agents/` 디렉토리에 `.md` 파일 생성
- frontmatter에 `name`, `description`, `model`, `tools` 포함
- 공통 인터페이스 계약 준수 (mode/scope/files, CLAUDE.md 로딩, 심각도 통일, 읽기 전용, 테이블 출력)
- 전역 스캔이 필요한 점검 항목이 있으면 `base-diff` 모드에서의 축소 규칙을 반드시 명시
- `codebase-review/SKILL.md`의 도메인 테이블에 추가
