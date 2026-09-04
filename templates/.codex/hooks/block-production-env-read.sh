#!/bin/sh

payload=$(cat)
file_path=$(printf '%s' "$payload" | jq -r '
  .tool_input.file_path //
  .input.file_path //
  .input.path //
  .input.filePath //
  .input.command //
  .tool_input.command //
  ""
')

case "$file_path" in
  */.env.production.local|*/.env.prod.local|*/production.local.env|*/prod.local.env)
    jq -n '{
      decision: "block",
      reason: "Protected environment file. Agent cannot read .env.production.local, .env.prod.local, production.local.env, or prod.local.env.",
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "Protected environment file. Agent cannot read .env.production.local, .env.prod.local, production.local.env, or prod.local.env."
      }
    }'
    ;;
esac
