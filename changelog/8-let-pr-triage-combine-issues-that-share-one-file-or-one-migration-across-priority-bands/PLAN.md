# Let /pr:triage combine issues that share one file or one migration across priority bands

Start date: 2026-09-16 16:25:32 MDT

## Overview

`/pr:triage` step 5 currently refuses to consolidate two issues whose work lands in the
same file or the same migration when they carry different `priority:` labels. That bar is
right for issues that merely share a theme and wrong for work that cannot be split, where
it costs a full duplicated lifecycle to deliver what is often a single extra line.

This branch splits the consolidation bar by strength rather than loosening any clause. A
**strict** path applies where members' changes land in the same file or the same
migration: the band requirement is replaced by "the group takes the highest member's
band", the report names each promoted member explicitly, clause 1 is implied rather than
separately required, and two members suffice. A **loose** path covers members that share a
feature area but sit in different files, and keeps today's rules verbatim. The report says
which strength applied. § What this skill never does is revisited so its intent matches
the new behaviour.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**Issue:** [#8 — Let /pr:triage combine issues that share one file or one migration across priority bands](https://github.com/cjus/cjus-skills/issues/8)
**Labels:** `status:in-progress`, `priority:high`, `refactor`

`/pr:triage` step 5 refuses to combine two issues whose work lands in the same file or the same migration when they carry different `priority:` labels. That refusal is correct for issues which merely share a theme. It is wrong for work that cannot be split, where it costs a full duplicated lifecycle to deliver what is often a single extra line.

### Where it bites

Measured in `The-Clarity-Brand/behirut-ai2`, which runs this plugin. Three groups have been refused across three consecutive triage runs:

| Members | Shared material | Bands | Outcome |
|---|---|---|---|
| #69, #71 | one `revoke` migration on community gamification | high, medium | refused, both ran as separate branches |
| #71, #82 | one `revoke` migration on community gamification | medium, high | refused, both still open |
| #23, #24, #34 | `src/sections/dashboard/decisions/`, a two-file directory | medium, medium, low | refused |

In the second row the medium member is one additional `revoke` statement in a migration the high member already requires. Delivering it separately costs `/pr:start`, a worktree, a plan folder, a review gate, the close artifacts, a continuity entry and `/pr:cleanup`.

### What is miscalibrated

**Clause 3 answers the wrong question for indivisible work.** Its rationale is that combining across bands silently promotes the low member or demotes the high one, and `/pr:next` ranks band above everything else. That holds when the members are separable. When they land in one file or one migration the work is a single unit, and the only real question is when that unit gets scheduled. The honest answer is the highest member's band.

**Clause 1 is near-redundant when clause 2 is strict.** If doing one member puts you inside the file the other names, then the occasion for one is the occasion for the other by construction.

**The two-member guidance is inverted for this case.** The skill treats a pair below three members as usually costing more attention than it saves. What a same-file pair saves is one entire lifecycle, which is the largest saving the skill has to offer.

**The risk the bar is paying for is already mitigated.** Step 7c quotes each member's body verbatim into the combined issue, so `/pr:next` and `/pr:start` still see every member's detail. The failure that justifies "do-not-combine is the default" is one the implementation already designed out.

### Proposed change

Split clause 2 by strength rather than loosening any clause.

- [x] **Strict clause 2**, where the members' changes land in the same file or the same migration. The band requirement is replaced by this: the group takes the **highest** member's band, and the report names each promoted member explicitly, so the promotion is visible rather than silent. Clause 1 is implied and not separately required. Two members is sufficient.
- [x] **Loose clause 2**, where the members share a feature area but sit in different files. Everything stays exactly as written today: same band, one occasion, three members preferred.
- [x] Have the report say which strength applied, so a reader can tell why a group formed.
- [x] Revisit § What this skill never does, which reads "Never changes a `priority:` label". Under the strict path no existing issue's label is edited, since the band lands on a newly created issue, so the sentence is still literally true while its intent has changed. Make that explicit rather than leaving a reader to reconcile it.

The asymmetry supports the change. A band on a newly created issue is one label and trivially reversible. A duplicated lifecycle is spent for good.

### Occasion

The next time `/pr:triage` refuses a group whose members share one file, which in the source repo named above is now happening on every run.

## Plan

- [x] Phase 1: Read `/pr:triage` step 5 as it stands, and the clauses it references, to fix exactly which sentences carry the bar and which downstream steps (6, 7c, the report, § What this skill never does) depend on them.
- [x] Phase 2: Write the strict path — same file or same migration, highest member's band, clause 1 implied, two members sufficient — as a distinct branch of clause 2 rather than an edit to the existing text.
- [x] Phase 3: Restate the loose path verbatim as today's rule, so a reader sees the two strengths side by side and cannot mistake which one they are under.
- [x] Phase 4: Make the report name the strength that applied and, on the strict path, each promoted member by number and prior band.
- [x] Phase 5: Revisit § What this skill never does so the "never changes a `priority:` label" sentence states why it remains true under the strict path.
- [x] Phase 6: Re-read step 5 through step 7c end to end against the three refused groups in the ticket, confirming each would now form or still be refused as intended.

## Open Questions

- **RESOLVED (operator, Phase 1).** Should the ticket's group 3 (#23, #24, #34), which shares a
  two-file directory rather than a single file, be reachable by the strict path? **No — it stays
  refused, and that is intended.** Strict is scoped to the same file or the same migration; a
  shared directory is neither. Phase 6 records row 3 as still-refused rather than as a miss.

- **RESOLVED (Phase 1).** Does "the same migration" mean the same migration file, or any two
  migrations applied together? The narrow reading stands, by this question's own fallback:
  step 5 says nothing about migrations. `migration` appears in the triage skill only at
  SKILL.md:107 and :121 (step 4 verdict-checking) and :280-281 (§ Common mistakes), never in
  the consolidation clauses. Nothing to override the narrow reading.

- **STANDS, no-op.** On the strict path, does the highest member's band apply when every member
  already carries the same band? Yes, and it is a no-op by construction. A writing concern for
  Phase 2, not a decision: the text should not make a reader stop and check.

- **STANDS as assumed.** Does the strict path change anything for a group of three or more, or
  only lower the two-member bar? Assumed the former, strictness being about shared material
  rather than group size. No example in the ticket is a three-member same-file group, so nothing
  exercises the difference.

## Phase 1 findings

**RESOLVED (operator).** The ticket describes the loose path as members that "share a feature
area but sit in different files", and Phase 3 calls for restating today's rule "verbatim". Those
are two different edits: today's clause 2 already reads "Doing any one puts you inside the files
the others name", so it is already file-shaped and grants no different-files permission to
restate. **Loose is today's clause 2, genuinely verbatim.** The two strengths share the file
requirement and differ in band and member count only, which keeps the overview's promise to
split the bar rather than loosen any clause. The checked ticket box above retains the issue's
original wording; what shipped is the narrower reading.


Three dependents of the bar sit outside the phase list as written. Recorded here as status, not
as new scope; each is a consequence of the fixed objective rather than an addition to it.

1. **`plugins/pr/reference/ticketing.md:37` carries the bar and is outside the skill.** It reads
   "A consolidated issue inherits the shared band of its members, because those were already
   ranked and the combining bar required them to agree." That contradicts the strict path in a
   shared reference other skills read. Folded into Phase 5.

2. **`SKILL.md:266` becomes false under strict, not merely dated.** "consolidation changes how
   work is grouped, never whether it is scheduled" is the sharpest conflict in the skill: a
   low+high strict group enters at high, moving the low member from outside `/pr:next`'s queue
   to inside it. Phase 5 names only § What this skill never does; this sentence needs it more.

3. **§ Common mistakes (SKILL.md:283) counts the clauses.** "Three clauses, written out, or it
   is not a group" stops being accurate for strict groups, where clause 1 is implied and
   clause 3 is replaced. Same for SKILL.md:133 ("all three") and :139.
