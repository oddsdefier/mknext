# mknext v1 specification

This file defines mknext v1 behavior.

## Purpose

`mknext` creates a Next.js app with a fixed tool set.
It runs on macOS and Linux.
It uses Bash and pnpm.

## Commands

| Command | Result |
| --- | --- |
| `mknext PROJECT` | Creates a Next.js app. This is the main form. |
| `create` | Creates a Next.js app. |
| `--migrate` / `migrate` | Replaces existing ESLint and Prettier tooling. |
| `ci` | Runs local app checks. |
| `doctor` | Checks setup. `--update` updates direct dependencies. |
| `sync` | Synchronizes mknext-owned configuration, workflows, and pins. |
| `update` | Downloads and installs the pinned mknext release. |

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | The command passed. |
| `1` | The command failed. |
| `2` | The command input was not valid. |

## Modes

Autonomous mode is the default.
It uses defaults without prompts when possible.

Guided mode can ask for user input.
Both modes call the same step functions.

## Flags

| Flag | Meaning |
| --- | --- |
| `--help` | Shows help. |
| `--version` | Shows the version. |
| `--name NAME` | Sets the new app path. |
| `--mode MODE` | Sets `autonomous` or `guided`. |
| `--ci TARGET` | Sets the CI target (`local` or `github`). |
| `--preset CODE` | Sets the shadcn preset code. |
| `--region REGION` | Sets the Vercel region. |
| `--yes` | Accepts default answers. |
| `--dry-run` | Prints create steps without file changes. |
| `--update` | Updates direct dependencies. `doctor` only. |
| `--quiet` | Hides normal messages. |
| `--no-color` | Turns off colored output. |
| `--force` | Reserved for later use. It does not replace a target in v1. |

The main create form is `mknext PROJECT [options]`.
The longer `mknext create --name PROJECT [options]` form also works.

## Config

User config is at `~/.config/mknext/config`.
Project config is in `.mknext`.

The supported keys are `ci`, `mode`, `preset`, and `region`.

The config order is:

1. Command flags
2. Project config
3. User config
4. Built-in defaults

The defaults are `ci=local`, `mode=autonomous`, `preset=b67ek3WsVs`, and `region=sin1`.

## Create steps

`create` runs these 20 steps in order:

1. Resolve the app name and target path.
2. Check pnpm. Install the pinned pnpm version when corepack is available.
3. Create the target parent folder.
4. Run the pinned shadcn CLI with `--preset CODE --template next`.
5. Write `.mknext` and run the base install.
6. Keep the minimum release age active and non-blocking.
7. Install pinned packages and write package scripts.
8. Add Oxlint and anti-slop rules.
9. Add Oxfmt.
10. Add Vitest and a sample test.
11. Add React Doctor.
12. Add Knip.
13. Add Oxlint complexity checks.
14. Add Husky, staged Gitleaks scanning, and lint-staged.
15. Add Changesets.
16. Add pull request files, remote CI, Gitleaks config, security docs, and the branch protection script.
17. Add `AGENTS.md`, `CLAUDE.md`, and `CONTEXT.md`.
18. Add `vercel.json` with the selected region.
19. Offer Tailscale setup in guided mode and format the completed app.
20. Rename the branch to `main`. Offer the first commit in guided mode.

The generated app uses Next.js App Router.
It enables React Compiler.
It uses Tailwind CSS and shadcn/ui. The default preset uses Base UI and Hugeicons.

After scaffolding, the pinned shadcn CLI runs `eject --yes`.
This inlines shadcn styles and removes its CLI dependency.
This removes the vulnerable `braces` dependency chain from generated apps.
Future shadcn stylesheet updates need a manual refresh.
Existing apps can run the pinned CLI's `eject --yes` command.
`sync` preserves application styles and does not perform this migration.

The generated app does not use ESLint.
The generated app does not use Prettier.

## Lint and format rules

Oxlint is the only general linter.
The local anti-slop plugin runs through Oxlint.

