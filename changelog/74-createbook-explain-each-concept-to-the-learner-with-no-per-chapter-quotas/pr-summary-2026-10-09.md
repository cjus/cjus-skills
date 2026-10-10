# createbook: explain each concept to the learner, with no per-chapter quotas

## Overview

`/createbook` chapters written under the guide profile carried their teaching passages as
directions to an explainer: what to say, what to land, what to ask. A reader who was learning
the subject got no explanation from them and went to another tool for it. The core prose rules
also rationed the devices an explanation is made of, with per-chapter quotas on wrong models,
analogies, numbers, hedges and flagged simplifications.

This branch makes every chapter explain each of its concepts directly to the reader, after the
method of the `explain` plugin's `qe` skill, with no length cap and no per-chapter quotas on
explaining devices. It adds the outline machinery that method needs: the reader's knowledge
boundary, a coverage ledger, and a sample part the operator approves before any chapter is
drafted. Ticket #74, which consolidates #34. #34's blind reader comparison was prepared as the
acceptance test and not scored: the operator spot-checked the redrafts and ruled the revised
rules the default (§ Plan alignment).

## Key changes

- **`createbook/reference/chapter-prose.md`**, the core rules every chapter follows.
  - The per-chapter limits on wrong models, analogies, numbers and honesty hedges are gone, and
    so is "Flag one simplification plainly in each chapter". A new rule, § Explaining devices
    have no quota, keeps each device's form.
  - New rules: § The chapter is the explanation, said to the reader; § The reader's knowledge
    boundary; § Explain each concept in four steps; § The why is required, and an example
    never stands in for it; § A fact is stated, not explained; § Answer the reader's likely
    questions.
  - Six new terms is now where a chapter reports itself drawn too wide, and no gloss is dropped
    to meet it. Anchors (two) and deflations (two) stay budgets.
  - The plan, the before-sending list and the cut order follow, and a new explanation-checks
    list sits in § Before sending. Two before-and-after pairs.
- **`createbook/reference/guide.md`.** § A shape for a teaching chapter loses the lesson-script
  item and explains concepts to the reader, with a before-and-after pair rewriting a direction
  as the explanation. § The wrong model loses "at most one per chapter". An `In the room`
  callout says what the reader will see, never what to say. § Opening leaves the fluent side
  unglossed.
- **`createbook/SKILL.md`.**
  - § 2 records the knowledge boundary and a coverage ledger, and each chapter row gains a
    Teaches row.
  - § 3 shows both, puts unmapped coverage items first as defects, and names any row past six
    new terms.
  - A second blocking stop at the end of § 4: one sample part, drafted into `<book>/sample/`,
    approved before the fan-out.
  - § 5 passes the boundary, the coverage items and the approved sample to every chapter agent.
- **`createbook/NOTES.md`.** § Explaining to the learner, 2026-10-09: where the method came
  from, what was measured (one reader, one book, three days) and what was asserted, plus the
  operator's rulings. § Why the core rules say what they say gains entries for the new rules.
- **`updatebook/SKILL.md`**: the budget sentence follows the new term rule, and the Teaches row
  moves with an edit. **`plugins/bookcraft/README.md`** describes the new gate and the sample
  stop. **`plugin.json`**: 1.10.0 to 1.11.0.

## Code examples

The quota list, before and after (`createbook/reference/chapter-prose.md`):

```markdown
Before:
- **Analogy: one at most**, and none when the mechanism is already concrete. ...
- **Numbers: three at most, and none bare.** ...
- **New terms: six at most.** ...
- **Honesty hedges: two at most**, and one of them is the simplification flag § Never requires.
- **The wrong model: one at most** (§ The wrong model).

After:
**Explaining devices have no quota.** An analogy, a number, a wrong model and a hedge are how
a concept lands, so a chapter uses as many as its concepts need. Each still has a form.
...
- **New terms: every one glossed, and more than six reported.** ... More than six in one
  chapter means the outline drew it too wide: report that to the outline, and write the
  chapter with every gloss in place.
```

The four steps (`createbook/reference/chapter-prose.md § Explain each concept in four steps`):

```markdown
**Explain each concept in four steps**, in this order: the idea, how it works, why it matters,
and the mistake it prevents. ...

**The why is required, and an example never stands in for it.** An example shows the idea at
work, and a reader shown one still has to guess the reason.
```

The teaching-chapter shape (`createbook/reference/guide.md § A shape for a teaching chapter`):

```markdown
Before:
3. **The lesson script**: what to say, what to ask, what to watch for, and roughly how long
   each takes.

After:
2. **The concepts, in teaching order**, each explained to the reader: the idea, how it works,
   why it matters and the mistake it prevents, with the assessment item it feeds.
```

## Plan alignment

Items 1 to 9 of the objective are delivered as planned.

