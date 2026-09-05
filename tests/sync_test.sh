#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm" "$root_dir/tests/fakes/check-tool"

# Test 1: sync fails outside a project
if "$root_dir/bin/mknext" sync --quiet 2>/dev/null; then
  printf 'FAIL: sync should fail without .mknext marker\n' >&2
  exit 1
fi

# Create a sample project
PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

# Test 2: sync succeeds in a valid project
(
  cd "$test_dir/app"
  PATH="$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" sync --quiet
)

# Test 3: sync backs up overwritten files and reports complete dry runs
(
  cd "$test_dir/app"
  printf 'custom config\n' >next.config.ts
  dry_output=$(PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" sync --dry-run)
  rg -q 'vercel.json' <<<"$dry_output"
  PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" sync --quiet
  compgen -G '.mknext-sync-backups/*/next.config.ts' >/dev/null || {
    printf 'FAIL: sync did not back up next.config.ts\n' >&2
    exit 1
  }
)

# Test 4: formatter errors fail sync
(
  cd "$test_dir/app"
  mkdir -p node_modules/.bin
  cat >node_modules/.bin/oxfmt <<'SH'
#!/usr/bin/env sh
exit 1
SH
  chmod +x node_modules/.bin/oxfmt
  if PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" sync --quiet 2>/dev/null; then
    printf 'FAIL: sync accepted a formatter failure\n' >&2
    exit 1
  fi
  rm -f node_modules/.bin/oxfmt
)

# Test 5: CI target validation fails on unknown target
(
  cd "$test_dir/app"
  if "$root_dir/bin/mknext" ci --ci invalid-ci --quiet 2>/dev/null; then
    printf 'FAIL: invalid CI target should fail\n' >&2
    exit 1
  fi
)

# Test 6: CI target github runs with fake tools
mkdir -p "$test_dir/app/node_modules/.bin" "$test_dir/bin"
for tool in knip oxlint oxfmt react-doctor vitest tsc; do
  cp "$root_dir/tests/fakes/check-tool" "$test_dir/app/node_modules/.bin/$tool"
done
cp "$root_dir/tests/fakes/check-tool" "$test_dir/bin/gitleaks"
check_log="$test_dir/ci-github.log"
: >"$check_log"

(
  cd "$test_dir/app"
  MKNEXT_CHECK_LOG="$check_log" \
    PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" ci --ci github --quiet
)

rg -q '^pnpm run build$' "$check_log"

# Test 7: sync rejects destinations that escape through symbolic links
(
  cd "$test_dir/app"
  outside="$test_dir/outside"
  mkdir -p "$outside"
  rm -rf lib
  ln -s "$outside" lib
  if PATH="$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" sync --quiet 2>/dev/null; then
    printf 'FAIL: sync followed a destination symbolic link\n' >&2
    exit 1
  fi
  [[ ! -e "$outside/utils.ts" ]] || {
    printf 'FAIL: sync wrote outside the project\n' >&2
    exit 1
  }
)

printf 'PASS: mknext sync and extended ci targets pass checks\n'
