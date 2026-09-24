# /updatebook: provenance and what is actually measured

Not loaded at runtime. Read this before changing a number or a rule in `SKILL.md`.

## Where the skill came from

Filed on 2026-09-10. The occasion recorded in the ticket: the reference book will need a correction before the course runs on October 5, and the only tool for that today is a rerun of `/createbook`, which rewrites twenty chapters to change one.

The skill is deliberately thin. `/createbook` owns the prose rules and the structure rules, `/makebook` owns the bind, and neither of them is restated here. What is left is the part neither covers: which files an instruction may touch, and what an edit obliges you to carry with it.

## The citation counts, measured rather than inherited

Counted on 2026-09-10 against the source repo, with the reference book at 20 chapters and 427 tags.

| What | Count | Where |
|---|---|---|
| Paragraph tags `[N-M]` cited outside the book folder | 30 | `prep/readiness-checklist.md` (25), `prep/assumptions-to-confirm.md` (5) |
| Paragraph tags cited inside the book folder | 5 at the time of counting, 8 after this skill's own first run added three | `diagrams/README.md` (7), `OUTLINE.md` (1) |
| Chapter numbers `ch. N` cited in the assessment files | 74 | the seven files in `assessments/` |

All 30 external tag citations resolve to a paragraph the book actually has, checked by extracting every `^\[N-M\] ` from the twenty chapters and testing each citation against that set.

**That one-off check is now `check-references.sh`'s check 3**, filed and built on 2026-09-10. Re-measured with the committed tool on the same day: 427 tags defined across 20 chapters, 38 citations across the four referring files, 0 unresolved. The counts above are reproduced exactly.

**Two figures in sibling files are stale, and `SKILL.md` deliberately does not repeat either.**

`createbook/NOTES.md` and `check-book.sh` both say the guide's tags "alone are cited fifty-six times outside the book". The 56 is real but it is a different measurement: it was recorded against the *superseded* seventeen-chapter guide's chapter numbers, cited across the six assessment files before the 2026-09-09 remap. It was widened from chapter numbers to paragraph tags somewhere between those files. The tag count is 30 and the current chapter-number count is 74.

Neither sibling's argument depends on the digit, which is why this is recorded rather than fixed here: both files are making the point that a tag is an address worth protecting, and 30 makes it as well as 56 does. Correcting the two lines belongs to whoever next edits them.

## Adding a paragraph without renumbering, 2026-09-24

**Until this date there was no free way to add a paragraph to a tagged chapter.** Two rules closed every escape. `check-book.sh` required the paragraph half of every tag to count 1, 2, 3 with no gap, so `[5-12a]` was refused and an insert at 12 shifted every later tag. And the close is the last paragraph (`narration.md § Close`, `guide.md § Close`), so appending after it made a chapter with two closes. `SKILL.md` then ranked three ways out, cheapest first: grow an existing paragraph up to the 90-word stop, move a sentence across a boundary, or insert and repoint.

**The first way out was the one taken, and nothing checked its stop.** Ticket #28 measured the reference guide after many revisions: 46 of its 576 paragraphs past 90 words, 13 of them past 120, 28 of the 46 in chapters 1 to 4, which are among the most revised. One paragraph went from 81 words at first bind to 207 in a single revision. Callouts, which take no tag, were the other free place to add text, and chapter 1's pass-off `Warning.` came to hold a definition, a points split, a no-make-up rule, a scheduling gap, a named contact and a note on the teaching model.

**Now a revision adds a paragraph with a lettered tag.** `[5-12a]` follows `[5-12]`, then `[5-12b]`; `[5-13]` never moves. Letters were chosen over a decimal `[5-12.1]`, which reads like a section or version number, and over always renumbering, which is the cost that pushed revisions into growing paragraphs. The operator settled the format on 2026-09-24. `SKILL.md § Adding prose` now puts the lettered paragraph first, lets a paragraph grow only while it stays at 90 words, and bars new text from callouts, tables and lists.

**What renumbers them is a chapter rewrite**, the middle of the three levels in `SKILL.md § When to stop editing in place`. A lettered tag is a patch, and `check-book.sh` reports every chapter carrying one so the patches stay visible.

**Five programs read a tag, and all five accept the form.** `check-book.sh` checks the sequence: a plain tag counts on from the last plain one, and a lettered one repeats the number of the paragraph it follows with the next letter from `a`. `check-references.sh` and `check-provenance.sh` parse `[A2-4]` and `[5-12a]` and keep both halves as strings. `/check-claims` takes a unit's tag from its text, as written. `build-book.py`'s `PARA_TAG_RE` strips a lettered tag from the reading edition, where an unmatched one would have printed. `createbook/fixtures/lettered-tags/run.sh` asserts all of it, and the checkers as they stood before the change fail that fixture on every lettered tag.

