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
| `ci` | Runs local app checks. |
| `doctor` | Checks setup and updates direct dependencies. |
| `update` | Downloads and installs the current mknext main branch. |

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
| `--ci TARGET` | Sets the CI target. Only `local` works in v1. |
| `--preset CODE` | Sets the shadcn preset code. |
| `--region REGION` | Sets the Vercel region. |
| `--yes` | Accepts default answers. |
| `--dry-run` | Prints create steps without file changes. |
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

`create` runs these 19 steps in order:

1. Resolve the app name and target path.
2. Check pnpm. Install the pinned pnpm version when corepack is available.
3. Create the target parent folder.
4. Run `pnpm dlx shadcn@latest init --preset CODE --template next` to create the Next.js app and add shadcn/ui.
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
17. Add the `AGENTS.md` stub.
18. Add `vercel.json` with the selected region.
19. Offer Tailscale setup in guided mode and format the completed app.

The generated app uses Next.js App Router.
It enables React Compiler.
It uses Tailwind CSS and shadcn/ui. The default preset uses Base UI and Hugeicons.

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

## Local CI

`mknext ci` requires `.mknext` and `node_modules/.bin`.
It supports the `local` target.

It starts these checks in parallel:

1. `oxlint .`
2. `oxlint -c oxlint.complexity.config.ts .`
3. `oxfmt --check .`
4. `react-doctor --no-score --blocking error`
5. `knip`
6. `vitest run`
7. `next typegen && tsc --noEmit`
8. `pnpm audit`
9. `gitleaks git --redact .`

It exits with code `1` when a check fails.

## Doctor

`mknext doctor` checks:

- Node.js on `PATH`
- pnpm on `PATH`
- Gitleaks on `PATH`
- The `.mknext` marker
- Valid config values
- Direct dependency updates through pnpm
- The mknext version and install path

The update uses exact versions.
It enforces the pnpm minimum release age.
It does not change the minimum-release config.

It exits with code `0` when all checks pass.
It exits with code `1` when a check fails.

## Package pins

`versions.env` is the source for pinned versions.
Pinned npm packages do not use `@latest`.
The shadcn scaffold command is the exception. It uses `shadcn@latest` as part of the requested template command.

`mknext` does not write or change `.npmrc`.
It writes `minimumReleaseAge: 1440` in `pnpm-workspace.yaml`.
It writes `minimumReleaseAgeStrict: false` so a new pinned package does not stop the install.

Generated apps use Changesets.
They use `cn` instead of `clsx` and `tailwind-merge`.
They install React Grab as a dev dependency.
The mknext source also uses Changesets.

The source package is private.
Changesets can version the private package.
`pnpm changeset:version` copies the package version to `VERSION`.

## Installer

The public install command is:

```bash
curl -fsSL https://raw.githubusercontent.com/oddsdefier/mknext/main/install.sh | bash
```

`install.sh` copies mknext to a user folder.
The normal command path is `~/.local/bin/mknext`.
The program files are under `~/.local/share/mknext`.

The installer can use `MKNEXT_INSTALL_PREFIX` for a test install.

`mknext update` downloads and runs the same public installer.
It replaces the installed program files with the current main branch.
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
11. `mknext doctor` reports setup problems and updates direct dependencies.
12. A generated app keeps the minimum release age active and non-blocking.
13. The root Changesets command keeps `package.json` and `VERSION` in sync.
14. A generated app has Gitleaks config and local secret scanning.
15. A generated app audits dependencies in local and remote CI.
16. A generated app has remote security, quality, and build checks.
17. A generated app has a script that protects `main` with required checks and reviews.
18. A generated app uses `cn` and has React Grab as a dev dependency.

- Replace the `AGENTS.md` stub when its full rules are approved.
