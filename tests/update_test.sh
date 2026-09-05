#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

install_prefix="$test_dir/prefix"
MKNEXT_INSTALL_PREFIX="$install_prefix" "$root_dir/install.sh" >/dev/null

# A local git repository stands in for GitHub. Update clones a tag from it.
release_repository="$test_dir/release.git"
release_work="$test_dir/release"
mkdir -p "$release_work"
cp "$root_dir/VERSION" "$root_dir/versions.env" "$root_dir/install.sh" "$release_work/"
cp -R "$root_dir/bin" "$root_dir/lib" "$root_dir/templates" "$release_work/"
printf '9.9.9\n' >"$release_work/VERSION"
(
  cd "$release_work"
  git init --quiet --initial-branch main .
  git add -A
  git -c user.name=test -c user.email=test@example.com commit --quiet -m 'chore: release'
  git tag v9.9.9
  git clone --quiet --bare . "$release_repository"
)

MKNEXT_SOURCE_REPOSITORY="$release_repository" \
  MKNEXT_INSTALL_PREFIX="$install_prefix" \
  "$install_prefix/bin/mknext" update >/dev/null

[[ -x "$install_prefix/bin/mknext" ]]
[[ $(cat "$install_prefix/share/mknext/VERSION") == 9.9.9 ]] || {
  printf 'FAIL: update did not install the newest tag\n' >&2
  exit 1
}

# The newest tag is already installed, so update stops without a download.
update_output=$(MKNEXT_SOURCE_REPOSITORY="$release_repository" \
  MKNEXT_INSTALL_PREFIX="$install_prefix" \
  "$install_prefix/bin/mknext" update 2>&1)
grep -q 'already the newest release' <<<"$update_output" || {
  printf 'FAIL: update reinstalled the version it already had\n' >&2
  exit 1
}

# A repository with no release tag must fail, not install an arbitrary commit.
untagged_repository="$test_dir/untagged.git"
git clone --quiet --bare "$release_work" "$untagged_repository"
git -C "$untagged_repository" tag -d v9.9.9 >/dev/null
if MKNEXT_SOURCE_REPOSITORY="$untagged_repository" \
  MKNEXT_INSTALL_PREFIX="$install_prefix" \
  "$install_prefix/bin/mknext" update >/dev/null 2>&1; then
  printf 'FAIL: update accepted a repository with no release tag\n' >&2
  exit 1
fi

# A missing repository must fail, and must not damage the installation.
if MKNEXT_SOURCE_REPOSITORY="$test_dir/absent.git" \
  MKNEXT_INSTALL_PREFIX="$install_prefix" \
  "$install_prefix/bin/mknext" update >/dev/null 2>&1; then
  printf 'FAIL: update accepted a missing repository\n' >&2
  exit 1
fi
[[ -x "$install_prefix/bin/mknext" ]] || {
  printf 'FAIL: a failed update damaged the installation\n' >&2
  exit 1
}

# Failed replacement restores any previous installation entry.
rollback_prefix="$test_dir/rollback-prefix"
mkdir -p "$rollback_prefix/bin" "$rollback_prefix/share"
ln -s missing-release "$rollback_prefix/share/mknext"
mkdir "$rollback_prefix/bin/mknext"
chmod 500 "$rollback_prefix/bin/mknext"
if MKNEXT_INSTALL_PREFIX="$rollback_prefix" "$root_dir/install.sh" >/dev/null 2>&1; then
  printf 'FAIL: installer should fail when the command path is a directory\n' >&2
  exit 1
fi
[[ -L "$rollback_prefix/share/mknext" ]] || {
  printf 'FAIL: installer did not restore the prior dangling link\n' >&2
  exit 1
}
[[ $(readlink "$rollback_prefix/share/mknext") == missing-release ]] || {
  printf 'FAIL: installer restored the wrong prior target\n' >&2
  exit 1
}

printf 'PASS: update clones the newest release tag\n'
