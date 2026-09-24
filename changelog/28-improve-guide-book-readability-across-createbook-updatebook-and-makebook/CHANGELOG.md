# Improve guide-book readability across createbook, updatebook and makebook

Start date: 2026-09-24 07:44:16 MDT

Change the book skills so a guide book reads the way a guide is used, one chapter at a time
when it is needed, and so revising a finished chapter does not wear it down. The changes cover
the `createbook` prose spec and procedure, `check-book.sh`, `/updatebook`'s edit rules and
`/makebook`'s bind. Ticket #28.

## Changes

### 2026-09-24 — Rewrite or recreate, and the reference guide

**The reference teaching guide will be recreated under the new rules, not patched.** Its
defects in #28 come from the rules it was written under (handoff openers, teaser headings,
summaries that copy the body), so they are in every chapter, and `/updatebook` exists to leave
unreached chapters byte-identical. Splitting its over-long paragraphs would renumber tags
throughout chapters 1 to 4 anyway, since 28 of the 46 sit there and a split is an insert.

**Phase 5 gains a rule for when to stop editing in place**, with three levels: edit a passage,
rewrite one chapter, recreate the book. Today the skills offer only the first and the last,
and without the middle one, the change of class size was patched into five chapters as
asides. Before a rewrite or a recreate, facts a revision put only in the prose move into
`OUTLINE.md` first, or the regeneration drops them.

**Two open questions move.** The paragraph stop fails a `guide` book, since its only named cost
was the book now being recreated. A chapter rewrite is the trigger that renumbers suffixed
tags, which leaves only the tag format open. That question also gained a fifth consumer:
`build-book.py`'s `PARA_TAG_RE` strips tags for the reading edition and would print one it
does not match.

### 2026-09-24 — The open questions, settled

**Every open question is now answered**, so the phases can run in order without stopping for a
decision. Phase 7 still stops once, when the redrafts are ready for the operator to read.

- **Citations: the core keeps the name.** `chapter-prose.md` stays as the shared core, with
  `narration.md` and `guide.md` beside it. Rule names hold, so only citations to moved rules
  change, and only their filename. A one-off check before Phase 1 closes confirms every
  `<file> § <rule>` citation resolves.
- **Tags: a letter suffix, `[1-2a]`.** Chosen over a decimal suffix, which reads like a
  section or version number, and over always renumbering, which is the cost that pushed
  revisions into growing paragraphs. Accepting `[A2-4a]` in `check-references.sh` means
  accepting appendix tags at all, which closes the gap where `[A1-99]` went unseen.
- **Edition: declared in `book.json`.** `/makebook` already reads `"edition": "reading"`, so
  having `/createbook` write it for a guide book keeps the two-file contract intact, where
  writing both editions every run would have doubled it.
- **Header: `This chapter` merges into `## In short`, under `guide` only.** The spec's own
  reason for keeping them apart is the walk's ban on glossed terms, which Phase 3 removes;
  keeping both after that leaves two summaries of one chapter.
- **Phase 7: the operator reads blind, and the redraft runs in the source repo.** Four
  versions labelled A to D, with the key opened after scoring. The source repo's path is
  passed to the run rather than recorded here.
