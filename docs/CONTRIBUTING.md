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

Keep the minimum release age active.
Generated apps set `minimumReleaseAgeStrict: false` so a new pinned package does not stop the install.

Do not edit a generated lockfile.
Use a new temporary app for full create tests.

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

## Local checks

Run the shell tests:

```bash
bash tests/changesets_test.sh
bash tests/no_eslint_test.sh
bash tests/shorthand_create_test.sh
bash tests/security_defaults_test.sh
```

Check Bash syntax:

```bash
bash -n bin/mknext install.sh lib/config.sh lib/log.sh lib/commands/*.sh tests/*.sh tests/fakes/*
```

For a full test, create a new app in a temporary folder.
Then run `mknext doctor` and `mknext ci` there.

Stop if pnpm rejects a package for release age.
Do not approve a bypass.

## Pull requests

Use the pull request template.
State the real code changes.
List each check and its result.
State each skipped check and reason.

Do not add tool credit text to commits or pull requests.
