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

rg -q '^DRY RUN 19/19 ' <<<"$dry_run_output"

printf 'PASS: project name starts the create command\n'
