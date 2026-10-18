#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/app/src"

printf '%s\n' '{"name":"existing-app","private":true,"scripts":{"dev":"next dev","lint":"next lint","lint:fix":"eslint --fix src","format":"prettier --check .","check":"eslint . && node verify.js"},"dependencies":{"next":"16.4.1","react":"19.3.1","eslint-plugin-react":"7.37.5"},"devDependencies":{"eslint":"9.39.0","eslint-config-next":"16.4.1","@typescript-eslint/parser":"8.50.0","prettier":"3.8.3","prettier-plugin-tailwindcss":"0.8.0"},"lint-staged":{"*.ts":["eslint --fix","prettier --write"]}}' >"$test_dir/app/package.json"
printf 'export default [];\n' >"$test_dir/app/eslint.config.mjs"
printf '{"singleQuote":false,"semi":false,"tabWidth":4}\n' >"$test_dir/app/.prettierrc.json"
printf 'generated/\n' >"$test_dir/app/.prettierignore"
printf 'vendor/\n' >"$test_dir/app/.eslintignore"
printf 'minimumReleaseAge: 4320\ntrustPolicy: no-downgrade\n' >"$test_dir/app/pnpm-workspace.yaml"
printf 'export const answer = 42;\n' >"$test_dir/app/src/answer.ts"
cp "$test_dir/app/package.json" "$test_dir/package.before.json"
cp "$test_dir/app/pnpm-workspace.yaml" "$test_dir/workspace.before.yaml"

(
  cd "$test_dir/app"
  PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" --migrate --dry-run --quiet
)
cmp -s "$test_dir/package.before.json" "$test_dir/app/package.json"
[[ ! -e "$test_dir/app/.mknext-migrate-backups" ]]
[[ ! -e "$test_dir/app/oxlint.config.ts" ]]

(
  cd "$test_dir/app"
  PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" --migrate --yes --quiet
)
node --input-type=module - "$test_dir/app" "$root_dir" <<'NODE'
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
const [app, root] = process.argv.slice(2);
const data = JSON.parse(await readFile(path.join(app, 'package.json'), 'utf8'));
const pins = Object.fromEntries((await readFile(path.join(root, 'versions.env'), 'utf8')).split('\n').map(line => line.split('=')));
assert.equal(data.dependencies.next, '16.4.1');
assert.equal(data.dependencies.react, '19.3.1');
assert.equal(data.scripts.dev, 'next dev');
assert.equal(data.scripts.lint, 'oxlint .');
assert.equal(data.scripts['lint:fix'], 'oxlint --fix .');
assert.equal(data.scripts.format, 'oxfmt --check .');
assert.equal(data.scripts.check, 'oxlint . && node verify.js');
assert.deepEqual(data['lint-staged']['*.ts'], ['oxlint --fix', 'oxfmt --write']);
assert.equal(data.devDependencies.oxlint, pins.OXlint_VERSION);
assert.equal(data.devDependencies['@oxlint/plugins'], pins.OXlint_PLUGINS_VERSION);
assert.equal(data.devDependencies.oxfmt, pins.OXFMT_VERSION);
for (const group of ['dependencies', 'devDependencies']) {
  for (const name of Object.keys(data[group] ?? {})) {
    assert.ok(!name.includes('eslint') && !name.includes('prettier'), name);
  }
}
const backups = await readdir(path.join(app, '.mknext-migrate-backups'));
assert.equal(backups.length, 1);
const previous = JSON.parse(await readFile(path.join(app, '.mknext-migrate-backups', backups[0], 'package.json'), 'utf8'));
assert.equal(previous.devDependencies.eslint, '9.39.0');
const formatter = JSON.parse(await readFile(path.join(app, '.oxfmtrc.json'), 'utf8'));
assert.equal(formatter.singleQuote, false);
assert.equal(formatter.semi, false);
assert.equal(formatter.tabWidth, 4);
NODE
[[ -f "$test_dir/app/oxlint.config.ts" ]]
[[ -f "$test_dir/app/tools/oxlint/anti-slop/index.ts" ]]
[[ ! -e "$test_dir/app/eslint.config.mjs" ]]
[[ ! -e "$test_dir/app/.prettierrc.json" ]]
rg -q '^/\.mknext-migrate-backups/$' "$test_dir/app/.gitignore"
cmp -s "$test_dir/workspace.before.yaml" "$test_dir/app/pnpm-workspace.yaml"
rg -q '^export const answer = 42;$' "$test_dir/app/src/answer.ts"
cp "$test_dir/app/package.json" "$test_dir/package.after.json"
(
  cd "$test_dir/app"
  PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" migrate --quiet
)
cmp -s "$test_dir/package.after.json" "$test_dir/app/package.json"

mkdir "$test_dir/failure"
cp "$test_dir/package.before.json" "$test_dir/failure/package.json"
printf 'export default [];\n' >"$test_dir/failure/eslint.config.mjs"
(
  cd "$test_dir/failure"
  if MKNEXT_FAKE_PNPM_INSTALL_FAIL=1 PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" --migrate --quiet; then
    printf 'FAIL: migrate accepted an installation failure\n' >&2
    exit 1
  fi
)
cmp -s "$test_dir/package.before.json" "$test_dir/failure/package.json"
[[ -f "$test_dir/failure/eslint.config.mjs" ]]
[[ ! -e "$test_dir/failure/oxlint.config.ts" ]]

mkdir "$test_dir/format-failure"
cp "$test_dir/package.before.json" "$test_dir/format-failure/package.json"
printf '{"semi":false}\n' >"$test_dir/format-failure/.prettierrc.json"
(
  cd "$test_dir/format-failure"
  if MKNEXT_FAKE_OXFMT_FAIL=1 PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" --migrate --quiet; then
    printf 'FAIL: migrate accepted a formatter failure\n' >&2
    exit 1
  fi
)
cmp -s "$test_dir/package.before.json" "$test_dir/format-failure/package.json"
[[ -f "$test_dir/format-failure/.prettierrc.json" ]]
[[ ! -e "$test_dir/format-failure/.oxfmtrc.json" ]]

mkdir "$test_dir/custom"
cp "$test_dir/package.before.json" "$test_dir/custom/package.json"
printf '{"rules":{"no-console":"off"}}\n' >"$test_dir/custom/.oxlintrc.json"
printf '{"semi":false}\n' >"$test_dir/custom/.oxfmtrc.json"
cp "$test_dir/custom/.oxlintrc.json" "$test_dir/oxlint.before.json"
cp "$test_dir/custom/.oxfmtrc.json" "$test_dir/oxfmt.before.json"
(
  cd "$test_dir/custom"
  PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" --migrate --quiet
)
cmp -s "$test_dir/oxlint.before.json" "$test_dir/custom/.oxlintrc.json"
cmp -s "$test_dir/oxfmt.before.json" "$test_dir/custom/.oxfmtrc.json"
[[ ! -e "$test_dir/custom/oxlint.config.ts" ]]

mkdir "$test_dir/linked"
ln -s "$test_dir/package.before.json" "$test_dir/linked/package.json"
(
  cd "$test_dir/linked"
  if PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" --migrate --quiet; then
    printf 'FAIL: migrate followed a package.json symbolic link\n' >&2
    exit 1
  fi
)
(
  cd "$test_dir"
  if "$root_dir/bin/mknext" --migrate --quiet; then
    printf 'FAIL: migrate accepted a missing package.json\n' >&2
    exit 1
  fi
)

printf 'PASS: migration replaces ESLint and Prettier and preserves project files\n'
