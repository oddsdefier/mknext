#!/usr/bin/env bash

MKNEXT_SYNC_DRY_RUN=0
MKNEXT_SYNC_BACKUP_DIR=''

sync_assert_local_path() {
  local relative_path=$1
  local current=$PWD
  local part
  local -a parts
  IFS='/' read -r -a parts <<<"$relative_path"
  for part in "${parts[@]}"; do
    [[ -n "$part" && "$part" != '.' ]] || continue
    [[ "$part" != '..' ]] || {
      log_error "sync path leaves project: $relative_path"
      return 1
    }
    current="$current/$part"
    [[ ! -L "$current" ]] || {
      log_error "sync refuses symbolic link: $relative_path"
      return 1
    }
  done
}

sync_backup_file() {
  local file=$1
  sync_assert_local_path "$file"
  [[ -e "$file" ]] || return 0
  if [[ -L "$PWD/.mknext-sync-backups" ]]; then
    log_error 'sync backup directory cannot be a symbolic link'
    return 1
  fi
  if [[ -z "$MKNEXT_SYNC_BACKUP_DIR" ]]; then
    MKNEXT_SYNC_BACKUP_DIR="$PWD/.mknext-sync-backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
    mkdir -p "$MKNEXT_SYNC_BACKUP_DIR"
  fi
  mkdir -p "$MKNEXT_SYNC_BACKUP_DIR/$(dirname "$file" | sed 's#^./##')"
  cp -R "$file" "$MKNEXT_SYNC_BACKUP_DIR/$file"
}

sync_copy_template() {
  local relative_path=$1
  local destination="$PWD/$relative_path"

  sync_assert_local_path "$relative_path"
  if ((MKNEXT_SYNC_DRY_RUN == 1)); then
    log_info "DRY RUN sync: $relative_path"
    return 0
  fi

  if [[ -e "$destination" || -L "$destination" ]] &&
    ! cmp -s "$ROOT_DIR/templates/$relative_path" "$destination"; then
    sync_backup_file "$relative_path"
  fi
  mkdir -p "$(dirname "$destination")"
  cp "$ROOT_DIR/templates/$relative_path" "$destination"
}

sync_write_marker() {
  if ((MKNEXT_SYNC_DRY_RUN == 1)); then
    log_info 'DRY RUN sync: .mknext'
    return 0
  fi
  local marker="$PWD/.mknext.tmp.$$"
  printf 'ci=%s\nmode=%s\npreset=%s\nregion=%s\n' \
    "$MKNEXT_CONFIG_CI" "$MKNEXT_CONFIG_MODE" "$MKNEXT_CONFIG_PRESET" "$MKNEXT_CONFIG_REGION" >"$marker"
  mv "$marker" "$PWD/.mknext"
}

sync_vercel_config() {
  sync_copy_template vercel.json
  if ((MKNEXT_SYNC_DRY_RUN == 1)); then
    log_info "DRY RUN sync: set Vercel region to $MKNEXT_CONFIG_REGION"
    return 0
  fi
  sed -i.bak "s/__MKNEXT_REGION__/$MKNEXT_CONFIG_REGION/" "$PWD/vercel.json"
  rm -f "$PWD/vercel.json.bak"
}

run_sync() {
  [[ -f .mknext ]] || {
    log_error '.mknext project marker is missing'
    return 1
  }

  load_config

  if [[ -t 1 && "${MKNEXT_QUIET:-0}" -eq 0 ]]; then
    ui_banner
    log_step 'Synchronizing project files with mknext templates...'
  fi
  MKNEXT_SYNC_BACKUP_DIR=''

  sync_copy_template oxlint.config.ts
  sync_copy_template .oxfmtrc.json
  sync_copy_template vitest.config.ts
  sync_copy_template doctor.config.ts
  sync_copy_template knip.json
  sync_copy_template oxlint.complexity.config.ts
  sync_copy_template next.config.ts
  sync_copy_template pnpm-workspace.yaml
  sync_copy_template tsconfig.json
  sync_copy_template lib/utils.ts
  sync_copy_template .gitignore

  if [[ -d "$ROOT_DIR/templates/tools/oxlint/anti-slop" ]]; then
    if ((MKNEXT_SYNC_DRY_RUN == 0)); then
      sync_assert_local_path tools/oxlint/anti-slop
      if [[ -d "$PWD/tools/oxlint/anti-slop" ]]; then
        sync_backup_file tools/oxlint/anti-slop
        rm -rf "$PWD/tools/oxlint/anti-slop"
      fi
      mkdir -p "$PWD/tools/oxlint"
      cp -R "$ROOT_DIR/templates/tools/oxlint/anti-slop" "$PWD/tools/oxlint/"
    else
      log_info 'DRY RUN sync: tools/oxlint/anti-slop'
    fi
  fi

  sync_copy_template scripts/git-hooks/config.sh
  sync_copy_template scripts/git-hooks/lib.sh
  sync_copy_template scripts/git-hooks/commit-msg.sh
  sync_copy_template scripts/git-hooks/pre-push.sh
  if ((MKNEXT_SYNC_DRY_RUN == 0)); then
    chmod +x "$PWD/scripts/git-hooks/commit-msg.sh" "$PWD/scripts/git-hooks/pre-push.sh" 2>/dev/null || true
  fi

  sync_copy_template .husky/pre-commit
  sync_copy_template .husky/commit-msg
  sync_copy_template .husky/pre-push
  if ((MKNEXT_SYNC_DRY_RUN == 0)); then
    chmod +x "$PWD/.husky/pre-commit" "$PWD/.husky/commit-msg" "$PWD/.husky/pre-push" 2>/dev/null || true
  fi

  sync_copy_template .github/pull_request_template.md
  sync_copy_template .github/workflows/ci.yml
  sync_copy_template .github/workflows/pr-governance.yml
  sync_copy_template .github/workflows/strip-ai-pr-body.yml
  sync_copy_template .gitleaks.toml
  sync_copy_template docs/SECURITY.md
  sync_copy_template scripts/configure-main-protection.sh
  if ((MKNEXT_SYNC_DRY_RUN == 0)); then
    chmod +x "$PWD/scripts/configure-main-protection.sh" 2>/dev/null || true
  fi

  if claude_guard_requested "$PWD"; then
    if ((MKNEXT_SYNC_DRY_RUN == 0)); then
      if claude_guard_paths_writable "$PWD"; then
        sync_backup_file .claude/settings.local.json
      fi
      install_claude_guard "$PWD"
    else
      log_info 'DRY RUN sync: .claude hooks and settings.local.json'
    fi
  fi

  if has_codex_dir "$PWD"; then
    if ((MKNEXT_SYNC_DRY_RUN == 0)); then
      sync_backup_file .codex/hooks.json
      sync_backup_file .codex/config.toml
      install_codex_guard "$PWD"
    else
      log_info 'DRY RUN sync: .codex hooks and hooks.json'
    fi
  fi

  sync_vercel_config
  if ((MKNEXT_SYNC_DRY_RUN == 0)); then
    node "$ROOT_DIR/lib/update-package.mjs" "$PWD"
    if [[ -x "$PWD/node_modules/.bin/oxfmt" ]]; then
      "$PWD/node_modules/.bin/oxfmt" --write . >/dev/null 2>&1 || {
        log_error 'project formatter failed during sync'
        return 1
      }
    fi
    sync_write_marker
    log_success 'Project synchronized with mknext templates!'
  else
    log_info 'DRY RUN sync: update package pins and format files'
    sync_write_marker
    log_info 'Dry run complete: no project files modified.'
  fi
}
