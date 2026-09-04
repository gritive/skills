#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prd="$root_dir/skills/project/prd-to-issue.md"
build="$root_dir/skills/project/build.md"
scope="$root_dir/skills/project/references/issue-scope.md"
template="$root_dir/skills/project/templates/CLAUDE.md.template"

grep -q -- '--blocked-by' "$prd"
grep -q -- '--json blockedBy,blocking' "$build"
grep -q -- '--json parent,subIssues,blockedBy,blocking' "$scope"
grep -q 'GitHub native blocked-by' "$template"

if grep -q '## 의존' "$prd"; then
  echo 'prd-to-issue still writes dependencies in the issue body' >&2
  exit 1
fi

if grep -q '`## 의존`의 `선행:`' "$build"; then
  echo 'build still treats body metadata as the primary dependency source' >&2
  exit 1
fi
