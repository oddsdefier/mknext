#!/usr/bin/env bash

MKNEXT_DOCTOR_UPDATE=0

run_doctor() {
  local status=healthy
  local checks=()
  local problems=()

  if ! command -v node >/dev/null 2>&1; then
    printf 'problem: node is not on PATH\n'
    status=unhealthy
    problems+=('node is not on PATH')
  else
    local node_version
    node_version=$(node --version 2>/dev/null || true)
    if ! node -e 'process.exit(Number(process.version.slice(1).split(".")[0]) < Number(process.argv[1]) ? 1 : 0)' "$NODE_MIN_VERSION"; then
      printf 'problem: Node.js %s or newer is required\n' "$NODE_MIN_VERSION"
      status=unhealthy
      problems+=("Node.js $NODE_MIN_VERSION or newer is required")
    else
      checks+=("Node.js $node_version")
    fi
  fi

  if ! command -v pnpm >/dev/null 2>&1; then
    printf 'problem: pnpm is not on PATH\n'
    status=unhealthy
    problems+=('pnpm is not on PATH')
  else
    checks+=("pnpm $(pnpm --version 2>/dev/null || echo 'installed')")
  fi

  if ! command -v gitleaks >/dev/null 2>&1; then
    printf 'problem: gitleaks is not on PATH\n'
    status=unhealthy
    problems+=('gitleaks is not on PATH')
  else
    checks+=('Gitleaks installed')
  fi

  if [[ ! -f .mknext ]]; then
    printf 'problem: .mknext project marker is missing\n'
    status=unhealthy
    problems+=('.mknext project marker is missing')
  else
    checks+=('Project marker (.mknext)')
  fi

  if ! validate_config; then
    printf 'problem: config has an invalid value\n'
    status=unhealthy
    problems+=('config has an invalid value')
  else
    checks+=('Configuration valid')
  fi

  if [[ "$status" == healthy && "$MKNEXT_DOCTOR_UPDATE" -eq 1 ]]; then
    if pnpm update --latest --save-exact --config.minimum-release-age-strict=true; then
      printf 'dependencies: updated\n'
      checks+=('Direct dependencies updated')
    else
      printf 'problem: dependency update failed\n'
      status=unhealthy
      problems+=('dependency update failed')
    fi
  elif [[ "$status" == healthy ]]; then
    printf 'dependencies: unchanged\n'
    checks+=('Direct dependencies unchanged')
  fi

  if [[ -t 1 && "${MKNEXT_QUIET:-0}" -eq 0 ]]; then
    init_colors
    printf '\n%s▲ mknext doctor%s\n\n' "$C_BOLD$C_CYAN" "$C_RESET"
    if ((${#checks[@]} > 0)); then
      printf '%sPassed checks:%s\n' "$C_BOLD" "$C_RESET"
      for check in "${checks[@]}"; do
        printf '  %s %s\n' "$ICON_SUCCESS" "$check"
      done
    fi
    if ((${#problems[@]} > 0)); then
      printf '\n%sDetected issues:%s\n' "$C_BOLD" "$C_RESET"
      for prob in "${problems[@]}"; do
        printf '  %s %s%s%s\n' "$ICON_FAIL" "$C_RED" "$prob" "$C_RESET"
      done
    fi
    printf '\n'
  fi

  printf 'version: %s\n' "$(<"$ROOT_DIR/VERSION")"
  printf 'install: %s\n' "$ROOT_DIR"
  printf 'mode: %s\n' "$MKNEXT_CONFIG_MODE"
  printf 'ci: %s\n' "$MKNEXT_CONFIG_CI"
  printf 'preset: %s\n' "$MKNEXT_CONFIG_PRESET"
  printf 'region: %s\n' "$MKNEXT_CONFIG_REGION"
  printf 'status: %s\n' "$status"

  [[ "$status" == healthy ]]
}
