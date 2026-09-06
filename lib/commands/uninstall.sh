#!/usr/bin/env bash

MKNEXT_UNINSTALL_YES=0

run_uninstall() {
  local prefix bin_file share_dir
  prefix=${MKNEXT_INSTALL_PREFIX:-"$HOME/.local"}
  bin_file="$prefix/bin/mknext"
  share_dir="$prefix/share/mknext"

  if [[ ! -e "$bin_file" && ! -d "$share_dir" ]]; then
    log_error "mknext is not installed in $prefix"
    return 1
  fi

  if ((MKNEXT_UNINSTALL_YES == 0)); then
    log_info 'This removes:'
    [[ -e "$bin_file" ]] && log_info "  $bin_file"
    [[ -d "$share_dir" ]] && log_info "  $share_dir"
    if ! ui_confirm 'Remove mknext?' 'N'; then
      log_info 'Cancelled.'
      return 0
    fi
  fi

  # The shell keeps this script open, so unlinking it during the run is safe.
  rm -f "$bin_file"
  rm -rf "$share_dir"
  log_success "Removed mknext from $prefix"
  log_info 'Generated apps stay unchanged.'
}
