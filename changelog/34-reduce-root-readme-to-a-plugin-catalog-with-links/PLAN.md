# Reduce root README to a plugin catalog with links

Start date: 2026-09-20 09:59:48 MDT

Ticket: https://github.com/cjus/cjus-skills/issues/34

## Overview

The root `README.md` still records too much detail about each plugin. It should be a catalog:
what plugins are available, what each one does, and a link to that plugin's own documentation
in `plugins/<name>/README.md`.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

The root `README.md` still records too much detail about each plugin. It should be a catalog: what plugins are available, what each one does, and a link to that plugin's own documentation.

### What it should become

- One short entry per plugin — name, one- or two-line description of what it does, and a link to `plugins/<name>/README.md`.
- Keep the repo-level material that genuinely belongs at the root (install, layout, releasing, license).
- Move plugin-specific detail down into the plugin folder's `README.md` rather than dropping it.

### Current state

- `README.md` is 167 lines, with a `### <plugin>` section per plugin plus plugin-specific subsections (e.g. `#### Configuration`, `#### Hooks` under `pr`).
- All four plugins already have their own README: `bookcraft`, `council`, `explain`, `pr`.

### Acceptance criteria

- [x] Root `README.md` `## Plugins` section is a catalog with a link per plugin, no per-plugin configuration or usage detail.
- [x] Any detail removed from the root is present in the corresponding `plugins/<name>/README.md`.
- [x] No broken links between the root README and the plugin READMEs.

## Plan

- [x] Phase 1: Audit what the root README says about each plugin, and diff it against what
      `plugins/<name>/README.md` already covers, to identify detail that would be lost.
- [x] Phase 2: Move any root-only plugin detail into the corresponding plugin README
      (notably the `pr` Configuration and Hooks subsections).
- [x] Phase 3: Rewrite the root `## Plugins` section as a catalog — one entry per plugin with
      a one- or two-line description and a link to `plugins/<name>/README.md`.
- [x] Phase 4: Verify every relative link resolves and no plugin detail was dropped.

## Open Questions

Both resolved by the operator on 2026-09-20, before implementation.

- ~~Should the catalog also list each plugin's skills by name, or only the plugin itself?~~
  **Only the plugin itself.** The four skill tables were dropped; each plugin's README documents
  its own skills.
- ~~Does the root `## Layout` section stay as-is, or does part of it belong with the catalog?~~
  **Removed entirely.** Its per-plugin file trees were already covered by each plugin's
  `## What ships here`; its two trailing paragraphs were relocated (see CHANGELOG).

Governing constraint for the rewrite: the root README should be easy to read and browse, and
concise by nature.

## Status

Complete as of 2026-09-20. All four phases and all three acceptance criteria done. `README.md`
is 167 lines to 57. One commit, `ea8c632`, plus the close artifacts. PR #35 open against `main`,
merging cleanly. Review verdict APPROVE, no blocking or important issues.

## Deviations

**The ticket said to keep `layout` at the root; it was removed instead.** The ticket's "What it
should become" listed the repo-level material to keep as "install, layout, releasing, license".
The operator directed on 2026-09-20 that `## Layout` be removed outright. The section's substance
was not lost: its per-plugin trees were already carried by each plugin's `## What ships here`, and
its two trailing paragraphs were relocated (the `${CLAUDE_PLUGIN_ROOT}` explanation to `## Install`
at the root, the reference-docs rationale into the `pr` and `council` READMEs).

**Phase 2 moved different content than predicted.** The phase anticipated relocating the `pr`
Configuration and Hooks subsections. The Phase 1 audit found `plugins/pr/README.md` already
covered both in more depth, so nothing moved for them. Three other root-only details did need
relocating, and were. The phase's intent, no detail lost, was met.

## Deferred

- `plugins/bookcraft/README.md:342` — its `## What ships here` tree lacks the `plugins/bookcraft/`
  root line that the other three plugin trees carry. Raised by the 2026-09-20 review. Now the only
  file tree for that plugin, since the root one is gone. Cosmetic inconsistency, no reader is
  misled.
