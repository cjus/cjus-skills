---
name: start
description: Begin work on a ticket. Creates the branch (in a worktree when configured), installs dependencies, initializes the branch's plan folder, enriches PLAN.md from the GitHub issue, and moves the issue to status:in-progress. Use when the user says "/pr:start <branch-name>" or asks to start work on a ticket.
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Bash(date:*), Bash(mkdir:*), Bash(ls:*), Bash(cp:*), Read, Write, Edit
argument-hint: <branch-name>
---

# /pr:start

Open a workspace for `$ARGUMENTS` and fix the objective for the life of the branch.

Accepts the branch name with or without the configured `branchPrefix`, since `/pr:ticket` reports it with the prefix. Normalize before doing anything: strip a leading prefix if present, then re-apply it once. A doubled prefix is the most common way this skill goes wrong.

If `$ARGUMENTS` is empty, ask which ticket to start and stop.

## Step 1. Resolve configuration and the ticket

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline --text
```

Take `repo`, and read `.claude/pr-config.json` for `worktrees`, `checks` and `docs`. Defaults apply when it is absent; say so in one clause and continue.

Derive `BRANCH`, `SLUG` (branch minus `branchPrefix`) and the issue number, by the rules in `${CLAUDE_PLUGIN_ROOT}/reference/config.md`.

**A branch carrying no issue number is allowed.** Skip every ticket step below and say so once in the report. A branch made by hand is still a branch.

## Step 2. Create the branch

**Check whether it already exists before creating it:**

```bash
git show-ref --verify --quiet "refs/heads/$BRANCH" && echo local
git show-ref --verify --quiet "refs/remotes/origin/$BRANCH" && echo remote
```

Existing branch? Check it out. Absent? Create it from the default branch **automatically, without prompting.**

### When `worktrees.enabled` is true

```bash
WORKTREE_PATH="$WORKTREE_ROOT/$BRANCH"
mkdir -p "$(dirname "$WORKTREE_PATH")"
git worktree add -b "$BRANCH" "$WORKTREE_PATH" "$DEFAULT_BRANCH"   # or without -b, if it exists
```

`worktrees.root` expands `{repo}` to the repo's directory name and resolves relative paths against the **main checkout**, not the cwd. The branch name keeps its prefix as a directory segment, so `feature/412-x` lives at `<root>/feature/412-x`.

**Never create a worktree inside the repo.** Git tracking conflicts and ignore-rule surprises follow.

### When `worktrees.enabled` is false

```bash
git checkout -b "$BRANCH" "$DEFAULT_BRANCH"    # or git checkout "$BRANCH"
```

**Refuse if the tree is dirty**, listing the paths. Switching branches under uncommitted work is how someone's changes end up on the wrong branch. Never reach for `git stash` to clear it: the stash stack is shared across every worktree of the repo, so a later `git stash pop` elsewhere can take what you pushed.

### Push it

```bash
git -C "$WORK_PATH" push -u origin HEAD
```

Run the push as its **own** tool call, separate from the checkout. The default-branch guard evaluates before a command runs, so a compound `checkout && push` is judged against the branch as it stands beforehand, which is still the default branch. See `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`.

## Step 3. Carry over what the checkout does not

**Only when a worktree was created.** A `git worktree add` checkout includes tracked files only, so anything gitignored stays behind. Two things commonly matter:

- **Environment files.** If the main checkout holds gitignored `.env*` files, copy them across, preserving relative paths. **Report what was copied, and report "no environment files to copy" when there are none**, so a missing credential is never a silent discovery later.
- **An untracked `.mcp.json`**, copied only if present in the main checkout and absent in the worktree.

**Never print the contents of either.** Copy the file; do not read its values into the transcript.

## Step 4. Install dependencies

Run the repo's install command in the new working path when one applies, inferred from the lockfile the same way `/pr:init` infers it. This step is **mandatory where it applies**: the workspace must be immediately ready for work.

**Use the package manager the lockfile names.** Running a different one writes a second lockfile and a `node_modules` layout the repo does not expect, and CI installs with the pinned one, so local and CI diverge silently.

Per-machine caches, such as browser binaries for an end-to-end runner, are **not** per-worktree. Do not reinstall them here.

## Step 5. Initialize the plan folder

Skip entirely when `docs.changelogRoot` is `null`.

```bash
CHANGELOG_PATH="$WORK_PATH/$CHANGELOG_ROOT/$SLUG"
mkdir -p "$CHANGELOG_PATH"
date '+%Y-%m-%d %H:%M:%S %Z'
```

The path is **always** `<changelogRoot>/<branch-slug>/` at the repo root of the working path. Not pluralized, not without the per-branch folder, not under `.claude/`.

**`CHANGELOG.md`:**

```markdown
# <Branch Title>

