#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

node - "$root_dir" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const root = process.argv[2];
const packageData = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const config = JSON.parse(fs.readFileSync(path.join(root, '.changeset/config.json'), 'utf8'));
const version = fs.readFileSync(path.join(root, 'VERSION'), 'utf8').trim();

if (packageData.version !== version) throw new Error('package.json and VERSION do not match');
if (packageData.devDependencies['@changesets/cli'] !== '3.0.1') throw new Error('Changesets is not pinned');
if (packageData.scripts.changeset !== 'changeset') throw new Error('changeset command is missing');
if (packageData.scripts['changeset:version'] !== 'changeset version && node scripts/sync-version.mjs') {
  throw new Error('version command is missing');
}
if (config.privatePackages.version !== true) throw new Error('private package versioning is off');
NODE

mkdir -p "$test_dir/scripts"
cp "$root_dir/scripts/sync-version.mjs" "$test_dir/scripts/sync-version.mjs"
printf '{"version":"1.2.3"}\n' >"$test_dir/package.json"
printf '0.0.0\n' >"$test_dir/VERSION"
(cd "$test_dir" && node scripts/sync-version.mjs)

if [[ "$(<"$test_dir/VERSION")" != '1.2.3' ]]; then
  printf 'FAIL: version sync did not update VERSION\n' >&2
  exit 1
fi

printf 'PASS: Changesets versions the mknext source\n'