Oxfmt is the only formatter.
It sorts Tailwind CSS v4 classes in markup and in `cn` and `cva` calls.
The create command formats the completed app before it exits.
lint-staged runs Oxfmt on supported staged files.

The main Oxlint config fails when complexity is above 20.
The second Oxlint config reports a warning when complexity is above 15.

React Doctor runs its own React checks.
Its high-complexity React rule uses the tool's built-in limit.
mknext does not claim that React Doctor uses the Oxlint limits.

## CI checks

`mknext ci` requires `.mknext` and `node_modules/.bin`.
It supports the `local` and `github` targets.

For `local`, it starts these checks in parallel:

1. `oxlint .`
2. `oxlint -c oxlint.complexity.config.ts .`
3. `oxfmt --check .`
4. `react-doctor --no-score --blocking error`
5. `knip`
6. `vitest run`
7. `next typegen && tsc --noEmit`
8. `pnpm audit`
9. `gitleaks git --redact .`

For `github`, it verifies `.github/workflows/ci.yml` is present and runs the full remote CI parity checks, including `pnpm run build`.

It exits with code `1` when a check fails.

React Doctor ignores `only-export-components` in `components/ui/**`.
shadcn components export variant helpers next to the component.

`mknext create` writes `metadata` in `app/layout.tsx` when the scaffold has none.
The title uses the project name.

## Migrate

`mknext --migrate` operates on the current project's `package.json`.
It does not require an `.mknext` marker.
`mknext migrate` provides the same behavior.
`--dry-run` previews migration without changes or installation.

Migration installs pinned Oxlint, Oxfmt, and the anti-slop plugin.
It preserves npm/pnpm selection and existing package-manager lockfiles.
It removes ESLint/Prettier packages and root configuration files.
It updates common lint/format scripts and inline lint-staged commands.
It preserves unrelated scripts, application dependencies, source, and supply-chain settings.
Existing successor configurations remain unchanged.
Oxfmt converts existing Prettier configuration before its removal.
Ignore files remain available to the successor tools.
Custom ESLint rules need manual review against the replacement preset.

Backups live under `.mknext-migrate-backups/`.
They contain replaced manifests, lockfiles, and configuration files.
Migration restores those files after an installation or conversion failure.
Reinstall original dependencies if an interrupted installation changed `node_modules`.
Migration rejects symbolic links in its managed paths.
It never automatically formats application source.

## Sync

`mknext sync` updates an existing mknext project to match its installed version. It updates configuration, tool settings, Git hooks, security settings, workflows, and package script pins.
It rewrites the `.mknext` marker from the resolved config values.
It keeps replaced files in `.mknext-sync-backups/`.
It supports `--dry-run` to preview changes without file modifications.
It preserves application-owned files and custom package scripts.
It never replaces `next.config.ts` or `tsconfig.json`.
It never replaces `.gitignore`, `pnpm-workspace.yaml`, or `lib/utils.ts`.

## Audit

`mknext audit` scans an mknext project for security issues and compliance:

- Gitleaks scans the repository for secrets.
- `pnpm audit` checks dependencies for known vulnerabilities.
- The audit checks whether Git tracks sensitive `.env*` files.
- It detects server secrets in `'use client'` files.
- It requires top-level `permissions` in GitHub Actions workflows.
- It checks `minimumReleaseAge: 4320` in `pnpm-workspace.yaml`.
- It checks `trustPolicy: no-downgrade` in `pnpm-workspace.yaml`.
- `--setup-safe-install` installs safe package manager wrappers and backs up shell configuration files.
- If `.claude` exists, the audit checks its production environment protection hooks.
  The check needs `jq` and `realpath`.
  On Linux, it also needs `bwrap` and `socat`.
  It reports and skips missing tools. `MKNEXT_ENABLE_CLAUDE_GUARD=0` turns it off.
- If `.codex` exists, the audit checks its production environment protection hooks.
  It sets `hooks = true` under `[features]` in `.codex/config.toml`.
  Codex asks for hook approval during the first interactive run.
  It stores the approval as a hash.
  The guard stays inactive until approval. `mknext audit` cannot check approval.
  Codex runs `PreToolUse` for shell commands only.
  The guard blocks commands, not file reads.

