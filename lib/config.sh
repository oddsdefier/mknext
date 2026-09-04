#!/usr/bin/env bash

MKNEXT_CONFIG_CI=local
MKNEXT_CONFIG_MODE=autonomous
MKNEXT_CONFIG_PRESET=b67ek3WsVs
MKNEXT_CONFIG_REGION=sin1

load_config_file() {
  local file=$1
  local key
  local value

  [[ -f "$file" ]] || return 0

  while IFS='=' read -r key value; do
    case "$key" in
      ci) MKNEXT_CONFIG_CI=$value ;;
      mode) MKNEXT_CONFIG_MODE=$value ;;
      preset) MKNEXT_CONFIG_PRESET=$value ;;
      region) MKNEXT_CONFIG_REGION=$value ;;
      ''|'#'*) ;;
    esac
  done <"$file"
}

load_config() {
  load_config_file "$HOME/.config/mknext/config"
  load_config_file "$PWD/.mknext"
}

validate_config() {
  case "$MKNEXT_CONFIG_MODE" in
    autonomous|guided) ;;
    *) return 1 ;;
  esac

  case "$MKNEXT_CONFIG_CI" in
    local|github) ;;
    *) return 1 ;;
  esac
  [[ "$MKNEXT_CONFIG_PRESET" =~ ^[A-Za-z0-9]+$ ]] || return 1
  [[ "$MKNEXT_CONFIG_REGION" =~ ^[a-z]{3}[0-9]+$ ]] || return 1
}
