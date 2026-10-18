# Project Instructions

## Hard rules

- Read `CONTEXT.md` before changing project files.
- Keep changes minimal and focused.
- Preserve user changes and unrelated files.
- Never lower `minimumReleaseAge`.
- Never remove `trustPolicy` settings.
- Never edit generated artifacts directly.
- Never bypass Git hooks.
- Never add AI attribution.
- Stop after repeated failures.
- Report unresolved errors honestly.

## Design

- Keep module interfaces small. Put related behavior inside each module.
- Keep domain rules inside their owning module.
- Make callers and tests use one interface.
- Accept dependencies through interfaces.
- Add seams only when behavior varies.
- Remove pass-through modules without leverage.
- Avoid speculative abstractions and duplicated rules.

## Implementation

- Implement the specification.
- Do not implement assumptions.
- Make the smallest coherent change.
- Search existing code before adding code.
- Reuse installed libraries where possible.
- Use test-driven development when correct seams exist.
- Do not commit or push without approval.

## Validation

- Run the narrowest useful checks first.
- Run broader checks for risky changes.
- Run all relevant tests before completion.
- Never claim success after skipped required checks.

## GitHub Actions

- Finish local validation before pushing.
- Batch related commits into few pushes.
- Open review-ready pull requests.
- Never depend on draft status for CI control.
- Require final CI success before completion.

## Debugging

1. Reproduce the exact reported symptom.
2. Minimize the reproduction before forming theories.
3. Rank three falsifiable hypotheses.
4. Test one variable at a time.
5. Add a regression test first.
6. Remove temporary instrumentation afterward.
7. Recheck the original reproduction.

## Review

- Review Standards separately.
- Review Spec separately.
- Report findings with exact file evidence.

## Git conventions

- Use Conventional Commits.
- Use imperative commit summaries.
- Use focused branch names.
- Split unrelated changes.
- Use every pull request template heading.

## Completion report

- State what changed.
- State what passed.
- State every failed or skipped check.
- State unresolved risks.
- Verify branch, commit, and pull request names.

## Writing style

- Write terse ASD-STE100.
- Keep sentences under twelve words.
- Use active voice.
- Omit filler.
