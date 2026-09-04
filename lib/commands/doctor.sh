#!/usr/bin/env bash

run_doctor() {
  local status=healthy

  if ! command -v node >/dev/null 2>&1; then
    printf 'problem: node is not on PATH\n'
    status=unhealthy
  fi

  if ! command -v pnpm >/dev/null 2>&1; then
    printf 'problem: pnpm is not on PATH\n'
    status=unhealthy
  fi

  if ! command -v gitleaks >/dev/null 2>&1; then
    printf 'problem: gitleaks is not on PATH\n'
    status=unhealthy
  fi

  if [[ ! -f .mknext ]]; then
    printf 'problem: .mknext project marker is missing\n'
    status=unhealthy
  fi

  if ! validate_config; then
    printf 'problem: config has an invalid value\n'
    status=unhealthy
  fi

  if [[ "$status" == healthy ]]; then
    if pnpm update --latest --save-exact --config.minimum-release-age-strict=true; then
      printf 'dependencies: updated\n'
    else
      printf 'problem: dependency update failed\n'
      status=unhealthy
    fi
  fi

  printf 'version: %s\n' "$(<"$ROOT_DIR/VERSION")"
  printf 'install: %s\n' "$ROOT_DIR"
  printf 'mode: %s\n' "$MKNEXT_CONFIG_MODE"
  printf 'ci: %s\n' "$MKNEXT_CONFIG_CI"
  printf 'region: %s\n' "$MKNEXT_CONFIG_REGION"
  printf 'status: %s\n' "$status"

  [[ "$status" == healthy ]]
}
