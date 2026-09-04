#!/bin/sh

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
hooks_file="$project_dir/.codex/hooks.json"
guard_hook="$script_dir/block-production-env-read.sh"

required_commands="jq"
if [ "$(uname -s)" = "Linux" ]; then
  required_commands="jq bwrap socat"
fi

for command_name in $required_commands; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Production environment guard failed. Required command is missing: $command_name." >&2
    exit 2
  fi
done

if [ ! -x "$guard_hook" ]; then
  echo "Production environment guard failed. Read hook is missing or is not executable." >&2
  exit 2
fi

if [ -f "$hooks_file" ]; then
  if ! grep -q 'block-production-env-read.sh' "$hooks_file" 2>/dev/null; then
    echo "Production environment guard failed. Block hook is not registered in .codex/hooks.json." >&2
    exit 2
  fi
fi

for file_name in .env.production.local .env.prod.local production.local.env prod.local.env; do
  result=$(printf '{"tool_input":{"file_path":"%s/%s"}}\n' "$project_dir" "$file_name" | "$guard_hook")
  if ! printf '%s\n' "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny" or .decision == "block"' >/dev/null; then
    echo "Production environment guard failed. Read hook allowed: $file_name." >&2
    exit 2
  fi
done

result=$(printf '{"tool_input":{"file_path":"%s/.env.example"}}\n' "$project_dir" | "$guard_hook")
if [ -n "$result" ]; then
  echo "Production environment guard failed. Read hook blocked .env.example." >&2
  exit 2
fi
