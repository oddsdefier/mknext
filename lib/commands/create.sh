#!/usr/bin/env bash

MKNEXT_CREATE_DRY_RUN=0
MKNEXT_CREATE_FORCE=0
MKNEXT_CREATE_YES=0
MKNEXT_CREATE_NAME=''
MKNEXT_CREATE_TARGET=''

set -o allexport
source "$ROOT_DIR/versions.env"
set +o allexport

copy_template_file() {
  local relative_path=$1
  local destination="$MKNEXT_CREATE_TARGET/$relative_path"

  mkdir -p "$(dirname "$destination")"
  cp "$ROOT_DIR/templates/$relative_path" "$destination"
}

run_in_app() {
  (
    cd "$MKNEXT_CREATE_TARGET"
    "$@"
  )
}

create_resolve_name() {
  local requested_name=$MKNEXT_CREATE_NAME

  case "$requested_name" in
    /*) MKNEXT_CREATE_TARGET=${requested_name%/} ;;
    *) MKNEXT_CREATE_TARGET="$PWD/${requested_name%/}" ;;
  esac

  if [[ -e "$MKNEXT_CREATE_TARGET" ]]; then
    log_error "target already exists: $MKNEXT_CREATE_TARGET"
    return 1
  fi
}

create_ensure_pnpm() {
  local pnpm_version=''

  if command -v pnpm >/dev/null 2>&1; then
    pnpm_version=$(pnpm --version)
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
  mkdir -p "$(dirname "$MKNEXT_CREATE_TARGET")"
}

create_next_app() {
  pnpm dlx "create-next-app@$CREATE_NEXT_APP_VERSION" "$MKNEXT_CREATE_TARGET" \
    --typescript \
    --tailwind \
    --no-linter \
    --app \
    --import-alias '@/*' \
    --react-compiler \
    --use-pnpm \
    --skip-install \
    --yes
  copy_template_file next.config.ts
  copy_template_file pnpm-workspace.yaml
  copy_template_file tsconfig.json
  copy_template_file .gitignore
  node "$ROOT_DIR/lib/update-package.mjs" "$MKNEXT_CREATE_TARGET" --package-manager-only
}

create_install_base_dependencies() {
  printf 'ci=%s\nmode=%s\nregion=%s\n' \
    "$MKNEXT_CONFIG_CI" \
    "$MKNEXT_CONFIG_MODE" \
    "$MKNEXT_CONFIG_REGION" >"$MKNEXT_CREATE_TARGET/.mknext"
  run_in_app pnpm install
}

create_minimum_release_config() {
  log_info 'NOTICE: minimum release age is active and non-blocking'
}

create_install_pinned_tools() {
  run_in_app pnpm add \
    "class-variance-authority@$CVA_VERSION" \
    "clsx@$CLSX_VERSION" \
    "next@$NEXT_VERSION" \
    "react@$REACT_VERSION" \
    "react-dom@$REACT_DOM_VERSION" \
    "tailwind-merge@$TAILWIND_MERGE_VERSION"
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
    "tailwindcss@$TAILWIND_VERSION" \
    "typescript@$TYPESCRIPT_VERSION" \
    "vitest@$VITEST_VERSION"
  node "$ROOT_DIR/lib/update-package.mjs" "$MKNEXT_CREATE_TARGET"
}

create_shadcn() {
  run_in_app pnpm dlx "shadcn@$SHADCN_VERSION" init --base base --preset b67ek3WsVs --yes
  copy_template_file lib/utils.ts
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
  copy_template_file .husky/pre-commit
  copy_template_file .husky/commit-msg
  chmod +x "$MKNEXT_CREATE_TARGET/.husky/pre-commit" "$MKNEXT_CREATE_TARGET/.husky/commit-msg"
}

create_changesets() {
  copy_template_file .changeset/config.json
}

create_pull_request_files() {
  copy_template_file .github/pull_request_template.md
  copy_template_file .github/workflows/ci.yml
  copy_template_file .github/workflows/strip-ai-pr-body.yml
  copy_template_file .gitleaks.toml
  copy_template_file docs/SECURITY.md
  copy_template_file scripts/configure-main-protection.sh
  chmod +x "$MKNEXT_CREATE_TARGET/scripts/configure-main-protection.sh"
}

create_agents_stub() {
  copy_template_file AGENTS.md
}

create_vercel_config() {
  copy_template_file vercel.json
  sed -i.bak "s/__MKNEXT_REGION__/$MKNEXT_CONFIG_REGION/" "$MKNEXT_CREATE_TARGET/vercel.json"
  rm "$MKNEXT_CREATE_TARGET/vercel.json.bak"
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
      [[ -n "$tailscale_ip" ]] || {
        log_error 'Tailscale did not return an IPv4 address'
        return 1
      }
      sed -i.bak "s/allowedDevOrigins: \[\]/allowedDevOrigins: ['$tailscale_ip']/" "$MKNEXT_CREATE_TARGET/next.config.ts"
      rm "$MKNEXT_CREATE_TARGET/next.config.ts.bak"
      ;;
  esac

  run_in_app pnpm exec oxfmt --write .
  log_info "Created $MKNEXT_CREATE_TARGET"
  log_info "Next: cd $MKNEXT_CREATE_TARGET && mknext doctor && mknext ci"
}

run_create_step() {
  local number=$1
  local title=$2
  local action=$3

  if ((MKNEXT_CREATE_DRY_RUN == 1)); then
    printf 'DRY RUN %02d/20 %s\n' "$number" "$title"
    return 0
  fi

  printf 'STEP %02d/20 %s\n' "$number" "$title"
  "$action"
}

run_create() {
  local project_name=$MKNEXT_CREATE_NAME

  if [[ -z "$project_name" ]]; then
    project_name=$(basename "$PWD")
  fi

  MKNEXT_CREATE_NAME=$project_name

  run_create_step 1 "Resolve project name: $project_name" create_resolve_name
  run_create_step 2 'Ensure pnpm is available' create_ensure_pnpm
  run_create_step 3 'Create the app directory and marker' create_app_directory
  run_create_step 4 'Scaffold Next.js' create_next_app
  run_create_step 5 'Install base dependencies' create_install_base_dependencies
  run_create_step 6 'Confirm the minimum release config' create_minimum_release_config
  run_create_step 7 'Apply pinned tool versions' create_install_pinned_tools
  run_create_step 8 'Add shadcn UI' create_shadcn
  run_create_step 9 'Configure oxlint and anti-slop' create_oxlint
  run_create_step 10 'Configure oxfmt' create_oxfmt
  run_create_step 11 'Add the Vitest test harness' create_vitest
  run_create_step 12 'Add react-doctor' create_react_doctor
  run_create_step 13 'Add Knip' create_knip
  run_create_step 14 'Set complexity gates' create_complexity_gates
  run_create_step 15 'Add Husky and lint-staged' create_git_hooks
  run_create_step 16 'Add Changesets' create_changesets
  run_create_step 17 'Add pull request, CI, and security files' create_pull_request_files
  run_create_step 18 'Write the AGENTS.md stub' create_agents_stub
  run_create_step 19 'Write the Vercel region' create_vercel_config
  run_create_step 20 'Configure optional Tailscale origins' create_tailscale
}
