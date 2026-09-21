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

## There is no free way to add a paragraph to a tagged chapter

Derived rather than asserted, from two rules that were each written for another reason:

- `check-book.sh` requires the paragraph half of every tag to count 1, 2, 3 with no gap, no repeat and no padding. So a paragraph cannot be inserted as `[5-12a]`, and inserting at 12 shifts every later tag in that chapter by one.
- `chapter-prose.md § Close` makes the last paragraph the close, which is one paragraph carrying the verdict and the noun the chapter hands forward. So appending after it produces a chapter with two closes.

Together those close the obvious escape. `SKILL.md § Adding prose` states the consequence and ranks the three ways out: grow an existing paragraph inside the 90-word stop, move a sentence across a paragraph boundary, or insert and repoint. The ranking is a judgment about cost, not a measurement.

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

The insert-and-renumber path was run against the real book on 2026-09-10 to see what each check catches. Chapter 6 went from 24 paragraphs to 25 by an insert at position 2, which is the cheapest possible version of the failure `SKILL.md § Adding prose` warns about, and `readiness-checklist.md`'s 25 citations were left untouched.

| Run | Result |
|---|---|
| Existence only (`--no-baseline`) | `unresolved: 0`, exit 0, `OK` |
| With the default `HEAD` baseline | `drifted: 20 (20 where the chapter itself moved)`, exit 1 |

Every one of those 25 citations still resolved, because a shifted tag points at a real paragraph. That is the whole argument for check 4 and against stopping at check 3: the weaker check reports green on precisely the failure the ticket was filed about.

The FAIL-versus-REVIEW split was measured the same way. Editing `[6-4]`'s wording in place, leaving chapter 6 at 24 paragraphs, produces `REVIEW` and exit 0, because a paragraph reworded where it stands breaks no citation into it.

The glossary's 61 terms match the outline's term ledger exactly, summed row by row. That is the derivation `SKILL.md § The glossary` relies on, holding in the one book that exercises it.

## What is asserted rather than measured

- **The order of the three ways to add prose.** Cheapest-first is a judgment about what an edit costs, not a finding.
- **The change taxonomy in step 2.** Seven kinds chosen to cover what the ticket named and what the reference book would plausibly need. Nothing shows the list is complete.
- **The instruction not to delegate the prose edit.** It follows the rule at `createbook/SKILL.md § 5. Draft the chapters` on work whose output a reader takes as taught, and it has not been tried both ways here.
- **Reading `OUTLINE.md` first as the targeting step.** It is the cheapest index the book has, and no alternative was measured against it.

## Copies

Nothing here is synced to another repo. `/updatebook` reads `/createbook`'s folder and cites `/makebook`'s, so the three travel together; the other two still reach for nothing here and remain liftable as a pair on their own.
