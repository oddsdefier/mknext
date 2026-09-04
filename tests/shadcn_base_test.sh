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
mkdir -p "$test_dir/home/.config/mknext"
printf 'preset=userPreset456\n' >"$test_dir/home/.config/mknext/config"

MKNEXT_CHECK_LOG="$check_log" \
  HOME="$test_dir/home" \
  PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --preset customPreset123 --yes --quiet

rg -q '^pnpm dlx shadcn@latest init --preset customPreset123 --template next --name app --yes$' "$check_log"
if rg -q '^pnpm dlx create-next-app@' "$check_log"; then
  printf 'FAIL: create still calls create-next-app\n' >&2
  exit 1
fi
rg -q '^preset=customPreset123$' "$test_dir/app/.mknext"
rg -q '"style":"base-nova"' "$test_dir/app/components.json"
rg -q '"iconLibrary":"hugeicons"' "$test_dir/app/components.json"

MKNEXT_CHECK_LOG="$check_log" \
  HOME="$test_dir/home" \
  PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/config-app" --yes --quiet

rg -q '^pnpm dlx shadcn@latest init --preset userPreset456 --template next --name config-app --yes$' "$check_log"
rg -q '^preset=userPreset456$' "$test_dir/config-app/.mknext"

printf 'PASS: shadcn scaffolds the app with the configured preset\n'