**Two faults were found and fixed on the way.** `check-references.sh` accepted no appendix tag at all, so `[A1-99]` cited against a book with one appendix passed uncounted; accepting `[A2-4a]` meant accepting `[A2-4]`. And its check 4 read a provenance mark written on the line under a paragraph as part of that paragraph, so re-sourcing a mark reported the paragraph as drifted; a mark now ends the paragraph, as it does in `check-book.sh`. Its FAIL-versus-REVIEW split now counts only plain tags, because a lettered insert lengthens a chapter without sliding anything.

**Asserted, not measured:** where lettering stops paying and a rewrite starts. `SKILL.md` calls it "several" and says it is a judgement.

## One fact lives in more places than the chapter that owns it

Swept the reference book's folder for `3.51.0` on 2026-09-10. Six occurrences across four files: chapter 5 (`[5-4]`), chapter 18 (`[18-18]`), `OUTLINE.md` three times (the verified-facts list twice and the anchor ledger once), and `diagrams/README.md` once.

That is the evidence behind the sweep in `SKILL.md § 1`. The instruction that reaches chapter 5 reaches five other places, and two of them are not chapters.

**The `.svg` half of that rule is precautionary rather than measured.** The same sweep found no version string in any of the nine SVGs under `diagrams/`, so nothing here shows a figure going stale with its chapter. The rule stands on what a figure is: `makebook/SKILL.md § Deciding where a figure helps` treats a fact drawn in a figure as a fact checked, and grepping only `*.md` would not see one.

## Why git is the proof

The claim "every other chapter came back byte-identical" is the skill's whole promise, and it is not checkable by reading. `check-book.sh` would pass a book whose twenty chapters were all silently reflowed, because reflowed prose is still structurally sound.

`git diff --stat` on the book folder answers the actual question, which is why step 0 refuses to start over a dirty folder: a pre-existing edit makes the diff say nothing. The `shasum` fallback exists because `/createbook` and `/makebook` are copyable into a repo that may not be under git, and this skill should not be the one that breaks that.

The reference book's folder is fully tracked, the bound `.pdf` and `.epub` included, so an in-place edit leaves two tracked binaries stale. `SKILL.md § 6` reports that rather than rebinding, matching `createbook/SKILL.md § 9. Report`.

## The baseline this was written against

`check-book.sh books/reference-guide`, 2026-09-10:

```
chapters: 20    content-checked: 20    tagged: 20/20 (required)    words: 30222    glossary: 61 terms
OK    structure is sound; read the seams for continuity
```

`check-references.sh` against the seven files in `assessments/` on the same day: 74 references, 2 quotations, both `REVIEW` items quiz stems rather than quotations of the book, and no failures.

Against the four files that cite tags, after checks 3 and 4 were added:

```
chapters: 20    references: 26    quotations: 9    book: books/reference-guide
tags defined: 427 (declared)    tag citations: 38    unresolved: 0    drifted: 0 (0 where the chapter itself moved)
```

The 8 `REVIEW` items in that run are check 2 firing on `OUTLINE.md` and `diagrams/README.md`, which quote the course documents and their own earlier notes rather than the book. They are not defects, and passing those two files in is still right, because between them they hold 8 of the 38 tag citations.

## What check 4 is worth, measured

The insert-and-renumber path was run against the real book on 2026-09-10 to see what each check catches. Chapter 6 went from 24 paragraphs to 25 by an insert at position 2, which is the cheapest possible version of the failure `SKILL.md § Cutting prose` warns about, and `readiness-checklist.md`'s 25 citations were left untouched.

| Run | Result |
|---|---|
| Existence only (`--no-baseline`) | `unresolved: 0`, exit 0, `OK` |
| With the default `HEAD` baseline | `drifted: 20 (20 where the chapter itself moved)`, exit 1 |

Every one of those 25 citations still resolved, because a shifted tag points at a real paragraph. That is the whole argument for check 4 and against stopping at check 3: the weaker check reports green on precisely the failure the ticket was filed about.

The FAIL-versus-REVIEW split was measured the same way. Editing `[6-4]`'s wording in place, leaving chapter 6 at 24 paragraphs, produces `REVIEW` and exit 0, because a paragraph reworded where it stands breaks no citation into it.

The glossary's 61 terms match the outline's term ledger exactly, summed row by row. That is the derivation `SKILL.md § The glossary` relies on, holding in the one book that exercises it.

## What is asserted rather than measured

- **The order of the ways to add prose.** Lettered paragraph first, then growing a paragraph inside its stop, then moving a sentence. It is a judgement about what reads best and costs least, not a finding.
- **The change taxonomy in step 2.** Nine kinds chosen to cover what the tickets named and what the reference book would plausibly need; ticket #28 split adding from cutting and added the premise row. Nothing shows the list is complete.
- **The instruction not to delegate the prose edit.** It follows the rule at `createbook/SKILL.md § 5. Draft the chapters` on work whose output a reader takes as taught, and it has not been tried both ways here.
- **Reading `OUTLINE.md` first as the targeting step.** It is the cheapest index the book has, and no alternative was measured against it.

## Copies

Nothing here is synced to another repo. `/updatebook` reads `/createbook`'s folder and cites `/makebook`'s, so the three travel together; the other two still reach for nothing here and remain liftable as a pair on their own.
