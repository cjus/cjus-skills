---
name: summary
description: Write a comprehensive summary of the completed work on this branch into the plan folder, with code examples, plan alignment, testing notes and an impact assessment. Use when the user says "/pr:summary", asks for a PR write-up, or when /pr:close needs the document that becomes the PR body.
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Bash(date:*), Read, Write, Glob
---

# /pr:summary

Write the document that becomes the PR body: what this branch did, how it maps to the plan, and how to verify it.

The branch should be feature complete and tested before this runs.

## Step 1. Context

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline --text
```

Take the branch, the slug and the plan folder from that. Then read:

- `<changelogRoot>/<slug>/PLAN.md` for the original objective
- `<changelogRoot>/<slug>/CHANGELOG.md` for curated decisions, which may be sparse

**`git log` is the authoritative record of what was done.** The changelog is a curated companion to it, not a substitute, so never describe work the log does not show.

## Step 2. Analyze the changes

```bash
git log "$DEFAULT_BRANCH"..HEAD --oneline
git diff "$DEFAULT_BRANCH"...HEAD --stat
git diff "$DEFAULT_BRANCH"...HEAD
date '+%Y-%m-%d'
```

The three-dot form compares against the merge base, which is what a reviewer sees on the PR. The two-dot form would fold in unrelated commits the default branch gained since the branch started.

## Step 3. Write the document

Write to `<changelogRoot>/<slug>/pr-summary-<date>.md`:

**Overview.** What this PR accomplishes, one or two paragraphs.

**Key changes.** The files and components modified, each with a brief description.

**Code examples.** Two or three representative snippets: a before and after for a refactor, a new interface, or the key logic change. Anchor each to its path.

**Plan alignment.** How the implementation maps to `PLAN.md`: items completed as planned, deviations and why, items deferred or descoped. A deviation stated plainly here is worth more than a summary that reads as though nothing moved.

**Testing.** How to verify the change by hand, which automated tests were added or modified, and which edge cases were considered.

**Impact assessment.** Files changed, lines added and removed, dependencies affected, and any breaking change.

**Deferred work.** Anything parked under `## Deferred` in `PLAN.md`, listed as prose. This is where dropped items stay findable: `/pr:close` triages them, most exit as DROP, and the summary is the only place they remain on the record. See `${CLAUDE_PLUGIN_ROOT}/reference/scope-contract.md`.

**No closing keyword followed by an issue reference, anywhere in the document, even in inline code.** `/pr:close` makes this file the PR body, and when the PR merges GitHub closes every issue a closing keyword points at. The keywords are `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves` and `resolved`, in any case and with or without a colon after them, and a reference is `#123` or `owner/repo#123`. Ordinary prose counts as much as quoted syntax: a sentence saying the branch fixed #30 links #30. Where the text has to show a closing line, as a summary about this workflow will, write the number as a placeholder, `Closes #N`, or name the issue without the keyword, "the ticket, #42". `/pr:close` writes the one closing line the PR needs, and its verify stops on a link to any issue other than the ticket.

Where the repo configures an assertions file, include the full audit statement in the format `${CLAUDE_PLUGIN_ROOT}/reference/assertion-audit.md § Reporting` gives. A PR summary is a reviewed artifact, so the enumeration is required rather than optional.

## Step 4. Report

When invoked standalone, end with: *"Summary written to `<changelogRoot>/<slug>/pr-summary-<date>.md`. Run `/pr:close` when you are ready to merge. It is required before the branch can merge."*

**Omit that line when running as a step of `/pr:close`**, since the close is already underway.

Never describe the branch as merge-ready without naming the command.
