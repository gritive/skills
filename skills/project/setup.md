# project setup

`/project setup <RFP-path>` — RFP 한 장에서 프로젝트의 기획·기준 문서를 생성한다. 기존 스킬(`deep-research`, gap-analysis subagent)을 **오케스트레이션**한다. 연구 루프나 gap 분석을 여기서 재구현하지 않는다.

## 입력

- `<RFP-path>`: RFP 마크다운 경로(예: `docs/RFP.md`). 없으면 사용자에게 묻는다.

## 절차

### 1. RFP 읽기
- RFP를 Read로 읽고 도메인·목표·주요 요구·제약을 파악한다.

### 2. deep-research #1 — 도메인/시장/베스트프랙티스
- `deep-research` 스킬을 호출한다. research question 예: "{도메인} 서비스의 표준 기능 범위, 경쟁 제품, 데이터 모델 관례, 운영 워크플로우 베스트프랙티스는?"
- 결과를 `docs/research/domain-research.md`로 저장(디렉터리 없으면 생성).

### 3. 기술스택·툴체인 확정
- RFP가 스택을 명시하면(예: "SvelteKit 기반") 그대로 채택한다. 명시가 없거나 불완전하면 도메인·요구에 맞게 **결정**한다.
- 언어·프레임워크만이 아니라 이후 슬롯이 요구하는 세부까지 정한다: 패키지 매니저, ORM/DB, 마이그레이션·시드·테스트 명령 세트. 이 결정이 이후 `{{TECH_STACK}}`·`{{COMMANDS}}`·`{{GETTING_STARTED}}`와 4~5단계 research question의 `{기술스택}` 근거다.
- 언어가 Python이면(RFP가 다른 웹 프레임워크·ORM·패키지 매니저를 명시하지 않는 한) 웹 프레임워크는 FastAPI, ORM은 SQLAlchemy, 패키지 매니저는 uv를 기본값으로 채택한다.
- 언어가 Go이면(RFP가 다른 웹 프레임워크·ORM을 명시하지 않는 한) 웹 프레임워크는 Echo, ORM은 GORM을 기본값으로 채택한다.
- 언어가 JavaScript/TypeScript(Node.js)이면(RFP가 다른 프레임워크·ORM·패키지 매니저를 명시하지 않는 한) 프레임워크는 SvelteKit, ORM은 Drizzle, 패키지 매니저는 bun을 기본값으로 채택한다.

### 4. PRD 생성 또는 갱신 (`docs/prd.md`)
- RFP + research #1을 근거로 작성한다. 이미 `docs/prd.md`가 있으면 research 결과를 **반영(갱신)** 하되 기존 결정 이력을 보존한다.
- 필수 섹션 스켈레톤:
  1. 개요 (배경 / 목표 / 1차 범위 원칙)
  2. 사용자와 역할
  3. 기능 요구사항 (기능별 소절)
  4. 1차 범위 제외 (향후 검토)
  5. 비기능 요구사항
  6. 데이터 모델 개요
  7. 결정 사항 — 채택 스택(3단계)과 미확정 이슈(`Q1..Qn`)를 기록한다

### 5. deep-research #2 — 디자인/UX
- `deep-research`를 다시 호출한다. research question 예: "{제품 유형}의 데이터 테이블/폼/대시보드/RBAC UX 베스트프랙티스, {기술스택} 컴포넌트 매핑, WCAG AA 기준은?"
- 결과를 `docs/research/design-research.md`로 저장.

### 6. 디자인·UX 가이드 생성 (`docs/design-guide.md`)
- RFP + PRD + research #2로 작성. 각 근거에 신뢰도 표기(`[소스]` / `[검증]` / `[관례]` / `[PRD]`)를 단다.
- 필수 섹션 스켈레톤: 핵심 원칙 / 디자인 토큰 / 데이터 테이블 / 입력 폼 / 대시보드 / RBAC UX / 공통 상태(로딩·빈·오류) / 접근성 체크리스트 / 컴포넌트 인벤토리 / 출처.
- (선택) 메뉴·라우트가 복잡하면 `docs/ia.md`(사이트맵 / 메뉴 정의 / 역할별 진입 / 라우트 구조)도 생성한다.

### 7. gap 분석 (fresh-eye subagent)
- Agent 툴로 subagent 1회 dispatch. 프롬프트: "RFP와 PRD를 fresh eye로 읽고, RFP 요구 중 PRD가 누락·모호·상충하는 항목만 목록화하라. 각 항목에 RFP 근거 위치와 제안 보강안을 붙여라. 구현 얘기는 하지 마라."
- 결과를 받아 PRD를 보강한다(누락 요구 추가, 미확정 이슈를 `Q` 항목/결정 이력에 반영).

### 8. CLAUDE.md / README.md 생성
- `templates/CLAUDE.md.template`, `templates/README.md.template`을 Read로 읽는다.
- 공유 baseline은 그대로 두고 `{{…}}` 슬롯만 채운다:
  - `{{TECH_STACK}}`·`{{COMMANDS}}`·`{{GETTING_STARTED}}` ← 3단계 스택 결정. 예시 프로젝트 값을 그대로 박지 않는다.
  - `{{ARCHITECTURE_PROJECT_NOTES}}`·`{{PROJECT_STRUCTURE}}` ← PRD 데이터 모델(6장) + 채택 스택으로 실제 디렉터리 경로·모듈별 책임을 도출해 채운다(템플릿의 레이어 baseline 불릿 아래에 덧붙인다).
  - `{{IMPLEMENTATION_PROJECT_STANDARDS}}` ← PRD 비기능 요구(5장)·데이터 저장·인증·도메인 규칙 등 프로젝트 고유 기준.
  - `{{ISSUE_BOARD_TARGET}}` ← org/보드/마일스톤. 미정이면 사용자에게 확인.
  - `{{DOMAIN_GLOSSARY}}` ← PRD/RFP 도메인 용어.
- 공유 baseline 불릿(Clean Architecture 원칙 / God Object 방지 / 개발 원칙, 그리고 이슈 관리·Architecture·구현 기준의 baseline 불릿)은 템플릿 그대로 유지한다.
- RFP 경로가 `docs/RFP.md`가 아니면 README의 RFP 링크를 실제 경로로 치환한다(또는 RFP를 `docs/`로 배치한다).

### 9. 문서 라우팅 반영
- 실제 생성된 문서(prd / design-guide / ia 중 존재하는 것)만으로 CLAUDE.md "문서 라우팅" 표 행을 채운다. "충돌하면 구체 → 원문 순 우선" 규칙 문장을 유지한다.

## 완료 보고

- 생성/갱신한 파일 목록과 남은 미확정 이슈(`Q` 항목)를 요약한다.

## 순서 주의

- 8단계는 템플릿(`templates/*.template`)이 존재해야 동작한다. 스킬 최초 도입 시 템플릿이 없으면 실행자에게 알린다.
