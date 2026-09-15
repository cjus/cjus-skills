---
name: cp
description: Stage everything, commit with a concise message, and push the current branch. Use when the user says "/pr:cp" or asks to commit and push.
allowed-tools: Bash(git:*)
argument-hint: "[commit message]"
---

# /pr:cp

Commit all changes and push the current branch.

## Steps

1. Run `git status`, `git diff` and `git branch --show-current` **in parallel** to see what will be committed and where.
2. **No changes to commit** → report that and stop. Still push if the branch is ahead of its upstream.
3. Stage with `git add -A`.
4. Commit with a concise, imperative, lowercase message, no trailing period. **If `$ARGUMENTS` carries a message, use it verbatim.**
5. Push with `git push`, or `git push -u origin HEAD` when the branch has no upstream.
6. Report the commit hash and the push result.

## Rules

- **Never put a secret value in a commit message**, including when quoting somebody who pasted one. Never commit `.env` files or large binaries. See `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`.
- **No machine-authorship markers.** No co-author trailer naming an AI, no "generated with" footer, no robot byline.
- **On the default branch the guard hook gates this**, where it is installed. That is expected, not a failure of this skill: stop, ask the operator, and only add the approval token if they say yes.
- **Run the commit and the push as separate tool calls** when the branch was just created in the same turn. The guard evaluates before a command runs, so a compound `checkout && push` is judged against the branch as it stood beforehand.
