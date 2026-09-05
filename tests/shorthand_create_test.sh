#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm"
PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" "$test_dir/short-app" --mode autonomous --yes --quiet

dry_run_output=$(PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/dry-app" --dry-run --quiet)

if [[ ! -f "$test_dir/short-app/.mknext" ]]; then
  printf 'FAIL: short create form did not create the app\n' >&2
  exit 1
fi

[[ -f "$test_dir/short-app/AGENTS.md" ]]
[[ -f "$test_dir/short-app/CLAUDE.md" ]]
grep -q 'ASD-STE100' "$test_dir/short-app/AGENTS.md"
grep -q '@AGENTS.md' "$test_dir/short-app/CLAUDE.md"
[[ -x "$test_dir/short-app/scripts/git-hooks/commit-msg.sh" ]]
[[ -x "$test_dir/short-app/scripts/git-hooks/pre-push.sh" ]]
[[ -x "$test_dir/short-app/.husky/pre-push" ]]

rg -q '^DRY RUN 20/20 ' <<<"$dry_run_output"

mkdir -p "$test_dir/existing"
if PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" create --name "$test_dir/missing/../existing" --yes --quiet 2>/dev/null; then
  printf 'FAIL: canonical target collision was not rejected\n' >&2
  exit 1
fi

if MKNEXT_FAKE_OXFMT_FAIL=1 PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/rollback-app" --yes --quiet 2>/dev/null; then
  printf 'FAIL: failed creation was accepted\n' >&2
  exit 1
fi
[[ ! -e "$test_dir/rollback-app" ]] || {
  printf 'FAIL: failed creation left a target behind\n' >&2
  exit 1
}
compgen -G "$test_dir/rollback-app.mknext.*" >/dev/null && {
  printf 'FAIL: failed creation left a staging directory\n' >&2
  exit 1
}

printf 'PASS: project creation rejects collisions and rolls back failures\n'
