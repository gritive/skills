# persona-test CLAUDE.md 설정 가이드

프로젝트 CLAUDE.md에 아래 설정을 둔다. 필수는 **인터페이스**와 **테스트 계정**이고, 페르소나·제품
스펙은 있으면 쓴다.

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

`persona-templates.md`의 표 양식대로 적는다.

### 제품 스펙

- `docs/PRODUCT_SPEC.md` — 제품 핵심 가치와 해결하는 문제
```
