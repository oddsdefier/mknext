#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm" "$root_dir/tests/fakes/check-tool"
check_log="$test_dir/checks.log"
: >"$check_log"
export MKNEXT_CHECK_LOG="$check_log"

# Test 1: audit fails outside an mknext project
if "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
  printf 'FAIL: audit should fail without .mknext marker\n' >&2
  exit 1
fi

# Create a sample project
PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

mkdir -p "$test_dir/app/node_modules/.bin" "$test_dir/bin"
for tool in knip oxlint oxfmt react-doctor vitest tsc; do
  cp "$root_dir/tests/fakes/check-tool" "$test_dir/app/node_modules/.bin/$tool"
done
cp "$root_dir/tests/fakes/check-tool" "$test_dir/bin/gitleaks"

# Test 2: audit passes in a fresh valid project
(
  cd "$test_dir/app"
  PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet
)

# Test 3: audit detects tracked .env file
(
  cd "$test_dir/app"
  git init -q 2>/dev/null || true
  touch .env.local
  git add -f .env.local 2>/dev/null || true
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when .env file is tracked in git\n' >&2
    exit 1
  fi
  git rm -f --cached .env.local 2>/dev/null || true
  rm -f .env.local
)

# Test 4: safe install setup backs up and appends to shell rc
fake_home="$test_dir/fakehome"
mkdir -p "$fake_home"
printf '# original bashrc\nexport TEST=1\n' >"$fake_home/.bashrc"

(
  cd "$test_dir/app"
  HOME="$fake_home" PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --setup-safe-install --quiet
)

if [[ ! -f "$fake_home/.bashrc.mknext.bak" ]]; then
  printf 'FAIL: safe install setup did not create a backup of .bashrc\n' >&2
  exit 1
fi

grep -q 'alias npm=' "$fake_home/.bashrc"
grep -q 'alias pnpm=' "$fake_home/.bashrc"

# Test 5: client secret leak in 'use client'
(
  cd "$test_dir/app"
  mkdir -p app
  cat >app/leaky.tsx <<'TSX'
'use client';
export const config = { secret: process.env.DATABASE_URL };
TSX
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when client component references DATABASE_URL\n' >&2
    exit 1
  fi
  rm -f app/leaky.tsx
)

# Test 6: supply chain release age check
(
  cd "$test_dir/app"
  mv pnpm-workspace.yaml pnpm-workspace.yaml.bak
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when pnpm-workspace.yaml is missing\n' >&2
    exit 1
  fi
  mv pnpm-workspace.yaml.bak pnpm-workspace.yaml
)

# Test 7: NEXT_PUBLIC_ secret anti-pattern
(
  cd "$test_dir/app"
  cat >lib/env-leak.ts <<'TS'
export const token = process.env.NEXT_PUBLIC_API_SECRET;
TS
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when NEXT_PUBLIC_ secret is present\n' >&2
    exit 1
  fi
  rm -f lib/env-leak.ts
)

# Test 8: leaked secret in .next/static bundle
(
  cd "$test_dir/app"
  mkdir -p .next/static/chunks
  cat >.next/static/chunks/main.js <<'JS'
console.log(process.env.DATABASE_URL);
JS
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when .next/static contains server secret reference\n' >&2
    exit 1
  fi
  rm -rf .next
)

printf 'PASS: mknext audit and security checks pass\n'
