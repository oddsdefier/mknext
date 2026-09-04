#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/curl"
check_log="$test_dir/checks.log"
: >"$check_log"
install_prefix="$test_dir/prefix"

MKNEXT_INSTALL_PREFIX="$install_prefix" "$root_dir/install.sh" >/dev/null

(
  cd "$test_dir"
  MKNEXT_CHECK_LOG="$check_log" \
    MKNEXT_UPDATE_MARKER="$test_dir/updated" \
    MKNEXT_UPDATE_PREFIX_MARKER="$test_dir/updated-prefix" \
    PATH="$root_dir/tests/fakes:$PATH" \
    "$install_prefix/bin/mknext" update
)

rg -q '^curl -fsSL https://raw.githubusercontent.com/oddsdefier/mknext/main/install.sh$' "$check_log"
rg -q '^updated$' "$test_dir/updated"
rg -Fqx "$install_prefix" "$test_dir/updated-prefix"

if MKNEXT_FAKE_CURL_FAIL=1 PATH="$root_dir/tests/fakes:$PATH" \
  "$install_prefix/bin/mknext" update >/dev/null 2>&1; then
  printf 'FAIL: update accepted a curl failure\n' >&2
  exit 1
else
  update_status=$?
fi
[[ "$update_status" -eq 1 ]] || { printf 'FAIL: curl failure returned %s\n' "$update_status" >&2; exit 1; }

if MKNEXT_FAKE_INSTALLER_FAIL=1 PATH="$root_dir/tests/fakes:$PATH" \
  "$install_prefix/bin/mknext" update >/dev/null 2>&1; then
  printf 'FAIL: update accepted an installer failure\n' >&2
  exit 1
else
  update_status=$?
fi
[[ "$update_status" -eq 1 ]] || { printf 'FAIL: installer failure returned %s\n' "$update_status" >&2; exit 1; }

printf 'PASS: update runs the public installer\n'
