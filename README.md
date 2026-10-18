# mknext

`mknext` is a Bash command-line tool for macOS and Linux.
It creates a Next.js app with a fixed tool set.
It also checks an existing mknext app.

## Tool set

A generated app uses:

- Next.js App Router
- TypeScript
- React Compiler
- Tailwind CSS
- shadcn/ui
- Oxlint
- Anti-slop Oxlint rules
- Oxfmt
- Vitest
- React Doctor
- React Grab
- Knip
- Husky
- lint-staged
- Changesets
- Gitleaks
- GitHub Actions security and quality checks
- A `main` branch protection setup script
- Complete agent rules and project context

Generated apps do not use ESLint or Prettier.
Oxfmt sorts Tailwind CSS classes in markup and class helper calls.
The `cn` package merges conditional Tailwind CSS classes.
React Grab is installed as a development tool.
The pre-commit hook scans staged changes for secrets.

## Install

Run the pinned installer:

```bash
installer=$(mktemp)
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/oddsdefier/mknext/4fad3f0814cbce114c74a272720236c1784db06c/install.sh -o "$installer"
bash "$installer"
rm "$installer"
```

The installer clones the newest release tag. Git verifies the content.

The installer explains how to add `~/.local/bin` to `PATH` when needed.

Check the install:

```bash
~/.local/bin/mknext --version
~/.local/bin/mknext --help
```

Update an installed copy:

```bash
mknext update
```

The update command finds the newest release tag on GitHub.
It stops when that tag is already installed.
It keeps the install prefix used by the installed command.

Remove an installed copy:

```bash
mknext uninstall
```

The uninstall command asks first. Use `--yes` to skip the question.
It removes the command and its files. Generated apps stay unchanged.

Synchronize mknext-owned configuration, workflows, and tool pins:

```bash
mknext sync
```

`sync` preserves application-owned files and custom package scripts.

## Create an app

Preview all steps without file changes:

```bash
mknext my-app --dry-run --yes
```

Create the app:

```bash
mknext my-app --yes
```

Use another shadcn preset:

```bash
mknext my-app --preset PRESET_CODE --yes
```

The longer `mknext create --name my-app --yes` form also works.

The command stops if the target path already exists.

## Migrate an existing project

Run this from the existing project's directory:

```bash
mknext --migrate --dry-run
mknext --migrate
```

Migration replaces ESLint and Prettier dependencies with pinned Oxlint/Oxfmt.
It preserves npm/pnpm selection and updates common package scripts.
It preserves source files, ignore files, and supply-chain settings.
Oxfmt converts existing Prettier settings.
Existing Oxlint and Oxfmt configurations stay unchanged.
Backups keep replaced configs, package data, and lockfiles.
Find them under `.mknext-migrate-backups/`.
Migration restores project files after an installation failure.
Review custom ESLint rules manually against the backed-up configuration.
Migration does not automatically format or repair application code.

## Check an app

Run these commands from the generated app:

```bash
mknext doctor
mknext ci
mknext audit
```

`doctor` checks the command, Node.js, pnpm, Gitleaks, the project marker, and config.
Use `mknext doctor --update` to update direct dependencies.

`ci` runs these project-local tools in parallel:

- Oxlint
- The Oxlint complexity check
- Oxfmt
- React Doctor
- Knip
- Vitest
- TypeScript
- `pnpm audit`
- Gitleaks

Local CI fails if any check fails.

`audit` checks the project for security problems:

- Gitleaks scans for committed secrets.
- `pnpm audit` checks for known dependency flaws.
- The scan checks whether Git tracks sensitive `.env*` files.
- The scan checks `'use client'` components for server secrets.
- The scan checks workflow permissions in `.github/workflows`.
- The scan checks the 3-day package delay (`minimumReleaseAge: 4320`).
- The scan checks Socket.dev safe install aliases. Run `mknext audit --setup-safe-install` to install them. This command backs up shell settings to `~/.bashrc.mknext.bak` or `~/.zshrc.mknext.bak`.
- The Claude environment guard runs by default. It needs `jq` and `realpath`. On Linux, it also needs `bwrap` and `socat`. Set `MKNEXT_ENABLE_CLAUDE_GUARD=0` to turn it off.
- If `.codex` exists, the scan checks its production environment read hooks. It checks that no other hook replaced them.

## Protect the GitHub repository

Each generated app has a GitHub Actions workflow. It runs dependency audits, Gitleaks, quality checks, and the production build.

After the first workflow run, protect `main`:

```bash
./scripts/configure-main-protection.sh OWNER/REPOSITORY
```

See `docs/SECURITY.md` in the generated app for setup details.

## Config

User config is at `~/.config/mknext/config`.
Project config is in `.mknext`.

The supported keys are:

- `ci`
- `mode`
- `preset`
- `region`

Config order is:

1. Command flags
2. Project config
3. User config
4. Built-in defaults

The defaults are:

```text
ci=local
mode=autonomous
preset=b67ek3WsVs
region=sin1
```

## Supply-chain rule

`mknext doctor` does not change the minimum-release config.
pnpm can stop an install when a package is too new.
Do not bypass that check.

## Version changes

The mknext source uses Changesets.

Add a changeset:

```bash
pnpm changeset
```

Apply pending version changes:

```bash
pnpm changeset:version
```

The version command updates `package.json` and `VERSION`.

A change to `VERSION` on `main` creates the matching `vX.Y.Z` tag.
`install.sh` and `mknext update` clone the newest tag.
See [Contributing](docs/CONTRIBUTING.md) for the full release steps.

## More docs

- [Specification](docs/SPEC.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Contributing](docs/CONTRIBUTING.md)
