#!/usr/bin/env bash

has_codex_dir() {
  local target_dir=${1:-"$PWD"}
  [[ -d "$target_dir/.codex" ]]
}

install_codex_guard() {
  local target_dir=${1:-"$PWD"}
  local codex_dir="$target_dir/.codex"
  local hooks_dir="$codex_dir/hooks"
  local hooks_file="$codex_dir/hooks.json"
  local config_file="$codex_dir/config.toml"

  if [[ ! -d "$codex_dir" ]]; then
    return 0
  fi

  mkdir -p "$hooks_dir"

  cp "$ROOT_DIR/templates/.codex/hooks/block-production-env-read.sh" "$hooks_dir/"
  cp "$ROOT_DIR/templates/.codex/hooks/validate-production-env-guard.sh" "$hooks_dir/"
  chmod +x "$hooks_dir/block-production-env-read.sh" "$hooks_dir/validate-production-env-guard.sh" 2>/dev/null || true

  node "$ROOT_DIR/lib/merge-codex-hooks.mjs" "$hooks_file"

  if [[ -f "$config_file" ]]; then
    if ! grep -q 'codex_hooks' "$config_file" 2>/dev/null; then
      printf '\n[features]\ncodex_hooks = true\n' >>"$config_file"
    fi
  fi

  log_success "Appended Codex production env guard hooks to $hooks_file"
}

verify_codex_guard() {
  local target_dir=${1:-"$PWD"}
  local codex_dir="$target_dir/.codex"
  local hooks_dir="$codex_dir/hooks"
  local hooks_file="$codex_dir/hooks.json"

  if [[ ! -d "$codex_dir" ]]; then
    return 0
  fi

  [[ -x "$hooks_dir/block-production-env-read.sh" ]] || return 1
  [[ -x "$hooks_dir/validate-production-env-guard.sh" ]] || return 1
  [[ -f "$hooks_file" ]] || return 1

  grep -q 'block-production-env-read.sh' "$hooks_file" 2>/dev/null || return 1

  return 0
}
