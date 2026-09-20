# Rewrite root README as a skill catalog with per-plugin READMEs

Start date: 2026-09-19 13:44:39 MDT

## Overview

The root `README.md` should do three jobs at once: **introduce the repo**, **serve as a
catalog** of the skills it ships, and act as a **jumping-off point** into the per-plugin
READMEs. Each plugin carries its own `README.md` that fully documents the plugin and every
one of its underlying skills.

Two concrete gaps remain. The root catalog describes skills but links nowhere, so the
jumping-off half of its job does not exist. And `plugins/pr/` — the largest plugin in the
repo at 22 skills — has no README at all.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**[#11 Rewrite root README as a skill catalog with per-plugin READMEs](https://github.com/cjus/cjus-skills/issues/11)**
— `priority:high`, `docs`.

Action items carried from the ticket body:

- [x] Root `README.md`: introduction, catalog, and jumping-off point.
  - [x] Introduces the repo and what a plugin marketplace is.
  - [x] Catalogs every plugin with a per-skill table (16 rows across four plugins).
  - [x] **Links into each plugin's `README.md`.** Four `Full documentation:` pointers, one
        per plugin section, plus links to `pr/reference/config.md` and `pr/hooks/README.md`.
- [x] Every plugin has a `README.md` fully documenting the plugin and all its skills.
  - [x] `plugins/bookcraft/README.md` — 4 of 4 skills documented.
  - [x] `plugins/council/README.md` — 3 of 3 skills documented.
  - [x] `plugins/explain/README.md` — 2 of 2 skills documented.
  - [x] `plugins/pr/README.md` — 22 of 22 skills documented, verified by set comparison.

### Starting state, verified 2026-09-19

- Four plugins, 31 skills: `bookcraft` (4), `council` (3), `explain` (2), `pr` (22).
- Every skill has a `SKILL.md`; no skill has its own `README.md`, and none needs one. The
  plugin README is the unit of human-facing documentation.
- The three existing plugin READMEs share one structure: `Contents` → `Install` → a
  section per skill → `What ships here`. `plugins/pr/README.md` should follow it.
- The root README's only sub-README reference is a bare code span
  (`plugins/pr/hooks/README.md`), not a link.

## Plan

- [x] Phase 1: Write `plugins/pr/README.md`, following the structure the other three
      share, covering all 22 skills — the lifecycle spine (`init`, `ticket`, `start`,
      `pre-test`, `close`, `cleanup`, `abort`), the branch-level helpers (`cp`, `status`,
      `resume`, `sync`, `plan-check`, `precompact`, `condense`, `summary`, `commitmsg`,
      `sanity`, `continuity-add`, `continuity-prune`) and the queue-level ones (`next`,
      `reviews`, `triage`).
- [x] Phase 2: Add links from each root `### <plugin>` section into that plugin's README,
      so the catalog is a jumping-off point rather than a terminus.
- [x] Phase 3: Re-read the root README end to end as an introduction, confirming the three
      jobs hold together after the edits.

## Open Questions

Both resolved 2026-09-19, by operator decision.

- **Root README intro framing.** Resolved: fixed on this branch as part of "introduce the
  repo". The line now reads "Four ship today — `bookcraft`, `council`, `explain` and `pr`"
  rather than naming `bookcraft` as the first plugin.
- **Depth split for `pr` in the root catalog.** Resolved as already settled: the root keeps
  `pr` at 7 spine rows, and the remaining 15 skills get their treatment in the plugin README.

## Deferred

- **`plugins/pr/hooks/README.md` states the guard probe suite is "54 cases".** The suite
  reported 73 on 2026-09-19 (`passed 31, failed 42`). The count is stale. The new plugin
  README deliberately states no number so it does not bake in a third one. Docs-only fix,
  outside this branch's objective.
- **`jq` on this machine is the wrong architecture** — `/usr/local/bin/jq: Bad CPU type in
  executable` (x86 binary, arm64 host). That, not a plugin defect, is what failed 42 of the
  73 guard probe cases. Environment fix for the operator: reinstall `jq` for arm64.

From the `/pr:pre-test` code review, 2026-09-19. Both verified pre-existing on `main` and
untouched by this branch, so both fail the in-scope test:

- **The root catalog omits `/pr:continuity-add` and `/pr:continuity-prune`.** `README.md:88`
  enumerates 13 of the 15 non-spine `pr` skills, so those two are undiscoverable from the
  root. Byte-identical on `main`. Largely mitigated by this branch's link into the plugin
  README, which does cover all 22. Occasion: next edit to the root `### pr` section.
- **The `## Releasing` section is hardcoded to bookcraft.** It names
  `plugins/bookcraft/plugin.json` and `claude plugin tag plugins/bookcraft` as *the*
  procedure, now that four plugins ship. Occasion: the next release of a non-bookcraft
  plugin.

From the `/pr:close` review gate, 2026-09-20. Both verified byte-identical on `main`:

- **The root `### pr` section carries two stale one-liners.** `README.md:149` credits the
  `code-reviewer` agent to "the close gate" (the `Stop` hook) when it is spawned by
  `/pr:close` Step 2 and `/pr:pre-test` Step 4; `README.md:71` describes `/pr:init`'s label
  set as only the queue labels. Occasion: next edit to the root `### pr` section.
