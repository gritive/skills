# codebase-review CLAUDE.md 설정 가이드

codebase-review 스킬의 6개 에이전트는 프로젝트 CLAUDE.md를 읽고 프로젝트 특화 규칙을 반영합니다.
CLAUDE.md에 아래 설정을 추가하면 리뷰 정확도가 크게 향상됩니다.

## 최소 설정

```markdown
## Codebase Review

- 기술 스택: Go 1.22, SvelteKit 2, PostgreSQL 16
- 아키텍처: handler → service → repository 계층 구조
```

## 상세 설정

```markdown
## Codebase Review

### 기술 스택
- Backend: Go 1.22, Echo v4, sqlc
- Frontend: SvelteKit 2, TypeScript, TailwindCSS
- Database: PostgreSQL 16
- 테스트: Go testing, Vitest

### 아키텍처 원칙
- 계층: handler → service → repository (단방향 의존)
- handler에서 직접 DB 접근 금지
- 도메인 모델에 외부 의존성 침투 금지

### 보안 규칙
- 모든 API 엔드포인트에 인증 미들웨어 필수
- 멀티테넌시: 모든 쿼리에 workspace_id 필터링 필수
- soft delete 정책: 물리 삭제 사용 금지
- 시크릿은 환경변수로만 관리

### 코딩 규칙
- Go: 에러는 반드시 래핑하여 반환 (`fmt.Errorf("...: %w", err)`)
- Frontend: 컴포넌트 300줄 초과 금지
- 전역 상태 최소화, 서버 상태는 TanStack Query 사용
- any 타입 사용 금지

### 성능 규칙
- 목록 API에 페이지네이션 필수
- N+1 쿼리 금지 — JOIN 또는 Preload 사용
- 프론트엔드 번들 초기 로드 150KB 이하
```

## 에이전트별 활용

| 에이전트          | CLAUDE.md에서 읽는 정보                              |
| ----------------- | ---------------------------------------------------- |
| arch-reviewer     | 아키텍처 원칙, 계층 구조, 패키지 구조 규칙           |
| refactor-reviewer | 코딩 규칙, 네이밍 컨벤션, 프레임워크 패턴            |
| deadcode-reviewer | 기술 스택 (언어별 분석 도구 선택), 특수 진입점       |
| perf-reviewer     | 성능 규칙, DB 인덱스 요구사항, 번들 예산             |
| security-reviewer | 보안 규칙, 인증/인가 정책, 데이터 보호 요구사항      |
| frontend-reviewer | 프론트엔드 프레임워크, 컴포넌트 규칙, 상태 관리 패턴 |

## 팁

- **구체적일수록 좋다**: "코드 품질 유지" 보다 "함수 50줄 초과 금지, 중첩 4단계 초과 금지"
- **위반 시 심각도를 명시**: "workspace_id 필터링 누락은 CRITICAL"
- **프레임워크 패턴 명시**: "SvelteKit의 load 함수에서만 데이터 fetch"
- **예외 허용 시 조건 명시**: "벌크 처리 시 물리 삭제 허용 (관리자 API만)"
