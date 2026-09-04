#!/usr/bin/env bash

run_update() {
  command -v curl >/dev/null 2>&1 || {
    log_error 'curl is required to update mknext'
    return 1
  }

  if ! curl -fsSL https://raw.githubusercontent.com/oddsdefier/mknext/main/install.sh | bash; then
    log_error 'update failed'
    return 1
  fi
}
