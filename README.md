# Gritive

코드베이스 종합 리뷰 및 페르소나 기반 UX 테스트를 위한 Claude Code 플러그인.

## Features

### Codebase Review (`/codebase-review`)

6개 전문 리뷰 에이전트를 병렬 실행하여 코드베이스를 종합 점검합니다.

| 도메인       | 에이전트            | 점검 항목                                     |
| ------------ | ------------------- | --------------------------------------------- |
| Architecture | `arch-reviewer`     | 계층 위반, 순환 의존, 관심사 분리, 모듈 구조  |
| Refactoring  | `refactor-reviewer` | 코드 중복, 복잡도, 코드 스멜, 네이밍          |
| Dead Code    | `deadcode-reviewer` | 미사용 함수, 고아 파일, 미사용 의존성         |
| Performance  | `perf-reviewer`     | N+1 쿼리, 메모리 릭, 번들 크기, 캐싱          |
| Security     | `security-reviewer` | 인증/인가, 입력 검증, 주입 공격, OWASP Top 10 |
| Frontend     | `frontend-reviewer` | 타입 안전성, 컴포넌트 품질, a11y, 상태 관리   |

```
/codebase-review                          # since-last (이력 없으면 전체), 6개 도메인
/codebase-review --full                   # 전체 코드베이스, 6개 도메인
/codebase-review backend                  # 백엔드만, Frontend 제외
/codebase-review frontend                 # 프론트엔드만
/codebase-review --domain perf,security   # 특정 도메인만
/codebase-review --changed                # 미커밋 변경분만
```

### Persona Test (`/persona-test`)

고객 페르소나를 정의하고 서비스를 고객처럼 사용하여 PMF와 사용성을 검증합니다.

- Web UI, CLI, MCP, API, Plugin 인터페이스 지원
- Bug / Friction / Gap / Delight 분류 체계
- 프로젝트별 페르소나를 CLAUDE.md에서 설정 가능

### Setup (`/setup`)

프로젝트를 분석하여 CLAUDE.md에 gritive 최적 설정을 자동 생성합니다.

```
/setup                # codebase-review + persona-test 전체 설정
/setup --review       # codebase-review 설정만
/setup --persona      # persona-test 설정만
```

## Installation

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add gritive/skills

# 2. 플러그인 설치
claude plugin install gritive
```

## Project Setup

### Codebase Review

별도 설정 없이 바로 사용 가능합니다. 프로젝트 CLAUDE.md에 아키텍처 규칙, 보안 원칙 등이 있으면 리뷰 에이전트가 자동으로 반영합니다.

### Persona Test

프로젝트 CLAUDE.md에 다음을 추가하면 최적의 결과를 얻을 수 있습니다:

```markdown
## Persona Test

- 인터페이스: web (http://localhost:3000), cli (`myapp` command)
- 테스트 계정: `docs/test-accounts.md` 참조
- 제품 스펙: `docs/PRODUCT_SPEC.md`
```

상세 설정 가이드: `skills/persona-test/references/claude-md-setup.md`

## Plugin Structure

```
gritive/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── arch-reviewer.md
│   ├── deadcode-reviewer.md
│   ├── frontend-reviewer.md
│   ├── perf-reviewer.md
│   ├── refactor-reviewer.md
│   └── security-reviewer.md
├── skills/
│   ├── codebase-review/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── claude-md-setup.md
│   ├── persona-test/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── claude-md-setup.md
│   │       └── persona-templates.md
│   └── setup/
│       └── SKILL.md
└── README.md
```

## Agent Interface Contract

모든 리뷰 에이전트는 공통 인터페이스를 따릅니다:

- `scope` 파라미터 수용 (`backend`, `frontend`, `all`)
- 시작 시 CLAUDE.md를 읽고 프로젝트 규칙 반영
- 통일된 심각도 체계: `CRITICAL` / `HIGH` / `MEDIUM` / `LOW`
- 구조화된 테이블 형식 출력
- 읽기 전용 (코드 수정 없음)

## Development

### 버전 관리

push 시 `plugin.json`의 patch 버전을 자동으로 올리려면 git alias를 설정합니다:

```bash
git config alias.release '!bash scripts/push.sh'
```

이후 `git push` 대신 `git release`를 사용하면 버전이 자동 bump됩니다:

```bash
git release          # 0.1.1 → 0.1.2 → ... 자동 bump 후 push
```

## License

MIT
