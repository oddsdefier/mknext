#!/usr/bin/env bash

MKNEXT_CI_PIDS=()
MKNEXT_CI_NAMES=()

start_ci_job() {
  local name=$1
  shift

  log_info "START: $name"
  "$@" &
  MKNEXT_CI_PIDS+=("$!")
  MKNEXT_CI_NAMES+=("$name")
}

run_ci() {
  local index
  local failed=0
  local project_bin="$PWD/node_modules/.bin"

  [[ -f .mknext ]] || {
    log_error '.mknext project marker is missing'
    return 1
  }
  case "$MKNEXT_CONFIG_CI" in
    local|github) ;;
    *)
      log_error "unsupported CI target: $MKNEXT_CONFIG_CI"
      return 1
      ;;
  esac
  [[ -d "$project_bin" ]] || {
    log_error 'project node_modules/.bin is missing'
    return 1
  }

  if [[ -t 1 && "${MKNEXT_QUIET:-0}" -eq 0 ]]; then
    ui_banner
    log_step "Running $MKNEXT_CONFIG_CI CI quality gates in parallel..."
  fi

  case "$MKNEXT_CONFIG_CI" in
    local)
      start_ci_job lint "$project_bin/oxlint" .
      start_ci_job complexity "$project_bin/oxlint" -c oxlint.complexity.config.ts .
      start_ci_job format "$project_bin/oxfmt" --check .
      start_ci_job react-doctor "$project_bin/react-doctor" --no-score --blocking error
      start_ci_job knip "$project_bin/knip"
      start_ci_job test "$project_bin/vitest" run
      start_ci_job typecheck pnpm run typecheck
      start_ci_job audit pnpm audit
      start_ci_job gitleaks gitleaks git --redact .
      ;;
    github)
      [[ -f .github/workflows/ci.yml ]] || {
        log_error '.github/workflows/ci.yml is missing'
        return 1
      }
      start_ci_job audit pnpm audit
      start_ci_job gitleaks gitleaks git --redact .
      start_ci_job lint "$project_bin/oxlint" .
      start_ci_job complexity "$project_bin/oxlint" -c oxlint.complexity.config.ts .
      start_ci_job format "$project_bin/oxfmt" --check .
      start_ci_job react-doctor "$project_bin/react-doctor" --no-score --blocking error
      start_ci_job knip "$project_bin/knip"
      start_ci_job test "$project_bin/vitest" run
      start_ci_job typecheck pnpm run typecheck
      start_ci_job build pnpm run build
      ;;
  esac

  for index in "${!MKNEXT_CI_PIDS[@]}"; do
    if wait "${MKNEXT_CI_PIDS[$index]}"; then
      log_info "PASS: ${MKNEXT_CI_NAMES[$index]}"
    else
      log_error "check failed: ${MKNEXT_CI_NAMES[$index]}"
      failed=1
    fi
  done

  if [[ -t 1 && "${MKNEXT_QUIET:-0}" -eq 0 ]]; then
    printf '\n'
    if ((failed == 0)); then
      log_success 'All local CI checks passed!'
    else
      log_error 'One or more CI checks failed.'
    fi
  fi

  ((failed == 0))
}
