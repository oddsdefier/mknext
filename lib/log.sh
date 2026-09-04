#!/usr/bin/env bash

MKNEXT_NO_COLOR=0
MKNEXT_QUIET=0

log_info() {
  ((MKNEXT_QUIET == 1)) && return 0
  printf '%s\n' "$1"
}

log_error() {
  printf 'mknext: %s\n' "$1" >&2
}
