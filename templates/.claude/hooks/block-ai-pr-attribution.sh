#!/bin/sh
set -eu

# Same rule as the git hooks. One source, so the lists cannot drift apart.
config="$(dirname "$0")/../../scripts/git-hooks/config.sh"
if [ ! -f "$config" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "PR command blocked: scripts/git-hooks/config.sh is missing. Run mknext sync."
    }
  }'
  exit 0
fi
. "$config"

command=$(jq -r '.tool_input.command // ""')

case "$command" in
  *"gh pr create"*|*"gh pr edit"*)
    if printf '%s\n' "$command" | grep -qE '[$`]'; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "PR command blocked: shell-expanded input cannot be inspected. Use literal arguments."
        }
      }'
      exit 0
    fi

    # Check direct command string
    if printf '%s\n' "$command" | grep -iqE "$ai_attribution_regex"; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "PR creation blocked: AI attribution detected. Remove all AI signatures, Co-Authored-By lines, and Generated-by footers from the PR body."
        }
      }'
      exit 0
    fi

    # Resolve quoted body files. Reject shell-generated bodies we cannot inspect.
    if body_file=$(PR_COMMAND="$command" node <<'NODE'
const command = process.env.PR_COMMAND ?? '';
const dynamicBody = /(?:^|\s)(?:--body|-b)(?:=|\s+)[^\n]*[$`]/;
if (dynamicBody.test(command) || /(?:^|\s)-[bF][^\s=]+/.test(command)) process.exit(2);
const bodyFlags = [...command.matchAll(/(?:^|\s)(?:--body|-b|-F|--body-file)(?:=|\s+)/g)];
if (bodyFlags.length > 1) process.exit(2);
const bodyFileFlag = /(?:^|\s)(?:-F|--body-file)(?:=|\s+)/;
if (!bodyFileFlag.test(command)) process.exit(0);
const match = command.match(/(?:^|\s)(?:-F|--body-file)(?:=|\s+)(?:"([^"]+)"|'([^']+)'|([^\s]+))/);
if (!match) process.exit(2);
const file = match[1] ?? match[2] ?? match[3];
if (file.startsWith('~') || !/^[A-Za-z0-9_./ -]+$/.test(file)) process.exit(2);
process.stdout.write(file);
NODE
    ); then
      :
    else
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "PR creation blocked: dynamic body input cannot be inspected. Use a plain body file."
        }
      }'
      exit 0
    fi

    if [ -n "$body_file" ] && { [ ! -f "$body_file" ] || grep -iqE "$ai_attribution_regex" "$body_file"; }; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "PR creation blocked: body file is missing or contains AI attribution."
        }
      }'
      exit 0
    fi
    ;;
esac
