---
"mknext": patch
---

Add shell linting, repository consistency checks, and the missing project files.

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
