#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

chmod +x "$root_dir/tests/fakes/pnpm" "$root_dir/tests/fakes/check-tool"
check_log="$test_dir/checks.log"
: >"$check_log"
export MKNEXT_CHECK_LOG="$check_log"

# Test 1: audit fails outside an mknext project
if "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
  printf 'FAIL: audit should fail without .mknext marker\n' >&2
  exit 1
fi

# Create a sample project
PATH="$root_dir/tests/fakes:$PATH" \
  "$root_dir/bin/mknext" create --name "$test_dir/app" --yes --quiet

mkdir -p "$test_dir/app/node_modules/.bin" "$test_dir/bin"
ln -s "$(command -v node)" "$test_dir/bin/node"
for tool in knip oxlint oxfmt react-doctor vitest tsc; do
  cp "$root_dir/tests/fakes/check-tool" "$test_dir/app/node_modules/.bin/$tool"
done
cp "$root_dir/tests/fakes/check-tool" "$test_dir/bin/gitleaks"

# Test 2: audit passes in a fresh valid project
(
  cd "$test_dir/app"
  PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet
)

# Test 3: audit detects tracked .env file
(
  cd "$test_dir/app"
  git init -q 2>/dev/null || true
  touch .env.local
  git add -f .env.local 2>/dev/null || true
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when .env file is tracked in git\n' >&2
    exit 1
  fi
  git rm -f --cached .env.local 2>/dev/null || true
  rm -f .env.local
)

# Test 4: all sensitive env files fail tracking checks
(
  cd "$test_dir/app"
  git init -q 2>/dev/null || true
  touch .env.test
  git add -f .env.test 2>/dev/null || true
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should reject tracked .env.test\n' >&2
    exit 1
  fi
  git rm -f --cached .env.test 2>/dev/null || true
  rm -f .env.test
)

# Test 5: safe install setup backs up and appends to shell rc
fake_home="$test_dir/fakehome"
mkdir -p "$fake_home"
printf '# original bashrc\nexport TEST=1\n' >"$fake_home/.bashrc"

(
  cd "$test_dir/app"
  HOME="$fake_home" PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --setup-safe-install --quiet
)

if [[ ! -f "$fake_home/.bashrc.mknext.bak" ]]; then
  printf 'FAIL: safe install setup did not create a backup of .bashrc\n' >&2
  exit 1
fi

grep -q 'alias npm=' "$fake_home/.bashrc"
grep -q 'alias pnpm=' "$fake_home/.bashrc"

# Test 6: client secret leak in 'use client'
(
  cd "$test_dir/app"
  mkdir -p app
  cat >app/leaky.tsx <<'TSX'
'use client';
export const config = { secret: process.env.DATABASE_URL };
TSX
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when client component references DATABASE_URL\n' >&2
    exit 1
  fi
  rm -f app/leaky.tsx
)

# Test 7: supply chain release age check
(
  cd "$test_dir/app"
  mv pnpm-workspace.yaml pnpm-workspace.yaml.bak
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when pnpm-workspace.yaml is missing\n' >&2
    exit 1
  fi
  mv pnpm-workspace.yaml.bak pnpm-workspace.yaml
)

# Test 8: NEXT_PUBLIC_ secret anti-pattern
(
  cd "$test_dir/app"
  cat >lib/env-leak.ts <<'TS'
export const token = process.env.NEXT_PUBLIC_API_SECRET;
TS
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when NEXT_PUBLIC_ secret is present\n' >&2
    exit 1
  fi
  rm -f lib/env-leak.ts
)

# Test 9: leaked secret in .next/static bundle
(
  cd "$test_dir/app"
  mkdir -p .next/static/chunks
  cat >.next/static/chunks/main.js <<'JS'
console.log(process.env.DATABASE_URL);
JS
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when .next/static contains server secret reference\n' >&2
    exit 1
  fi
  rm -rf .next
)

# Test 10: MKNEXT_ENABLE_CLAUDE_GUARD=0 skips the Claude guard
(
  cd "$test_dir/app"
  mkdir -p .claude
  MKNEXT_ENABLE_CLAUDE_GUARD=0 PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" sync --quiet
  [[ ! -e .claude/hooks/block-production-env-read.sh ]] || {
    printf 'FAIL: sync installed the Claude guard when it was turned off\n' >&2
    exit 1
  }
  MKNEXT_ENABLE_CLAUDE_GUARD=0 PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet
  rm -rf .claude
)

