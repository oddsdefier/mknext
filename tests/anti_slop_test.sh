#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "$root_dir/.anti-slop-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
config="$root_dir/tests/anti-slop.config.ts"

cat >"$test_dir/violations.ts" <<'TS'
import { vi } from 'vitest';

const mocker = vi;
mocker.mock('./service');

const enabled = true;
export const options = { ...(enabled ? ({}) : { value: 1 }) };

export function parse(value: (unknown)): string {
  return String(value);
}

export function nested(): void {
  type Result = unknown;
  const read = (): Result => 'value';
  void read;
}

TS

cat >"$test_dir/duplicate.ts" <<'TS'
export const duplicate: object = {} as object;
TS

set +o errexit
output=$(cd "$root_dir" && pnpm exec oxlint --config "$config" "$test_dir/violations.ts" 2>&1)
status=$?
set -o errexit
[[ $status -ne 0 ]] || {
  printf 'FAIL: anti-slop violations passed linting\n' >&2
  exit 1
}
for rule in \
  no-module-mocking \
  no-conditional-empty-object-spread \
  no-unknown-parameters \
  no-unknown-returns \
  no-known-value-widening; do
  grep -q "anti-slop($rule)" <<<"$output" || {
    printf 'FAIL: %s behavior was not reported\n%s\n' "$rule" "$output" >&2
    exit 1
  }
done
set +o errexit
duplicate_output=$(cd "$root_dir" && pnpm exec oxlint --config "$config" "$test_dir/duplicate.ts" 2>&1)
duplicate_status=$?
set -o errexit
[[ $duplicate_status -ne 0 ]] || {
  printf 'FAIL: widening expression passed linting\n' >&2
  exit 1
}
count=$(grep -c 'anti-slop(no-known-value-widening)' <<<"$duplicate_output")
[[ $count -eq 1 ]] || {
  printf 'FAIL: widening expression produced %s reports\n' "$count" >&2
  exit 1
}

cat >"$test_dir/valid.ts" <<'TS'
type Promise<T> = { value: T };

export function customPromise(): Promise<unknown> {
  return { value: 'unparsed' };
}

export function parse(cause: (unknown)): string {
  return String(cause);
}
TS

(cd "$root_dir" && pnpm exec oxlint --config "$config" "$test_dir/valid.ts")

printf 'PASS: anti-slop rules enforce reviewed behavior\n'
