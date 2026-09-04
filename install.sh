#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SOURCE_DIR=''
TEMP_DIR=''

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
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

mkdir -p "$bin_dir" "$share_dir"
cp "$SOURCE_DIR/VERSION" "$SOURCE_DIR/versions.env" "$share_dir/"
cp -R "$SOURCE_DIR/bin" "$SOURCE_DIR/lib" "$SOURCE_DIR/templates" "$share_dir/"

cat >"$bin_dir/mknext" <<EOF
#!/usr/bin/env bash
export MKNEXT_INSTALL_PREFIX="\${MKNEXT_INSTALL_PREFIX:-$install_prefix}"
exec "$share_dir/bin/mknext" "\$@"
EOF
chmod +x "$bin_dir/mknext" "$share_dir/bin/mknext"

printf 'Installed mknext in %s\n' "$bin_dir"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf 'Add %s to PATH.\n' "$bin_dir" ;;
esac
