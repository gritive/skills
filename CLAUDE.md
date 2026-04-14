# Gritive Plugin

코드베이스 종합 리뷰 및 페르소나 기반 UX 테스트 플러그인.

## Structure

- `agents/` — 6개 리뷰 에이전트 + 1개 독립형 에이전트
- `skills/codebase-review/` — 에이전트 오케스트레이션 스킬
- `skills/persona-test/` — 페르소나 기반 서비스 테스트 스킬

## Agent Contract

리뷰 에이전트 공통 규칙:
- 모든 에이전트는 `scope` (backend/frontend/all)을 프롬프트에서 받는다
- 시작 시 반드시 프로젝트의 CLAUDE.md를 읽고 규칙을 반영한다
- 심각도 체계: CRITICAL / HIGH / MEDIUM / LOW
- 코드 수정은 하지 않는다 — 발견 사항만 보고한다
- 출력은 구조화된 마크다운 테이블 형식이다

## Development

에이전트 추가/수정 시:
- `agents/` 디렉토리에 `.md` 파일 생성
- frontmatter에 `name`, `description`, `model`, `tools` 포함
- 공통 인터페이스 계약 준수 (scope, CLAUDE.md 로딩, 심각도 통일, 읽기 전용, 테이블 출력)
- `codebase-review/SKILL.md`의 도메인 테이블에 추가
