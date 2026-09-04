#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/corepack" "$root_dir/tests/fakes/pnpm"

PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

node --input-type=module - "$test_dir/app" <<'NODE'
import { readFile } from 'node:fs/promises';
import path from 'node:path';

const appDirectory = process.argv[2];
const config = JSON.parse(await readFile(path.join(appDirectory, '.changeset/config.json'), 'utf8'));
const packageData = JSON.parse(await readFile(path.join(appDirectory, 'package.json'), 'utf8'));

if (config.changelog !== '@changesets/cli/changelog') {
  throw new Error('generated app does not use the manual Changesets changelog');
}

if ('@changesets/changelog-github' in packageData.devDependencies) {
  throw new Error('generated app includes the GitHub changelog package');
}
NODE

printf 'PASS: generated Changesets setup stays manual and non-interactive\n'
