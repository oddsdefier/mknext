#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SOURCE_DIR=''
TEMP_DIR=''
MKNEXT_SOURCE_REPOSITORY=${MKNEXT_SOURCE_REPOSITORY:-https://github.com/oddsdefier/mknext.git}
new_share=''
backup_share=''
new_bin=''
share_dir=''
install_committed=0
share_replaced=0

cleanup() {
  if ((install_committed == 0)); then
    if [[ -n "$new_share" ]]; then rm -rf "$new_share"; fi
    if [[ -n "$new_bin" ]]; then rm -rf "$new_bin"; fi
    if ((share_replaced == 1)) && [[ -n "$share_dir" ]]; then
      rm -rf "$share_dir"
      if [[ -e "$backup_share" || -L "$backup_share" ]]; then
        mv "$backup_share" "$share_dir"
      fi
    fi
  fi
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT

script_path=${BASH_SOURCE[0]:-}
if [[ -n "$script_path" ]]; then
  candidate_dir=$(cd "$(dirname "$script_path")" 2>/dev/null && pwd || true)
  if [[ -f "$candidate_dir/VERSION" && -d "$candidate_dir/templates" ]]; then
    SOURCE_DIR=$candidate_dir
  fi
fi

if [[ -z "$SOURCE_DIR" ]]; then
  command -v git >/dev/null 2>&1 || {
    printf 'mknext installer: git is required\n' >&2
    exit 1
  }
  TEMP_DIR=$(mktemp -d)
  # Git compares the content against the commit hash, so no separate checksum
  # is necessary. The newest tag is the newest release.
  source_tag=${MKNEXT_RELEASE_TAG:-}
  if [[ -z "$source_tag" ]]; then
    source_tag=$(git ls-remote --tags --refs --sort=-v:refname \
      "$MKNEXT_SOURCE_REPOSITORY" 'v*' | head -n 1 | sed 's|.*refs/tags/||')
  fi
  [[ "$source_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    printf 'mknext installer: no release tag found\n' >&2
    exit 1
  }
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$source_tag" \
    "$MKNEXT_SOURCE_REPOSITORY" "$TEMP_DIR/mknext" || {
    printf 'mknext installer: could not download %s\n' "$source_tag" >&2
    exit 1
  }
  SOURCE_DIR="$TEMP_DIR/mknext"
fi

install_prefix=${MKNEXT_INSTALL_PREFIX:-"$HOME/.local"}
bin_dir="$install_prefix/bin"
share_dir="$install_prefix/share/mknext"

mkdir -p "$bin_dir"

new_share="${share_dir}.new.$$"
rm -rf "$new_share"
mkdir -p "$new_share"
cp "$SOURCE_DIR/VERSION" "$SOURCE_DIR/versions.env" "$new_share/"
cp -R "$SOURCE_DIR/bin" "$SOURCE_DIR/lib" "$SOURCE_DIR/templates" "$new_share/"
chmod +x "$new_share/bin/mknext"
if [[ -d "$new_share/templates/.claude/hooks" ]]; then
  chmod +x "$new_share/templates/.claude/hooks/"*.sh 2>/dev/null || true
fi
if [[ -d "$new_share/templates/.codex/hooks" ]]; then
  chmod +x "$new_share/templates/.codex/hooks/"*.sh 2>/dev/null || true
fi

backup_share="${share_dir}.old.$$"
rm -rf "$backup_share"
if [[ -e "$share_dir" || -L "$share_dir" ]]; then
  mv "$share_dir" "$backup_share"
fi
share_replaced=1
mv "$new_share" "$share_dir"
new_share=''

new_bin="$bin_dir/mknext.tmp.$$"
shell_install_prefix=$(printf '%q' "$install_prefix")
shell_entrypoint=$(printf '%q' "$share_dir/bin/mknext")
{
  printf '#!/usr/bin/env bash\n'
  printf 'if [[ -z "${MKNEXT_INSTALL_PREFIX:-}" ]]; then export MKNEXT_INSTALL_PREFIX=%s; fi\n' "$shell_install_prefix"
  printf 'exec %s "$@"\n' "$shell_entrypoint"
} >"$new_bin"
chmod +x "$new_bin"
mv "$new_bin" "$bin_dir/mknext"
new_bin=''
rm -rf "$backup_share"
install_committed=1

printf 'Installed mknext in %s\n' "$bin_dir"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf 'Add %s to PATH.\n' "$bin_dir" ;;
esac
