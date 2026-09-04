#!/usr/bin/env bash

MKNEXT_SYNC_DRY_RUN=0

sync_copy_template() {
  local relative_path=$1
  local destination="$PWD/$relative_path"

  if ((MKNEXT_SYNC_DRY_RUN == 1)); then
    log_info "DRY RUN sync: $relative_path"
    return 0
  fi

  mkdir -p "$(dirname "$destination")"
  cp "$ROOT_DIR/templates/$relative_path" "$destination"
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
      mkdir -p "$PWD/tools/oxlint"
      cp -R "$ROOT_DIR/templates/tools/oxlint/anti-slop" "$PWD/tools/oxlint/"
    else
      log_info 'DRY RUN sync: tools/oxlint/anti-slop'
    fi
  fi

  sync_copy_template .husky/pre-commit
  sync_copy_template .husky/commit-msg
  if ((MKNEXT_SYNC_DRY_RUN == 0)); then
    chmod +x "$PWD/.husky/pre-commit" "$PWD/.husky/commit-msg" 2>/dev/null || true
  fi

  sync_copy_template .github/pull_request_template.md
  sync_copy_template .github/workflows/ci.yml
  sync_copy_template .github/workflows/strip-ai-pr-body.yml
  sync_copy_template .gitleaks.toml
  sync_copy_template docs/SECURITY.md
  sync_copy_template scripts/configure-main-protection.sh
  if ((MKNEXT_SYNC_DRY_RUN == 0)); then
    chmod +x "$PWD/scripts/configure-main-protection.sh" 2>/dev/null || true
  fi

  if has_claude_dir "$PWD"; then
    if ((MKNEXT_SYNC_DRY_RUN == 0)); then
      install_claude_guard "$PWD"
    else
      log_info 'DRY RUN sync: .claude hooks and settings.local.json'
    fi
  fi

  if ((MKNEXT_SYNC_DRY_RUN == 0)); then
    sync_copy_template vercel.json
    sed -i.bak "s/__MKNEXT_REGION__/$MKNEXT_CONFIG_REGION/" "$PWD/vercel.json"
    rm -f "$PWD/vercel.json.bak"
    node "$ROOT_DIR/lib/update-package.mjs" "$PWD"
    if [[ -x "$PWD/node_modules/.bin/oxfmt" ]]; then
      "$PWD/node_modules/.bin/oxfmt" --write . >/dev/null 2>&1 || true
    fi
    log_success 'Project synchronized with mknext templates!'
  else
    log_info 'Dry run complete: no project files modified.'
  fi
}
