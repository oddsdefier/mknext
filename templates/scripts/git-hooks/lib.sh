#!/usr/bin/env sh
set -eu

repo_root=$(git rev-parse --show-toplevel)

cd_repo_root() {
  cd "$repo_root"
}

info() {
  printf '%s\n' "$*"
}

warn() {
  printf '%s\n' "$*" >&2
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}
