# Show the reader persona at createbook's outline gate, and ask for one when the argument names none

Start date: 2026-09-20 09:25:41 MDT

Ticket: https://github.com/cjus/cjus-skills/issues/23

## Overview

`/bookcraft:createbook` already treats the reader persona as a first-class value: step 1 settles
it, the outline records it at the top, and every chapter agent's prompt carries it. Two things
are missing around it.

**Nothing asks when the argument names no reader.** The same file already does exactly that for
its other two underspecified inputs, sizing and tagging, so the pattern is in the skill and the
reader field simply does not use it.

**Nothing shows the reader at the confirmation gate.** Step 3 enumerates what it puts in front of
the operator — source ledger, chapter list, title, output folder, tag decision, estimated read
time — and the reader is not on that list. A persona the model inferred rather than one it was
given reaches every chapter prompt without the operator ever seeing it.

The gate is the load-bearing half. A presence check fires only when the field is empty, and from
a subject plus a folder of sources the model can nearly always infer a plausible persona. The
failure that costs a book is a confident wrong persona, which no presence check catches and
printing the derived value does.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred

**Empty. Both items raised by the reviews were resolved in this branch instead of deferred,
at the operator's direction during `/pr:close` step 6b triage (2026-09-20).**

- ~~Record the reader's provenance in `OUTLINE.md`.~~ Done. § 2 now records where the reader
  came from alongside the reader itself, and § 3 reads it from there rather than from memory.
  The gate can run in a later session than the outline, which is what made recall unsafe.
- ~~The persona/posture name collision reaches § 5.~~ Done. § 5's prompt list now tells each
  chapter agent that the reader it is handed is the domain persona and does not modify the
  reading posture that `chapter-prose.md § The reader` fixes, which is the file item 1 of the
  same prompt has just told it to follow.

**This is a scope change the operator made, not one the branch took.** The objective in
`## Overview` is unchanged; these two items were review findings parked for a follow-up ticket,
and the operator chose to resolve them here rather than file one.

## About Ticket

`/bookcraft:createbook` already treats the reader persona as a first-class value. Step 1 settles it (`plugins/bookcraft/skills/createbook/SKILL.md:146`), the outline records it at the top (`:199`), and every chapter agent's prompt carries it (`:259`). Two things are missing around it.

**Nothing tells the skill to ask when the argument names no reader.** The same file does exactly that for its other two underspecified inputs, sizing (`:160`) and tagging (`:111`), so the pattern is already in the skill and this is just a field that does not use it.

**Nothing shows the reader at the confirmation gate.** `:209` enumerates what step 3 puts in front of the operator: the source ledger, the chapter list, the title, the output folder, the tag decision and the estimated read time. The reader is not on that list, so a persona the model inferred rather than one it was given reaches every chapter prompt without the operator ever seeing it.

The gate is the load-bearing half. A check for "was a persona identified" fires only when the field is empty, and from a subject plus a folder of sources the model can nearly always infer a plausible one. The failure that costs a book is a confident wrong persona, which no presence check catches and printing the derived value does. Step 3 is also where a correction is still cheap, which is the argument `:207` already makes for its own existence.

For context on why this is not already handled: the reference teaching guide reads as though the skill elicited its persona, and it did not. The persona came from the invocation string, "A preparation guide for an instructor assigned a data modeling course who has taught neither this course nor, necessarily, this subject", and the book's `about-this-book.md` opens on that sentence plus the sprint dates the sources supplied. A vaguer argument would have produced a book with an inferred reader and no point at which anyone checked it.

- [ ] Add the reader to step 3's display list at `SKILL.md:209`, stated as a sentence rather than a label, so the operator corrects it at the gate.
- [ ] Add the conditional ask at `SKILL.md:146`, in the form already used at `:160` and `:111`: when the argument names no reader, ask who they are, what they must be able to do when they finish, and what they can be assumed to know.
- [ ] Ship the gate line first. If only one of the two lands, it is that one.

Out of scope: `reference/chapter-prose.md:9` defines a different reader, the reading posture that governs the prose, and that one is fixed by design. The ask is about the domain persona only, and the wording should not invite a chapter agent to renegotiate the posture.

Line numbers are against 1.0.2, which is byte-identical to `main` as of filing.

