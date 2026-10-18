# mknext context

## What it is

`mknext` is a Bash CLI. It creates a Next.js app with a fixed tool set.
It also audits and updates an app it created.
It targets macOS and Linux.

## Words we use

- A **generated app** is a Next.js project from `mknext create`.
- A **template** is a file under `templates/`. `create` and `sync` copy templates into generated apps.
- A **guard** is a hook that blocks unsafe agent actions. See `.claude/hooks/` and `.codex/hooks/`.
- A **pin** is a fixed version in `versions.env`. Nothing installs a floating version.
- A **release tag** is a `vX.Y.Z` git tag. `install.sh` and `update` clone the newest tag.
- An **anti-slop rule** is a custom Oxlint rule under `templates/tools/oxlint/anti-slop/`.

## Rules that do not change

- Generated apps use Oxlint and Oxfmt. They never use ESLint or Prettier.
- `minimumReleaseAge: 4320` stays in `pnpm-workspace.yaml`. Do not lower it.
- `trustPolicy: no-downgrade` stays in `pnpm-workspace.yaml`. Do not remove it.
- `trustPolicyIgnoreAfter: 43200` limits trust checks to packages from the last 30 days.
- Every mknext-managed dependency version comes from `versions.env`.
- `install.sh` and `update` clone a release tag. They never hardcode a commit or checksum.
`.github/workflows/release.yml` creates the tag when `VERSION` changes on `main`.
- Some files exist in both the repo root and `templates/`. Keep them identical.
`tests/repo_consistency_test.sh` lists them.
- Commits and pull requests carry no AI attribution. The git hooks enforce it.

## Where things live

- `bin/mknext` starts the command. It sources `versions.env` and every file in `lib/`.
- `lib/commands/` has one file per command: create, sync, audit, ci, doctor, update, uninstall.
- `lib/*-guard.sh` installs Claude and Codex hooks into a project.
- `templates/` contains the files for generated apps.
- `tests/*_test.sh` contains the test suite. Run `pnpm test`.

## Known limits

- Codex will not run its hooks until you approve them once, in an interactive session.
No script can grant that approval. See `docs/SPEC.md`.
- `install.sh` and `update` need `git` on PATH.
