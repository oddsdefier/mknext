# mknext

## 1.2.0

### Minor Changes

- 0161953: Add Claude Code production environment guard hooks and settings synchronization to prevent Claude from reading protected `.env` files.
- 0161953: Add Codex CLI production environment guard hooks and non-destructive `.codex/hooks.json` synchronization.
- 4fad3f0: Enforce local pre-push hook and Claude PreToolUse hook to block AI attribution before push and PR creation.
- 4908c64: Add a `doctor --update` flag, keep the Claude environment guard on by default and skip it with a report when its tools are missing, add a repository CI workflow. Fix the audit workflow-permissions check, which rejected the valid inline `permissions: {contents: read}` form.
- 0161953: Add unified AGENTS.md template with strict ASD-STE100 terse output style and CLAUDE.md pointing to AGENTS.md
- 883a877: Add an `mknext uninstall` command that removes the CLI from its install prefix. Ask for confirmation before the short `mknext <name>` form creates an app. Reject a create target inside the mknext source or install directory.
- 8e4d846: Add commit message attribution stripper hook, Claude attribution suppression in settings, and pull request body AI attribution protection.

### Patch Changes

- 0161953: Ignore agent scratchpads, draft plans, specs, and temporary docs in generated `.gitignore`.
- 4908c64: Add shell linting, repository consistency checks, and the missing project files.
  
  - `tests/repo_consistency_test.sh` runs ShellCheck, compares the release pin in
    `install.sh` against `versions.env`, and compares the files shared between the
    repository root and `templates/`.
  - Repository CI now runs ShellCheck, `pnpm audit`, and Gitleaks.
  - Add `LICENSE`, `SECURITY.md`, `CONTEXT.md`, and a Dependabot config for actions.
  
  `create` now renames the branch to `main` and offers the first commit.
  
  `install.sh` and `mknext update` now clone the newest `vX.Y.Z` git tag.
  This removes `MKNEXT_RELEASE_REF` and `MKNEXT_SOURCE_SHA256`.
  Update moved to the newest release, not the commit it shipped with.
  Both commands now need `git` instead of `curl` and `sha256sum`.
  
  A release workflow now tags `main` when `VERSION` changes.

## 1.1.0

### Minor Changes

- 47d9b4c: Add Knip checks to generated apps and local and remote CI.
- 263153d: Add React Grab and replace the class utility packages with `cn`.
- bd95e13: Add the `mknext update` command for public installer updates.
- 47d9b4c: Use Base UI preset `b67ek3WsVs` with Hugeicons in generated apps.
- 0a72ebc: Add polished CLI UI with styled headers, step timers, guided prompts, health reports, the `mknext sync` command, extended CI targets (`local` and `github`), and the `mknext audit` command with automated security gates and shell safe install (`--setup-safe-install`) supply chain protection.
- 9dc2ada: Add secret scans, dependency audits, remote CI, and main branch protection setup to generated apps.
- 263153d: Enable built-in Tailwind CSS class sorting in Oxfmt.
- 47d9b4c: Update direct dependencies through pnpm when Doctor finds a healthy app.
- eaffb88: Create Next.js apps through the configurable shadcn preset template.

### Patch Changes

- 47d9b4c: Copy the standard Next.js `.gitignore` into generated apps.
- ec0bbba: Document the public one-line GitHub installer command.
- c3c4981: Fix self-update crash by using atomic swaps for installation directories.
