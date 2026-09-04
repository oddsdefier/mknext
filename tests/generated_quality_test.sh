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
const packageData = JSON.parse(await readFile(path.join(appDirectory, 'package.json'), 'utf8'));
const tsconfig = JSON.parse(await readFile(path.join(appDirectory, 'tsconfig.json'), 'utf8'));
const complexityConfig = await readFile(path.join(appDirectory, 'oxlint.complexity.config.ts'), 'utf8');
const doctorConfig = await readFile(path.join(appDirectory, 'doctor.config.ts'), 'utf8');
const page = await readFile(path.join(appDirectory, 'app/page.tsx'), 'utf8');

if (packageData.scripts.typecheck !== 'next typegen && tsc --noEmit') {
  throw new Error('typecheck does not generate Next.js types');
}
if (packageData.type !== 'module') throw new Error('generated app does not use ES modules');
if (tsconfig.compilerOptions.allowImportingTsExtensions !== true) {
  throw new Error('TypeScript does not allow tool source imports');
}
if (!complexityConfig.includes("from './oxlint.config.ts'")) {
  throw new Error('complexity config cannot load the base config');
}
if (doctorConfig.includes("from 'react-doctor'")) {
  throw new Error('React Doctor config uses a missing run-time export');
}
if (page !== 'export default function Page() { return <main>Hello</main>; }\n') {
  throw new Error('generated app was not formatted');
}
NODE

printf 'PASS: generated app quality checks can run\n'
