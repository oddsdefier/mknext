#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

MKNEXT_ENABLE_CLAUDE_GUARD=0 \
  "$root_dir/bin/mknext" create --name "$test_dir/real-app" --yes --quiet

cd "$test_dir/real-app"
pnpm audit
node -e "const p=require('./package.json'); if (p.dependencies?.shadcn || p.devDependencies?.shadcn) process.exit(1)"
pnpm lint
pnpm lint:complexity
pnpm format
pnpm run doctor
pnpm knip
pnpm test:run
pnpm typecheck
pnpm build

printf 'PASS: real shadcn scaffold passes generated quality checks\n'
