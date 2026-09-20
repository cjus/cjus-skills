# Rewrite root README as a skill catalog with per-plugin READMEs

Closes the two gaps that kept the root `README.md` from doing the third of its three jobs.

## Overview

The root `README.md` is meant to introduce the repo, catalog the skills it ships, and act as a
jumping-off point into the per-plugin READMEs. The first two held; the third did not exist.
There were **zero markdown links** from the root README to any plugin README, so the catalog
was a terminus. And `plugins/pr/` — the largest plugin in the repo at 22 skills — had no
README at all, so for a third of the repo's skills there was nowhere to jump to.

This PR writes `plugins/pr/README.md` covering all 22 skills, and turns each of the root
catalog's four plugin sections into a jumping-off point. Along the way it removes a block of
bookcraft setup documentation that was sitting under the `### pr` heading, and reframes an
intro line that described a four-plugin repo as a one-plugin one.

Documentation only. No code, no scripts, no behavior change.

## Key changes

| File | Change |
|---|---|
| `plugins/pr/README.md` | **New, 452 lines.** All 22 `pr` skills, the config defaults, the plan folder, the three hooks, and the detection rules. |
| `README.md` | Four `Full documentation:` links, two deep links, the intro reframed, the misfiled `/makebook` block removed, `README.md` added to each plugin's Layout entry. |
| `changelog/11-.../PLAN.md` | Status refreshed to complete; both open questions resolved; four items logged under `## Deferred`. |
| `changelog/11-.../CHANGELOG.md` | The decisions behind the above. |

### `plugins/pr/README.md`

Follows the structure the other three plugin READMEs share — `Contents` → `Install` → a
section per skill → `What ships here` — with the 22 skills **grouped** rather than given 22
flat `##` sections, which at this size would be a list instead of a document:

- **The lifecycle spine** (7) — `init`, `ticket`, `start`, `pre-test`, `close`, `cleanup`, `abort`
- **Working on a branch** (12) — unordered, optional, none owed to the workflow
- **The queue** (3) — `next`, `reviews`, `triage`, which leave no branch artifact

Beyond the skills it documents the config table, the per-branch vs repo-global document split,
the three hooks and their activation rule, and a `How detection works` section carrying the
three rules the skills share. That last section is the `pr` analogue of council's `What
agreement is worth`: the design reasoning, not just the surface.

## Code examples

The root catalog gains a pointer per plugin, each naming what the target covers rather than
just pointing at it — `README.md:75`:

```markdown
**Full documentation: [`plugins/pr/README.md`](plugins/pr/README.md)** — all 22 skills, the
config defaults, the plan folder, the three hooks, and the detection rules every skill obeys.
The seven below are the spine; the table stops there because the rest are optional.
```

The intro no longer frames four plugins as one — `README.md:5`:

```diff
-The marketplace exists so the collection can grow: `bookcraft` is the first plugin in it,
-not the whole of it.
+Four ship today — `bookcraft`, `council`, `explain` and `pr` — and the marketplace exists
+so the collection can grow.
```

The new README's own design rationale, rather than a restatement of the skill list —
`plugins/pr/README.md`, `How detection works`:

```markdown
**A value that could not be determined never produces a gap.** If `gh` is unreachable, a
missing issue and an unreadable issue look identical from here, so the state is reported as
unresolved and nothing is said. Treating an absence as proof is the trap; a gate that
false-positives trains you to click through it.
```

## Plan alignment

Every item in `PLAN.md` is complete, and all three phases landed as written.

| Plan item | Outcome |
|---|---|
| Phase 1 — write `plugins/pr/README.md` for all 22 skills | Done. Coverage verified by set comparison against `plugins/pr/skills/`. |
| Phase 2 — link each root `### <plugin>` section into its README | Done, four links, plus two deep links that were bare code spans. |
| Phase 3 — re-read the root README end to end as an introduction | Done, and it surfaced the misfiled `/makebook` block. |

**Two deviations, both operator-approved during the run:**

