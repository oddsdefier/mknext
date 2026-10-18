# Security checks

Install Gitleaks before you run local CI. Follow the official installation guide.

Run all local checks:

```sh
mknext ci
```

The pre-commit hook uses Gitleaks to scan staged changes. It stops commits containing secrets.

Local CI runs `pnpm audit`. Gitleaks scans Git history. A failed check stops the command.

GitHub Actions runs these checks on pull requests and pushes to `main`. Organization-owned repositories need the `GITLEAKS_LICENSE` secret. Personal repositories do not need it.

After you create the GitHub repository and run its workflow once, protect `main`:

```sh
./scripts/configure-main-protection.sh OWNER/REPOSITORY
```

The script requires the `security` and `quality` checks. It also requires one approval, resolved conversations, and current branch status. It blocks force pushes and branch deletion.
