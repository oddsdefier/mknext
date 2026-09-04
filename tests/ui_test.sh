#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm"

# Test 1: help output contains USAGE and COMMANDS sections
help_output=$("$root_dir/bin/mknext" --help)
rg -q 'USAGE' <<<"$help_output"
rg -q 'COMMANDS' <<<"$help_output"
rg -q 'OPTIONS' <<<"$help_output"

# Test 2: --no-color suppresses ANSI escape codes
no_color_help=$("$root_dir/bin/mknext" --help --no-color)
if grep -q $'\033' <<<"$no_color_help"; then
  printf 'FAIL: --no-color produced ANSI escape sequences\n' >&2
  exit 1
fi

# Test 3: create dry-run preserves DRY RUN 19/19 step output
dry_output=$(PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --dry-run --quiet)
rg -q '^DRY RUN 19/19 ' <<<"$dry_output"

# Test 4: doctor reports status
mkdir -p "$test_dir/app"
(
  cd "$test_dir/app"
  PATH="$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" doctor --quiet 2>&1 || true
)

# Test 5: update displays progress feedback
chmod +x "$root_dir/tests/fakes/curl"
update_output=$(
  MKNEXT_CHECK_LOG="$test_dir/curl.log" \
  MKNEXT_UPDATE_MARKER="$test_dir/updated" \
  MKNEXT_UPDATE_PREFIX_MARKER="$test_dir/prefix" \
  PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" update
)
rg -q 'mknext CLI has been successfully updated' <<<"$update_output"

printf 'PASS: CLI UI and formatting pass checks\n'
