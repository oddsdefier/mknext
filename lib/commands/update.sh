#!/usr/bin/env bash

run_update() {
  command -v git >/dev/null 2>&1 || {
    log_error 'git is required to update mknext'
    return 1
  }

  log_step 'Reading the newest mknext release tag from GitHub...'

  local temp_dir source_tag source_dir installed_version
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' RETURN

  source_tag=${MKNEXT_UPDATE_RELEASE_TAG:-}
  if [[ -z "$source_tag" ]]; then
    source_tag=$(git ls-remote --tags --refs --sort=-v:refname \
      "$MKNEXT_SOURCE_REPOSITORY" 'v*' | head -n 1 | sed 's|.*refs/tags/||') || true
  fi
  [[ "$source_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    log_error 'no mknext release tag was found'
    return 1
  }

  installed_version=$(cat "$ROOT_DIR/VERSION" 2>/dev/null || echo '')
  if [[ "$source_tag" == "v$installed_version" ]]; then
    log_success "mknext $installed_version is already the newest release"
    return 0
  fi

  # Git compares the content against the commit hash. That replaces the
  # separate archive checksum this command used before.
  log_step "Downloading mknext $source_tag..."
  if ! git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$source_tag" \
    "$MKNEXT_SOURCE_REPOSITORY" "$temp_dir/mknext"; then
    log_error 'update download failed'
    return 1
  fi
  source_dir="$temp_dir/mknext"

  if ! MKNEXT_INSTALL_PREFIX="${MKNEXT_INSTALL_PREFIX:-}" "$source_dir/install.sh"; then
    log_error 'update installation failed'
    return 1
  fi

  log_success "mknext is updated to $source_tag"
}