| Phase | Where |
|---|---|
| 1. Drop the quotas, keep the per-unit stops | `chapter-prose.md § Explaining devices have no quota`, § Spend these deliberately, § Never |
| 2. The four steps, why required | `chapter-prose.md § Explain each concept in four steps` |
| 3. No lesson script | `guide.md § A shape for a teaching chapter` |
| 4. Knowledge boundary in the outline and the prompt | `chapter-prose.md § The reader's knowledge boundary`, `SKILL.md § 2` and `§ 5` |
| 5. Likely questions, one level past | `chapter-prose.md § Answer the reader's likely questions` |
| 6. Coverage ledger, unmapped item a defect | `SKILL.md § 2` and `§ 3` |
| 7. Sample approved before the fan-out | `SKILL.md § 4`, its last two paragraphs |
| 8. Before-and-after pairs | Two in `chapter-prose.md`, one in `guide.md` |
| 9. `NOTES.md` | § Explaining to the learner, 2026-10-09 |

**The operator settled the four open questions on 2026-10-09**, recorded in `PLAN.md`:

- Six new terms becomes a report.
- Likely questions are answered in the prose, with no fifth callout label.
- The four steps go in the core for both profiles, and `narration.md` keeps its one required
  wrong model.
- Phase 10 runs on this branch before close. It did, and ended in the operator's ruling below
  instead of a blind score.

**Deviations, stated plainly:**

- **The sample stop sits at the end of § 4, not § 3** as the ticket wrote. The review found
  that the sample's marks and source names come from `book.json`, which § 4 writes.
- **`guide.md § The wrong model` also lost its per-chapter cap**, which the ticket named only for
  the core. The objective is no per-chapter quotas on explaining devices in any chapter.
- **The ticket's running example domain and its claims run against the real artifact did not
  become rules.** The first is one document's habit. The second changes a checker, which the
  ticket put out of scope. `NOTES.md` says so.

**Phase 10, the acceptance test, was prepared and settled by the operator's ruling instead
of a blind score.** One teaching chapter and one administrative chapter of the reference
teaching guide were redrafted under these rules. The chapter agents had the same outline rows,
sources and entries as the current versions and never saw them. Both redrafts pass
`check-book.sh` and `check-provenance.sh` with the rest of that book. The four versions were
blinded A to D in the source repo, with the key in a file to open after scoring.

The operator spot-checked them, did not score them blind, and ruled that the revised rules
become the default. `NOTES.md` records that as the verdict, says plainly that no blind
comparison was run, and records what was measured on the redrafts:

- ten and thirteen new terms against the outline's six each, which the new report caught
- reading copies 30% and 33% longer
- outline rows still capping numbers under the old rules

`guide.md` needed no change for the verdict, since the ruling adopts its rules as written. The
blind set stays on its source-repo branch, so the comparison can still be run there.

## Testing

**By hand:** read the rule files as a chapter agent would. The operator spot-checked the
Phase 10 redrafts against the current chapters. The blind set remains available to score.

**Automated:**

- `scripts/check-citations.py` resolves 203 citations, against 190 on `main`, so every new
  `§` rule name is citable.
- The bookcraft fixture suite passes 18 of 18 locally.
- CI's fixtures job passes on macOS and Linux.
- Every paragraph in `chapter-prose.md` and `guide.md` is within 90 words and every sentence
  within 45, measured by script, and neither file has an em dash.
- No checker enforced the removed quotas, so no script changed.

**Edge cases considered:**

- A narration book keeps its required wrong model.
- A fact needs no four steps.
- A new-side term the ledger missed is glossed and reported.
- An over-six chapter can still be kept whole by the operator.
- The sample folder is invisible to every checker and `/makebook`, which read one level deep.

## Impact assessment

Before the close's own artifacts: 11 files changed, 1,101 insertions and 45 deletions. Of the
insertions, 836 are this branch's `changelog/` folder and 265 are the plugin. No dependency changes. No script changes.

**Behaviour change for new books:** a `/createbook` run now stops twice, at the outline and at
the sample, and its chapters run longer, because every new term is glossed and every concept
gets its why.

Existing books are unaffected until they are recreated. `/updatebook` edits now follow the new
core rules.

**Assertions:** disabled for this repo (`assertionsFile` is `null`).

## Deferred work

From the pre-test review and the Phase 10 redrafts, for triage at `/pr:close`:

- **The analogy in two places.** `chapter-prose.md § These rules add words` and the cut
  order's analogy step pull against each other. Pre-existing.
- **Two-part chapters.** The teaching shape allows two parts, where core § Shape reserves two
  for one mechanism and one complication. Pre-existing.
- **Narration handoff nouns.** The new boundary rule may report one as a ledger miss.
- **The sample folder.** `<book>/sample/` is never removed after the fan-out.
- **Old outlines cap numbers.** An outline written before these rules still caps numbers in its
  chapter rows, and a chapter agent follows the row. Found by the Phase 10 redrafts.
