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
  if [[ -L "$codex_dir" || -L "$hooks_dir" || -L "$hooks_file" || -L "$config_file" ]]; then
    log_error 'Codex guard paths cannot be symbolic links'
    return 1
  fi

  mkdir -p "$hooks_dir"
  local hook
  for hook in block-production-env-read.sh validate-production-env-guard.sh; do
    if [[ -L "$hooks_dir/$hook" ]]; then
      log_error "Codex guard hook cannot be a symbolic link: $hook"
      return 1
    fi
  done

  cp "$ROOT_DIR/templates/.codex/hooks/block-production-env-read.sh" "$hooks_dir/"
  cp "$ROOT_DIR/templates/.codex/hooks/validate-production-env-guard.sh" "$hooks_dir/"
  chmod +x "$hooks_dir/block-production-env-read.sh" "$hooks_dir/validate-production-env-guard.sh" 2>/dev/null || true

  node "$ROOT_DIR/lib/merge-codex-hooks.mjs" "$hooks_file"

  node - "$config_file" <<'NODE'
const fs = require('node:fs');
const file = process.argv[2];
let lines = fs.existsSync(file) ? fs.readFileSync(file, 'utf8').split(/\r?\n/) : [];
let inFeatures = false;
let found = false;
let seenFeatures = false;
for (let index = 0; index < lines.length; index += 1) {
  const line = lines[index];
  if (/^\s*\[features\]\s*$/.test(line)) {
    inFeatures = true;
    seenFeatures = true;
    continue;
  }
  if (/^\s*\[.*\]\s*$/.test(line)) {
    if (inFeatures && !found) lines.splice(index, 0, 'hooks = true');
    inFeatures = false;
    continue;
  }
  if (inFeatures && /^\s*(codex_)?hooks\s*=/.test(line)) {
    lines[index] = 'hooks = true';
    found = true;
  }
}
if (inFeatures && !found) lines.push('hooks = true');
if (!seenFeatures) lines.push('', '[features]', 'hooks = true');
fs.writeFileSync(file, `${lines.join('\n').replace(/\n*$/, '')}\n`);
NODE

  log_success "Appended Codex production env guard hooks to $hooks_file"
  log_info 'Codex asks you to approve these hooks on the first interactive run'
}

verify_codex_guard() {
  local target_dir=${1:-"$PWD"}
  local codex_dir="$target_dir/.codex"
  local hooks_dir="$codex_dir/hooks"
  local hooks_file="$codex_dir/hooks.json"
  local config_file="$codex_dir/config.toml"

  if [[ ! -d "$codex_dir" ]]; then
    return 0
  fi
  [[ ! -L "$codex_dir" && ! -L "$hooks_dir" && ! -L "$hooks_file" && ! -L "$config_file" ]] || return 1
  [[ ! -L "$hooks_dir/block-production-env-read.sh" ]] || return 1
  [[ ! -L "$hooks_dir/validate-production-env-guard.sh" ]] || return 1

  [[ -x "$hooks_dir/block-production-env-read.sh" ]] || return 1
  [[ -x "$hooks_dir/validate-production-env-guard.sh" ]] || return 1
  [[ -f "$hooks_file" ]] || return 1
  [[ -f "$config_file" ]] || return 1
  node - "$hooks_file" "$config_file" <<'NODE'
const fs = require('node:fs');
const hooks = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const config = fs.readFileSync(process.argv[3], 'utf8');
const commands = {
  guard: './.codex/hooks/block-production-env-read.sh',
  validate: './.codex/hooks/validate-production-env-guard.sh',
};
const hasCommand = (group, command, matcher) => (hooks.hooks?.[group] ?? []).some((entry) =>
  (matcher === undefined || entry.matcher === matcher) &&
  (entry.hooks ?? []).some((hook) => hook.type === 'command' && hook.command === command)
);
const preToolMatcher = 'Read|read_file|view_file|file_read|cat|shell_command|exec_command';
if (!hasCommand('SessionStart', commands.validate)) process.exit(1);
if (!hasCommand('PreToolUse', commands.guard, preToolMatcher)) process.exit(1);
let inFeatures = false;
let enabled = false;
for (const line of config.split(/\r?\n/)) {
  if (/^\s*\[features\]\s*$/.test(line)) {
    inFeatures = true;
    continue;
  }
  if (/^\s*\[.*\]\s*$/.test(line)) {
    inFeatures = false;
    continue;
  }
  if (inFeatures && /^\s*hooks\s*=\s*true\s*(#.*)?$/.test(line)) enabled = true;
}
if (!enabled) process.exit(1);
NODE
}
