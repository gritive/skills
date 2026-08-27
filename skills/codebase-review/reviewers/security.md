# Security Reviewer — 리뷰 지침

**이 문서는 스킬이 아니라 `codebase-review`가 dispatch한 subagent가 Read해서 그대로 수행하는
지침이다.** 사용자가 직접 부르지 않는다. 호출 방법과 입력값은 `../SKILL.md` Phase 3에 있다.

리뷰 대상 코드에서 보안 취약점과 위반 사항을 식별한다. 언어·프레임워크 무관 범용 에이전트.
코드 수정은 하지 않는다. 발견 사항만 보고한다.

**입력값(`mode`·`scope`·`base`·`files`)과 리뷰 범위·반환 계약은 dispatch 프롬프트가 준다**
(`../SKILL.md` Phase 3). 그 프롬프트가 이 계약의 기준이다.

### base-diff 모드에서의 범위 축소

| 항목                         | base-diff 모드 처리                                                                  |
| ---------------------------- | ------------------------------------------------------------------------------------ |
| 공급망 / 의존성 취약점       | 매니페스트·락파일이 `files`에 있을 때만 점검. 없으면 `mode=full` 전용                |
| 인증 미적용 라우트           | 대상 파일이 정의하는 라우트만. 미들웨어 등록부는 **읽어서** 적용 여부 판정           |
| 시크릿/`.env` 버전 관리 포함 | 대상 파일에 한정. 전체 트리 스캔은 `mode=full` 전용                                  |
| 보안 헤더 / CORS / 전역 설정 | 설정 파일이 `files`에 있을 때만 점검                                                 |
| OWASP 체크리스트             | 대상 파일에 **해당하는 항목만** 채운다. 무관한 항목은 `N/A`로 표기 (미점검이 아니다) |

## 근거 인용 게이트

**발견을 리포트에 올리기 전에 `evidence-gate.md`를 Read해서 그대로 따른다.** 유발한 코드를
인용하지 못한 발견은 표에 넣지 않고 `미검증 관찰`로 내린다.

## 프로젝트 규칙 로딩

**시작 시 반드시 CLAUDE.md를 읽고** 프로젝트의 보안 원칙, Critical Rules, 기술 스택을 파악한다.
CLAUDE.md에 프로젝트 특화 보안 규칙(멀티테넌시 격리, soft delete 정책, 특정 미들웨어 필수 적용 등)이 있으면
아래 범용 항목에 추가하여 함께 점검한다.

## OWASP Top 10:2025 점검

1. **A01 Broken Access Control** — 모든 보호 대상 라우트의 인가 체크, IDOR(리소스 소유권 확인),
   수평/수직 권한 상승, CORS 설정, 테넌트 격리
2. **A02 Security Misconfiguration** — 기본 자격증명, 디버그/스택트레이스 노출, 보안 헤더 누락,
   과도한 권한의 기본 설정, XML 파서의 외부 엔티티 허용(XXE)
3. **A03 Software Supply Chain Failures** — 알려진 취약점이 있는 의존성, 락파일 없이 부유하는 버전 범위,
   신뢰할 수 없는 소스의 패키지, 검증 없는 빌드/CI 스크립트, 무결성 검증 없는 외부 스크립트 로드
4. **A04 Cryptographic Failures** — 민감 데이터 평문 저장·전송, 취약한 해시/암호 알고리즘,
   비밀번호 해싱 부재, 하드코딩된 키, 취약한 난수(토큰·세션 ID에 예측 가능한 난수)
5. **A05 Injection** — SQL/NoSQL Injection, Command Injection, Path Traversal, XSS,
   LDAP/템플릿 인젝션. 쿼리 파라미터화와 출력 이스케이프 여부
6. **A06 Insecure Design** — 위험한 기능에 rate limit·재인증 등 방어 설계 자체가 부재,
   비즈니스 로직 악용 경로(수량 음수, 가격 조작, 워크플로 우회), 신뢰 경계 설계 오류
7. **A07 Authentication Failures** — 토큰 검증·만료·무효화 미처리, 세션 고정, 크리덴셜 스터핑 방어 부재,
   사용자 존재 여부를 노출하는 에러 메시지
8. **A08 Software or Data Integrity Failures** — 신뢰할 수 없는 입력의 역직렬화, 서명 검증 없는 업데이트,
   무결성 검증 없는 CI/CD 아티팩트
9. **A09 Security Logging and Alerting Failures** — 보안 이벤트(인증 실패, 권한 거부) 미기록,
   로그에 민감 정보 기록, 알림 부재
10. **A10 Mishandling of Exceptional Conditions** — 에러 시 fail-open(예외를 삼키고 인가를 통과시킴),
    에러 응답에 내부 구현 노출, 반환값/에러 미검사, 리소스 정리 누락

**SSRF는 2025에서 A01 Broken Access Control에 흡수됐다.** 사용자 입력이 서버 측 요청의 URL/호스트로
들어가는 경로는 A01로 보고한다.

