# Git conventions

## Branches

Branch names come from the ticket, using `branchPrefix` and `ticketPrefix` from `config.md`. The default shape is `feature/123-short-slug`.

A branch that does not match the pattern carries no ticket. That is a reportable state, not an error: a branch made by hand is still a branch, and the skills degrade to the parts that do not need an issue number.

## Commit messages

Imperative mood, lowercase, no trailing period.

```
add websocket retry logic          # good
Added WebSocket retry logic.       # bad
```

Before committing, run status, diff and log together to understand the state you are about to record.

## No machine-authorship markers

Commit messages, commit trailers, PR titles and PR bodies carry **no** co-author line naming an AI, no "generated with" footer, no session identifier, and no robot byline.

This holds even when the harness's own default attribution behavior would add one. Set it off explicitly so nothing is added on your own:

```json
// .claude/settings.json
{ "attribution": { "commit": "", "pr": "" } }
```

If you find such a line in a message you are about to write, strip it before committing.

## Never commit

`.env` files, secrets, or large binaries. **Never put a real secret value in a changelog, a PR body, or any other committed file**, including when quoting somebody who pasted one. Replace it with `[REDACTED]` or describe the kind of secret it was.

## Committing on a feature branch

Commit and push freely on a feature branch. No permission question first, and that holds inside every skill here, `/pr:close` included, which commits and pushes as its own steps.

## The default branch is the exception

Writes to the default branch are gated by the `PreToolUse` hook this plugin ships, when `mainGuard.enabled` is true. It gates a commit or push when:

- The current branch is the default branch
- A push's refspec targets the default branch from any branch, including `HEAD:main` and a leading `+`
- It cannot determine the branch at all

Whole-repo push forms are gated too, because they name no ref while writing every branch: `--mirror`, `--all`, and a wildcard refspec. Force spellings are gated on the default branch: `--force`, `-f`, a leading `+`, and a quoted refspec.

**When denied, stop and ask the operator in conversation.** If they approve, re-run prefixed with the configured `mainGuard.approvalToken`. **Never add that prefix on your own initiative.** Nothing but this rule stops you from doing so, which is what makes the token a record of the operator's approval rather than a lock.

### Two things the guard cannot do

**It evaluates before the command runs**, so a compound `git checkout -b new-branch && git push` is judged against the branch as it stands *now*, which is still the default branch. The push is gated even though it would have been legal by the time it executed. Run the checkout and the push as separate tool calls.

**It sees tool calls only.** A script that commits internally passes unguarded, because the hook matched the invocation of the script and not the git commands inside it. The guard covers the agent typing git; it is not a repo-wide write barrier.

## `/pr:close` is required before a merge

There is no other path. The moment a branch is merge-ready, the next action is `/pr:close`, and **the operator runs it**. Do not merge, do not open the merge, and do not describe a branch as ready to merge without naming that command.

`/pr:close` is the only thing that produces the PR summary, the continuity entry, the assertions audit, the verified `Closes #N` link and the deferred-work triage, and it runs the merge-conflict and drift gates. Skipping it strands all of that.

## Squash merges

Where the repo squash-merges, a branch's commit shape never reaches the default branch. Two consequences the skills rely on:

- `/pr:cleanup` deletes branches with `git branch -D` rather than `-d`, because the merged commits are not ancestors of the default branch and `-d` would refuse.
- Rebasing a published feature branch buys nothing.

## Worktrees and the shared stash

**The stash stack is shared across every worktree of a repo.** `refs/stash` resolves into the common git directory from all of them, so a bare `git stash pop` in one worktree can take whatever another session pushed. Never reach for `git stash` to clear a dirty tree that is not yours.