1. **Phase 3 removed 23 lines the plan did not anticipate.** `#### One-time setup for
   /makebook` sat under the `### pr` heading — bookcraft content misfiled under the wrong
   plugin. Before deleting, every fact in it was traced to `plugins/bookcraft/README.md`
   (its setup table covers the requirements; `What ships here` names the four pip packages),
   so nothing was lost. The operator chose the pointer over relocating the block, which
   would have made the bookcraft section far longer than the other three.
2. **The `PLAN.md` open question about the intro line was resolved as in scope** rather than
   split into its own ticket, since "introduce the repo" is the first of the root README's
   three jobs.

## Testing

No automated tests; this repo configures no `checks.*` and has no CI workflows. Verification
was by checking documentation claims against source:

- **Skill coverage** — `### /pr:x` headings set-compared against `ls plugins/pr/skills/`.
  22/22, exact match, nothing invented and nothing missed.
- **File tree** — `What ships here` diffed against `find plugins/pr -type f`. All 20
  non-skill paths exist; nothing real omitted.
- **Config table** — all 12 rows checked against `reference/config.md` and
  `reference/pr-config.schema.json`.
- **Gap IDs** — the 13 listed match `reference/lifecycle.md`, in order.
- **Links and anchors** — all 6 relative links in the root README resolve; all 12 in-page
  anchors in the plugin README match real heading slugs.
- **The deletion** — all eight facts in the removed block traced to specific lines in
  `plugins/bookcraft/README.md`.

A `/pr:pre-test` code review returned `APPROVE` with no critical or important findings and
six suggestions, all of which were verified against source and applied in `b81f036`.

**To verify by hand:** open `plugins/pr/README.md` and click through the Contents anchors;
open the root `README.md` and click each `Full documentation:` link; confirm the `### pr`
section now ends at `#### Hooks` with no bookcraft content under it.

### Edge cases considered

- **Stale numbers.** `plugins/pr/hooks/README.md` claims the guard probe suite has 54 cases;
  it reported 73 when run. The new README deliberately **states no count**, so it does not
  bake in a third number. Logged under Deferred.
- **Inferred claims.** A draft line called `/pr:sanity` "the only skill here that touches no
  tools at all", inferred from its frontmatter carrying no `allowed-tools`. Its body says the
  opposite — it re-runs a tool call to settle a flagged claim, just never speculatively.
  Corrected before commit.

## Impact assessment

```
 README.md                    |  42 +-   (15 added, 27 removed)
 changelog/11-.../CHANGELOG.md|  52 +
 changelog/11-.../PLAN.md     |  90 +
 plugins/pr/README.md         | 452 +
 4 files changed, 609 insertions(+), 27 deletions(-)
```

**No breaking change. No dependency change. No runtime surface touched** — no skill, script,
hook, agent or manifest is modified. The only file a user's tooling reads that changes at all
is the root `README.md`, and only its prose.

**Assertions: disabled.** `docs.assertionsFile` is `null` in `.claude/pr-config.json`, so no
audit applies to this branch.

## Deferred work

Four items, none in scope for this branch's frozen objective. All recorded in
`PLAN.md § Deferred` so they stay findable after triage.

- **`plugins/pr/hooks/README.md` says the guard probe suite is "54 cases".** It ran 73 on
  2026-09-19. The count is stale. Docs-only fix.
- **`jq` on the development machine is the wrong architecture** — `/usr/local/bin/jq: Bad CPU
  type in executable`, an x86 binary on an arm64 host. That, not a plugin defect, failed 42 of
  the 73 guard probe cases. An environment fix for the operator, not a repo change.
- **The root catalog omits `/pr:continuity-add` and `/pr:continuity-prune`.** `README.md:88`
  enumerates 13 of the 15 non-spine skills. Verified byte-identical on `main`, so pre-existing
  and out of scope; largely mitigated by this branch's link into the plugin README, which
  covers all 22.
- **`## Releasing` is hardcoded to bookcraft.** It names `plugins/bookcraft/plugin.json` as
  *the* release procedure now that four plugins ship. Pre-existing and untouched here.
