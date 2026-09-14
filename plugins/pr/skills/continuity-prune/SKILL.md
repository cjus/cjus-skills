---
name: continuity-prune
description: Delete continuity entry files older than a cutoff date, after showing the list and asking. Destructive, so it only runs when the user invokes it explicitly. Use when the user says "/pr:continuity-prune <YYYY-MM-DD>".
disable-model-invocation: true
allowed-tools: Bash(date:*), Bash(git:*), Bash(ls:*), Bash(grep:*), Bash(sed:*), Bash(cut:*), Bash(sort:*), Bash(head:*), Read, Glob
argument-hint: <from-date> [repo-root]
---

# /pr:continuity-prune

Delete entry files from the continuity folder whose date is strictly older than a cutoff.

**Destructive.** Deleted entries are recoverable only through git history. **Never invoked automatically.**

## Arguments

- `$1` **(required)**: cutoff date, ISO `YYYY-MM-DD`. Entries dated strictly **older** are removed; entries on or after the cutoff are kept.
- `$2` *(optional)*: target root. Defaults to the repo root of the current checkout.

## Step 1. Resolve the target and validate

```bash
git rev-parse --show-toplevel     # unless $2 was given
```

Read `docs.continuityRoot` from config. **Disabled (`null`)** → report that and stop.

- The folder must exist and match at least one `[0-9]*.md`. Otherwise this is a no-op: print "Nothing to prune" and exit.
- `$1` must match `^\d{4}-\d{2}-\d{2}$`. Otherwise exit with "Invalid cutoff date (expected YYYY-MM-DD)".
- **`$1` in the future** → ask for confirmation first, since that would delete every entry.

## Step 2. Identify the candidates

**Each entry's date is its filename's first 10 characters**, so no file needs opening to classify it:

```bash
ls "$CONTINUITY_ROOT"/[0-9]*.md | sort
```

An entry is a candidate when that date is strictly older than `$1`.

Read each candidate's title line and `Date added` field for the summary, and **sanity-check that `Date added` matches the filename prefix**. If they disagree, surface it, treat the **filename** as authoritative for ordering, and ask before deleting that one.

## Step 3. Confirm before deleting

```
Pruning continuity entries at <root>/<continuityRoot>/
Cutoff: <date> (entries strictly older will be removed)

To remove (N):
  - 2025-11-04-some-slug.md: "Title"

To keep (M):
  - 2026-05-22-other-slug.md: "Title"

Proceed with deletion? (yes/no)
```

**Wait for explicit confirmation.** Anything other than `yes` aborts without modification.

## Step 4. Delete

```bash
git rm "$CONTINUITY_ROOT/<each candidate>"
```

`git rm` so the deletions are staged and reviewable as deletions rather than an untracked mess.

**Delete whole files only.** There is no header to update, no count to recompute, and no surviving entry to touch: every header fact is derived at read time from the files that remain. **If you find yourself editing a file you are not deleting, stop.**

## Step 5. Report

```
Pruned N entries. Kept M. Oldest retained: <date> (<slug>).
```

Derive "oldest retained" from the surviving filenames, never from a stored field:

```bash
ls "$CONTINUITY_ROOT"/[0-9]*.md | sed 's|.*/||' | cut -c1-10 | sort | head -1
```

## What NOT to do

- **Do not prune without the step 3 confirmation.** Always show the list first.
- **Do not rename or re-date surviving entries.** Filenames are immutable identity, and gaps are expected and informative.
- **Do not touch entries on or after the cutoff**, even where their status is superseded or stale. The cutoff is purely temporal.
- **Do not edit the contents of any surviving entry.** This skill only deletes whole files.
- **Do not delete a `README.md`** in that folder. The `[0-9]*` glob already excludes it; do not widen it to `*.md`.
- **Do not commit.** Leave the deletions staged so the operator can review them.
- **Do not chain into any other workflow.** Pruning is a one-shot, intentional operation.

## When to use it

The folder has grown past roughly 50 entries and the oldest are no longer informative, or recent work has subsumed their content into durable documents.

**If unsure whether to prune, do not.** Old entries are cheap to keep, and git retains them anyway after pruning.
