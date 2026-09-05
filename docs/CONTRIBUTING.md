# Contributing to mknext

Keep each change small.
Keep the code and docs consistent.

## Before a change

Read:

1. `docs/SPEC.md`
2. `docs/ARCHITECTURE.md`
3. The affected command file
4. The affected templates
5. Existing tests for the public command

Search for an existing helper before you add one.
Reuse the existing helper when it does the job.

## Test-first work

Test behavior through a public command.
Use a fake command only for an outside system such as pnpm.

Use this order:

1. Add one behavior test.
2. Run it and confirm that it fails for the expected reason.
3. Make the smallest code change.
4. Run the test again.
5. Run all relevant checks.

Generated app tests must check the app files and package data.
They must not test private shell functions.
Keep the short and long create forms on the same command path.

## Tool rules

Generated apps use Oxlint for lint checks.
They use Oxfmt for format checks.
They do not use ESLint or Prettier.

When tool behavior changes, update:

- `versions.env`
- The package update file
- The related template
- The create step
- The specification
- The behavior test

## Package pins

Use exact versions in `versions.env`.
Check the current package version before a pin change.
No command uses `@latest`. The shadcn scaffold command uses the pinned `SHADCN_VERSION`.

Keep the minimum release age active.
Generated apps set `minimumReleaseAgeStrict: false` so a new pinned package does not stop the install.
Doctor enforces the minimum release age when it updates direct dependencies.
Doctor must not change the minimum-release config.

Do not edit a generated lockfile.
Use a new temporary app for full create tests.

## Repository CI

`.github/workflows/ci.yml` runs on every pull request and every push to `main`.

The workflow runs these checks in this order:

1. ShellCheck on every tracked `*.sh` file and `bin/mknext`
2. `pnpm audit`
3. Gitleaks on Git history
4. `pnpm test`

## Changesets

Add a changeset for each user-visible change:

```bash
pnpm changeset
```

Choose `patch`, `minor`, or `major` from the change scope.
Write a short summary of the real change.

Apply pending versions with:

```bash
pnpm changeset:version
```

This command updates `package.json`, the changelog, and `VERSION`.

## Release

Merge the version change to `main`. The release is automatic from there.

`.github/workflows/release.yml` watches `VERSION` on `main`.
A change to that file creates and pushes the matching `vX.Y.Z` tag.
The workflow stops when the tag already exists. It never moves a tag.

`install.sh` and `mknext update` clone the newest `vX.Y.Z` tag.

Use `pnpm release:tag` only to tag a release the workflow missed.

## Local checks

Run `pnpm test`. That is the same test suite that CI runs.

`pnpm test` skips ShellCheck when it is missing. CI does not skip it.
Install ShellCheck, then run the same command that CI runs:

```bash
git ls-files '*.sh' bin/mknext | xargs shellcheck --severity=warning --external-sources
```

For a full test, create a new app in a temporary folder.
Then run `mknext doctor` and `mknext ci` there.

Stop if pnpm rejects a package for release age.
Do not approve a bypass.

## Pull requests

Use the pull request template in `.github/pull_request_template.md`.

`.github/workflows/pr-governance.yml` checks these headings:

- `## Summary`
- `## Validation`
- `## Risks`

The check warns when a heading is missing or empty.
State the real code changes in Summary.
List each check and its result in Validation.
State each skipped check and reason.
Write `None` in Risks when no risk is known.
When a section does not apply, write `N/A - <reason>`.

Do not add tool credit text to commits or pull requests.
