# mknext

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
