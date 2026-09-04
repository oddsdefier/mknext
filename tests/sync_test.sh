#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm" "$root_dir/tests/fakes/check-tool"

# Test 1: sync fails outside a project
if "$root_dir/bin/mknext" sync --quiet 2>/dev/null; then
  printf 'FAIL: sync should fail without .mknext marker\n' >&2
  exit 1
fi

# Create a sample project
PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

# Test 2: sync succeeds in a valid project
(
  cd "$test_dir/app"
  PATH="$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" sync --quiet
)

# Test 3: CI target validation fails on unknown target
(
  cd "$test_dir/app"
  if "$root_dir/bin/mknext" ci --ci invalid-ci --quiet 2>/dev/null; then
    printf 'FAIL: invalid CI target should fail\n' >&2
    exit 1
  fi
)

# Test 4: CI target github runs with fake tools
mkdir -p "$test_dir/app/node_modules/.bin" "$test_dir/bin"
for tool in knip oxlint oxfmt react-doctor vitest tsc; do
  cp "$root_dir/tests/fakes/check-tool" "$test_dir/app/node_modules/.bin/$tool"
done
cp "$root_dir/tests/fakes/check-tool" "$test_dir/bin/gitleaks"
check_log="$test_dir/ci-github.log"
: >"$check_log"

(
  cd "$test_dir/app"
  MKNEXT_CHECK_LOG="$check_log" \
    PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" ci --ci github --quiet
)

rg -q '^pnpm run build$' "$check_log"

printf 'PASS: mknext sync and extended ci targets pass checks\n'
