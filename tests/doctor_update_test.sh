#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/corepack" "$root_dir/tests/fakes/pnpm" "$root_dir/tests/fakes/check-tool"
check_log="$test_dir/checks.log"
: >"$check_log"

MKNEXT_CHECK_LOG="$check_log" PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

cp "$test_dir/app/pnpm-workspace.yaml" "$test_dir/pnpm-workspace.before.yaml"
cp "$root_dir/tests/fakes/check-tool" "$test_dir/gitleaks"

node --input-type=module - "$test_dir/app/package.json" <<'NODE'
import { readFile, writeFile } from 'node:fs/promises';

const packageFile = process.argv[2];
const packageData = JSON.parse(await readFile(packageFile, 'utf8'));
packageData.dependencies.next = '^1.0.0';
packageData.devDependencies.knip = '~1.0.0';
packageData.optionalDependencies = { 'test-optional': '1.x' };
await writeFile(packageFile, `${JSON.stringify(packageData, null, 2)}\n`);
NODE

(
  cd "$test_dir/app"
  MKNEXT_CHECK_LOG="$check_log" PATH="$test_dir:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" doctor --quiet
)

cmp -s "$test_dir/pnpm-workspace.before.yaml" "$test_dir/app/pnpm-workspace.yaml"
[[ "$(node -p "require('$test_dir/app/package.json').dependencies.next")" == '99.0.0' ]]
[[ "$(node -p "require('$test_dir/app/package.json').devDependencies.knip")" == '99.0.0' ]]
[[ "$(node -p "require('$test_dir/app/package.json').optionalDependencies['test-optional']")" == '99.0.0' ]]
rg -q '^pnpm update --latest --save-exact --config.minimum-release-age-strict=true$' "$check_log"

cp "$test_dir/app/package.json" "$test_dir/package.before-failure.json"
if failure_output=$(
  cd "$test_dir/app"
  MKNEXT_CHECK_LOG="$check_log" MKNEXT_FAKE_PNPM_UPDATE_FAIL=1 \
    PATH="$test_dir:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" doctor --quiet 2>&1
); then
  printf 'FAIL: doctor accepted a rejected dependency update\n' >&2
  exit 1
fi

rg -q '^problem: dependency update failed$' <<<"$failure_output"
rg -q '^status: unhealthy$' <<<"$failure_output"
cmp -s "$test_dir/package.before-failure.json" "$test_dir/app/package.json"
cmp -s "$test_dir/pnpm-workspace.before.yaml" "$test_dir/app/pnpm-workspace.yaml"

printf 'PASS: doctor updates dependencies without changing release-age config\n'
