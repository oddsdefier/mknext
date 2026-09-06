#!/usr/bin/env bash

MKNEXT_CREATE_DRY_RUN=0
MKNEXT_CREATE_FORCE=0
MKNEXT_CREATE_YES=0
MKNEXT_CREATE_NAME=''
MKNEXT_CREATE_TARGET=''
MKNEXT_CREATE_FINAL_TARGET=''
MKNEXT_SET_PRESET=0
MKNEXT_SET_REGION=0

copy_template_file() {
  local relative_path=$1
  local destination="$MKNEXT_CREATE_TARGET/$relative_path"

  mkdir -p "$(dirname "$destination")"
  cp "$ROOT_DIR/templates/$relative_path" "$destination"
}

run_in_app() {
  (
    cd "$MKNEXT_CREATE_TARGET" || exit 1
    "$@"
  )
}

create_reject_mknext_dir() {
  local dir=$1 canonical_root
  canonical_root=$(cd -P "$ROOT_DIR" && pwd)
  while [[ "$dir" != / && -n "$dir" ]]; do
    if [[ "$dir" == "$canonical_root" ]] ||
      [[ -f "$dir/bin/mknext" && -f "$dir/VERSION" && -d "$dir/templates" ]]; then
      log_error "cannot create an app inside the mknext directory: $dir"
      return 1
    fi
    dir=$(dirname "$dir")
  done
}

