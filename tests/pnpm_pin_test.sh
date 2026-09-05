#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/corepack" "$root_dir/tests/fakes/pnpm"
check_log="$test_dir/checks.log"
: >"$check_log"

MKNEXT_CHECK_LOG="$check_log" \
  MKNEXT_EXPECT_PACKAGE_MANAGER=pnpm@12.3.1 \
  MKNEXT_FAKE_PNPM_VERSION=11.6.0 \
  PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

rg -q '^corepack prepare pnpm@12.3.1 --activate$' "$check_log"
rg -q '^pnpm dlx shadcn@\^4.20.1 init --preset b67ek3WsVs --template next --name app\.mknext\.[A-Za-z0-9]+ --yes$' "$check_log"
rg -q '^preset=b67ek3WsVs$' "$test_dir/app/.mknext"
rg -q '^minimumReleaseAge: 1440$' "$test_dir/app/pnpm-workspace.yaml"
rg -q '^minimumReleaseAgeStrict: false$' "$test_dir/app/pnpm-workspace.yaml"

printf 'PASS: create applies pnpm defaults before install\n'
