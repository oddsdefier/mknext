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
    local file basename
    while IFS= read -r -d '' file; do
      basename=${file##*/}
      case "$basename" in
        .env.example) ;;
        .env|.env.*) return 1 ;;
      esac
    done < <(git ls-files -z 2>/dev/null)
  fi
  return 0
}

check_client_secret_leaks() {
  local file
  local secret_name='(DATABASE_URL|[A-Za-z0-9_]*(SECRET|PASSWORD|PRIVATE_KEY|TOKEN|API_KEY)[A-Za-z0-9_]*)'
  local process_env='process[[:space:]]*\.[[:space:]]*env'
  local env_secret="(${process_env}[[:space:]]*\\.[[:space:]]*$secret_name|${process_env}[[:space:]]*\\[[[:space:]]*['\"]${secret_name}['\"][[:space:]]*\\])"
  local dynamic_env="${process_env}[[:space:]]*\\[[[:space:]]*[^'\"]"
  local next_public_secret='NEXT_PUBLIC_[A-Za-z0-9_]*(SECRET|PASSWORD|PRIVATE_KEY|DATABASE_URL|TOKEN|API_KEY)'

  while IFS= read -r -d '' file; do
    if grep -q -E "(['\"]use client['\"]|$next_public_secret)" "$file" 2>/dev/null; then
      if grep -q -E "$next_public_secret" "$file" 2>/dev/null; then return 1; fi
      if grep -q -E "$env_secret|$dynamic_env|\\{[^}]*${secret_name}[^}]*\\}[[:space:]]*=[[:space:]]*$process_env" "$file" 2>/dev/null; then
        return 1
      fi
    fi
  done < <(find . -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' -o -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \) \
    -not -path './node_modules/*' -not -path './.next/*' -not -path './.git/*' -print0 2>/dev/null)

  while IFS= read -r -d '' file; do
    if grep -q -E "$next_public_secret" "$file" 2>/dev/null; then return 1; fi
  done < <(find . -type f -name '.env*' -not -name '.env.example' -not -path './node_modules/*' -print0 2>/dev/null)

  if [[ -d .next/static ]] && grep -r -q -E "$secret_name|$next_public_secret" .next/static 2>/dev/null; then
    return 1
  fi
  return 0
}

check_workflow_permissions() {
  [[ -d .github/workflows ]] || return 0
  local wf
  for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [[ -f "$wf" ]] || continue
    awk '
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*$/ { next }
      $0 ~ /permissions:[[:space:]]*/ && $0 !~ /^permissions:/ { bad=1; next }
      /^permissions:[[:space:]]*$/ { found=1; block=1; next }
      /^permissions:[[:space:]]+/ {
        found=1; value=$0; sub(/^permissions:[[:space:]]*/, "", value)
        if (value !~ /^[{][[:space:]]*contents:[[:space:]]*(read|none)[[:space:]]*[}][[:space:]]*(#.*)?$/) bad=1
        next
      }
      block && /^[^[:space:]]/ { block=0 }
      block {
        if ($0 !~ /^[[:space:]]+(contents|pull-requests):[[:space:]]*(read|none|write)[[:space:]]*(#.*)?$/) bad=1
      }
      END { if (!found || bad) exit 1 }
    ' "$wf" || return 1
  done
}

check_supply_chain_delay() {
  [[ -f pnpm-workspace.yaml ]] || return 1
  grep -q -E '^minimumReleaseAge:[[:space:]]*1440([[:space:]]*#.*)?$' pnpm-workspace.yaml || return 1
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
  local rc marker='mknext safe npm/pnpm protection'
  local socket_pattern=${SOCKET_CLI_VERSION//^/\\^}
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [[ -f "$rc" ]] && grep -q "$marker" "$rc" 2>/dev/null &&
      grep -q -E "alias npm='(sfw npm|npx --yes @socketsecurity/cli@$socket_pattern npm)'" "$rc" 2>/dev/null &&
      grep -q -E "alias pnpm='(sfw pnpm|npx --yes @socketsecurity/cli@$socket_pattern pnpm)'" "$rc" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

setup_safe_install_wrapper() {
  local target_rc
  target_rc=$(detect_shell_rc)
  [[ -f "$target_rc" ]] || touch "$target_rc"

  if grep -q 'mknext safe npm/pnpm protection' "$target_rc" 2>/dev/null; then
    log_info "Safe npm/pnpm wrapper already exists in $target_rc"
    return 0
  fi
  if [[ ! -f "${target_rc}.mknext.bak" ]]; then
    cp "$target_rc" "${target_rc}.mknext.bak"
  fi

  cat >>"$target_rc" <<RC

# >>> mknext safe npm/pnpm protection (Socket.dev sfw) >>>
# Intercept and scan packages before installation to prevent malware
if command -v sfw >/dev/null 2>&1; then
  alias npm='sfw npm'
  alias pnpm='sfw pnpm'
else
  alias npm='npx --yes @socketsecurity/cli@$SOCKET_CLI_VERSION npm'
  alias pnpm='npx --yes @socketsecurity/cli@$SOCKET_CLI_VERSION pnpm'
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
    if claude_guard_requested; then
      install_claude_guard
    fi
    if has_codex_dir; then
      install_codex_guard
    fi
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
    checks+=('Shell Protection: Safe npm/pnpm wrapper configured in shell startup')
  else
    suggestions+=('Supply Chain Firewall: Safe wrapper for "pnpm install" is not active')
    suggestions+=('  Run: mknext audit --setup-safe-install')
    suggestions+=('  (Protects pnpm/npm by intercepting packages and blocking malware before install scripts execute)')
  fi

  if claude_guard_requested; then
    if ! claude_guard_dependencies_available; then
      suggestions+=('Claude Environment Guard: Install jq and realpath, plus bwrap and socat on Linux, then run "mknext sync"')
    elif verify_claude_guard; then
      checks+=('Claude Environment Guard: Production env read hooks active (.claude)')
    else
      problems+=('Claude Environment Guard: .claude directory exists but production env protection is not configured (run "mknext sync" or "mknext audit --setup-safe-install")')
      failed=1
    fi
  fi

  if has_codex_dir; then
    if verify_codex_guard; then
      checks+=('Codex Environment Guard: Production env read hooks active (.codex)')
      checks+=('Codex Environment Guard: Approve the hooks once in an interactive Codex session')
    else
      problems+=('Codex Environment Guard: .codex directory exists but production env protection is not configured (run "mknext sync" or "mknext audit --setup-safe-install")')
      failed=1
    fi
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
