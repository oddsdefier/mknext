#!/bin/sh

file_path=$(jq -r '.tool_input.file_path // ""')

case "$file_path" in
  */.env.production.local|*/.env.prod.local|*/production.local.env|*/prod.local.env)
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "Protected environment file. Claude cannot read .env.production.local, .env.prod.local, production.local.env, or prod.local.env."
      }
    }'
    ;;
esac
