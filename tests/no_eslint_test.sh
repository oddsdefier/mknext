#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm"
PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

package_data=$(<"$test_dir/app/package.json")
case "$package_data" in
  *'"eslint"'*|*'"eslint-config-next"'*|*'"prettier"'*|*'"prettier-plugin-tailwindcss"'*)
    printf 'FAIL: generated app includes ESLint or Prettier packages\n' >&2
    exit 1
    ;;
esac

if [[ -e "$test_dir/app/eslint.config.mjs" || -e "$test_dir/app/.prettierignore" || -e "$test_dir/app/.prettierrc" ]]; then
  printf 'FAIL: generated app includes an ESLint or Prettier config\n' >&2
  exit 1
fi

printf 'PASS: generated app uses no ESLint or Prettier packages or config\n'
