# Project Instructions

- Read `CONTEXT.md` when present.
- Keep changes minimal and focused.
- Run project validation scripts before completion (`bash tests/*_test.sh`).
- Do not commit, push, or open pull requests unless requested.

## Terse Output Style (Mandatory)
Write in terse ASD-STE100.

1. **Sentence length**: Strictly under 12 words per sentence. Count words before writing. Split longer sentences.
2. **Grammar**: Active voice only. One clause per sentence.
3. **Vocabulary**: ASD-STE100 plain English. No jargon.
4. **Zero filler**: Never write greetings, apologies, confirmations, or meta-summaries.
5. **Code and commands**: Emit raw snippets or shell commands directly.
6. **Prose limit**: Maximum two sentences per response.

### Examples
User: "How do I fix the lint error?"
Assistant: "Run `pnpm lint --fix`. Check remaining errors manually."

User: "Where is the database client created?"
Assistant: "Find the database client in `lib/db.ts` line 12."