# Test 11: the Claude guard installs by default
(
  cd "$test_dir/app"
  mkdir -p .claude
  printf '{"model":"my-custom-model","customSetting":true,"permissions":{"deny":["Read(**/.env.production.local)","Read(**/.env.prod.local)","Read(**/production.local.env)","Read(**/prod.local.env)"]},"sandbox":{"filesystem":{"denyRead":["./**/.env.production.local","./**/.env.prod.local","./**/production.local.env","./**/prod.local.env"]}}}\n' >.claude/settings.local.json
  cp .claude/settings.local.json .claude/settings.local.json.before
  if ! missing_output=$(PATH="$test_dir/bin:$root_dir/tests/fakes:/usr/bin:/bin" \
    "$root_dir/bin/mknext" sync --quiet 2>&1); then
    printf 'FAIL: sync should survive missing Claude sandbox dependencies\n' >&2
    exit 1
  fi
  grep -q 'Skipped the Claude guard' <<<"$missing_output" || {
    printf 'FAIL: sync did not warn about missing Claude sandbox dependencies\n' >&2
    exit 1
  }
  [[ ! -e .claude/hooks/block-production-env-read.sh ]] || {
    printf 'FAIL: sync installed the Claude guard without its dependencies\n' >&2
    exit 1
  }

  PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" sync --quiet

  [[ -x .claude/hooks/block-production-env-read.sh ]] || {
    printf 'FAIL: block-production-env-read.sh is missing or not executable\n' >&2
    exit 1
  }
  [[ -x .claude/hooks/validate-production-env-guard.sh ]] || {
    printf 'FAIL: validate-production-env-guard.sh is missing or not executable\n' >&2
    exit 1
  }

  grep -q '"my-custom-model"' .claude/settings.local.json || {
    printf 'FAIL: existing settings were overwritten\n' >&2
    exit 1
  }
  grep -q 'block-production-env-read.sh' .claude/settings.local.json || {
    printf 'FAIL: hook not added to settings.local.json\n' >&2
    exit 1
  }
  if grep -Eq 'Read\(\*\*/|"\./\*\*/' .claude/settings.local.json; then
    printf 'FAIL: Claude settings still contain unsupported glob rules\n' >&2
    exit 1
  fi
  jq -e --arg project_dir "$PWD" '
    (.permissions.deny // []) as $deny |
    (.sandbox.filesystem.denyRead // []) as $sandbox_deny |
    ([
      "Read(//" + ($project_dir | ltrimstr("/")) + "/.env.production.local)",
      "Read(//" + ($project_dir | ltrimstr("/")) + "/.env.prod.local)",
      "Read(//" + ($project_dir | ltrimstr("/")) + "/production.local.env)",
      "Read(//" + ($project_dir | ltrimstr("/")) + "/prod.local.env)"
    ] - $deny | length == 0) and
    ([
      $project_dir + "/.env.production.local",
      $project_dir + "/.env.prod.local",
      $project_dir + "/production.local.env",
      $project_dir + "/prod.local.env"
    ] - $sandbox_deny | length == 0)
  ' .claude/settings.local.json >/dev/null || {
    printf 'FAIL: Claude settings missed exact protected paths\n' >&2
    exit 1
  }

  MKNEXT_ENABLE_CLAUDE_GUARD=1 PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet

  printf 'Generated by Claude\n' >'pr body.md'
  hook_output=$(printf '%s\n' '{"tool_input":{"command":"gh pr create --body-file \"pr body.md\""}}' | .claude/hooks/block-ai-pr-attribution.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook missed a quoted body file\n' >&2
    exit 1
  }
  hook_output=$(printf '%s\n' '{"tool_input":{"command":"gh pr create --body \"$(cat body.md)\""}}' | .claude/hooks/block-ai-pr-attribution.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook accepted a dynamic body\n' >&2
    exit 1
  }
  hook_output=$(printf '%s\n' '{"tool_input":{"command":"gh pr create --body \"$BODY\""}}' | .claude/hooks/block-ai-pr-attribution.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook accepted a variable body\n' >&2
    exit 1
  }
  hook_output=$(printf '%s\n' '{"tool_input":{"command":"gh pr create --body-file ~/body.md"}}' | .claude/hooks/block-ai-pr-attribution.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook accepted an expanded body path\n' >&2
    exit 1
  }
  hook_output=$(printf '%s\n' '{"tool_input":{"command":"gh pr create --body-file safe.md --body-file later.md"}}' | .claude/hooks/block-ai-pr-attribution.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook accepted multiple body sources\n' >&2
    exit 1
  }
  hook_output=$(printf '%s\n' '{"tool_input":{"command":"gh pr create -Fsafe.md -Flater.md"}}' | .claude/hooks/block-ai-pr-attribution.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook accepted attached body sources\n' >&2
    exit 1
  }
  touch .env.production.local
  ln -s .env.production.local production-link
  hook_output=$(printf '%s\n' '{"tool_input":{"file_path":"production-link"}}' | .claude/hooks/block-production-env-read.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook accepted a protected symlink alias\n' >&2
    exit 1
  }
  hook_output=$(printf '%s\n' '{"tool_input":{"file_path":".env.production.local"}}' | .claude/hooks/block-production-env-read.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook accepted a relative protected path\n' >&2
    exit 1
  }
  mkdir -p "$test_dir/failing-path"
  printf '#!/bin/sh\nexit 1\n' >"$test_dir/failing-path/realpath"
  chmod +x "$test_dir/failing-path/realpath"
  hook_output=$(printf '%s\n' '{"tool_input":{"file_path":"production-link"}}' | PATH="$test_dir/failing-path:$PATH" .claude/hooks/block-production-env-read.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Claude hook failed open after realpath failure\n' >&2
    exit 1
  }
  rm -f 'pr body.md' production-link .env.production.local
  rm -rf .claude
)

# Test 12: .codex directory without protection fails audit
(
  cd "$test_dir/app"
  mkdir -p .codex
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should fail when .codex exists without env read protection\n' >&2
    exit 1
  fi
)

# Test 13: sync configures .codex hooks and preserves user settings
(
  cd "$test_dir/app"
  printf '{"hooks":{"CustomHook":[]},"customKey":"keepMe"}\n' >.codex/hooks.json
  PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" sync --quiet

  [[ -x .codex/hooks/block-production-env-read.sh ]] || {
    printf 'FAIL: .codex block-production-env-read.sh is missing or not executable\n' >&2
    exit 1
  }
  [[ -x .codex/hooks/validate-production-env-guard.sh ]] || {
    printf 'FAIL: .codex validate-production-env-guard.sh is missing or not executable\n' >&2
    exit 1
  }

  grep -q '"keepMe"' .codex/hooks.json || {
    printf 'FAIL: existing codex hooks were overwritten\n' >&2
    exit 1
  }
  grep -q 'block-production-env-read.sh' .codex/hooks.json || {
    printf 'FAIL: hook not added to .codex/hooks.json\n' >&2
    exit 1
  }
  grep -qx 'hooks = true' .codex/config.toml || {
    printf 'FAIL: .codex/config.toml does not enable the hooks feature\n' >&2
    exit 1
  }
  if grep -q 'codex_hooks' .codex/config.toml; then
    printf 'FAIL: .codex/config.toml keeps the stale codex_hooks key\n' >&2
    exit 1
  fi
  # The self-test needs bwrap and socat on Linux. Skip it when they are absent.
  if command -v bwrap >/dev/null && command -v socat >/dev/null; then
    .codex/hooks/validate-production-env-guard.sh || {
      printf 'FAIL: Codex guard self-test failed\n' >&2
      exit 1
    }
  fi

  PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" \
    "$root_dir/bin/mknext" audit --quiet

  hook_output=$(printf '%s\n' '{"tool_input":{"command":"cat .e*"}}' | .codex/hooks/block-production-env-read.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Codex hook accepted a protected shell glob\n' >&2
    exit 1
  }
  hook_output=$(printf '%s\n' '{"tool_input":{"command":"for f in *; do cat \"$f\"; done"}}' | .codex/hooks/block-production-env-read.sh)
  grep -q '"permissionDecision": "deny"' <<<"$hook_output" || {
    printf 'FAIL: Codex hook accepted an indirect wildcard read\n' >&2
    exit 1
  }
  rm -rf .codex
)

# Test 14: broad workflow permissions fail the audit
(
  cd "$test_dir/app"
  cat >.github/workflows/unsafe.yml <<'YAML'
name: unsafe
on: push
permissions: write-all
jobs: {}
YAML
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should reject write-all workflow permissions\n' >&2
    exit 1
  fi
  rm -f .github/workflows/unsafe.yml
)

# Test 15: job permissions cannot override safe workflow permissions
(
  cd "$test_dir/app"
  cat >.github/workflows/unsafe.yml <<'YAML'
name: unsafe job
on: push
permissions:
  contents: read
jobs:
  unsafe:
    permissions:
      contents: write
    runs-on: ubuntu-latest
    steps: []
YAML
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should reject job-level permissions\n' >&2
    exit 1
  fi
  rm -f .github/workflows/unsafe.yml
)

# Test 15b: the inline permissions form passes the audit
(
  cd "$test_dir/app"
  cat >.github/workflows/inline.yml <<'YAML'
name: inline
on: push
permissions: {contents: read}
jobs: {}
YAML
  PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" audit --quiet || {
    printf 'FAIL: audit should accept inline permissions: {contents: read}\n' >&2
    exit 1
  }
  rm -f .github/workflows/inline.yml
)

