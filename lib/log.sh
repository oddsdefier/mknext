#!/usr/bin/env bash

MKNEXT_NO_COLOR=0
MKNEXT_QUIET=0

C_RESET=''
C_BOLD=''
C_DIM=''
C_RED=''
C_GREEN=''
C_YELLOW=''
C_BLUE=''
C_MAGENTA=''
C_CYAN=''
C_GRAY=''
ICON_SUCCESS='✓'
ICON_FAIL='✖'
ICON_WARN='▲'
ICON_INFO='ℹ'
ICON_STEP='●'
ICON_ARROW='→'
ICON_QUESTION='?'

init_colors() {
  if [[ "${MKNEXT_NO_COLOR:-0}" -eq 1 || -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    C_RESET=''
    C_BOLD=''
    C_DIM=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_MAGENTA=''
    C_CYAN=''
    C_GRAY=''
    ICON_SUCCESS='✓'
    ICON_FAIL='✖'
    ICON_WARN='▲'
    ICON_INFO='ℹ'
    ICON_STEP='●'
    ICON_ARROW='→'
    ICON_QUESTION='?'
  else
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
    C_GRAY=$'\033[90m'
    ICON_SUCCESS=$'\033[32m✓\033[0m'
    ICON_FAIL=$'\033[31m✖\033[0m'
    ICON_WARN=$'\033[33m▲\033[0m'
    ICON_INFO=$'\033[34mℹ\033[0m'
    ICON_STEP=$'\033[36m●\033[0m'
    ICON_ARROW=$'\033[90m→\033[0m'
    ICON_QUESTION=$'\033[36m?\033[0m'
  fi
}

init_colors

log_info() {
  ((MKNEXT_QUIET == 1)) && return 0
  printf '%s\n' "$1"
}

log_step() {
  ((MKNEXT_QUIET == 1)) && return 0
  init_colors
  printf '%s %s%s%s\n' "$ICON_STEP" "$C_BOLD" "$1" "$C_RESET"
}

log_success() {
  ((MKNEXT_QUIET == 1)) && return 0
  init_colors
  printf '%s %s%s%s\n' "$ICON_SUCCESS" "$C_GREEN" "$1" "$C_RESET"
}

log_warn() {
  ((MKNEXT_QUIET == 1)) && return 0
  init_colors
  printf '%s %s%s%s\n' "$ICON_WARN" "$C_YELLOW" "$1" "$C_RESET"
}

log_error() {
  init_colors
  if [[ "${MKNEXT_NO_COLOR:-0}" -eq 1 || -n "${NO_COLOR:-}" || ! -t 2 ]]; then
    printf 'mknext: %s\n' "$1" >&2
  else
    printf '%s %smknext:%s %s\n' "$ICON_FAIL" "$C_RED$C_BOLD" "$C_RESET" "$1" >&2
  fi
}

ui_banner() {
  ((MKNEXT_QUIET == 1)) && return 0
  init_colors
  local version
  version=$(<"$ROOT_DIR/VERSION")
  printf '\n%s▲ mknext%s %sv%s%s — %sProduction-grade Next.js App Generator%s\n\n' \
    "$C_BOLD$C_CYAN" "$C_RESET" "$C_DIM" "$version" "$C_RESET" "$C_DIM" "$C_RESET"
}

ui_prompt() {
  local prompt_text=$1
  local default_value=${2:-}
  local var_name=$3
  local user_input=''

  init_colors
  if [[ -n "$default_value" ]]; then
    printf '%s %s%s%s %s(%s)%s: ' \
      "$ICON_QUESTION" \
      "$C_BOLD" "$prompt_text" "$C_RESET" \
      "$C_DIM" "$default_value" "$C_RESET"
  else
    printf '%s %s%s%s: ' \
      "$ICON_QUESTION" \
      "$C_BOLD" "$prompt_text" "$C_RESET"
  fi

  read -r user_input || return 1
  if [[ -z "$user_input" ]]; then
    user_input=$default_value
  fi
  printf -v "$var_name" '%s' "$user_input"
}

ui_confirm() {
  local prompt_text=$1
  local default_val=${2:-Y}
  local response=''

  init_colors
  local hint='[Y/n]'
  [[ "$default_val" =~ ^[nN] ]] && hint='[y/N]'

  printf '%s %s%s%s %s%s%s ' \
    "$ICON_QUESTION" \
    "$C_BOLD" "$prompt_text" "$C_RESET" \
    "$C_DIM" "$hint" "$C_RESET"

  read -r response || return 1
  response=${response:-$default_val}
  case "$response" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

ui_success_summary() {
  local target=$1
  local name
  name=$(basename "$target")

  init_colors
  printf '\n%s%s✔ Success!%s Created %s%s%s at %s%s%s\n\n' \
    "$C_BOLD" "$C_GREEN" "$C_RESET" \
    "$C_BOLD" "$name" "$C_RESET" \
    "$C_DIM" "$target" "$C_RESET"
  printf '%sInside that directory, you can run:%s\n\n' "$C_BOLD" "$C_RESET"
  printf '  %spnpm dev%s\n' "$C_CYAN" "$C_RESET"
  printf '    Starts the Next.js development server.\n\n'
  printf '  %smknext doctor%s\n' "$C_CYAN" "$C_RESET"
  printf '    Diagnoses environment and updates dependencies.\n\n'
  printf '  %smknext ci%s\n' "$C_CYAN" "$C_RESET"
  printf '    Runs local quality, security, and test checks.\n\n'
  printf '%sGet started:%s\n' "$C_BOLD" "$C_RESET"
  printf '  %scd %s && pnpm dev%s\n\n' "$C_CYAN" "$name" "$C_RESET"
}

ui_doctor_report() {
  local status=$1
  shift
  local checks=("$@")

  init_colors
  printf '\n%s%s▲ mknext doctor%s\n\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%sChecks:%s\n' "$C_BOLD" "$C_RESET"
  for check in "${checks[@]}"; do
    printf '  %s %s\n' "$ICON_SUCCESS" "$check"
  done
  printf '\n'
}
