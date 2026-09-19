# Rewrite root README as a skill catalog with per-plugin READMEs

Start date: 2026-09-19 13:44:39 MDT

Make the root `README.md` introduce the repo, catalog its skills, and link out to
per-plugin READMEs; and give `plugins/pr/` the README it has never had.

## Changes

### 2026-09-19 — `plugins/pr/README.md`, and the root README as a jumping-off point

**Wrote `plugins/pr/README.md`** (451 lines), following the `Contents` → `Install` → per-skill
→ `What ships here` structure the other three plugin READMEs share. All 22 skills documented,
verified by set comparison against `plugins/pr/skills/`.

The 22 are grouped rather than given 22 flat `##` sections, which at this size would be a list
instead of a document:

- **The lifecycle spine** (7) — the fixed order, `init` through `cleanup`, plus `abort`.
- **Working on a branch** (12) — unordered and optional; none is a step you owe the workflow.
- **The queue** (3) — `next`, `reviews`, `triage`, which leave no branch artifact.

Beyond the skills it documents the config schema, the plan folder and the per-branch vs
repo-global split, the three hooks, and a `How detection works` section carrying the three
rules the skills share (ask the system not the text; detect outcomes not invocations; an
undeterminable value never produces a gap). That section is the `pr` analogue of council's
`What agreement is worth` — the design reasoning, not just the surface.

**Root README now links out.** Four `Full documentation:` pointers, one per plugin section,
each naming what the target covers rather than just pointing. Also linked the two deep
references that were bare code spans (`pr/reference/config.md`, `pr/hooks/README.md`), and
listed `README.md` in each plugin's `## Layout` block now that all four exist.

## Decisions

- **Stated no case count for the guard probe suite.** `hooks/README.md` says 54; the suite
  reported 73 when run. Rather than propagate a stale number or introduce a competing one,
  the new README describes the suite without counting it. The drift is logged under
  `PLAN.md § Deferred`.
- **Deleted `#### One-time setup for /makebook` from the root README** (23 lines). It was
  bookcraft's venv and Chromium setup misfiled under the `### pr` heading. Verified nothing
  was lost first: `plugins/bookcraft/README.md` covers every requirement in its setup table,
  and names the four pip packages in its `What ships here` block. Operator chose the pointer
  over relocating it, which would have made the bookcraft section far longer than the other
  three and unbalanced the catalog.
- **Reframed the intro for four plugins.** The open question from `PLAN.md` — whether
  "`bookcraft` is the first plugin in it" was in scope — resolved as in scope, since
  "introduce the repo" is the first of the root README's three jobs.
- **Corrected a claim before it shipped.** A draft line called `/pr:sanity` "the only skill
  here that touches no tools at all", inferred from its frontmatter carrying no
  `allowed-tools`. Its body says the opposite: it re-runs a tool call to settle a flagged
  claim, just never speculatively. Rewritten to say that.
