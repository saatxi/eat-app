---
description: Analyzes the pending changes in the repository and proposes a commit message following the project's style.
argument-hint: "Optional: extra context about the change, e.g. 'fix for the login bug'"
---

# Generate commit message

Analyze the current state of the repository and write a commit message following this project's conventions.

Additional context provided by the user (may be empty): $ARGUMENTS

## Steps

1. Run in parallel:
   - `git status` to see modified/new/deleted files.
   - `git diff` and `git diff --staged` to understand the actual content of the changes.
   - `git log --oneline -10` to detect the message style used in the repo (prefix type, language, length, use of scope, etc.).
2. If there are no changes (neither staged, unstaged, nor untracked), say so clearly and do not continue.
3. Analyze the full diff, not just the file names. Identify the actual purpose of the change (what problem it solves or what it adds), not just which lines changed.
4. If the changes span clearly distinct, unrelated topics, point that out and suggest splitting them into several commits instead of forcing a single message.

## Format rules

See [AGENTS.md](../../AGENTS.md)'s "Commit and tag messages" section for the full rules (when an agent may run `git commit`/`git tag`, message format, no attribution lines, etc.) — they apply here too. In short:

```text
Short summary

Optional detailed explanation
```

- Imperative mood, lowercase type, concise summary line.
- Always in English, regardless of the language used in the conversation.
- Body (if needed) explains the "why", not the "what" — each bullet starts with a capital letter and uses `-` (not `*`) as its marker.
- No manual line wrapping anywhere in the message — the summary and every body paragraph/bullet is a single continuous physical line, even when just shown in chat before committing.
- Never add a `Co-Authored-By`, "Generated with ...", or other attribution/signature line.
- Present the message inside a fenced code block (` ``` `) so it's easy to copy into `git commit`.
