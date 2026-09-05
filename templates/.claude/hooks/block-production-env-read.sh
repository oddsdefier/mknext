#!/bin/sh

payload=$(cat)
file_path=$(printf '%s' "$payload" | jq -r '
  .tool_input.file_path //
  .input.file_path //
  .input.path //
  .input.filePath //
  ""
')
command=$(printf '%s' "$payload" | jq -r '
  .input.command //
  .tool_input.command //
  ""
')

protected=0
if [ -n "$file_path" ]; then
  if command -v realpath >/dev/null 2>&1; then
    if canonical_path=$(realpath -m -- "$file_path" 2>/dev/null); then
      file_path=$canonical_path
    else
      protected=1
    fi
  else
    protected=1
  fi
fi

case "$file_path" in
  .env.production.local|.env.prod.local|production.local.env|prod.local.env|*/.env.production.local|*/.env.prod.local|*/production.local.env|*/prod.local.env)
    protected=1
    ;;
esac
case "$command" in
  *'.env'*|*'production'*'env'*|*'prod'*'env'*|*'env'*'production'*|*'env'*'prod'*)
    protected=1
    ;;
esac
if printf '%s\n' "$command" | grep -qE '(^|[;&|[:space:]])(cat|head|tail|grep|sed|awk|less|more|strings|xxd|cp)[[:space:]]' &&
  printf '%s\n' "$command" | grep -qE '(\*|\?|\[|\$|`|(^|[;&|[:space:]])for[[:space:]])'; then
  protected=1
fi

if [ "$protected" -eq 1 ]; then
  jq -n '{
    decision: "block",
    reason: "Protected production environment file.",
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Protected production environment file."
    }
  }'
fi
