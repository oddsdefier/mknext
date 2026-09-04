#!/usr/bin/env sh
set -eu

. "$(git rev-parse --show-toplevel)/scripts/git-hooks/lib.sh"
. "$repo_root/scripts/git-hooks/config.sh"

commit_msg_file=${1:-}
[ -n "$commit_msg_file" ] || fail "commit-msg hook needs a commit message file"
[ -f "$commit_msg_file" ] || fail "commit message file not found: $commit_msg_file"

tmp_file="${commit_msg_file}.tmp.$$"
removed_file="${commit_msg_file}.removed.$$"
trap 'rm -f "$tmp_file" "$removed_file"' EXIT HUP INT TERM

# Drop attribution lines from the body. Keep the subject: a bad subject must
# fail below, not disappear. Removed lines go to `removed_file` so the hook can
# report them. A silent strip hides both a tool that adds the line and a commit
# that skipped the hook.
awk '
  {
    line = tolower($0)
    is_subject = NR == 1
    is_ai_line = line ~ ai_marker_regex
    if (is_subject || !is_ai_line) print
    else print > removed_file
  }
' ai_marker_regex="$ai_marker_regex" removed_file="$removed_file" "$commit_msg_file" > "$tmp_file"
mv "$tmp_file" "$commit_msg_file"

if [ -s "$removed_file" ]; then
  warn "commit-msg: removed AI/tool attribution from the commit body:"
  sed 's/^/  /' "$removed_file" >&2
  warn "Stop the tool that adds it. This hook does not run under --no-verify."
fi

rm -f "$removed_file"
trap - EXIT HUP INT TERM

message=$(head -n 1 "$commit_msg_file")

if printf '%s\n' "$message" | awk -v ai_marker_regex="$ai_marker_regex" '
  { exit(tolower($0) ~ ai_marker_regex ? 0 : 1) }
'; then
  fail "Commit subject contains AI/tool attribution. Remove it before committing."
fi

if printf '%s\n' "$message" | grep -qE '^(Merge|Revert|Bump)'; then
  exit 0
fi

conventional_regex="^(${conventional_commit_types})(\\(.+\\))?!?: .+"

if printf '%s\n' "$message" | grep -qE "$conventional_regex"; then
  exit 0
fi

cat >&2 <<EOF

Invalid commit message.

   Message: $message

   Commit messages must follow Conventional Commits:

   <type>(<scope>)?: <description>

   Allowed types:
     feat      - new feature
     fix       - bug fix
     docs      - documentation only
     style     - formatting only
     refactor  - code change that neither fixes a bug nor adds a feature
     test      - adding or correcting tests
     chore     - build process, dependencies, auxiliary tools
     ci        - CI/CD changes
     build     - build system or external dependency changes
     perf      - performance improvement

   Examples:
     feat(auth): add OAuth2 login
     fix(api): handle null response in user endpoint
     chore(deps): bump next to 16.2.6

EOF

exit 1
