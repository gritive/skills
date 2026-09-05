# Project V2 단건 상태 조회

후보 이슈나 상위 에픽 하나의 현재 상태가 필요할 때만 아래 GraphQL 조회를 쓴다. `OWNER`·`REPO`·`NUMBER`은 이미 확정한 값으로 바꾼다.

```bash
gh api graphql \
  -f query='query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        projectItems(first: 20) {
          nodes {
            id
            project { number }
            fieldValueByName(name: "Status") {
              ... on ProjectV2ItemFieldSingleSelectValue { name optionId }
            }
          }
        }
      }
    }
  }' \
  -F owner=OWNER -F repo=REPO -F number=NUMBER
```

응답에서 현재 대상 프로젝트 번호와 같은 node만 쓴다. node가 없으면 보드 미연결이며 Status는 없다. `fieldValueByName`이 null이면 Status 값 없음으로 취급한다. 이 조회는 후보 선정·착수 직전 refresh·연결 뒤·Status 변경 뒤에 실행한다.

## GraphQL rate limit 임시 우회

위 단건 조회가 `rate limit`이면, Browser/Chrome 제어가 가능한 현재 세션에서 로그인된 GitHub Project V2 UI로 같은 사실을 확인한다. 브라우저 제어 스킬의 선택·안전 규칙을 먼저 따른다.

1. 대상 보드의 현재 Board view에서 이슈 번호가 붙은 정확한 카드를 찾는다. 카드가 놓인 열 제목이 그 이슈의 `Status`다. 카드가 없으면 보드 미연결로 취급한다.
2. 후보와 각 상위 에픽을 각각 확인한다. 후보 자격은 `build.md` 2단계의 보드 상태 규칙을 적용한다. 착수 직전 refresh에서도 화면을 새로고침해 현재 상태를 확인한다. 카드·열을 확정할 수 없으면 상태를 추측하지 말고 중단한다.
3. 후보가 `Todo`거나 상태가 없을 때만 보드 연결 또는 `Status` 변경을 한다. 변경 뒤 같은 카드가 `In Progress` 열에 있는지 다시 확인한다.

이 우회는 GraphQL quota가 회복될 때까지의 상태 확인·변경 경로다. REST 이슈 목록은 열린 이슈와 본문·댓글의 기준으로 계속 사용하며, `gh project item-list` 전량 조회를 다시 도입하지 않는다.
