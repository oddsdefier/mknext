#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SOURCE_DIR=''
TEMP_DIR=''
new_share=''
backup_share=''
new_bin=''

cleanup() {
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
  if [[ -n "${new_share:-}" && -d "$new_share" ]]; then
    rm -rf "$new_share"
  fi
  if [[ -n "${backup_share:-}" && -d "$backup_share" ]]; then
    rm -rf "$backup_share"
  fi
  if [[ -n "${new_bin:-}" && -f "$new_bin" ]]; then
    rm -f "$new_bin"
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
  command -v curl >/dev/null 2>&1 || {
    printf 'mknext installer: curl is required\n' >&2
    exit 1
  }
  TEMP_DIR=$(mktemp -d)
  curl -fsSL https://github.com/oddsdefier/mknext/archive/refs/heads/main.tar.gz \
    -o "$TEMP_DIR/mknext.tar.gz"
  tar -xzf "$TEMP_DIR/mknext.tar.gz" -C "$TEMP_DIR"
  SOURCE_DIR="$TEMP_DIR/mknext-main"
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
if [[ -d "$share_dir" ]]; then
  mv "$share_dir" "$backup_share"
fi
mv "$new_share" "$share_dir"
rm -rf "$backup_share"

new_bin="$bin_dir/mknext.tmp.$$"
cat >"$new_bin" <<EOF
#!/usr/bin/env bash
export MKNEXT_INSTALL_PREFIX="\${MKNEXT_INSTALL_PREFIX:-$install_prefix}"
exec "$share_dir/bin/mknext" "\$@"
EOF
chmod +x "$new_bin"
mv "$new_bin" "$bin_dir/mknext"

printf 'Installed mknext in %s\n' "$bin_dir"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf 'Add %s to PATH.\n' "$bin_dir" ;;
esac
