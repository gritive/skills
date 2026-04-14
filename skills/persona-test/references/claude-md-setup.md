# persona-test CLAUDE.md 설정 가이드

프로젝트에서 persona-test 스킬을 효과적으로 사용하려면, CLAUDE.md에 다음 설정을 추가하세요.

## 최소 설정

```markdown
## Persona Test

- 인터페이스: web (http://localhost:3000), cli (`myapp` command)
- 테스트 계정: `docs/test-accounts.md` 참조
- 제품 스펙: `docs/PRODUCT_SPEC.md`
```

## 상세 설정

```markdown
## Persona Test

### 인터페이스
| 인터페이스 | URL/명령어                | 확인 방법         |
| ---------- | ------------------------- | ----------------- |
| web        | http://localhost:3000     | lsof -i :3000     |
| cli        | myapp --version           | which myapp       |
| mcp        | myapp-mcp server          | MCP tool 호출     |
| api        | http://localhost:8080/api | curl health check |

### 테스트 계정
- 위치: `docs/test-accounts.md`
- 관리자: admin@test.com / test1234
- 일반 사용자: user@test.com / test1234

### 페르소나
| ID  | 이름        | 역할        | 업무 목표                | 시나리오             | 핵심 검증      |
| --- | ----------- | ----------- | ------------------------ | -------------------- | -------------- |
| P-1 | 신규 사용자 | 첫 방문자   | 회원가입 후 첫 작업 완료 | 가입→설정→첫 사용    | 온보딩 흐름    |
| P-2 | 파워유저    | 일상 사용자 | 일일 루틴 효율적 수행    | 로그인→주요작업→완료 | 반복 작업 효율 |
| P-3 | 관리자      | 팀 관리     | 현황 파악 및 의사결정    | 대시보드→확인→조치   | 정보 가시성    |

### 제품 스펙
- `docs/PRODUCT_SPEC.md` — 제품 핵심 가치와 해결하는 문제
```

## 필드 설명

| 필드        | 필수 | 설명                                           |
| ----------- | ---- | ---------------------------------------------- |
| 인터페이스  | O    | 테스트 가능한 인터페이스 목록과 접속 방법      |
| 테스트 계정 | O    | 계정 정보 파일 위치 또는 직접 기재             |
| 페르소나    | -    | 미리 정의된 페르소나. 없으면 스킬이 자동 제안  |
| 제품 스펙   | -    | 제품 문서 경로. 있으면 페르소나 제안 품질 향상 |
