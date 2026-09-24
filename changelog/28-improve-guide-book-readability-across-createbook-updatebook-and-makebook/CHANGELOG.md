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

### 2026-09-24 — Phases 1 to 4: the rule files, the guide path, the summary and the checks

**Phase 1: `guide` is a rule set of its own.** `reference/chapter-prose.md` is now the core
every chapter follows, with `reference/guide.md` and `reference/narration.md` beside it, and
step 5 hands an agent the core plus the book's profile file and no third. The core kept its
name, so only citations of moved rules changed; `scripts/check-citations.py` resolves all of
them. The reasoning moved to `NOTES.md § The rule files split, 2026-09-24`, and the core and
guide file are written in the style they ask for: "rather than" fell from 63 uses to 1 and
"carry" from 62 to 12, and every paragraph and sentence in both keeps the stops.
`narration.md` moved unchanged. `guide.md` carries before-and-after examples for a handoff
opener, teaser headings, a catch-all callout, a riddling summary and a noun-delivering close,
plus the heading test and "a shape, not a script". An independent audit of old against new
found eight lost rules, six weakened and four contradictions; all were fixed but one, kept on
purpose and recorded: a guide part walks a mechanism only where it explains one. The teaching
shape lost a fourth part it could never have passed the checker with.

**Phase 2: no handoff chain under `guide`.** The outline's **Opens on** and **Closes on**
rows, the plan's fixed nouns, step 5's nouns and step 8's seam read are narration-only now.
A guide outline records a **Scope** row; the opening orients; the close lands the main point
or the next step, must be true of the whole chapter, and hands nothing forward.

**Phase 3: `## In short` under `guide`.** One summary: it opens with what the chapter covers,
may use the chapter's terms with a short definition, stops near 120 words and never reuses
the chapter's sentences. The `This chapter` row merged into it, per the settled question.

**Phase 4: `check-book.sh` checks the stops.** A paragraph over 90 words fails a guide book
and is reported under narration. New reports: sentences over 45, callouts over four
sentences, summaries over 120 words or sharing an eight-word run with the chapter, four-word
phrases in three or more chapters, and repo-path header keys with no display name. Two new
fixtures, `guide-reports/` (manifest row) and `paragraph-stop/` (`run.sh`); the suite passes
13 of 13. `/updatebook` step 5 now reads the reports against step 0's.

### 2026-09-24 — Phases 5 and 6: revising without wear, and what the reader is handed

**Phase 5: `/updatebook` adds a paragraph without renumbering.** A new paragraph after
`[5-12]` is `[5-12a]`, then `[5-12b]`; `[5-13]` never moves. All five programs that read a
tag accept the form: `check-book.sh` checks the lettered sequence and reports every chapter
carrying one; `check-references.sh` and `check-provenance.sh` parse it; `/check-claims` takes
it as written; `build-book.py` strips it from the reading edition. Accepting `[A2-4a]` closed
the gap where `check-references.sh` never saw an appendix citation. Its check 4 also stopped
reading a provenance mark as part of the paragraph above it, and its slid-versus-reworded
test counts only plain tags. `§ Adding prose` now puts the lettered paragraph first, lets a
paragraph grow only within 90 words and bars text from callouts, tables and lists; cutting is
its own section; the classify table gained adding, cutting and premise rows; and the new
`§ When to stop editing in place` sets the three levels, with the revision-facts-to-outline
step before any rewrite. `fixtures/lettered-tags/run.sh` asserts it through all three
checkers, and the pre-change checkers fail it on every lettered tag.

**Phase 6: a guide reader gets the reading edition, display names, and no markers.**
`/createbook` writes `"edition": "reading"` for a guide book, so the default bind is the
reader's copy and the operator's is `--no-reading-edition` with its own `--out`; step 9 and
`/updatebook`'s rebind name both files. `build-book.py` swaps display names for source keys
in the header rows of both editions, which carries into the endnotes, and renders the
settled book once more with the page markers hidden, keeping the clean render only when it
matches the probed one page for page. Verified by hand: 13 pages before and after, 9 markers
before and none after, display names in the header, the endnote and the EPUB. A self-review
caught the swap reaching a narration chapter's opening paragraph and doubling a name already
present; it now touches table rows only and leaves existing names alone.

bookcraft bumped to 1.6.0. The suite passes 14 of 14 under `--strict`, and
`scripts/check-citations.py` resolves all 180 citations.

### 2026-09-24 — /pr:pre-test review fixes

**The display-name swap is scoped to the `Draws on` and `Fills in` rows.** The branch review
(REQUEST_CHANGES) found it touching every header row, so a key that is an ordinary word
printed "Check your the syllabus" in the `Act on this` row of the reader's copy. Pinned by
`makebook/fixtures/display-names/run.sh`, which runs the pure function under plain `python3`
so CI covers it without a bind; the committed version fails it on exactly that case.

**Suggestions taken:** the marker comparison collapses whitespace before stripping markers,
as `locate()` does, so a split marker cannot read as a moved page; `check-references.sh`'s
baseline notes print "appendix 2" rather than "chapter A2"; a stale "five headings" is gone;
and `/updatebook § Adding prose` says a paragraph with a lettered follower cannot be split
without a rewrite. **Not taken:** merging overlapping four-word windows in the phrase report,
which is report-only.

**A citation written `[03-7]` resolves again.** Keeping tag halves as strings had made it
fail where `main` resolved it through `int()`; `check-references.sh` and
`check-provenance.sh` now drop leading zeros before the lookup, so behaviour outside the
book is unchanged. The suite passes 15 of 15.

**The second, independent review found three more, all fixed and pinned.** The swap
doubled articles ("the the syllabus") in 34 header rows of the two real guide books,
because it swapped every key with a display name; it now swaps only path-like keys, by
`check-book.sh`'s own test, and keeps an article already in front of a key.
`check-references.sh` check 4 read a relettered run (cut `[1-2a]`, reletter `[1-2b]`) as a
rewording and exited 0; a run whose baseline letters are no longer the start of its
current letters now counts as a slide. And its unanchored appendix pattern read
`sql-02-appendix-1-...` as an appendix, a regression; it is anchored as the other two
checkers anchor it. `lettered-tags/run.sh` gained both check-references cases and
`display-names/run.sh` the article and word-key cases; each new case fails against the
committed code. One gap is disclosed rather than fixed: an untagged guide book with no
marks lets its opening paragraph escape the paragraph stop, and the run's fallback note now
says so.

### 2026-09-24 — Synced with main, and bumped to 1.7.0

**Merged `main` at `ee9a8e1`**, which brought in #26 (the pr plugin's cleanup) and #31 (the
bind date and time stamped under the title page byline). `git merge-tree` reported a clean
merge, and it was one, but #31 touched three files this branch also changes. Two needed a
look. #31 reads its stamp once per run and threads it through `assemble`, so the new
hidden-marker render prints the same stamp as the probed one and the page comparison holds;
a bind after the merge printed the stamp, the display names and no markers, with no
fallback warning. And #31 had bumped bookcraft from 1.5.0 to 1.6.0, the same edit this
branch made, so the merge was silent about it while leaving this branch's changes under a
version already released. **bookcraft is now 1.7.0**, so installed copies refresh. The suite
passes 15 of 15 under `--strict` after the merge.
