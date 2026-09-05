#!/usr/bin/env bash

has_claude_dir() {
  local target_dir=${1:-"$PWD"}
  [[ -d "$target_dir/.claude" ]]
}

# The Claude guard is on by default. Set MKNEXT_ENABLE_CLAUDE_GUARD=0 to skip it.
claude_guard_requested() {
  local target_dir=${1:-"$PWD"}
  [[ "${MKNEXT_ENABLE_CLAUDE_GUARD:-1}" != 0 ]] && has_claude_dir "$target_dir"
}

claude_guard_paths_writable() {
  local target_dir=${1:-"$PWD"}
  local claude_dir="$target_dir/.claude"
  [[ ! -L "$claude_dir" && ! -L "$claude_dir/hooks" && ! -L "$claude_dir/settings.local.json" ]]
}

claude_guard_dependencies_available() {
  local command_name
  for command_name in jq realpath; do
    command -v "$command_name" >/dev/null 2>&1 || return 1
  done
  if [[ "$(uname -s)" == Linux ]]; then
    for command_name in bwrap socat; do
      command -v "$command_name" >/dev/null 2>&1 || return 1
    done
  fi
}

install_claude_guard() {
  local target_dir=${1:-"$PWD"}
  local claude_dir="$target_dir/.claude"
  local hooks_dir="$claude_dir/hooks"
  local settings_file="$claude_dir/settings.local.json"

  if [[ ! -d "$claude_dir" ]]; then
    return 0
  fi
  if ! claude_guard_dependencies_available; then
    log_error 'Skipped the Claude guard: it needs jq and realpath, and bwrap and socat on Linux'
    return 0
  fi
  if ! claude_guard_paths_writable "$target_dir"; then
    log_error 'Skipped the Claude guard: its paths cannot be symbolic links'
    return 0
  fi

  mkdir -p "$hooks_dir"
  local hook
  for hook in block-production-env-read.sh validate-production-env-guard.sh block-ai-pr-attribution.sh; do
    if [[ -L "$hooks_dir/$hook" ]]; then
      log_error "Claude guard hook cannot be a symbolic link: $hook"
      return 1
    fi
  done

  cp "$ROOT_DIR/templates/.claude/hooks/block-production-env-read.sh" "$hooks_dir/"
  cp "$ROOT_DIR/templates/.claude/hooks/validate-production-env-guard.sh" "$hooks_dir/"
  cp "$ROOT_DIR/templates/.claude/hooks/block-ai-pr-attribution.sh" "$hooks_dir/"
  chmod +x "$hooks_dir/block-production-env-read.sh" \
           "$hooks_dir/validate-production-env-guard.sh" \
           "$hooks_dir/block-ai-pr-attribution.sh" 2>/dev/null || true

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
  claude_guard_dependencies_available || return 1
  [[ ! -L "$claude_dir" && ! -L "$hooks_dir" && ! -L "$settings_file" ]] || return 1
  [[ ! -L "$hooks_dir/block-production-env-read.sh" ]] || return 1
  [[ ! -L "$hooks_dir/validate-production-env-guard.sh" ]] || return 1
  [[ ! -L "$hooks_dir/block-ai-pr-attribution.sh" ]] || return 1

  [[ -x "$hooks_dir/block-production-env-read.sh" ]] || return 1
  [[ -x "$hooks_dir/validate-production-env-guard.sh" ]] || return 1
  [[ -f "$settings_file" ]] || return 1
node - "$settings_file" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const settingsPath = process.argv[2];
const projectDir = path.resolve(path.dirname(settingsPath), '..');
const protectedNames = [
  '.env.production.local',
  '.env.prod.local',
  'production.local.env',
  'prod.local.env',
];
const absoluteProjectPath = projectDir.replace(/^\/+/, '');
const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
const commands = {
  guard: '${CLAUDE_PROJECT_DIR}/.claude/hooks/block-production-env-read.sh',
  validate: '${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-production-env-guard.sh',
  attribution: '${CLAUDE_PROJECT_DIR}/.claude/hooks/block-ai-pr-attribution.sh',
};
const hasCommand = (group, command, matcher) => (settings.hooks?.[group] ?? []).some((entry) =>
  (!matcher || entry.matcher === matcher) && (entry.hooks ?? []).some((hook) => hook.type === 'command' && hook.command === command)
);
const denied = settings.permissions?.deny ?? [];
const sandboxDenied = settings.sandbox?.filesystem?.denyRead ?? [];
const deniedRules = protectedNames.map((name) => `Read(//${absoluteProjectPath}/${name})`);
const sandboxRules = protectedNames.map((name) => `${projectDir}/${name}`);
if (!deniedRules.every((rule) => denied.includes(rule))) process.exit(1);
if (!sandboxRules.every((rule) => sandboxDenied.includes(rule))) process.exit(1);
if (settings.sandbox?.enabled !== true || settings.sandbox?.failIfUnavailable !== true || settings.sandbox?.allowUnsandboxedCommands !== false) process.exit(1);
if (!hasCommand('SessionStart', commands.validate)) process.exit(1);
if (!hasCommand('ConfigChange', commands.validate, 'user_settings|project_settings|local_settings')) process.exit(1);
if (!hasCommand('PreToolUse', commands.guard, 'Read')) process.exit(1);
if (!hasCommand('PreToolUse', commands.attribution, 'Bash')) process.exit(1);
NODE
}
