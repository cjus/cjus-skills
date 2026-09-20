# Show the reader persona at createbook's outline gate, and ask for one when the argument names none

Start date: 2026-09-20 09:25:41 MDT

`/bookcraft:createbook` already carries a reader persona through the whole run, but nothing
asks for one when the invocation names none, and nothing shows the derived persona at the
step 3 confirmation gate. This branch adds both, gate line first.

## Changes

### 2026-09-20 — both halves shipped, gate first

**Phase 1, the gate line.** `SKILL.md § 3` lists the reader among what it shows
the operator, stated as a sentence rather than a `Reader:` label, because a
label reads as already settled and does not invite the correction the gate
exists to collect. The sentence marks where the persona came from.

**Phase 2, the ask.** When the argument names no reader, § 1 asks three
questions: who they are, what they must be able to do when they finish, and
what they can be assumed to know. The third is load-bearing, since it sets what
every chapter may leave unglossed. Declining hands back to the gate, where the
persona is marked inferred.

**Both open questions were the operator's calls**, answered before any code was
written and recorded in `PLAN.md § Open Questions § Resolved`. Marking
provenance beat printing the bare value, which would have kept § 3's display
list uniform with its six other bare entries and lost because an inferred
persona printing identically to a supplied one gets read past. Putting the ask
inside § 1 beat giving it its own section, which would have matched the sizing
and tagging asks it copies and lost to keeping the reader's handling in one
place.

**The scope boundary is held in the prose, not only in the plan.**
`chapter-prose.md § The reader` defines the reading posture, fixed by design;
this branch touches the domain persona only. § 1 cites the posture file a
paragraph above the new ask, so a paragraph now says outright which reader is
which, and that the posture is not a chapter agent's to renegotiate.

**Phase 3.** `NOTES.md § The reader at the gate, 2026-09-20` records both
decisions with the alternative each beat, and marks the reference guide account asserted
rather than measured — that book is not in this repo. Version 1.1.0 → 1.2.0.

**Beyond the three phases:** `plugins/bookcraft/README.md`, two lines. Its
argument table called the reader optional "where useful" and said nothing about
the new ask; its approval-gate line said nothing about the reader. Both are
user-facing behavior this branch changes, and they are the same class of drift
#27 was filed for — that ticket covered the root and hooks READMEs, not this
one, so nothing else was going to catch it.

### 2026-09-20 — review round one, PR #33

**APPROVE, no critical findings.** Four items fixed in `5826d32`, two deferred,
one dropped. Full disposition in `pr-review-2026-09-20.md`.

**The finding that mattered sat at the seam between the two phases.** Each half
was correct alone: Phase 1 marks a persona given or inferred, Phase 2 adds an
ask. Together they create a third origin — the operator's answer to that ask —
which is neither, and the gate had no label for it. An agent following the text
would have called a persona the operator dictated "inferred", a false alarm at
the one gate built to raise real ones.

**A `NOTES.md` claim was wrong about its own diff**, saying both new § 1
paragraphs draw the persona/posture boundary when only the second does. That
file's authority rests on its claims surviving a check, so it was corrected
rather than softened. Also: "always" relaxed to "almost always" in both files to
match what `PLAN.md` claims, and the Arguments table now cites § 1 as its three
sibling rows already did.

### 2026-09-20 — review round two, the close gate

**APPROVE, no blocking findings.** Round one's fixes all verified landed. Five
accuracy findings fixed before the summary was finalized, since that document
becomes the PR body. Full disposition in `pr-review-2026-09-20-close.md`.

**The marker widened once more, to the part-given case.** An argument naming
"apprentice electricians" and nothing else fires no ask, because a reader *was*
named, while what they can be assumed to know is still the model's to guess.
Reporting that as "from the argument" hides the inferred half. § 3 now says to
name which part was supplied.

**Four documentation corrections.** The summary claimed 63 insertions under
`plugins/` where the diff measures 60. Both the summary and this changelog
credited PR #28 with drift this branch prevents, and that PR never touched
`plugins/bookcraft/README.md` — corrected to cite the class of drift rather
than a PR that did not cover this file. `SKILL.md`'s "The third case" was a
positional reference `NOTES.md` counts to differently, now "An inferred
persona". This changelog's Phase 1 entry still described the pre-fix binary
marker.

### 2026-09-20 — deferred work resolved in branch, not deferred

At `/pr:close` step 6b the operator directed both surviving deferred items to be
resolved here rather than filed as a follow-up. A scope change the operator
made; the objective in `PLAN.md § Overview` is unchanged.

**`OUTLINE.md` now records where the reader came from**, not just who they are.
§ 3 has to state the provenance and § 3 can run in a later session than § 2, so
an outline recording the persona but not its origin left the gate reconstructing
from memory the one thing it exists to check. § 3 now reads it off the outline's
top line.

**§ 5's prompt names the persona/posture collision where the agent meets it.**
Item 1 of that prompt tells a chapter agent to follow every rule in
`chapter-prose.md`, whose § The reader is the reading posture; item 2 then hands
it "the reader" meaning the domain persona. Same name, one prompt, and an agent
left to reconcile them reads the persona as licence to adjust the posture. Item
2 now says outright that it does not, and passes provenance where the persona
was inferred.

Nothing parses `OUTLINE.md`'s top line, so neither change touches
`check-book.sh` or `book.json`.

**Dropped, unchanged:** batching § 1's three asks into one message.
