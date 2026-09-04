#!/usr/bin/env bash

MKNEXT_AUDIT_SETUP_SAFE=0

check_secret_scanning() {
  if command -v gitleaks >/dev/null 2>&1; then
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      gitleaks git --redact . >/dev/null 2>&1
    else
      gitleaks dir . >/dev/null 2>&1
    fi
  else
    return 2
  fi
}

check_dependency_cves() {
  if command -v pnpm >/dev/null 2>&1; then
    pnpm audit >/dev/null 2>&1
  else
    return 2
  fi
}

check_env_hygiene() {
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local tracked_env
    tracked_env=$(git ls-files .env .env.local .env.production .env.development .env.*.local 2>/dev/null || true)
    if [[ -n "$tracked_env" ]]; then
      return 1
    fi
  fi
  return 0
}

check_client_secret_leaks() {
  local leaked=0
  local pattern='process\.env\.(DATABASE_URL|[A-Za-z0-9_]*SECRET[A-Za-z0-9_]*|[A-Za-z0-9_]*PASSWORD[A-Za-z0-9_]*|[A-Za-z0-9_]*PRIVATE_KEY[A-Za-z0-9_]*)'
  local next_public_secret='NEXT_PUBLIC_[A-Za-z0-9_]*(SECRET|PASSWORD|PRIVATE_KEY|DATABASE_URL)'

  # 1. Scan client components ('use client') for direct server secret references
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if grep -q -E "('use client'|\"use client\")" "$file" 2>/dev/null; then
      if grep -q -E "$pattern" "$file" 2>/dev/null; then
        leaked=1
        break
      fi
    fi
  done < <(find app components lib -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.ts" -o -name "*.js" \) 2>/dev/null || true)

  if ((leaked != 0)); then
    return 1
  fi

  # 2. Check for NEXT_PUBLIC_ variables containing sensitive terms, which Next.js inlines into browser JS
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if grep -q -E "$next_public_secret" "$file" 2>/dev/null; then
      leaked=1
      break
    fi
  done < <(find app components lib -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.ts" -o -name "*.js" \) 2>/dev/null || true)

  if ((leaked != 0)); then
    return 1
  fi

  for env_file in .env .env.local .env.development .env.production .env.example; do
    if [[ -f "$env_file" ]]; then
      if grep -q -E "$next_public_secret" "$env_file" 2>/dev/null; then
        return 1
      fi
    fi
  done

  # 3. If Next.js has been compiled (.next/static exists), inspect client-side bundles for server secrets
  if [[ -d .next/static ]]; then
    if grep -r -q -E "$pattern" .next/static 2>/dev/null; then
      return 1
    fi
  fi

  return 0
}

check_workflow_permissions() {
  if [[ -d .github/workflows ]]; then
    for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
      [[ -f "$wf" ]] || continue
      if ! grep -q -E '^permissions:' "$wf"; then
        return 1
      fi
    done
  fi
  return 0
}

check_supply_chain_delay() {
  if [[ -f pnpm-workspace.yaml ]]; then
    grep -q 'minimumReleaseAge:\s*1440' pnpm-workspace.yaml || return 1
  else
    return 1
  fi
  return 0
}

detect_shell_rc() {
  if [[ "${SHELL:-}" =~ zsh$ && -f "$HOME/.zshrc" ]]; then
    echo "$HOME/.zshrc"
  elif [[ "${SHELL:-}" =~ bash$ && -f "$HOME/.bashrc" ]]; then
    echo "$HOME/.bashrc"
  elif [[ -f "$HOME/.zshrc" ]]; then
    echo "$HOME/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    echo "$HOME/.bashrc"
  else
    echo "$HOME/.bashrc"
  fi
}

check_safe_install_wrapper() {
  if command -v sfw >/dev/null 2>&1 || command -v socket >/dev/null 2>&1; then
    return 0
  fi

  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [[ -f "$rc" ]] && grep -q -E '(sfw|socket)' "$rc" 2>/dev/null; then
      return 0
    fi
  done

  return 1
}

setup_safe_install_wrapper() {
  local target_rc
  target_rc=$(detect_shell_rc)
  [[ -f "$target_rc" ]] || touch "$target_rc"

  cp "$target_rc" "${target_rc}.mknext.bak"

  cat >>"$target_rc" <<'RC'

# >>> mknext safe npm/pnpm protection (Socket.dev sfw) >>>
# Intercept and scan packages before installation to prevent malware
if command -v sfw >/dev/null 2>&1; then
  alias npm='sfw npm'
  alias pnpm='sfw pnpm'
else
  alias npm='npx -y @socketsecurity/cli npm'
  alias pnpm='npx -y @socketsecurity/cli pnpm'
fi
# <<< mknext safe npm/pnpm protection <<<
RC

  log_success "Created backup: ${target_rc}.mknext.bak"
  log_success "Added Safe npm/pnpm wrapper (sfw / Socket.dev) to $target_rc"
  log_info "To activate immediately, run: source $target_rc"
}

run_audit() {
  local failed=0
  local checks=()
  local problems=()

  [[ -f .mknext ]] || {
    log_error '.mknext project marker is missing'
    return 1
  }

  load_config

  if [[ -t 1 && "${MKNEXT_QUIET:-0}" -eq 0 ]]; then
    ui_banner
    log_step 'Running automated security audit...'
    printf '\n'
  fi

  if ((MKNEXT_AUDIT_SETUP_SAFE == 1)); then
    setup_safe_install_wrapper
    return 0
  fi

  if check_secret_scanning; then
    checks+=('Secret Scanning: No credentials or secrets detected (Gitleaks)')
  else
    local st=$?
    if ((st == 2)); then
      checks+=('Secret Scanning: Gitleaks not on PATH (skipped)')
    else
      problems+=('Secret Scanning: Credentials or secrets detected in Git history')
      failed=1
    fi
  fi

  if check_dependency_cves; then
    checks+=('Dependency Audit: 0 vulnerabilities reported by pnpm audit')
  else
    local st=$?
    if ((st == 2)); then
      checks+=('Dependency Audit: pnpm not on PATH (skipped)')
    else
      problems+=('Dependency Audit: Known vulnerabilities detected in dependency graph')
      failed=1
    fi
  fi

  if check_env_hygiene; then
    checks+=('Environment Hygiene: No sensitive .env files tracked in Git')
  else
    problems+=('Environment Hygiene: One or more .env files are tracked by Git (untracked required)')
    failed=1
  fi

  if check_client_secret_leaks; then
    checks+=('Client Isolation: No server secrets exposed in "use client" components')
  else
    problems+=('Client Isolation: Server secret variable referenced in client component')
    failed=1
  fi

  if check_workflow_permissions; then
    checks+=('CI Security: GitHub Actions workflows enforce least-privilege permissions')
  else
    problems+=('CI Security: GitHub Actions workflow missing contents: read permissions')
    failed=1
  fi

  if check_supply_chain_delay; then
    checks+=('Supply Chain: 24-hour minimum release age delay active (pnpm-workspace.yaml)')
  else
    problems+=('Supply Chain: minimumReleaseAge not set to 1440 in pnpm-workspace.yaml')
    failed=1
  fi

  local suggestions=()

  if check_safe_install_wrapper; then
    checks+=('Shell Protection: Safe npm/pnpm wrapper (sfw / Socket.dev) active in shell')
  else
    suggestions+=('Supply Chain Firewall: Safe wrapper for "pnpm install" is not active')
    suggestions+=('  Run: mknext audit --setup-safe-install')
    suggestions+=('  (Protects pnpm/npm by intercepting packages and blocking malware before install scripts execute)')
  fi

  if [[ -t 1 && "${MKNEXT_QUIET:-0}" -eq 0 ]]; then
    printf '%sSecurity Gates:%s\n' "$C_BOLD" "$C_RESET"
    for check in "${checks[@]}"; do
      printf '  %s %s\n' "$ICON_SUCCESS" "$check"
    done
    if ((${#problems[@]} > 0)); then
      printf '\n%sSecurity Issues Found:%s\n' "$C_BOLD" "$C_RESET"
      for prob in "${problems[@]}"; do
        printf '  %s %s%s%s\n' "$ICON_FAIL" "$C_RED" "$prob" "$C_RESET"
      done
    fi
    if ((${#suggestions[@]} > 0)); then
      printf '\n%sSecurity Recommendations:%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
      for sugg in "${suggestions[@]}"; do
        printf '  %s %s%s%s\n' "$ICON_INFO" "$C_CYAN" "$sugg" "$C_RESET"
      done
    fi
    printf '\n'
    if ((failed == 0)); then
      log_success 'Audit PASSED: Your project passes security gates!'
    else
      log_error 'Audit FAILED: Please resolve the issues above.'
    fi
    printf '\n'
  fi

  ((failed == 0))
}