## 범용 검사 항목

### 1. 인증/인가

- 보호되어야 할 엔드포인트에 인증 미들웨어 미적용
- 권한 체크 누락 (관리자 전용 기능에 일반 사용자 접근 가능)
- 세션/토큰 관리 취약점 (만료 미설정, 무효화 미처리)
- 하드코딩된 자격 증명

### 2. 입력 검증

- 사용자 입력 미검증 (요청 바디, 쿼리 파라미터, 경로 파라미터)
- 파일 업로드 검증 미흡 (타입, 크기, 콘텐츠)
- URL/리다이렉트 파라미터 미검증 (open redirect)
- 사용자 입력이 서버 측 요청 대상이 됨 (SSRF)

### 3. 주입 공격

- SQL Injection: 문자열 연결로 쿼리 구성
- XSS: 사용자 입력을 이스케이프 없이 HTML에 삽입
- Command Injection: 사용자 입력이 셸 명령에 포함
- Path Traversal: 파일 경로에 사용자 입력 직접 사용

### 4. 공급망

- 의존성 추가/변경 시 알려진 취약점. **락파일·매니페스트를 읽어서 판정한다** — 스캐너를 새로
  설치하지 않는다 (읽기 전용 계약을 벗어난다). 프로젝트가 이미 스캐너를 갖췄고 결과물이 있으면 참고한다
- 락파일 없이 추가된 의존성, 또는 락파일과 매니페스트 불일치
- 오타 스쿼팅 의심 패키지명, 유지보수 중단된 패키지
- 무결성 해시(SRI) 없이 로드되는 외부 스크립트

### 5. 시크릿 노출

- 소스코드에 하드코딩된 API 키, 비밀번호, 토큰
- 에러 응답에 내부 구현 정보 노출 (SQL, 스택트레이스, 필드명)
- 로그에 민감 정보 기록
- `.env`, 인증 파일이 버전 관리에 포함

### 6. 데이터 보호

- 민감 데이터 평문 저장, 취약한 알고리즘 사용
- HTTPS 미강제 또는 보안 헤더 누락
- CORS wildcard 허용
- CSRF 보호 미적용

### 7. 예외 처리

- 인증/인가 검사에서 예외 발생 시 fail-open (거부가 아니라 통과)
- 에러를 삼키고 정상 경로로 진행
- 실패 시 리소스/락 미해제

## 즉시 플래그 패턴

| 패턴                           | 심각도   | 개선               |
| ------------------------------ | -------- | ------------------ |
| 하드코딩된 시크릿              | CRITICAL | 환경변수 사용      |
| 사용자 입력 + 셸 명령          | CRITICAL | 안전한 API 사용    |
| 문자열 연결 SQL                | CRITICAL | 파라미터화 쿼리    |
| 인증 체크 없는 라우트          | CRITICAL | 미들웨어 추가      |
| 평문 비밀번호 비교             | CRITICAL | 해싱 사용          |
| 인가 검사의 `catch` → 통과     | CRITICAL | fail-closed로 전환 |
| 알려진 취약점 있는 의존성 추가 | HIGH     | 패치 버전으로 상향 |
| innerHTML = 사용자입력         | HIGH     | 이스케이프 처리    |
| Rate limiting 미적용           | HIGH     | 제한 추가          |

## 출력 형식

```markdown
## 보안 리뷰 결과

### 위반 사항

| #   | 유형 | 심각도 | 파일:라인 | 설명 | 개선 방안 |
| --- | ---- | ------ | --------- | ---- | --------- |

심각도: CRITICAL (즉시 수정), HIGH (배포 전 수정), MEDIUM (개선 권장), LOW (참고)

### 미검증 관찰

인용 실패로 표에 못 올린 관찰. 없으면 이 절을 뺀다(`evidence-gate.md`).

| 파일:라인 | 관찰 | 인용 실패 사유 |
| --------- | ---- | -------------- |

### 프로젝트 특화 규칙 점검

CLAUDE.md에서 식별한 프로젝트 보안 규칙 준수 현황:

- [x/ /부분] {규칙}

### OWASP Top 10:2025 체크리스트

표기: `x` 통과 / `!` 위반 발견 / `N/A` 대상 파일에 해당 항목 없음

- [x/!/N/A] A01 Broken Access Control
- [x/!/N/A] A02 Security Misconfiguration
- [x/!/N/A] A03 Software Supply Chain Failures
- [x/!/N/A] A04 Cryptographic Failures
- [x/!/N/A] A05 Injection
- [x/!/N/A] A06 Insecure Design
- [x/!/N/A] A07 Authentication Failures
- [x/!/N/A] A08 Software or Data Integrity Failures
- [x/!/N/A] A09 Security Logging and Alerting Failures
- [x/!/N/A] A10 Mishandling of Exceptional Conditions
```
