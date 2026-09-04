#!/bin/sh
set -eu

command=$(jq -r '.tool_input.command // ""')

case "$command" in
  *"gh pr create"*|*"gh pr edit"*)
    ai_regex='((co-authored-by|signed-off-by):.*(claude|anthropic|chatgpt|codex|cursor|gemini)|(generated|written|created)[[:space:]]+(by|with)[[:space:]]+.*(claude|anthropic|chatgpt|codex|cursor|gemini)|claude(-|[[:space:]]+)(code|session)|https?://claude\.ai/code)'

    # Check direct command string
    if printf '%s\n' "$command" | grep -iqE "$ai_regex"; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "PR creation blocked: AI attribution detected. Remove all AI signatures, Co-Authored-By lines, and Generated-by footers from the PR body."
        }
      }'
      exit 0
    fi

    # Check body file if passed via -F or --body-file
    body_file=$(printf '%s\n' "$command" | sed -nE 's/.*(-F|--body-file)[ =]+([^ ]+).*/\2/p')
    if [ -n "$body_file" ] && [ -f "$body_file" ]; then
      if grep -iqE "$ai_regex" "$body_file"; then
        jq -n '{
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "PR creation blocked: AI attribution detected in body file. Remove all AI signatures, Co-Authored-By lines, and Generated-by footers from the PR body."
          }
        }'
        exit 0
      fi
    fi
    ;;
esac
