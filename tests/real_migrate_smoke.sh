#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
for manager in pnpm npm; do
  app_dir="$test_dir/$manager"
  mkdir -p "$app_dir/src"
  printf '%s\n' '{"name":"real-migration","private":true,"type":"module","scripts":{"lint":"eslint .","format":"prettier --check ."},"devDependencies":{"eslint":"9.39.0","prettier":"3.8.3"}}' >"$app_dir/package.json"
  if [[ "$manager" == npm ]]; then
    node -e 'const fs=require("node:fs"); const p=JSON.parse(fs.readFileSync(process.argv[1])); p.packageManager=`npm@${process.argv[2]}`; fs.writeFileSync(process.argv[1], JSON.stringify(p));' "$app_dir/package.json" "$(npm --version)"
  fi
  printf 'export default [];\n' >"$app_dir/eslint.config.mjs"
  printf '{"singleQuote":false,"semi":false,"tabWidth":4}\n' >"$app_dir/.prettierrc.json"
  printf 'export const answer = 42\n' >"$app_dir/src/answer.js"
  cp "$app_dir/src/answer.js" "$test_dir/source.before.js"

  (
    cd "$app_dir"
    CI=true NODE_ENV=production "$root_dir/bin/mknext" --migrate --yes --quiet
    cmp -s "$test_dir/source.before.js" src/answer.js
    [[ ! -e eslint.config.mjs ]]
    [[ ! -e .prettierrc.json ]]
    node --input-type=module - "$manager" <<'NODE'
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const data = JSON.parse(await readFile('package.json', 'utf8'));
assert.ok(data.packageManager.startsWith(`${process.argv[2]}@`));
assert.ok(data.devDependencies.oxlint);
assert.ok(data.devDependencies.oxfmt);
assert.ok(!data.devDependencies.eslint);
assert.ok(!data.devDependencies.prettier);
const config = JSON.parse(await readFile('.oxfmtrc.json', 'utf8'));
assert.equal(config.semi, false);
assert.equal(config.singleQuote, false);
assert.equal(config.tabWidth, 4);
NODE
    "$manager" run lint
    "$manager" run lint:complexity
    "$manager" run format
    if [[ "$manager" == pnpm ]]; then
      pnpm install --frozen-lockfile
    else
      npm ci --include=dev
      [[ ! -e pnpm-lock.yaml ]]
    fi
    "$manager" audit
    cp package.json "$test_dir/migrated.json"
    "$root_dir/bin/mknext" --migrate --quiet
    cmp -s "$test_dir/migrated.json" package.json
  )
done

printf 'PASS: npm and pnpm migrations install working tools and preserve settings\n'
