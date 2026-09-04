#!/usr/bin/env sh
set -eu

. "$(git rev-parse --show-toplevel)/scripts/git-hooks/lib.sh"
. "$repo_root/scripts/git-hooks/config.sh"

cd_repo_root

# Read ref updates from stdin: <local_ref> <local_sha> <remote_ref> <remote_sha>
while read -r local_ref local_sha remote_ref remote_sha; do
  # Ignore branch deletion (all zeros local SHA)
  case "$local_sha" in
    *[!0]*) ;;
    *) continue ;;
  esac

  # Determine range of commits being pushed
  zero_sha="0000000000000000000000000000000000000000"
  if [ "$remote_sha" = "$zero_sha" ] || [ -z "$remote_sha" ]; then
    # New branch: check commits not reachable by any remote ref
    range=$(git rev-list "$local_sha" --not --remotes 2>/dev/null || git rev-list -n 30 "$local_sha")
  else
    range=$(git rev-list "$remote_sha..$local_sha" 2>/dev/null || git rev-list -n 30 "$local_sha")
  fi

  for commit in $range; do
    msg=$(git log -1 --format=%B "$commit")
    if printf '%s\n' "$msg" | grep -iqE "$ai_marker_regex"; then
      warn "Push rejected: commit $commit contains AI/tool attribution:"
      printf '%s\n' "$msg" | grep -iE "$ai_marker_regex" >&2 || true
      fail "Strip AI attribution with git rebase before pushing."
    fi
  done
done

exit 0
