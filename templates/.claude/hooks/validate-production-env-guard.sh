#!/bin/sh

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
settings_file="$project_dir/.claude/settings.local.json"
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

if ! jq -e --arg guard_hook '${CLAUDE_PROJECT_DIR}/.claude/hooks/block-production-env-read.sh' --arg validate_hook '${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-production-env-guard.sh' '
  (.permissions.deny // []) as $deny |
  (.sandbox.filesystem.denyRead // []) as $sandbox_deny |
  ([
    "Read(**/.env.production.local)",
    "Read(**/.env.prod.local)",
    "Read(**/production.local.env)",
    "Read(**/prod.local.env)"
  ] - $deny | length == 0) and
  ([
    "./**/.env.production.local",
    "./**/.env.prod.local",
    "./**/production.local.env",
    "./**/prod.local.env"
  ] - $sandbox_deny | length == 0) and
  (.sandbox.enabled == true) and
  (.sandbox.failIfUnavailable == true) and
  (.sandbox.allowUnsandboxedCommands == false) and
  any(.hooks.PreToolUse[]?;
    .matcher == "Read" and
    any(.hooks[]?; .type == "command" and .command == $guard_hook)
  ) and
  any(.hooks.SessionStart[]?;
    any(.hooks[]?; .type == "command" and .command == $validate_hook)
  ) and
  any(.hooks.ConfigChange[]?;
    .matcher == "user_settings|project_settings|local_settings" and
    any(.hooks[]?; .type == "command" and .command == $validate_hook)
  )
' "$settings_file" >/dev/null; then
  echo "Production environment guard failed. A required Claude rule is missing or invalid." >&2
  exit 2
fi

for file_name in .env.production.local .env.prod.local production.local.env prod.local.env; do
  result=$(printf '{"tool_input":{"file_path":"%s/%s"}}\n' "$project_dir" "$file_name" | "$guard_hook")
  if ! printf '%s\n' "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null; then
    echo "Production environment guard failed. Read hook allowed: $file_name." >&2
    exit 2
  fi
done

result=$(printf '{"tool_input":{"file_path":"%s/.env.example"}}\n' "$project_dir" | "$guard_hook")
if [ -n "$result" ]; then
  echo "Production environment guard failed. Read hook blocked .env.example." >&2
  exit 2
fi
