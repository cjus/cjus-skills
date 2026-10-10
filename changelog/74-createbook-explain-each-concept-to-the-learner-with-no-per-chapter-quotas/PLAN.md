# createbook: explain each concept to the learner, with no per-chapter quotas

Start date: 2026-10-09 11:09:51 MDT

Ticket: #74 (status:todo -> status:in-progress)

## Overview

`/createbook` chapters written under the guide profile carry teaching passages as directions
to an explainer: what to say, what to land, what to ask. A reader who is learning the subject
gets no explanation from them and goes to another tool for it. The core prose rules also ration
the devices that carry an explanation, with per-chapter quotas on wrong models, analogies,
numbers, hedges and flagged simplifications.

The objective is to make every `/createbook` chapter explain each of its concepts directly to
the learner, after the method of the `explain` plugin's `qe` skill, with no length cap and no
per-chapter quotas on explaining devices. In full:

1. The per-chapter quotas in `chapter-prose.md` are gone; the per-unit stops (45-word
   sentences, 40 to 90-word paragraphs, one idea per paragraph) stay.
2. The core rules explain each concept in four steps: the idea, how it works, why it matters,
   and the mistake it prevents. The why is required and an example does not stand in for it.
3. `guide.md`'s teaching-chapter shape explains concepts to the reader and no longer asks for
   a lesson script.
4. The outline records the reader's knowledge boundary, and each chapter agent receives it.
5. Chapters answer the reader's likely questions, one level past what the book requires.
6. The outline carries a coverage ledger, and an unmapped item is a defect at the `§ 3` gate.
7. A sample part is drafted and approved by the operator before the `§ 5` fan-out.
8. The rule files carry before-and-after pairs, one of which rewrites a direction about an
   explanation as the explanation.
9. `NOTES.md` records where the method came from, and which parts were measured and which
   asserted.

Acceptance: the blind reader comparison from #34. One teaching chapter and one administrative
chapter of the reference teaching guide are redrafted under the new rules from the same outline
rows and sources, and each is compared blind against its current version, with the key in a
file the operator opens only after scoring. The method should help the teaching chapter and not
hurt the administrative one, which is the control. The verdicts feed into `guide.md` and
`NOTES.md`.

Out of scope: running a book's commands and code to check them.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#74: createbook: explain each concept to the learner, with no per-chapter quotas**

Labels at start: `feature`, `status:todo`, `priority:high`.

The body below is the ticket's, with its headings nested one level down. Its `## Changes`
checklist is reproduced as plain bullets so that the only checkboxes in this file are the
phases under `## Plan`.

Make `/createbook` chapters explain each concept directly to the learner, using the method the
`explain` plugin's `qe` skill uses, with no length cap and no per-chapter quotas on the devices
that carry an explanation. Consolidates #34, whose blind reader comparison becomes this issue's
acceptance test.

### Why

The reference teaching guide, written under the guide profile, follows each slide image with
labelled notes to the instructor: what to say, what to land, what to ask and what to watch for.
Its reader is an instructor who is also learning the subject. Preparing the first evening, that
reader asked more than a dozen questions just to decode the notes, such as what to say over a
given slide. Some notes pointed elsewhere instead of explaining, such as a direction to draw an
example "as chapter 8 plans it".

Rewriting those notes as read-aloud explanation in a companion document, after `qe`'s method,
worked. The instructor approved one sample before the rest were written, and made the same form
a requirement for every in-class demo the same day.

Most of `qe`'s rules are already in `chapter-prose.md`: a term defined in a clause at first use,
a wrong fix failing on a concrete case, one idea per paragraph, nothing invented. What differed
was this:

- **The addressee.** The text was the explanation itself, said to the learner. The guide's
  notes were directions to the explainer about it.
- **The reader's knowledge boundary.** The reader programs but is new to the subject, so every
  term on the new side was defined where it first appeared.
- **A per-concept order.** Every concept got the idea, how it works, why it matters, and the
  mistake it prevents. The core rules spend one wrong model and one simplification flag per
  chapter.
- **One running example domain**, concrete in every concept.
- **A process.** A sample was approved before the fan-out, every graded item was mapped to the
  unit that teaches it, and claims were run against the real artifact.

Two findings set the limits of the method:

- **A length cap cut what the reader asked for.** The scripts carried a 250-word cap. Twice,
  adding an explanation the reader asked for meant cutting other lines to fit, and drafts ran
  to 249 of the 250 words. `NOTES.md § The ceiling removed` records the same pressure at
  chapter scale.
- **An example is not a reason.** One rewrite replaced the source's reason with an example, and
  the reader then needed `qe` to get the reason back.

