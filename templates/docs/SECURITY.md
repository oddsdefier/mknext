# Security checks

Install Gitleaks before you run local CI. See the official Gitleaks installation guide.

Run all local checks:

```sh
mknext ci
```

The pre-commit hook scans staged changes with Gitleaks. It stops the commit when it finds a secret.

The local CI command runs `pnpm audit` and scans the Git history with Gitleaks. Any finding stops the command.

The GitHub Actions workflow runs the same security gates for pull requests and pushes to `main`. An organization-owned repository must define the `GITLEAKS_LICENSE` secret. A personal repository does not need this secret.

After you create the GitHub repository and run its workflow once, protect `main`:

```sh
./scripts/configure-main-protection.sh OWNER/REPOSITORY
```

The script requires the `security` and `quality` checks, one approval, resolved conversations, and current branch status. It blocks force pushes and branch deletion.
