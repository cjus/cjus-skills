# Fix documentation drift in the root README and hooks README

Start date: 2026-09-20 07:53:18 MDT

## Overview

Correct four documentation-accuracy defects deferred from #11 (PR #25). All four were
verified against source when filed and are byte-identical on `main`, so they are
pre-existing drift rather than anything that branch introduced.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

**Scope bound:** these four items and the evidence needed to correct them. Rewriting
README structure, editing other plugins' READMEs, or fixing the guard suite itself are
all out of scope.

## About Ticket

**#27 — Fix documentation drift in the root README and hooks README**
https://github.com/cjus/cjus-skills/issues/27 · `priority:high`, `docs`

Four documentation-accuracy items deferred from #11. All four were verified against source, and all four are byte-identical on `main`, so they are pre-existing rather than introduced by that branch.

- [x] **`plugins/pr/hooks/README.md` states the guard probe suite has "54 cases".** It reported 73 when run on 2026-09-19. A maintainer running the suite after editing the guard cannot tell whether the extra results are new coverage or a broken run.
- [x] **The root catalog omits `/pr:continuity-add` and `/pr:continuity-prune`.** `README.md:88` enumerates 13 of the 15 non-spine `pr` skills, so those two are undiscoverable from the root.
- [x] **`## Releasing` is hardcoded to bookcraft.** It names `plugins/bookcraft/plugin.json` and `claude plugin tag plugins/bookcraft` as *the* procedure, now that four plugins ship.
- [x] **The root `### pr` section carries two stale one-liners.** `README.md:149` credits the `code-reviewer` agent to "the close gate" (the `Stop` hook) when it is spawned by `/pr:close` Step 2 and `/pr:pre-test` Step 4. `README.md:71` describes `/pr:init`'s label set as only the queue labels, when it creates eleven including six type labels.


## Plan

- [x] Phase 1: Establish ground truth for each of the four items before editing any
      prose. Run the guard probe suite and record the actual case count; enumerate the
      non-spine `pr` skills and diff that against the root catalog; confirm the four
      shipping plugins; read `/pr:close` Step 2 and `/pr:pre-test` Step 4 for what
      actually spawns the `code-reviewer` agent, and `/pr:init` for the full label set.
- [x] Phase 2: Fix the `plugins/pr/hooks/README.md` case count to the measured value.
- [x] Phase 3: Add `/pr:continuity-add` and `/pr:continuity-prune` to the root catalog
      at `README.md:88`.
- [x] Phase 4: Generalize `## Releasing` so it covers all four plugins rather than
      naming bookcraft's paths as the procedure.
- [x] Phase 5: Correct the two stale one-liners in the root `### pr` section —
      the `code-reviewer` attribution at `README.md:149` and the `/pr:init` label
      description at `README.md:71`.
- [x] Phase 6: Re-verify every corrected claim against source, since this branch's
      whole product is accuracy.

## Open Questions

Both resolved during the work; neither needed an operator decision.

- **Guard suite case count.** Settled by running the suite rather than trusting either
  number: `73 passed, 0 failed`. The hooks README's "54" was stale, and the ticket's
  observation of 73 on 2026-09-19 was correct. Note that a stock `jq` on PATH may be an
  x86 binary that fails on Apple Silicon; the run above used `/usr/bin/jq`. That is an
  environment issue, not a suite defect, and the case count is 73 either way.
- **`## Releasing` shape.** Resolved to one generalized procedure parameterized by
  plugin, on evidence rather than preference: all four plugins have the identical
  layout (`plugins/<name>/.claude-plugin/plugin.json` plus one entry in
  `.claude-plugin/marketplace.json`), so a per-plugin list would have been four copies
  of the same text. Their versions already differ (1.0.2, 0.1.0, 0.1.0, 0.2.1), which
  the new text states explicitly.

## Scope extension, by operator decision

At the `/pr:close` deferred-work triage the operator directed that the survivors be
**addressed on this branch rather than filed as follow-up issues**. The original
four-item objective above is unchanged and was delivered in full; these are additions
the operator authorized, recorded here rather than in the plan's checklist because the
objective itself is immutable.

- [x] Add `plugins/pr/scripts/test-acceptance.sh` to the root README's layout tree.
- [x] Make the guard suite's case count self-describing. It now counts skips and prints
      the invariant total: `passed 71, failed 0, skipped 2  (73 cases)`. Both skipped
      worktree cases are named, where before only one was and no skip count appeared, so
      a degraded run read as a complete one. Verified by forcing `git worktree add` to
      fail.
- [x] Correct the stale 54-case figure in issue #5. Added as a comment rather than a
      body edit, so the operator's original wording stands.
- [x] Add `.claude/settings.json` so the harness stops adding AI attribution, which is
      what `plugins/pr/reference/git-conventions.md:22` asks for and nothing enforced.

## Deferred

- Issue #27's own body cites `plugins/bookcraft/plugin.json`, which does not exist; the
  manifest is at `plugins/bookcraft/.claude-plugin/plugin.json`. It is one of the four
  stale citations in the ticket, and the only one this branch does not correct. Dropped:
  cosmetic once this ticket closes on merge, and no occasion would cause it to be
  picked up.
