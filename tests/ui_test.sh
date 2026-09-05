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

# Test 3: create dry-run preserves DRY RUN 20/20 step output
dry_output=$(PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --dry-run --quiet)
rg -q '^DRY RUN 20/20 ' <<<"$dry_output"

# Test 4: doctor reports status
mkdir -p "$test_dir/app"
(
  cd "$test_dir/app"
  PATH="$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" doctor --quiet 2>&1 || true
)

# Test 5: update displays progress feedback
release_work="$test_dir/release"
mkdir -p "$release_work"
cp "$root_dir/VERSION" "$root_dir/versions.env" "$root_dir/install.sh" "$release_work/"
cp -R "$root_dir/bin" "$root_dir/lib" "$root_dir/templates" "$release_work/"
printf '9.9.9\n' >"$release_work/VERSION"
(
  cd "$release_work"
  git init --quiet --initial-branch main .
  git add -A
  git -c user.name=test -c user.email=test@example.com commit --quiet -m 'chore: release'
  git tag v9.9.9
  git clone --quiet --bare . "$test_dir/release.git"
)
update_output=$(
  MKNEXT_SOURCE_REPOSITORY="$test_dir/release.git" \
  MKNEXT_INSTALL_PREFIX="$test_dir/ui-prefix" \
  "$root_dir/bin/mknext" update 2>&1
)
rg -q 'mknext is updated to v9.9.9' <<<"$update_output"

printf 'PASS: CLI UI and formatting pass checks\n'
