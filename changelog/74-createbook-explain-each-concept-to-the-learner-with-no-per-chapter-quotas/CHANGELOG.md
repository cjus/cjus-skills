# createbook: explain each concept to the learner, with no per-chapter quotas

Start date: 2026-10-09 11:09:51 MDT

`/createbook` chapters written as directions to an explainer leave a reader who is learning the
subject without the explanation. This branch makes every chapter explain each concept directly
to the learner, after `qe`'s method, and removes the per-chapter quotas on the devices that
carry an explanation.

## Changes

### 2026-10-09 11:32:37 MDT: Phases 1 to 9, the rules

**Decisions settled by the operator before any edit**, recorded in `PLAN.md § Open Questions`:
six new terms becomes a report; likely questions are answered in the prose; the four steps go
in the core for both profiles, with `narration.md` keeping its single required wrong model;
Phase 10 runs on this branch before close.

- **`chapter-prose.md`.** The per-chapter limits on wrong models, analogies, numbers and
  honesty hedges are gone, and so is "Flag one simplification plainly in each chapter". A new
  rule, § Explaining devices have no quota, keeps each device's form: an analogy never two to
  one idea, a number never bare, a hedge at the point of each simplification. Anchors (two)
  and deflations (two) stay budgets. Six new terms is now where a chapter reports itself drawn
  too wide, and no gloss is dropped to meet it. New rules: § The chapter is the explanation,
  said to the reader; § The reader's knowledge boundary; § Explain each concept in four steps,
  with the why required; § A fact is stated, not explained; § Answer the reader's likely
  questions. The plan, the before-sending list and the cut order follow. Two before-and-after
  pairs: an example standing where the reason belongs, and a likely question left unanswered.
- **`guide.md`.** § A shape for a teaching chapter loses its lesson-script item and explains
  concepts to the reader, with a before-and-after pair rewriting a direction to an explainer as
  the explanation. § The wrong model loses "at most one per chapter". An `In the room` callout
  says what the reader will see, never what to say.
- **`SKILL.md`.** § 2 records the knowledge boundary and a coverage ledger, and each chapter row
  gains a Teaches row. § 3 shows both, flags unmapped items and rows past six new terms, and
  adds a second blocking stop: one sample part approved before the fan-out, drafted into
  `<book>/sample/`, which every checker and `/makebook` skip. § 5 passes the boundary, the
  coverage items and the approved sample to every agent.
- **`NOTES.md`** gains § Explaining to the learner, 2026-10-09: where the method came from,
  what was measured (one reader, one book, three days) and what was asserted.
- `updatebook/SKILL.md`, the bookcraft README and the plugin version (1.10.0 to 1.11.0) follow.

Verified: `scripts/check-citations.py` resolves 203 citations (190 on `main`); every
paragraph in `chapter-prose.md` and `guide.md` is within 90 words and every sentence within
45; no em dash in either; the fixture suite passes 18 of 18.

### 2026-10-09 11:51:35 MDT: the pre-test review's findings, fixed

Draft PR #75 opened. `pr-review-2026-10-09.md` approved, with three important findings, all fixed:

- `guide.md § Opening` still said anything an earlier chapter had not glossed is glossed here,
  which under `guide` would override the core's fluent side. It now exempts the fluent side.
- The sample stop moved from the end of `SKILL.md § 3` to the end of `§ 4`, because its marks
  and source names come from `book.json`'s `sources` map, which § 4 writes.
- The likely-questions rule sent the question past the book's edge into the concept list, which
  the outline's source ledger fixes. It now stops there and adds nothing to that list.

Suggestions taken: the index pair keeps its example beside the reason; the direction search no
longer flags a numbered procedure; leftover quota wording in `SKILL.md`; coverage items marked
inferred where nothing states them; `/updatebook` carries the Teaches row; the README notes
narration's one required wrong model; `NOTES.md` credits `qe` with three steps, not four, and
says "at least two" wrong claims. The four deferred items are left for `/pr:close`'s triage.

### 2026-10-09 12:06:56 MDT: Phase 10, the blind set ready for scoring

One teaching chapter and one administrative chapter of the reference teaching guide were
redrafted under this branch's rules (at `2463162`) by chapter agents given the same outline
rows, sources and entries as the current versions, and never shown those versions. Both
redrafts pass `check-book.sh` and `check-provenance.sh` with the rest of that book. The four
versions are stripped alike and labelled A to D at random, with the key and the run's confounds
in a file the operator opens after scoring. It lives on a branch in the source repo; this repo
records no path to it.

**What the redraft agents reported, before any scoring:** glossing every new-side term took the
administrative chapter to ten new terms and the teaching chapter to thirteen, against the
outline's six each. The six-term report fired on both, as `§ Spend these deliberately` now
intends. The outline rows also still carried the old rules' number limits, and the agents
followed them.
