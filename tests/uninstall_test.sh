#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

prefix="$test_dir/prefix"
MKNEXT_INSTALL_PREFIX="$prefix" "$root_dir/install.sh" >/dev/null

[[ -x "$prefix/bin/mknext" ]]
[[ -d "$prefix/share/mknext" ]]

"$prefix/bin/mknext" uninstall --yes >/dev/null

if [[ -e "$prefix/bin/mknext" || -d "$prefix/share/mknext" ]]; then
  printf 'FAIL: uninstall left files behind\n' >&2
  exit 1
fi

if MKNEXT_INSTALL_PREFIX="$prefix" "$root_dir/bin/mknext" uninstall --yes 2>/dev/null; then
  printf 'FAIL: uninstall accepted a missing install\n' >&2
  exit 1
fi

printf 'PASS: uninstall removes the CLI and rejects a missing install\n'