Concrete wording also exposed errors that directions had hidden. Writing the explanations
surfaced wrong claims in the guide, including a grading claim and a simulator described as
showing three values side by side when it shows one at a time. A direction to demo the
simulator cannot be wrong; a sentence saying what it shows can.

**Cost:** a guide whose teaching passages are directions leaves a reader who is learning the
subject without the explanation, and that reader goes to another tool for it. `qe` was invoked
four times in three days of preparation.

### Changes

- **Drop the per-chapter quotas on explaining devices.** In `chapter-prose.md § Spend these
  deliberately`, remove the limits of one wrong model, one analogy, three numbers and two
  honesty hedges, and § Never's "Flag one simplification plainly in each chapter". Keep the
  per-unit stops: 45-word sentences, 40 to 90-word paragraphs, one idea per paragraph.
  `NOTES.md § What the numbers rest on` gates a tightening on measurement and does not gate a
  loosening.
- **Explain each concept in four steps,** in the core rules: the idea, how it works, why it
  matters, and the mistake it prevents. The why is required, and an example does not stand in
  for it.
- **Remove the lesson-script item from `guide.md § A shape for a teaching chapter`,** added with
  #33, which asks for "what to say, what to ask, what to watch for". A book that also needs words
  for a room gets them from its own brief or a companion document. Rewrite the shape so a
  teaching chapter explains its concepts to its reader.
- **Record the reader's knowledge boundary** in the outline (`SKILL.md § 2`) and pass it to each
  chapter agent (`§ 5`): what the reader is fluent in, and what is new to them. Every term on the
  new side is defined in a clause where it first appears (`chapter-prose.md § Glosses`). The term
  ledger still decides which chapter defines it first.
- **Answer the reader's likely questions,** one level past what the book requires them to do.
- **Add a coverage ledger to the outline:** each thing the reader must be able to do or answer,
  mapped to the chapter that teaches it. For a course the items are its graded work; otherwise
  they are the outcomes in the brief. An unmapped item is a defect, shown at the `§ 3` gate.
- **Add a sample gate at `§ 3`:** one part drafted under these rules and approved by the operator
  before the `§ 5` fan-out.
- **Add before-and-after pairs to the rule files,** since a drafting agent copies an example more
  reliably than it meets a count, the finding #28 acted on. One pair should rewrite a direction
  about an explanation as the explanation.
- **Record in `NOTES.md`** where the method came from, and which parts of it were measured and
  which asserted.
- **Acceptance: the blind reader comparison from #34.** Redraft one teaching chapter and one
  administrative chapter of the reference teaching guide under the new rules, from the same
  outline rows and sources. Compare each blind against its current version, with the key in a
  file the operator opens only after scoring. Drafting from the same rows removes the content
  confound #34's status records for a comparison of two editions. The administrative chapter is
  a control: the method should help the teaching chapter and not hurt the administrative one.
  Feed the verdicts into `guide.md` and `NOTES.md`.

**Out of scope:** running a book's commands and code to check them. It helped the companion
scripts, but it changes a checker rather than how chapters are written.

**Band:** priority:high, as #34 was.

**Occasion:** the next book written or recreated with `/createbook`.

### Unresolved

- Whether the six-term limit stays hard once every new term must be defined, or becomes a report
  that the outline drew the chapter too wide.
- Where likely questions sit in a chapter: in the part's prose, or under a callout label, which
  would be a fifth label and a change to `guide.md § Callouts`.
- Whether narration books take the per-concept order unchanged. The quotas live in the core file,
  so removing them reaches narration books too.

### #34, consolidated into this ticket

The ticket carries #34's original body and its 2026-09-27 status in a collapsed block,
reproduced here.

> Validate the guide-profile rules from #28 with a blind reader comparison before the reference
> teaching guide is recreated. Split out of #28 (Phase 7), which shipped the rules without this
> reader test.
>
> - Redraft one teaching chapter and one administrative chapter of the reference guide under the
>   new rules: `createbook/reference/chapter-prose.md` plus `guide.md`, lettered tags, the
>   reworked `## In short`, and no handoff chain.
> - Draft each from the same outline rows and sources as its current version.
> - Label the four versions A to D, with the key held in a file the operator opens only after
>   scoring, and have the operator read them blind.
> - The redraft runs on a branch in the source repo that holds the reference guide, its outline
>   and its sources. This repo records no path to it.
>
> **Outcome:** a recorded verdict per chapter, and the findings fed back into `guide.md` or
> `createbook/NOTES.md` before the reference guide is recreated.
>
> **Status, 2026-09-27:** the reference teaching guide was recreated under bookcraft 1.8.0's
> guide rules without this comparison. The course it serves starts on October 5, so the
> comparison was deferred for time and the recreate went ahead on the rules as shipped.
>
> What that changes:
>
> - **The outcome's condition can no longer be met.** Findings fed back "before the reference
>   guide is recreated" would have arrived after it.
> - **The comparison is now cheaper to run.** Both editions exist in full in the source repo, the
>   first in its history and the recreate as current, with the same chapter numbers and titles.
>   One teaching chapter and one administrative chapter from each edition are the four versions
>   this issue asks for, so no redraft is needed.
> - **One confound to state in the key file.** The recreate was written from a fresh reading of
>   the sources and the live course, not from the first edition's outline rows, so a pair
>   differs in content as well as in rules. A verdict should say which of the two it thinks it
>   is reacting to.
> - **The recreate produced no reader evidence.** It passes `check-book.sh` and
>   `check-provenance.sh`, and a full `/bookcraft:check-claims` ran in three rounds, the last
>   with every re-checked unit supported. That shows the chapters match their sources, not that
>   they read better.
>
> Proposed new outcome: run the blind comparison on the two editions' chapters, and feed the
> verdicts into `guide.md` or `createbook/NOTES.md` for the next book written under the guide
> profile.

