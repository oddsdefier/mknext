#!/usr/bin/env bash

has_claude_dir() {
  local target_dir=${1:-"$PWD"}
  [[ -d "$target_dir/.claude" ]]
}

install_claude_guard() {
  local target_dir=${1:-"$PWD"}
  local claude_dir="$target_dir/.claude"
  local hooks_dir="$claude_dir/hooks"
  local settings_file="$claude_dir/settings.local.json"

  if [[ ! -d "$claude_dir" ]]; then
    return 0
  fi

  mkdir -p "$hooks_dir"

  cp "$ROOT_DIR/templates/.claude/hooks/block-production-env-read.sh" "$hooks_dir/"
  cp "$ROOT_DIR/templates/.claude/hooks/validate-production-env-guard.sh" "$hooks_dir/"
  chmod +x "$hooks_dir/block-production-env-read.sh" "$hooks_dir/validate-production-env-guard.sh" 2>/dev/null || true

  node "$ROOT_DIR/lib/merge-claude-settings.mjs" "$settings_file"

  log_success "Appended Claude production env guard hooks to $settings_file"
}

verify_claude_guard() {
  local target_dir=${1:-"$PWD"}
  local claude_dir="$target_dir/.claude"
  local hooks_dir="$claude_dir/hooks"
  local settings_file="$claude_dir/settings.local.json"

  if [[ ! -d "$claude_dir" ]]; then
    return 0
  fi

  [[ -x "$hooks_dir/block-production-env-read.sh" ]] || return 1
  [[ -x "$hooks_dir/validate-production-env-guard.sh" ]] || return 1
  [[ -f "$settings_file" ]] || return 1

  grep -q 'block-production-env-read.sh' "$settings_file" 2>/dev/null || return 1
  grep -q 'Read(\*\*/\.env\.production\.local)' "$settings_file" 2>/dev/null || return 1

  return 0
}
