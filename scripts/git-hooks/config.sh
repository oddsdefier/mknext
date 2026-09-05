#!/usr/bin/env sh

protected_push_refs='refs/heads/main refs/heads/master'
conventional_commit_types='feat|fix|docs|style|refactor|test|chore|ci|build|perf'

# One vendor list. Both regexes below build from it.
ai_vendors='ai agent|aider|anthropic|chatgpt|claude|cline|codex|copilot|cursor|gemini|github copilot|grok|openai|perplexity|replit agent|tabnine|windsurf'

# Commit messages: a vendor name has no reason to appear. Match it anywhere.
ai_marker_regex="(${ai_vendors})"

# PR bodies name tools for good reasons. Match attribution shapes only.
ai_attribution_regex="((co-authored-by|signed-off-by):.*(${ai_vendors})|(generated|written|created)[[:space:]]+(by|with)[[:space:]]+.*(${ai_vendors})|(${ai_vendors})(-|[[:space:]]+)(code|session)|https?://claude[.]ai/code|noreply@anthropic[.]com)"
