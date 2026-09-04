#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm"
check_log="$test_dir/checks.log"
: >"$check_log"

MKNEXT_CHECK_LOG="$check_log" \
  PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

rg -q '^pnpm dlx shadcn@4.20.1 init --base base --preset b24 --yes$' "$check_log"
rg -q '"style":"base-nova"' "$test_dir/app/components.json"

printf 'PASS: generated app uses the shadcn Base UI preset\n'
