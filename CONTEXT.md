# mknext context

## What it is

`mknext` is a Bash CLI. It creates a Next.js app with a fixed tool set.
It also audits and updates an app it created.
It targets macOS and Linux.

## Words we use

- **Generated app** — a Next.js project that `mknext create` produced.
- **Template** — a file under `templates/`. `create` and `sync` copy it into a generated app.
- **Guard** — a hook that blocks an unsafe agent action. See `.claude/hooks/` and `.codex/hooks/`.
- **Pin** — a fixed version in `versions.env`. Nothing installs a floating version.
- **Release tag** — a `vX.Y.Z` git tag. `install.sh` and `update` clone the newest one.
- **Anti-slop rule** — a custom Oxlint rule under `templates/tools/oxlint/anti-slop/`.

## Rules that do not change

- Generated apps use Oxlint and Oxfmt. They never use ESLint or Prettier.
- `minimumReleaseAge: 1440` stays in `pnpm-workspace.yaml`. Do not lower it.
- Every dependency version comes from `versions.env`.
- `install.sh` and `update` clone a release tag. They never hardcode a commit or checksum.
`.github/workflows/release.yml` creates the tag when `VERSION` changes on `main`.
- Some files exist in the repo root and in `templates/`. They must stay identical.
`tests/repo_consistency_test.sh` lists them.
- Commits and pull requests carry no AI attribution. The git hooks enforce it.

## Where things live

- `bin/mknext` — entry point. It sources `versions.env` and every file in `lib/`.
- `lib/commands/` — one file per command: create, sync, audit, ci, doctor, update, uninstall.
- `lib/*-guard.sh` — installs the Claude and Codex hooks into a project.
- `templates/` — everything a generated app receives.
- `tests/*_test.sh` — the whole suite. Run `pnpm test`.

## Known limits

- Codex will not run its hooks until you approve them once, in an interactive session.
No script can grant that approval. See `docs/SPEC.md`.
- `install.sh` and `update` need `git` on PATH.