# Test 16: bracket and dynamic client secret access fails
(
  cd "$test_dir/app"
  cat >app/leaky.tsx <<'TSX'
'use client';
const name = 'DATABASE_URL';
export const direct = process.env["API_KEY"];
export const dynamic = process.env[name];
TSX
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should reject bracket client secrets\n' >&2
    exit 1
  fi
  rm -f app/leaky.tsx
)

# Test 17: Codex verification requires the expected matcher
(
  cd "$test_dir/app"
  mkdir -p .codex
  PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" sync --quiet
  node -e 'const fs=require("node:fs"); const p=".codex/hooks.json"; const d=JSON.parse(fs.readFileSync(p)); const hook=d.hooks.PreToolUse.find((e)=>e.hooks?.some((h)=>h.command.includes("block-production"))); hook.matcher="Wrong"; hook.hooks[0].command="echo ./.codex/hooks/block-production-env-read.sh"; fs.writeFileSync(p,JSON.stringify(d));'
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit should reject a wrong Codex matcher\n' >&2
    exit 1
  fi
  rm -rf .codex
)

# Test 18: workflow audit rejects inline nested permissions
(
  cd "$test_dir/app"
  cat >.github/workflows/unsafe.yml <<'YAML'
name: unsafe inline job
on: push
permissions: {contents: read}
jobs: {unsafe: {permissions: write-all}}
YAML
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" audit --quiet 2>/dev/null; then
    printf 'FAIL: audit accepted inline job permissions\n' >&2
    exit 1
  fi
  rm -f .github/workflows/unsafe.yml
)

