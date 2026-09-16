# Let /pr:triage combine issues that share one file or one migration across priority bands

Start date: 2026-09-16 16:25:32 MDT

Split `/pr:triage` step 5's consolidation bar into a strict path and a loose path, so
that issues whose changes land in the same file or the same migration may be combined
across `priority:` bands, taking the highest member's band and naming each promoted
member in the report.

## Changes

### Phase 1 — fixed which sentences carry the bar (2026-09-16)

Read step 5 and every dependent before touching anything. The bar is carried by seven sentences
in `plugins/pr/skills/triage/SKILL.md` § Step 5 (L131-143), and depended on in four places:
the § Step 6 Combine block, § Step 7c (L241, L256, L262-266), § What this skill never does
(L271) and § Common mistakes (L283).

**Decision: row 3 of the ticket (#23, #24, #34) stays refused, and that is intended.** Strict is
scoped to the same file or the same migration. A shared two-file directory is neither, so the
group falls to the loose path and fails the one-band requirement on medium/medium/low. The
change reaches two of the ticket's three motivating groups by design.

**Decision: `plugins/pr/reference/ticketing.md:37` is in scope for Phase 5.** It states the
combining rationale in a shared reference outside the triage skill ("the combining bar required
them to agree"). Leaving it would ship a plugin whose reference contradicts its skill. This is a
consequence of the fixed objective, not a widening of it.

**Finding: `SKILL.md:266` goes from dated to false.** "consolidation changes how work is grouped,
never whether it is scheduled" does not survive the strict path, because a low+high group enters
at high and the low member crosses into `/pr:next`'s queue. Phase 5 must reach this sentence,
not only the `priority:` label sentence it was scoped to.

**Finding: Phase 3's "restate the loose path verbatim" rests on a premise that does not hold.**
Today's clause 2 already reads "Doing any one puts you inside the files the others name" — it is
already file-shaped. The ticket describes loose as members that "share a feature area but sit in
different files," which today's bar does not permit. Restating today's rule verbatim and
describing loose that way are two different edits, and only one of them keeps the overview's
promise to split the bar "rather than loosening any clause."

### Phases 2-6 — the split, and the trace that closed it (2026-09-16)

**Loose is today's clause 2, genuinely verbatim** (operator decision). The two strengths share
the file requirement and differ in band and member count only, so nothing the skill permitted
before is now wider. Clause 2 became the spine of step 5: every group clears it, and its
strength decides how clauses 1 and 3 apply.

Edits landed in `plugins/pr/skills/triage/SKILL.md` (§ Step 5 rewritten around the fork, § Step 6
Combine block, § Step 7c's five band-dependent passages and its confirmation prompt, § What this
skill never does, § Common mistakes) and `plugins/pr/reference/ticketing.md:37`.

**Two additions beyond the phase list, both closing gaps the rewrite opened:**

- **The `AskUserQuestion` confirmation now names the promotion**, with the member and both bands.
  A strict group carries two decisions in one approval — that the group is real, and that the
  lower member should be scheduled at the higher band — and burying the second one asks the
  operator to approve one thing and get two.
- **§ Common mistakes gained "Reading a shared directory as the same file."** This is the guard
  that keeps the row-3 decision from eroding: a tightly-themed directory is not one file, and
  its members still owe clause 3.

**Phase 6 trace, against the ticket's three refused groups:**

| Group | Shared material | Bands | Strength | Outcome |
|---|---|---|---|---|
| #69, #71 | one `revoke` migration | high, medium | strict | **forms** at high; report names #71 promoted medium→high |
| #71, #82 | one `revoke` migration | medium, high | strict | **forms** at high; report names #71 promoted medium→high |
| #23, #24, #34 | a two-file directory | medium, medium, low | loose | **still refused** on clause 3, as intended |

Two of three now form, which is the designed reach. Row 3 fails on bands and is meant to.
