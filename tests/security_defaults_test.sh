#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm" "$root_dir/tests/fakes/check-tool"
PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" "$test_dir/secure-app" --mode autonomous --yes --quiet

app_dir="$test_dir/secure-app"
workflow="$app_dir/.github/workflows/ci.yml"
protection_script="$app_dir/scripts/configure-main-protection.sh"

[[ -f "$app_dir/.gitleaks.toml" ]]
[[ -f "$workflow" ]]
[[ -x "$protection_script" ]]
rg -q 'gitleaks git --staged --redact \.' "$app_dir/.husky/pre-commit"
rg -q 'pnpm audit' "$workflow"
rg -q 'pnpm knip' "$workflow"
rg -q 'gitleaks/gitleaks-action@' "$workflow"
rg -q 'security' "$protection_script"
rg -q 'quality' "$protection_script"
rg -q '"required_approving_review_count": 1' "$protection_script"
rg -q '"allow_force_pushes": false' "$protection_script"
rg -q '"allow_deletions": false' "$protection_script"
rg -q '"audit": "pnpm audit"' "$app_dir/package.json"
rg -q '"secrets": "gitleaks git --redact \."' "$app_dir/package.json"

mkdir -p "$app_dir/node_modules/.bin" "$test_dir/bin"
for tool in knip oxlint oxfmt react-doctor vitest tsc; do
  cp "$root_dir/tests/fakes/check-tool" "$app_dir/node_modules/.bin/$tool"
done
cp "$root_dir/tests/fakes/check-tool" "$test_dir/bin/gitleaks"
check_log="$test_dir/checks.log"
: >"$check_log"

(
  cd "$app_dir"
  MKNEXT_CHECK_LOG="$check_log" \
    PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" ci --quiet
)

rg -q '^pnpm audit$' "$check_log"
rg -q '^pnpm run typecheck$' "$check_log"
rg -q '^gitleaks git --redact \.$' "$check_log"
rg -q '^knip $' "$check_log"

printf 'PASS: generated apps include local and remote security gates\n'
