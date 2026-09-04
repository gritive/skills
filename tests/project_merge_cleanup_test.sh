#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="$root_dir/skills/project/build.md"

grep -Fq 'gh pr merge <N> --squash --delete-branch' "$build"
grep -Fq 'gh pr view <N> --json state,mergedAt' "$build"
grep -Fq 'git ls-remote --exit-code --heads origin <branch>' "$build"
grep -Fq 'exit 2만 원격 ref 없음' "$build"
grep -Fq 'git switch --detach' "$build"
grep -Fq 'git branch -D <branch>' "$build"
grep -Fq 'git show-ref --verify --quiet refs/heads/<branch>' "$build"
grep -Fq 'exit 1이어야 정리 성공' "$build"
grep -Fq 'worktree 디렉터리는 삭제하지 않는다' "$build"

if grep -Fq 'git worktree remove' "$build"; then
  echo 'merge flow must not remove the feature worktree' >&2
  exit 1
fi
