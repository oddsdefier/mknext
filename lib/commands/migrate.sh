#!/usr/bin/env bash

MKNEXT_MIGRATE_DRY_RUN=0

run_migrate() {
  node "$ROOT_DIR/lib/migrate-package.mjs" "$PWD" "$ROOT_DIR" "$MKNEXT_MIGRATE_DRY_RUN"
}