# Test 19: sync leaves linked Claude directories untouched
(
  cd "$test_dir/app"
  outside="$test_dir/outside-claude"
  mkdir -p "$outside"
  ln -s "$outside" .claude
  PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" sync --quiet
  [[ -L .claude ]] || {
    printf 'FAIL: sync changed a linked Claude directory\n' >&2
    exit 1
  }
  [[ -z $(find "$outside" -mindepth 1 -print -quit) ]] || {
    printf 'FAIL: sync wrote through a linked Claude directory\n' >&2
    exit 1
  }
  rm .claude
)

# Test 20: sync rejects linked guard hook files
(
  cd "$test_dir/app"
  outside="$test_dir/outside-hook"
  : >"$outside"
  mkdir -p .codex/hooks
  ln -s "$outside" .codex/hooks/block-production-env-read.sh
  if PATH="$test_dir/bin:$root_dir/tests/fakes:$PATH" "$root_dir/bin/mknext" sync --quiet 2>/dev/null; then
    printf 'FAIL: sync followed a linked guard hook\n' >&2
    exit 1
  fi
  [[ ! -s "$outside" ]] || {
    printf 'FAIL: sync overwrote an outside hook target\n' >&2
    exit 1
  }
  rm -rf .codex
)

printf 'PASS: mknext audit and security checks pass\n'
