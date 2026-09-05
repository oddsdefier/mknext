#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

# install.sh and update.sh clone the newest release tag. A hardcoded commit or
# checksum would go stale, because no release step writes one.
if grep -qE 'MKNEXT_RELEASE_REF|MKNEXT_SOURCE_SHA256' install.sh versions.env lib/commands/update.sh; then
  printf 'FAIL: a hardcoded release commit or checksum came back\n' >&2
  exit 1
fi

# These files ship to generated projects and stay in use here. Keep one copy.
shared_files=(
  scripts/git-hooks/config.sh
  scripts/git-hooks/lib.sh
  scripts/git-hooks/commit-msg.sh
  scripts/git-hooks/pre-push.sh
  .husky/commit-msg
  .husky/pre-push
  .github/pull_request_template.md
  .github/workflows/pr-governance.yml
  .github/workflows/strip-ai-pr-body.yml
)
for file in "${shared_files[@]}"; do
  cmp -s "templates/$file" "$file" || {
    printf 'FAIL: templates/%s and %s are different\n' "$file" "$file" >&2
    exit 1
  }
done

if command -v shellcheck >/dev/null 2>&1; then
  mapfile -t scripts < <(git ls-files '*.sh' bin/mknext)
  shellcheck --severity=warning --external-sources "${scripts[@]}" || {
    printf 'FAIL: shellcheck reported problems\n' >&2
    exit 1
  }
else
  printf 'SKIP: shellcheck is not installed\n'
fi

printf 'PASS: repository pins, shared files, and shell scripts are consistent\n'
