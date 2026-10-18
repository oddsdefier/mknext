---
"mknext": patch
---

Fix migration installation flags for project-pinned pnpm 12.3.1.
Use `--no-prod` instead of the unsupported `--prod=false` form.
Verify production and development dependencies under production NODE_ENV.
Test older pnpm, current pinned pnpm, and npm in CI.
Preserve project package-manager pins and release-age policy settings.
