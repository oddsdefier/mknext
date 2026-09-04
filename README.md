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
- Knip
- Husky
- lint-staged
- Changesets
- Gitleaks
- GitHub Actions security and quality checks
- A `main` branch protection setup script

Generated apps do not use ESLint or Prettier.
Their pre-commit hook scans staged changes for secrets.

## Install

Run:

```bash
cd /home/odds/projects/mknext
./install.sh
export PATH="$HOME/.local/bin:$PATH"
```

Check the install:

```bash
mknext --version
mknext --help
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

The longer `mknext create --name my-app --yes` form also works.

The command stops if the target path exists.

## Check an app

Run these commands from the generated app:

```bash
mknext doctor
mknext ci
```

`doctor` checks the command, Node.js, pnpm, Gitleaks, the project marker, and config.
It updates direct dependencies to the latest version allowed by pnpm.

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

## More docs

- [Specification](docs/SPEC.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Contributing](docs/CONTRIBUTING.md)
