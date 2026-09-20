# Fix documentation drift in the root README and hooks README

Start date: 2026-09-20 07:53:18 MDT

Correct four documentation-accuracy defects deferred from #11: a stale test-case
count in the hooks README, two skills missing from the root catalog, a `## Releasing`
section hardcoded to bookcraft, and two stale one-liners in the root `### pr` section.

## Changes

### 2026-09-20 — all four items corrected, each verified against source first

**The ticket's own citations had rotted — four of its five anchors.** Issue #27 cites
three line numbers and two paths. All three line numbers had moved: the root catalog
is at `README.md:87`, not `:88`; the `code-reviewer` one-liner at `:137`, not `:149`;
and the `/pr:init` sentence at `:69`, not `:71`, where line 71 is inside a code fence.
One of the two paths is wrong as well — `plugins/bookcraft/plugin.json` does not exist
and never did on `main`; the manifest is at `plugins/bookcraft/.claude-plugin/plugin.json`.
Exactly one anchor survived intact, `plugins/pr/hooks/README.md`.

This paragraph took three drafts to get right, which is the finding. The first said two
anchors had drifted; the second, correcting it, said three and claimed both paths held.
Both were caught in review, not by me. The count is four. A ticket about stale citations
whose own citations are stale, in a changelog that then miscounts them twice, is the
argument for anchoring on text rather than offsets — made rather more forcefully than
intended. The phase text in `PLAN.md` preserves the original numbers as filed, since the
objective is immutable; every edit was made against the anchors, not the offsets.

**Guard probe suite: 54 → 73.** Settled by running the suite, not by trusting either
recorded number. `73 passed, 0 failed`. A first run reported `passed 31, failed 42`,
which was an environment artifact rather than a real failure: the `jq` first on PATH
(`/usr/local/bin/jq`, 2022) is an x86-only binary that aborts with `Bad CPU type in
executable` on Apple Silicon. Re-running against `/usr/bin/jq` (universal, 1.7.1)
passed everything. The case count is 73 under either run; only the pass/fail split
changed.

**Root catalog completed.** Added `/pr:continuity-add` and `/pr:continuity-prune`, the
two skills the catalog omitted. Rather than appending them to the queue clause, where
they do not belong, they got their own clause naming what they operate on — the
repo-root continuity folder — with `continuity-add`'s double life as `/pr:close`'s
handoff step spelled out. Verified complete afterward by diffing the skill names in
the README against `plugins/pr/skills/`: 22 on disk, 22 named, no difference in either
direction.

**`## Releasing` generalized, one procedure rather than four.** The shape question was
resolved on evidence: all four plugins have an identical layout
(`plugins/<name>/.claude-plugin/plugin.json` plus one `.claude-plugin/marketplace.json`
entry), so a per-plugin list would have been the same text copied four times. The
section now parameterizes on `<plugin>` and states that versions move independently,
which is already true — 1.0.2, 0.1.0, 0.1.0, 0.2.1. The bare `.` in the first validate
command is called out as deliberately *not* parameterized, since it validates the
marketplace manifest covering all four. `claude plugin tag --help` confirms the
`{name}--v{version}` tag format and the marketplace-agreement check the prose claims,
and `claude plugin validate --strict` passes on the marketplace plus all four plugins.

**Two one-liners corrected.** The `code-reviewer` agent is spawned by `/pr:close`
Step 2 (`close/SKILL.md:157`) and `/pr:pre-test` Step 4 (`pre-test/SKILL.md:64`), not
by "the close gate" — the close gate is the `Stop` hook, `verify-close-landed.sh`,
which spawns nothing. `/pr:init` creates eleven labels, not just the queue's
(`init/SKILL.md:105-110`): two `status:*`, three `priority:*`, and six type labels.

**Four defects were introduced by this branch and caught before merge**, one by
self-review and three by the review gate across two passes:

1. The first draft of the generalized `## Releasing` said to substitute the plugin name
   "in all three commands", but only two of the three contain `<plugin>`. Caught in
   Phase 6 self-review.
2. The `/pr:continuity-prune` one-liner omitted that the command lists its targets and
   asks before deleting — a material omission for a destructive command. First gate.
3. The anchor-drift paragraph above claimed one anchor had drifted. First gate.
4. The correction to (3) said three, and claimed both paths held. Four of five had
   rotted. Second gate.

Three drafts of one paragraph, two of them wrong, both caught by a gate rather than by
the author. On a branch whose only product is accuracy, that is the argument for the
review gate being adversarial rather than confirmatory.

### 2026-09-20 — scope extended at the close triage, by operator decision

The `/pr:close` deferred-work triage normally files survivors as follow-up issues. The
operator directed instead that they be addressed on this branch. The original four-item
objective was already delivered in full; these are additions, not revisions.

**The guard suite now describes its own completeness.** This is the substantive one, and
it closes the loop on item 1 rather than just restating it. The suite could skip its two
linked-worktree cases when `git worktree add` fails, but it printed one skip line for the
two of them and no skip count at all, so a degraded run reported `passed 71, failed 0` and
read as a complete one. That is precisely the confusion #27 was filed over — a maintainer
cannot tell new coverage from a broken run — reproduced inside the tool meant to settle it.
The totals line is now `passed 71, failed 0, skipped 2  (73 cases)`, with both skipped
cases named. The parenthesised total is invariant, so the figure in the README is checkable
against any run rather than only against a perfect one. Verified by forcing the fixture to
fail.

**`.claude/settings.json` now exists.** `git-conventions.md:22` bans AI attribution and
prints the JSON to set, but nothing in the repo set it, so every agent-assisted commit
re-litigated it by hand — as this branch did, costing an operator decision and a
force-push. A detour worth recording: a subagent asked to verify the setting reported that
the documented empty-string form silently does nothing and that `false` was required. The
official docs page was truncated at the relevant example and could not settle it. What
settled it was precedent plus an empirical check: an existing repo uses the empty-string form
and carries zero attribution trailers across its last forty commits. The third review pass
then found the schema bundled in Claude Code 2.1.278, which describes `commit` verbatim as
"Attribution text for git commits, including any trailers. Empty string hides attribution."
The documented shape was correct. The claim that would have had us "correct" a working
convention did not survive being checked, which is the same lesson as the rest of this
branch.

Checking it did turn up a real gap, though. The same schema declares a third key,
`sessionUrl`, a boolean defaulting to **true** that emits a `Claude-Session:` trailer and a
PR-body link. `git-conventions.md:22` bans session identifiers in the same sentence as
co-author lines, but the JSON it printed set only `commit` and `pr`, so a repo following it
exactly would still emit the identifier from any cloud or Remote Control commit. The doc
now prescribes all three keys and explains why the types differ — two strings hidden by
emptiness, one boolean — and this repo's `.claude/settings.json` sets all three.

Also added `plugins/pr/scripts/test-acceptance.sh` to the root README's layout tree, and
commented the corrected case count onto issue #5 rather than editing its body, so the
operator's original wording stands.
