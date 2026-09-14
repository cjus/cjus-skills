---
name: continuity-add
description: Write one concise continuity entry as a new file under the repo-root continuity folder, sourced from the branch's plan folder, its commits and its PR. Additive only, touching no existing entry. Use when the user says "/pr:continuity-add", or as the handoff step of /pr:close.
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Bash(date:*), Bash(grep:*), Bash(ls:*), Bash(sort:*), Bash(head:*), Bash(tail:*), Bash(sed:*), Bash(cut:*), Bash(wc:*), Bash(cat:*), Read, Write, Glob
---

# /pr:continuity-add

Write a **single new entry file** summarizing the work just completed.

**Be concise.** Entries are handoff context for a returning agent, not exhaustive history. See `${CLAUDE_PLUGIN_ROOT}/reference/handoff-docs.md`.

## Why entries are separate files

One entry per file, and **nothing shared is ever rewritten.** Two PRs closing minutes apart write two differently named files and merge without conflict.

That is not a tidiness preference. When continuity was a single file with entries prepended at a fixed offset, two concurrent closes collided three ways, all three verified by controlled probe:

1. **The textual conflict silenced CI.** GitHub builds pull-request runs against the merge ref; when that commit cannot be computed it creates **no run at all**, not a red one, *none*. Measured: a conflicting PR produced zero runs where an otherwise identical PR from the same base produced one. A separate deploy check still reported green, because it builds the head commit rather than the merge ref, so the PR read as checked and passing while its only real gate had silently vanished.
2. **The entry count desynced silently.** Both branches incremented the same number, git saw the *same* change on both sides and merged it cleanly, and the file was left claiming one count while holding another.
3. **Sequential IDs collided silently.** Both branches allocated the next ID by scanning their own base.

**Mechanisms 2 and 3 raise no conflict at all.** Anything that reintroduces a shared, per-entry-rewritten file, whether a committed index, a regenerated combined document, or a header block with counts in it, brings all three back. **Do not add one.**

## Steps

### 1. Resolve the target

```bash
git rev-parse --show-toplevel
```

Read `docs.continuityRoot` from config. **Disabled (`null`)** → print one line saying continuity entries are disabled for this repo and exit. Otherwise create the folder if absent.

### 2. Gather source material

Derive the branch slug. **That slug names both the plan folder and this entry's file**, so the two always correspond.

Read in this priority order, stopping at the first hit with substantive content:

1. **`PLAN.md`**, the primary curated source. Extract the **past-tense, completed** portion; ignore open checkboxes and forward-looking sections.
2. **`CHANGELOG.md`**, secondary curated notes.
3. **`git log <default>..HEAD --oneline`**, the raw fallback. Commit titles only; do not paraphrase commit bodies.

Also run `gh pr view --json number,title,url`, tolerating failure when no PR exists, for the `Source` field.

**If none of those exist or have content, decline to fabricate.** Print "no source material available for a continuity entry" and exit.

### 3. Determine the filename

```
<continuityRoot>/<today>-<branch-slug>.md
```

**There is no ID to allocate and no counter to read.** Identity is the ticket slug, which is already unique and is the citation form the evidence rules require. **Do not invent a sequential ID, and do not scan other entries for a "next" anything: that scan is the collision.**

The ISO date prefix is load-bearing: lexical sort equals chronological sort, which is what gives newest-first ordering with no index to maintain. Always `YYYY-MM-DD`, always first.

**If the target filename already exists**, this branch has closed before. **Do not silently overwrite.** Read it, then either fold the new material in or write a `-2` suffixed sibling, asking which and naming the existing file.

### 4. Compose the entry

```markdown
# <one-line past-tense title>

- **Date added:** YYYY-MM-DD
- **Covers:** YYYY-MM-DD (or a range `YYYY-MM-DD -> YYYY-MM-DD`)
- **Source:** <PR #N, commit <sha>, ticket <full-slug>>
- **Status:** active
- **Affected:**
  - `path/to/file.ts → symbolName()`
- **Summary:**
  - 2-5 bullets, one sentence each, past tense. What was done, not how.
- **Open threads:** (omit the whole field when there are none)
  - [ ] Concise description of an unfinished item.
```

**Conciseness rules, enforced strictly:**

- **Summary:** five bullets maximum, two or three preferred. Each **25 words or fewer**. No code blocks, no prose paragraphs.
- **Source:** cite a ticket by its **full slug**, never a bare number, since GitHub shares one counter between issues and PRs.
- **Affected:** anchor to stable symbols, never line numbers.
- **Open threads:** only real, identified follow-ups. Do not speculate. Omit the field when there are none.
- **`Status` must be exactly one line.** The read-side active count greps for it across files: two in one file double-counts, and zero makes the entry invisible.
- **No redundancy with the assertions file.** If the work added an invariant, that entry is the durable record; note "added A-NNN" and stop. Do not restate the invariant.
- **No redundancy with the PR summary**, which holds the full account. Continuity is the truncated handoff form.

### 5. Write the file

**A single Write call creating the new file. That is the entire write.**

**Touch nothing else.** No existing entry is read, edited, renumbered or recounted. There is no index to update. **If you find yourself opening another entry file to change it, stop**: that is the shared-offset bug growing back.

### 6. Verify

```bash
ls "$CONTINUITY_ROOT"/*<branch-slug>*.md
grep -c '^- \*\*Status:\*\*' "$CONTINUITY_ROOT/<filename>"
git status --porcelain "$CONTINUITY_ROOT"/[0-9]*.md
```

Expect exactly one path, a count of `1`, and exactly one line showing an untracked new file.

**A modified entry in the third check is a bug in this run only if this run caused it.** Check with `git diff` before reacting: an entry may carry unrelated uncommitted edits from earlier in the session, such as a manual status change. If this run did touch it, revert that one file and redo step 5 as a pure create. **Do not blanket-revert**, which would discard the unrelated work too.

## Reading the collection

Consumers derive everything at read time; nothing is stored.

```bash
ls "$CONTINUITY_ROOT"/[0-9]*.md | sort -r                                        # newest first
ls "$CONTINUITY_ROOT"/[0-9]*.md | sed 's|.*/||' | cut -c1-10 | sort -r | head -1 # last updated
grep -l '^- \*\*Status:\*\* active' "$CONTINUITY_ROOT"/[0-9]*.md | wc -l         # active entries
```

The `[0-9]*` glob is deliberate: it matches date-prefixed entries and skips a `README.md`.

**Ordering is guaranteed across dates only.** Entries sharing one date sort by slug, which carries no meaning, so read `Date added` rather than inferring sequence from position.

## What NOT to do

- **Do not create or update any shared file.** No index, no combined document, no counts file.
- **Do not allocate a sequential ID.**
- **Do not modify, renumber or re-status any existing entry.** Superseding is a manual edit to that one file; removal is `/pr:continuity-prune`.
- **Do not add entries for cosmetic-only PRs.** If unsure, ask.
- **Do not include diffs, large code blocks, or summary-grade detail.**
- **Do not fabricate dates, slugs or PR numbers.** Omit a value from `Source` rather than guessing it.

## Pruning is a separate skill

This skill never deletes. Removal is `/pr:continuity-prune <from-date>`, which is destructive and requires explicit invocation. **Never auto-prune as part of a close.**