create_resolve_name() {
  local requested_name=$MKNEXT_CREATE_NAME
  local unresolved_target parent basename_target canonical_parent existing_parent

  [[ -n "$requested_name" && "$requested_name" != / ]] || {
    log_error 'project name cannot be empty'
    return 1
  }
  case "$requested_name" in
    /*) unresolved_target=${requested_name%/} ;;
    *) unresolved_target="$PWD/${requested_name%/}" ;;
  esac
  parent=$(dirname "$unresolved_target")
  basename_target=$(basename "$unresolved_target")
  [[ -n "$basename_target" && "$basename_target" != . && "$basename_target" != .. ]] || {
    log_error "invalid project target: $requested_name"
    return 1
  }
  # Check before mkdir, so a rejected target leaves no new directory.
  existing_parent=$parent
  while [[ ! -d "$existing_parent" && "$existing_parent" != / ]]; do
    existing_parent=$(dirname "$existing_parent")
  done
  create_reject_mknext_dir "$(cd -P "$existing_parent" && pwd)" || return 1

  mkdir -p "$parent"
  canonical_parent=$(cd -P "$parent" && pwd)
  MKNEXT_CREATE_FINAL_TARGET="$canonical_parent/$basename_target"
  MKNEXT_CREATE_TARGET="$MKNEXT_CREATE_FINAL_TARGET"

  if [[ -e "$MKNEXT_CREATE_FINAL_TARGET" || -L "$MKNEXT_CREATE_FINAL_TARGET" ]]; then
    log_error "target already exists: $MKNEXT_CREATE_FINAL_TARGET"
    return 1
  fi
}

create_ensure_pnpm() {
  local pnpm_version=''

  if command -v pnpm >/dev/null 2>&1; then
    pnpm_version=$(pnpm --version 2>/dev/null | tail -n 1 | tr -d '\r')
    if [[ "$pnpm_version" == "$PNPM_VERSION" ]]; then
      return 0
    fi
  fi

  command -v corepack >/dev/null 2>&1 || {
    log_error "pnpm $PNPM_VERSION is not on PATH and corepack is not available"
    return 1
  }
  corepack prepare "pnpm@$PNPM_VERSION" --activate
}

create_app_directory() {
  [[ ! -e "$MKNEXT_CREATE_FINAL_TARGET" && ! -L "$MKNEXT_CREATE_FINAL_TARGET" ]] || {
    log_error "target already exists: $MKNEXT_CREATE_FINAL_TARGET"
    return 1
  }
  MKNEXT_CREATE_TARGET=$(mktemp -d "${MKNEXT_CREATE_FINAL_TARGET}.mknext.XXXXXX")
  # mktemp reserves the name. shadcn refuses a destination that already exists.
  rmdir "$MKNEXT_CREATE_TARGET"
}

create_shadcn_app() {
  log_info "  → Downloading Next.js template and shadcn preset ($MKNEXT_CONFIG_PRESET)..."
  (
    cd "$(dirname "$MKNEXT_CREATE_TARGET")" || exit 1
    PNPM_CONFIG_MINIMUM_RELEASE_AGE=1440 \
      PNPM_CONFIG_MINIMUM_RELEASE_AGE_STRICT=false \
      pnpm dlx "shadcn@$SHADCN_VERSION" init \
      --preset "$MKNEXT_CONFIG_PRESET" \
      --template next \
      --name "$(basename "$MKNEXT_CREATE_TARGET")" \
      --yes
  )
  rm -f \
    "$MKNEXT_CREATE_TARGET/eslint.config.mjs" \
    "$MKNEXT_CREATE_TARGET/.prettierignore" \
    "$MKNEXT_CREATE_TARGET/.prettierrc"
  copy_template_file next.config.ts
  copy_template_file pnpm-workspace.yaml
  copy_template_file tsconfig.json
  copy_template_file .gitignore
  copy_template_file lib/utils.ts
  node "$ROOT_DIR/lib/update-package.mjs" "$MKNEXT_CREATE_TARGET" --package-manager-only
}

create_install_base_dependencies() {
  log_info '  → Resolving workspace packages and creating project marker...'
  printf 'ci=%s\nmode=%s\npreset=%s\nregion=%s\n' \
    "$MKNEXT_CONFIG_CI" \
    "$MKNEXT_CONFIG_MODE" \
    "$MKNEXT_CONFIG_PRESET" \
    "$MKNEXT_CONFIG_REGION" >"$MKNEXT_CREATE_TARGET/.mknext"
  run_in_app pnpm install
}

create_minimum_release_config() {
  log_info 'NOTICE: minimum release age is active and non-blocking'
}

create_install_pinned_tools() {
  log_info '  → Installing pinned packages (React, Next.js, Oxlint, Oxfmt, Vitest, Knip)...'
  run_in_app pnpm add \
    "class-variance-authority@$CVA_VERSION" \
    "cn@$CN_VERSION" \
    "next@$NEXT_VERSION" \
    "react@$REACT_VERSION" \
    "react-dom@$REACT_DOM_VERSION"
  run_in_app pnpm add --save-dev \
    "@changesets/cli@$CHANGESETS_VERSION" \
    "@oxlint/plugins@$OXlint_PLUGINS_VERSION" \
    "@tailwindcss/postcss@$TAILWIND_POSTCSS_VERSION" \
    "@types/node@$TYPES_NODE_VERSION" \
    "@types/react@$TYPES_REACT_VERSION" \
    "@types/react-dom@$TYPES_REACT_DOM_VERSION" \
    "@vitejs/plugin-react@$VITE_REACT_VERSION" \
    "babel-plugin-react-compiler@$REACT_COMPILER_VERSION" \
    "husky@$HUSKY_VERSION" \
    "jsdom@$JSDOM_VERSION" \
    "knip@$KNIP_VERSION" \
    "lint-staged@$LINT_STAGED_VERSION" \
    "oxfmt@$OXFMT_VERSION" \
    "oxlint@$OXlint_VERSION" \
    "react-doctor@$REACT_DOCTOR_VERSION" \
    "react-grab@$REACT_GRAB_VERSION" \
    "tailwindcss@$TAILWIND_VERSION" \
    "typescript@$TYPESCRIPT_VERSION" \
    "vitest@$VITEST_VERSION"
  node "$ROOT_DIR/lib/update-package.mjs" "$MKNEXT_CREATE_TARGET"
}

create_oxlint() {
  copy_template_file oxlint.config.ts
  mkdir -p "$MKNEXT_CREATE_TARGET/tools/oxlint"
  cp -R "$ROOT_DIR/templates/tools/oxlint/anti-slop" "$MKNEXT_CREATE_TARGET/tools/oxlint/"
}

create_oxfmt() {
  copy_template_file .oxfmtrc.json
}

create_vitest() {
  copy_template_file vitest.config.ts
  copy_template_file app/page.test.tsx
}

create_react_doctor() {
  copy_template_file doctor.config.ts
}

create_knip() {
  copy_template_file knip.json
}

create_complexity_gates() {
  copy_template_file oxlint.complexity.config.ts
}

create_git_hooks() {
  copy_template_file scripts/git-hooks/config.sh
  copy_template_file scripts/git-hooks/lib.sh
  copy_template_file scripts/git-hooks/commit-msg.sh
  copy_template_file scripts/git-hooks/pre-push.sh
  chmod +x "$MKNEXT_CREATE_TARGET/scripts/git-hooks/commit-msg.sh" "$MKNEXT_CREATE_TARGET/scripts/git-hooks/pre-push.sh"
  copy_template_file .husky/pre-commit
  copy_template_file .husky/commit-msg
  copy_template_file .husky/pre-push
  chmod +x "$MKNEXT_CREATE_TARGET/.husky/pre-commit" "$MKNEXT_CREATE_TARGET/.husky/commit-msg" "$MKNEXT_CREATE_TARGET/.husky/pre-push"
}

create_changesets() {
  copy_template_file .changeset/config.json
}

create_pull_request_files() {
  copy_template_file .github/pull_request_template.md
  copy_template_file .github/workflows/ci.yml
  copy_template_file .github/workflows/pr-governance.yml
  copy_template_file .github/workflows/strip-ai-pr-body.yml
  copy_template_file .gitleaks.toml
  copy_template_file docs/SECURITY.md
  copy_template_file scripts/configure-main-protection.sh
  chmod +x "$MKNEXT_CREATE_TARGET/scripts/configure-main-protection.sh"
  if claude_guard_requested "$MKNEXT_CREATE_TARGET"; then
    install_claude_guard "$MKNEXT_CREATE_TARGET"
  fi
  if has_codex_dir "$MKNEXT_CREATE_TARGET"; then
    install_codex_guard "$MKNEXT_CREATE_TARGET"
  fi
}

create_agents_stub() {
  copy_template_file AGENTS.md
  copy_template_file CLAUDE.md
}

create_vercel_config() {
  copy_template_file vercel.json
  sed -i.bak "s/__MKNEXT_REGION__/$MKNEXT_CONFIG_REGION/" "$MKNEXT_CREATE_TARGET/vercel.json"
  rm "$MKNEXT_CREATE_TARGET/vercel.json.bak"
}

create_commit_target() {
  [[ ! -e "$MKNEXT_CREATE_FINAL_TARGET" && ! -L "$MKNEXT_CREATE_FINAL_TARGET" ]] || {
    log_error "target appeared during creation: $MKNEXT_CREATE_FINAL_TARGET"
    return 1
  }
  mv "$MKNEXT_CREATE_TARGET" "$MKNEXT_CREATE_FINAL_TARGET"
  MKNEXT_CREATE_TARGET=$MKNEXT_CREATE_FINAL_TARGET
}

create_tailscale() {
  local answer=no
  local tailscale_ip

  if [[ "$MKNEXT_CONFIG_MODE" == guided && "$MKNEXT_CREATE_YES" -eq 0 ]]; then
    printf 'Add the current Tailscale IPv4 address to allowedDevOrigins? [y/N] '
    read -r answer
  fi

  case "$answer" in
    y|Y|yes|YES)
      command -v tailscale >/dev/null 2>&1 || {
        log_error 'tailscale is not on PATH'
        return 1
      }
      tailscale_ip=$(tailscale ip -4 | sed -n '1p')
      [[ "$tailscale_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || {
        log_error 'Tailscale did not return an IPv4 address'
        return 1
      }
      sed -i.bak "s/allowedDevOrigins: \[\]/allowedDevOrigins: ['$tailscale_ip']/" "$MKNEXT_CREATE_TARGET/next.config.ts"
      rm "$MKNEXT_CREATE_TARGET/next.config.ts.bak"
      ;;
  esac

  run_in_app pnpm exec oxfmt --write .
}

# The branch protection script, the CI workflow, and the push hook all name
# `main`. Git can default to another name, so set it here.
create_git_setup() {
  local answer=yes

  command -v git >/dev/null 2>&1 || {
    log_info 'git is not on PATH: skipped the branch and first commit'
    return 0
  }
  if ! run_in_app git rev-parse --git-dir >/dev/null 2>&1; then
    run_in_app git init --quiet
  fi
  run_in_app git branch -M main

  if [[ "$MKNEXT_CONFIG_MODE" == guided && "$MKNEXT_CREATE_YES" -eq 0 && -t 0 ]]; then
    printf 'Make the first commit on main? [Y/n] '
    read -r answer
  fi
  case "$answer" in
    n|N|no|NO) return 0 ;;
  esac

  run_in_app git add -A
  # A missing git identity must not destroy a good project. Report and continue.
  if ! run_in_app git commit --quiet -m 'chore: initial project setup'; then
    log_info 'The first commit failed. Set your git identity, then commit.'
    return 0
  fi
  log_info 'Committed the project on main'
}

create_finalize() {
  if ((MKNEXT_CREATE_DRY_RUN == 1)); then return 0; fi
  create_commit_target
  log_info "Created $MKNEXT_CREATE_FINAL_TARGET"
  log_info "Next: cd $MKNEXT_CREATE_FINAL_TARGET && mknext doctor && mknext ci"

  if [[ -t 1 && "${MKNEXT_QUIET:-0}" -eq 0 && "${MKNEXT_CREATE_DRY_RUN:-0}" -eq 0 ]]; then
    ui_success_summary "$MKNEXT_CREATE_FINAL_TARGET"
  fi
}

run_create_step() {
  local number=$1
  local title=$2
  local action=$3
  local start_time
  local end_time
  local duration

  if ((MKNEXT_CREATE_DRY_RUN == 1)); then
    printf 'DRY RUN %02d/20 %s\n' "$number" "$title"
    return 0
  fi

  if [[ "${MKNEXT_NO_COLOR:-0}" -eq 1 || -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    printf 'STEP %02d/20 %s\n' "$number" "$title"
    "$action"
    return $?
  fi

  start_time=$SECONDS
  printf '%s %sSTEP %02d/20%s %s%s%s\n' \
    "$ICON_STEP" "$C_CYAN" "$number" "$C_RESET" "$C_BOLD" "$title" "$C_RESET"
  "$action"
  local status=$?

  if ((status == 0)); then
    end_time=$SECONDS
    duration=$((end_time - start_time))
    if ((duration > 0)); then
      printf '  %s %sDone in %ds%s\n' "$ICON_ARROW" "$C_DIM" "$duration" "$C_RESET"
    fi
  fi
  return "$status"
}

create_cleanup_stage() {
  if [[ -n "${MKNEXT_CREATE_TARGET:-}" &&
    "$MKNEXT_CREATE_TARGET" != "${MKNEXT_CREATE_FINAL_TARGET:-}" &&
    -d "$MKNEXT_CREATE_TARGET" ]]; then
    rm -rf "$MKNEXT_CREATE_TARGET"
  fi
}

run_create() {
  local project_name=$MKNEXT_CREATE_NAME

  if [[ ( -t 0 && -t 1 && "$MKNEXT_CREATE_YES" -eq 0 && -z "$project_name" ) || ( "$MKNEXT_CONFIG_MODE" == guided && -t 0 && -t 1 && "$MKNEXT_CREATE_YES" -eq 0 ) ]]; then
    ui_banner

    if [[ -z "$project_name" ]]; then
      local default_name="my-app"
      while true; do
        ui_prompt "What is your project named?" "$default_name" project_name
        local target_check
        case "$project_name" in
          /*) target_check=${project_name%/} ;;
          *) target_check="$PWD/${project_name%/}" ;;
        esac
        if [[ -e "$target_check" ]]; then
          log_warn "Target already exists: $target_check. Please choose another name."
        else
          break
        fi
      done
    fi

    if [[ "$MKNEXT_CONFIG_MODE" == guided ]]; then
      if ((MKNEXT_SET_PRESET == 0)); then
        ui_prompt "shadcn preset code" "$MKNEXT_CONFIG_PRESET" MKNEXT_CONFIG_PRESET
      fi
      if ((MKNEXT_SET_REGION == 0)); then
        ui_prompt "Vercel deployment region" "$MKNEXT_CONFIG_REGION" MKNEXT_CONFIG_REGION
      fi
    fi
  fi

  if [[ -z "$project_name" ]]; then
    project_name=$(basename "$PWD")
  fi

  MKNEXT_CREATE_NAME=$project_name

  if ! validate_config; then
    log_error 'guided values have an invalid value'
    return 2
  fi

  if [[ -t 1 && "${MKNEXT_QUIET:-0}" -eq 0 && "$MKNEXT_CREATE_DRY_RUN" -eq 0 ]]; then
    ui_banner
  fi

  (
    trap create_cleanup_stage EXIT
    run_create_step 1 "Resolve project name: $project_name" create_resolve_name
    run_create_step 2 'Ensure pnpm is available' create_ensure_pnpm
    run_create_step 3 'Create the app directory and marker' create_app_directory
    run_create_step 4 'Scaffold Next.js with shadcn' create_shadcn_app
    run_create_step 5 'Install base dependencies' create_install_base_dependencies
    run_create_step 6 'Confirm the minimum release config' create_minimum_release_config
    run_create_step 7 'Apply pinned tool versions' create_install_pinned_tools
    run_create_step 8 'Configure oxlint and anti-slop' create_oxlint
    run_create_step 9 'Configure oxfmt' create_oxfmt
    run_create_step 10 'Add the Vitest test harness' create_vitest
    run_create_step 11 'Add react-doctor' create_react_doctor
    run_create_step 12 'Add Knip' create_knip
    run_create_step 13 'Set complexity gates' create_complexity_gates
    run_create_step 14 'Add Husky and lint-staged' create_git_hooks
    run_create_step 15 'Add Changesets' create_changesets
    run_create_step 16 'Add pull request, CI, and security files' create_pull_request_files
    run_create_step 17 'Write the AGENTS.md stub' create_agents_stub
    run_create_step 18 'Write the Vercel region' create_vercel_config
    run_create_step 19 'Configure optional Tailscale origins' create_tailscale
    run_create_step 20 'Set the main branch and first commit' create_git_setup
    trap - EXIT
    create_finalize
  )
}
