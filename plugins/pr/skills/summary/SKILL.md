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

Where the repo configures an assertions file, include the full audit statement in the format `${CLAUDE_PLUGIN_ROOT}/reference/assertion-audit.md § Reporting` gives. A PR summary is a reviewed artifact, so the enumeration is required rather than optional.

## Step 4. Report

When invoked standalone, end with: *"Summary written to `<changelogRoot>/<slug>/pr-summary-<date>.md`. Run `/pr:close` when you are ready to merge. It is required before the branch can merge."*

**Omit that line when running as a step of `/pr:close`**, since the close is already underway.

Never describe the branch as merge-ready without naming the command.
