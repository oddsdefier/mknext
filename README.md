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

Generated apps do not use ESLint or Prettier.
Oxfmt sorts Tailwind CSS classes in markup and class helper calls.
The `cn` package merges conditional Tailwind CSS classes.
React Grab is installed as a development tool.
Their pre-commit hook scans staged changes for secrets.

## Install

Run the pinned installer:

```bash
installer=$(mktemp)
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/oddsdefier/mknext/4fad3f0814cbce114c74a272720236c1784db06c/install.sh -o "$installer"
bash "$installer"
rm "$installer"
```

The installer clones the newest release tag. Git verifies the content.

The installer prints a PATH instruction when `~/.local/bin` is not on `PATH`.

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

Synchronize project configuration, workflows, and tool pins:

```bash
mknext sync
```

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

The command stops if the target path exists.

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

Any failed check makes local CI fail.

`audit` runs an automated security gate scan across the project:

- Secret Scanning: Scans for committed secrets via Gitleaks
- Dependency Audit: Checks for known vulnerabilities using `pnpm audit`
- Environment Hygiene: Verifies no sensitive `.env*` files are tracked in Git
- Client Isolation: Ensures server secrets are never referenced in `'use client'` components
- CI Security: Validates least-privilege workflow permissions in `.github/workflows`
- Supply Chain: Verifies the 24-hour package quarantine delay (`minimumReleaseAge: 1440`)
- Shell Protection: Verifies or installs Socket.dev safe wrapper aliases (`mknext audit --setup-safe-install`) with automatic shell config backup (`~/.bashrc.mknext.bak` / `~/.zshrc.mknext.bak`)
- Claude Environment Guard: On by default; needs `jq` and `realpath`, plus `bwrap` and `socat` on Linux. Turn it off with `MKNEXT_ENABLE_CLAUDE_GUARD=0`
- Codex Environment Guard: If `.codex` is present, ensures production environment read hooks are active and non-overwritten

## Protect the GitHub repository

Each generated app has a GitHub Actions workflow. It runs dependency audits, Gitleaks, all quality checks, and the production build.

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
