#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

command -v gh >/dev/null 2>&1 || {
  printf 'error: gh is not on PATH\n' >&2
  exit 1
}

repository=${1:-}
if [[ -z "$repository" ]]; then
  repository=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
fi

if [[ ! "$repository" =~ ^[^/]+/[^/]+$ ]]; then
  printf 'error: use OWNER/REPOSITORY\n' >&2
  exit 1
fi

gh api \
  --method PUT \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "repos/$repository/branches/main/protection" \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "checks": [{ "context": "security" }, { "context": "quality" }]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}

JSON

printf 'Protected main in %s\n' "$repository"