## Plan

- [x] Phase 1: Drop the per-chapter quotas on explaining devices in `chapter-prose.md`: the
      limits under "Spend these deliberately" (one wrong model, one analogy, three numbers, two
      honesty hedges) and § Never's "Flag one simplification plainly in each chapter". Keep the
      per-unit stops.
- [x] Phase 2: Add the four-step per-concept order to the core rules: the idea, how it works,
      why it matters, the mistake it prevents. The why is required; an example does not stand
      in for it.
- [x] Phase 3: Remove the lesson-script item from `guide.md § A shape for a teaching chapter`
      and rewrite the shape so a teaching chapter explains its concepts to its reader.
- [x] Phase 4: Record the reader's knowledge boundary in the outline (`SKILL.md § 2`) and pass
      it to each chapter agent (`§ 5`). Every term on the new side is glossed at first use; the
      term ledger still decides which chapter defines it first.
- [x] Phase 5: Require chapters to answer the reader's likely questions, one level past what the
      book requires them to do.
- [x] Phase 6: Add a coverage ledger to the outline, mapping each thing the reader must be able
      to do or answer to the chapter that teaches it. An unmapped item is a defect shown at the
      `§ 3` gate.
- [x] Phase 7: Add a sample gate at `§ 3`: one part drafted under the new rules and approved by
      the operator before the `§ 5` fan-out.
- [x] Phase 8: Add before-and-after pairs to the rule files, including one that rewrites a
      direction about an explanation as the explanation.
- [x] Phase 9: Record in `NOTES.md` where the method came from, and which parts were measured
      and which asserted.
- [x] Phase 10: Acceptance. Run the blind reader comparison on one teaching chapter and one
      administrative chapter of the reference teaching guide, redrafted from the same outline
      rows and sources. Record the verdicts and feed them into `guide.md` and `NOTES.md`.
      **Status, 2026-10-09:** both chapters redrafted and blinded in the source repo, on a
      branch there. The operator spot-checked the four versions, did not score them blind,
      and ruled that the revised rules become the default. Recorded in `NOTES.md` as a
      judgment from a spot check, with no blind verdict. `guide.md` needed no change, since
      the ruling adopts its rules as written.

## Open Questions

None open. The four the ticket and the plan raised were settled by the operator on 2026-10-09:

- **The six-term limit becomes a report.** Every term on the new side of the reader's
  knowledge boundary is defined. An outline row assigning more than six is shown at the `§ 3`
  gate as a chapter drawn too wide, and a chapter agent that needs a seventh defines it and
  writes a finding instead of dropping the definition.
- **Likely questions are answered in the prose**, where the question arises. No fifth callout
  label, so `guide.md § Callouts` and `check-book.sh` are unchanged.
- **The four-step order goes in the core, for both profiles.** `narration.md` keeps its
  required single wrong model, since a profile file wins where it names a rule; the core's
  per-chapter cap on wrong models goes.
- **Phase 10 runs on this branch.** After Phases 1 to 9 land, the two chapters are redrafted
  in the source repo, the four versions are blinded, and the operator's verdicts are recorded
  before `/pr:close`. The source repo's path is asked for at that point.

## Deferred

From `pr-review-2026-10-09.md`, for triage at `/pr:close`:

- `chapter-prose.md § These rules add words` against the cut order's analogy step (pre-existing).
- `guide.md`'s teaching shape allows two parts where core § Shape reserves two for one mechanism
  and one complication (pre-existing).
- A narration handoff noun may be reported as a ledger miss under the new boundary rule.
- `<book>/sample/` is never removed after the fan-out.
- An outline written before these rules still caps numbers in its chapter rows, and a chapter
  agent follows the row (found by the Phase 10 redrafts). `/updatebook` edits against such an
  outline inherit the cap until a recreate.
