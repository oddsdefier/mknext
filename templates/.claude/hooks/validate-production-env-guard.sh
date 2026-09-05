#!/bin/sh

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
settings_file="$project_dir/.claude/settings.local.json"
guard_hook="$script_dir/block-production-env-read.sh"

required_commands="jq realpath"
if [ "$(uname -s)" = "Linux" ]; then
  required_commands="jq realpath bwrap socat"
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

if ! jq -e --arg project_dir "$project_dir" --arg guard_hook '${CLAUDE_PROJECT_DIR}/.claude/hooks/block-production-env-read.sh' --arg validate_hook '${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-production-env-guard.sh' '
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

# The hook is also registered for Bash. Test that path, not just file_path.
for shell_command in \
  'cat .env.production.local' \
  'cat /tmp/prod.local.env' \
  'cp .env.prod.local /tmp/x'; do
  result=$(printf '{"tool_input":{"command":"%s"}}\n' "$shell_command" | "$guard_hook")
  if ! printf '%s\n' "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null; then
    echo "Production environment guard failed. Bash hook allowed: $shell_command." >&2
    exit 2
  fi
done

result=$(printf '{"tool_input":{"command":"ls -la"}}\n' | "$guard_hook")
if [ -n "$result" ]; then
  echo "Production environment guard failed. Bash hook blocked a harmless command." >&2
  exit 2
fi
