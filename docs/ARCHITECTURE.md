# mknext architecture

## Folder layout

```text
mknext/
  package.json
  VERSION
  versions.env
  .changeset/
  install.sh
  bin/mknext
  lib/
    config.sh
    log.sh
    update-package.mjs
    commands/
      create.sh
      ci.sh
      doctor.sh
  templates/
  tests/
  scripts/
    sync-version.mjs
  docs/
```

`bin/mknext` is the public entry point.
It reads config and starts one command.
It maps a first project-name argument to the existing `create --name` path.
Both create forms use the same parser and step functions.

`lib/commands` owns command behavior.
`templates` contains files copied into a generated app.
`versions.env` contains exact package versions.

The root `package.json` makes mknext a private Changesets package.
The root `.changeset` folder contains its Changesets config.
The version script copies the package version to `VERSION`.

## Install path

The installer copies program files to `~/.local/share/mknext`.
It writes a small command file to `~/.local/bin/mknext`.
That command starts the installed entry point.

The installer downloads the main branch when run through a pipe.
A local installer uses files from its own source folder.

## Config path

The entry point loads config in this order:

1. Built-in defaults
2. User config
3. Project config
4. Command flags

Each later source replaces an earlier value.

## Create path

`create` resolves one target path.
It stops when that path exists.

The command runs one shared list of 20 steps.
A dry run prints the same list.
A dry run does not call the step actions.

The Next.js step passes `--no-linter` and `--skip-install` to `create-next-app`.
This makes the no-ESLint choice explicit.
The base install runs after mknext writes the pinned package manager and pnpm settings.

Later steps copy Oxlint, anti-slop, Oxfmt, Vitest, React Doctor, Knip, Gitleaks, and GitHub Actions files.
The shadcn step uses Base UI and preset `b67ek3WsVs`.
The Changesets step copies its config without an interactive command.
The package update writes matching scripts and exact versions.
The final create step formats the completed app.

The create path does not write `.npmrc`.
It keeps the pnpm minimum release age active.
It makes the check non-blocking when no mature pinned version exists.

## CI path

`ci` uses files under the app's `node_modules/.bin` folder.
It does not use global lint, format, test, or type tools.

Safe checks run in parallel.
The command waits for every check.
One failed check makes the command fail.

Local CI also runs `pnpm audit` and Gitleaks from `PATH`.
This keeps npm advisories and committed secrets outside the app build.

The pre-commit hook uses the Gitleaks staged scan.
It can stop a staged secret before the commit exists.

The generated GitHub Actions workflow has two required jobs: `security` and `quality`.
The security job audits dependencies and scans Git history.
The quality job runs lint, format, React, Knip, test, type, and build checks.
The generated setup script can require both jobs on `main` after the GitHub repository exists.

## Doctor path

`doctor` checks the command and current app setup.
It checks that Gitleaks is on `PATH`.
When setup is healthy, it updates direct dependencies through pnpm.
The update enforces the minimum release age and does not change its config.

## Tool boundaries

Oxlint owns general lint rules.
The anti-slop rules are an Oxlint plugin.

Oxfmt owns formatting.
No Prettier config is generated.

React Doctor owns React checks.
Knip owns unused code and dependency checks.
Vitest owns tests.
TypeScript owns type checks.

Generated apps do not install or configure ESLint.