Start date: <TIMESTAMP>

<Brief description of branch purpose>

## Changes
```

**`PLAN.md`:**

```markdown
# <Branch Title>

Start date: <TIMESTAMP>

## Overview

<Brief description of branch purpose>

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## Plan

- [ ] Phase 1: ...
- [ ] Phase 2: ...

## Open Questions

- ...
```

That objective is the acceptance bar for the whole branch. See `${CLAUDE_PLUGIN_ROOT}/reference/scope-contract.md`.

## Step 6. Read recent continuity

Skip when `docs.continuityRoot` is `null`.

- Folder absent or holding no `[0-9]*.md`? Record "no prior continuity" and continue.
- Otherwise list newest-first, read the **three** most recent entries, and capture each title and `Date added` for the report:

```bash
ls "$WORK_PATH/$CONTINUITY_ROOT"/[0-9]*.md | sort -r
```

The ISO prefix makes lexical order chronological **across** dates. Entries sharing one date have no guaranteed order among themselves, so read `Date added` rather than inferring sequence from position.

Note any unresolved **Open threads**, which are candidates the new PR may want to address.

**This step is read-only.** `/pr:close` handles continuity updates at the end. **Do not duplicate continuity content into `PLAN.md`**: the two have opposite tenses, and a plan that restates the past stops being read as a plan.

## Step 7. Enrich PLAN.md and move the issue to in-progress

Only when the branch carries an issue number.

```bash
gh issue view "$N" --repo "$REPO" --json number,title,body,state,labels,url,comments
```

**Verify the full slug before touching anything.** The number alone is not identification. Slugify the returned title and confirm it matches the slug portion of the branch. **On mismatch, stop and surface it**: enriching or relabelling the wrong ticket is silent and hard to notice afterward.

**If the issue is already `CLOSED`, stop and surface that too.** Starting work against a closed ticket is almost always a mistyped number.

Then update `PLAN.md` with the issue title, its body under an "About Ticket" heading, and any `- [ ]` action items from the body or comments. Where step 6 surfaced a relevant open thread, a `## Recent Context` block may **reference** the entry by filename. Never paste its body.

Move the label:

```bash
gh issue edit "$N" --repo "$REPO" --remove-label "status:todo" --add-label "status:in-progress"
```

**`--remove-label` on a label the issue does not carry is an error, not a no-op.** Read the `labels` array from the fetch above and pass only the flags that apply. An issue already at `status:in-progress` needs neither; note the existing state rather than churning it.

## Step 8. Report

```
PR workspace ready:
  Path:      <full path>
  Branch:    <branch>
  Plan:      <changelogRoot>/<slug>/
  Ticket:    <id + full slug + label transition, or "none">
  Carried:   <env files copied, or "none">

Recent continuity:
  <"no prior continuity entries", or up to 3 "<title> (YYYY-MM-DD)" newest first>

Next: start a session in <working path>.
```

## Common mistakes

- **Doubling the branch prefix**, by passing a name that already carries it. Normalize first.
- **Pluralizing the changelog directory**, or omitting the per-branch subfolder, or nesting it under `.claude/`. Downstream skills read the exact path.
- **Chaining the checkout and the push in one call.** The guard judges the branch as it was before the command ran.
- **Enlarging the objective later.** `PLAN.md` updates refresh status, never scope.

## Lifecycle position

`/pr:start` follows `/pr:ticket` and opens the work band. Fold the state check into the report per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`, whose contract applies verbatim: gaps with remedies most consequential first, an empty list as one clause, `next` named but never run.
