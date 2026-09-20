---
name: status
description: Explain in plain language what the current branch does and what it now prevents, plus where it sits in the lifecycle. A 20-second read that writes nothing. Use when the user says "/pr:status" or asks for a quick rundown of what has been done on this branch.
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Read
---

# /pr:status

A **fast, plain-language** read on what this branch has done. A glance-and-go status the operator absorbs in seconds, not a report. They ask follow-ups if they want depth.

**Explain the branch, do not inventory it.** Lead with the core idea, then the mechanism, then what it buys. A status that lists what changed without saying what it now **prevents** has described a diff, and the operator can already read a diff. What they cannot get from `git log` is why the branch matters.

> Sibling of `/pr:summary`, which writes a detailed document to disk. This skill writes nothing.

## Step 1. Gather state

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --text
git log "$DEFAULT_BRANCH"..HEAD --oneline
git diff "$DEFAULT_BRANCH"...HEAD --stat
git status --short
```

An empty commit range means no commits ahead. Say so, and check for uncommitted work instead.

## Step 2. Read PLAN.md for intended scope

It says **what the branch set out to do**, which frames the git changes and separates what has landed from what is still open. No plan? Skip it silently and work from git alone.

## Step 3. Read the signal, do not dump it

- Group commits and diffstat **by theme**, not by commit.
- Cross-reference against the plan's checkboxes.
- Mention uncommitted work only if present.
- **Do not open every file.** Read one or two only if a commit subject is too thin to characterize.

**Then find the why, because the diff does not contain it.** The mechanism sentence and each bullet's consequence have to come from somewhere, and guessing them is how a status starts saying things that are not true:

- The plan's **Overview** states the problem the branch exists to solve. That is the source for "what it now prevents".
- Commit subjects written in imperative mood carry intent.
- **If neither yields a consequence for a change, say what changed and stop.** Do not invent a benefit to fill the pattern. An unsupported "which means users no longer…" reads as a finding, which makes it worse than a flat bullet.

## Output format

Plain language, no jargon, no headers, three to six short bullets.

```
On `{branch}`: {one-line gist of what this branch changes}.

{One or two sentences on how it actually works. The mechanism, not the file list.}

- {what changed, and what it now prevents or buys}
- {what changed, and what it now prevents or buys}

Lifecycle: {done steps as a group}. Left: {remaining as a group}.

{If the plan has open items:} Still open: {one line}.
{If uncommitted work exists:} Not yet committed: {one line}.
{If a gap was reported:} {the gap, plainly, with its remedy}.
Next: {`next` from the state check, or its note when no command applies}.

Want more detail on any of these? Just ask.
```

Rules:

- **Simple words.** "Added a retry when uploads fail", not "implemented exponential-backoff retry middleware". A non-engineer should follow it.
- **Every bullet earns its place by its consequence.** "Rewrote the upload handler" is a diff line. "Uploads now retry, so a flaky network no longer loses the file" is a status line. A change with no consequence worth stating belongs in the gist, not its own bullet.
- **Prefer the concrete failure mode over the abstract fix.** "A PR merged with an empty body and its ticket stayed open" lands; "improved PR body handling" does not.
- **Accuracy over completeness.** Simplify freely and omit edge cases, but never say something false. Where you have simplified past precision, say so in one clause.
- **Define a repo-specific term the moment it appears**, in one short clause. General engineering words need no gloss.
- Each bullet 15 words or fewer; at most 200 words before the lifecycle line.
- No code, no file lists, no impact tables, no preamble, no caveat list.
- **Always end with the invitation to ask follow-ups.** This skill opens a subject the reader may want to pull on, rather than answering one they already framed.
- Nothing done on the branch? Say that in one line and stop.
- **Never call a branch "ready to merge" without naming `/pr:close`.**

## The lifecycle line

`steps` carries one row per step with a tri-state `done`. Render it as **exactly one line**:

```
Lifecycle: ticket, plan, pushed, CI all done. Left: summary, close, cleanup.
```

- **One line, never a checklist.** The script's text output prints a table; that is for somebody debugging the lifecycle. Seven rows would dominate a 15-second read.
- **Name the done ones as a group, then the remaining ones as a group.**
- **A null step is called out separately**, because it means the check could not see far enough rather than that the step is outstanding: "couldn't check the ticket (offline)".
- Use plain-word names (`ticket`, `plan`, `pushed`, `CI`, `summary`, `close`, `cleanup`), not command names.

## Lifecycle position

`/pr:status` runs inside the work band and changes nothing. Fold the state check in per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`, with the one-line rendering above taking precedence over that section's general reporting shape.
