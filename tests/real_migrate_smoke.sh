#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mknext_cli=${MKNEXT_TEST_CLI:-"$root_dir/bin/mknext"}
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
for package_manager in pnpm@12.3.1 "$(node -p 'require(process.argv[1]).packageManager' "$root_dir/package.json")" "npm@$(npm --version)"; do
  manager=${package_manager%%@*}
  app_dir="$test_dir/$package_manager"
  mkdir -p "$app_dir/src"
  printf '%s\n' '{"name":"real-migration","private":true,"type":"module","scripts":{"lint":"eslint .","format":"prettier --check ."},"dependencies":{"is-number":"7.0.0"},"devDependencies":{"eslint":"9.39.0","prettier":"3.8.3"}}' >"$app_dir/package.json"
  node -e 'const fs=require("node:fs"); const p=JSON.parse(fs.readFileSync(process.argv[1])); p.packageManager=process.argv[2]; fs.writeFileSync(process.argv[1], JSON.stringify(p));' "$app_dir/package.json" "$package_manager"
  printf 'minimumReleaseAge: 4320\nminimumReleaseAgeStrict: false\ntrustPolicy: no-downgrade\ntrustPolicyIgnoreAfter: 43200\n' >"$app_dir/pnpm-workspace.yaml"
  cp "$app_dir/pnpm-workspace.yaml" "$test_dir/workspace.before.yaml"
  printf 'export default [];\n' >"$app_dir/eslint.config.mjs"
  printf '{"singleQuote":false,"semi":false,"tabWidth":4}\n' >"$app_dir/.prettierrc.json"
  printf 'export const answer = 42\n' >"$app_dir/src/answer.js"
  cp "$app_dir/src/answer.js" "$test_dir/source.before.js"

  (
    cd "$app_dir"
    printf 'Testing migration with %s\n' "$package_manager"
    "$manager" --version
    CI=true NODE_ENV=production "$mknext_cli" --migrate --yes --quiet
    cmp -s "$test_dir/source.before.js" src/answer.js
    cmp -s "$test_dir/workspace.before.yaml" pnpm-workspace.yaml
    [[ ! -e eslint.config.mjs ]]
    [[ ! -e .prettierrc.json ]]
    node --input-type=module - "$package_manager" <<'NODE'
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const data = JSON.parse(await readFile('package.json', 'utf8'));
assert.equal(data.packageManager, process.argv[2]);
assert.equal(data.dependencies['is-number'], '7.0.0');
assert.equal(require('is-number')(42), true);
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
    "$mknext_cli" --migrate --quiet
    cmp -s "$test_dir/migrated.json" package.json
  )
done

printf 'PASS: pnpm 12.3.1, pinned pnpm, and npm migrations preserve dependencies and policy\n'