It exits with code `0` when all security gates pass.
It exits with code `1` when an issue is detected.
Missing pnpm or Gitleaks makes the command fail.

## Attribution protection

Generated apps block AI attribution marks in commits and pull requests.

- A `commit-msg` hook strips attribution trailers from the commit message.
- A `pre-push` hook rejects a push when a commit message still carries a mark.
- A Claude `PreToolUse` hook blocks a pull request body that carries a mark.
- A `strip-ai-pr-body` workflow removes marks from a pull request body on GitHub.

## Doctor

`mknext doctor` checks:

- Node.js on `PATH`, at `NODE_MIN_VERSION` or newer
- pnpm on `PATH`
- Gitleaks on `PATH`
- The `.mknext` marker
- Valid config values
- Direct dependency updates through pnpm when `--update` is set
- The mknext version and install path

The update uses exact versions.
It enforces the pnpm minimum release age.
It does not change the minimum-release config.

It exits with code `0` when all checks pass.
It exits with code `1` when a check fails.

## Package pins

`versions.env` is the source for pinned versions.
Pinned npm packages do not use `@latest`.
The shadcn scaffold command uses the pinned `SHADCN_VERSION` value.
Generated `package.json` dependency versions are exact.

`mknext` does not write or change `.npmrc`.
It writes `minimumReleaseAge: 4320` in `pnpm-workspace.yaml`.
It writes `minimumReleaseAgeStrict: false` so a new pinned package does not stop the install.
It writes `trustPolicy: no-downgrade` so pnpm fails when a package loses publisher trust.
It writes `trustPolicyIgnoreAfter: 43200` so old packages without trust evidence do not block installs.

Generated apps use Changesets.
They use `cn` instead of `clsx` and `tailwind-merge`.
They install React Grab as a dev dependency.
The mknext source also uses Changesets.

The source package is private.
Changesets can version the private package.
`pnpm changeset:version` copies the package version to `VERSION`.

## Installer

The public install command downloads the pinned installer:

```bash
installer=$(mktemp)
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/oddsdefier/mknext/4fad3f0814cbce114c74a272720236c1784db06c/install.sh -o "$installer"
bash "$installer"
rm "$installer"
```

`install.sh` copies mknext to a user folder.
The normal command path is `~/.local/bin/mknext`.
The program files are under `~/.local/share/mknext`.

The installer can use `MKNEXT_INSTALL_PREFIX` for a test install.

`mknext update` clones the newest release tag. Git verifies the content.
It replaces the installed program files with that release.
It keeps the active install prefix.

## Acceptance checks

The v1 build must meet these checks:

1. `mknext --help` and `mknext --version` work.
2. A dry run creates no app files.
3. A generated app has no ESLint package or config.
4. A generated app has no Prettier package or config.
5. A generated app has Oxlint, anti-slop, and Oxfmt config.
6. A generated app has Vitest and React Doctor config.
7. A generated app has Knip config and a Knip CI check.
8. A generated app has Husky, lint-staged, and Changesets files.
9. A generated app has `.mknext`, `.gitignore`, and `vercel.json`.
10. `mknext ci` uses project-local tools.
11. `mknext doctor` reports setup problems. `--update` updates direct dependencies.
12. A generated app keeps the minimum release age active and non-blocking.
13. The root Changesets command keeps `package.json` and `VERSION` in sync.
14. A generated app has Gitleaks config and local secret scanning.
15. A generated app audits dependencies in local and remote CI.
16. A generated app has remote security, quality, and build checks.
17. A generated app has a script that protects `main` with required checks and reviews.
18. A generated app uses `cn` and has React Grab as a dev dependency.
19. `mknext audit` verifies secrets, CVEs, env hygiene, client isolation, CI permissions, and supply chain rules, and supports `--setup-safe-install` with shell backups.
20. A generated app blocks AI attribution marks in commit messages and pull request bodies.
