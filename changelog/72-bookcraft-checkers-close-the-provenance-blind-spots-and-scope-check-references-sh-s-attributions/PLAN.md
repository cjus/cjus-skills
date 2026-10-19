# bookcraft checkers: close the provenance blind spots and scope check-references.sh's attributions

Start date: 2026-10-17 14:24:16 MDT

Ticket: #72 (status:todo -> status:in-progress)

## Overview

Three of bookcraft's checks report a pass without doing the work behind it, and check 2 of
`check-references.sh` has two more gaps:

- `check-provenance.sh` checks no quotation in a unit whose mark follows a blank line, which is
  the layout `createbook/SKILL.md § Chapter file format` itself shows.
- `check-provenance.sh` matches a bare-number `§ N` locator by prefix, so `§ 1` resolves
  against `## 10.` after item 1 is gone.
- `check-references.sh` resolves every citation in a referring file against the one book it was
  given, including citations of another book.
- Check 2 never reads the file a file-sourced quotation names, and its `blocks()` reads a
  fenced example as prose.

The objective is that each of these checks either does the work it reports or names what it
skipped, with a fixture for each fix that fails without it. The paragraph rules the operator
settled on 2026-10-15 as #82's ruling R9 govern how a mark, a fence and a digit are read:
`changelog/82-bookcraft-load-the-book-folder-once-into-one-model-every-tool-reads/CHANGELOG.md`.

**Occasion:** the second teaching guide, which serves a course starting November 9. Its 58
units whose mark follows a blank line go unchecked today, so the `units_of()` fix lands first.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

The body of #72 as of the branch start, with its headings demoted two levels so they sit under
this one. Line numbers in it are as of `2231a04`; the current ones, on `fd1d571`, are under
`## Plan`. Its action items are tracked under `## Plan`.

Consolidates #51 and #65, which converge on how `check-references.sh` attributes a citation or a quotation to its source, alongside #51's two `check-provenance.sh` blind spots.

- bookcraft checkers: three blind spots that pass without checking
- createbook: verify file-sourced quotations and make blocks() fence-aware

**Why these combine:** strict. Both land in `plugins/bookcraft/skills/createbook/scripts/check-references.sh`. #51's third blind spot scopes checks 1 and 3 by each citation's nearest attribution, modelled on check 2's named-file reporting. #65 makes that named-file exemption (`:798-816`) read the file it names, and makes `blocks()` (`:161`), check 2's block reader (`:752`), fence-aware.

**Band:** priority:high, raised from #65's priority:medium, because its changes land in `check-references.sh`, which #51 also needs.

**Occasion carried from #51:** the second teaching guide, serving a course that starts November 9. #51's first blind spot, the `units_of()` reset at `check-provenance.sh:710-711`, is the one that leaves its quotations unchecked, so it is the part to land first if the whole issue cannot.

**What has moved since the members were filed** (triaged 2026-10-08 against `main` @ `2231a04`): #65's "Related: #24, which records that `check-references.sh` has no fixture coverage" no longer holds. `createbook/fixtures/lettered-tags/run.sh` runs `check-references.sh` (`:78`, `:100`, `:111`), and #24's triage stamp records that half done. What is still true is narrower: no createbook fixture exercises check 2, so a fixture for either of #65's halves would be check 2's first, not the script's.

<details><summary>#51: bookcraft checkers: three blind spots that pass without checking (original body)</summary>

Three blind spots in bookcraft 1.8.0's checkers, found while recreating the reference teaching guide. Each one lets a check pass without doing the work it reports. They are grouped because they are the same kind of work in the same two scripts.

#### 1. `check-provenance.sh` checks no quotation in a unit whose mark follows a blank line

`units_of()` resets its buffer on a blank line (`createbook/scripts/check-provenance.sh:710-711`), so when a blank line separates a paragraph from its `<!-- src: ... -->` mark, the unit it yields for that mark is empty. Every quotation in the paragraph goes unchecked, and the run still reports OK.

That layout is the one `createbook/SKILL.md` § Chapter file format shows: paragraph, blank line, mark (`SKILL.md:70-73`). `check-book.sh` accepts it, and `/makebook`'s `PROVENANCE_RE` strips it, so nothing else flags it.

- The reference guide's first edition had 523 of its 762 marks after a blank line, and a full run checked 20 quotations. Written with every mark directly under its unit, the recreated edition checks 246.
- Two other books in the same source repo still carry the layout: 58 of 783 marks in a second teaching guide, and 15 of 264 in a companion SQLite guide.

**Proposed fix:** treat a mark that follows one blank line as belonging to the unit before the blank, which is what `check-book.sh` and `/makebook` already assume. Change the SKILL.md example to put the mark directly under its unit either way.

#### 2. `§ N` locators match by prefix

`heading_hit` returns `any(c == h or h.startswith(c) for h in headings)` (`check-provenance.sh:837`). In a source whose headings are numbered items, `§ 1` resolves against `## 10.` through `## 15.` even after item 1 is removed. A probe copy of a numbered questions file with item 1's heading renamed still resolved `§ 1`; `§ 19` failed. A deleted or renumbered item keeps passing.

**Proposed fix:** when the locator is a bare number, require the heading's leading number token to equal it (`1` matches `1.` or `1 `, not `10.`). Prefix matching can stay for word locators, where a heading's words before a dash are a legitimate short form.

#### 3. `check-references.sh` resolves another book's citations against the book it was given

Checks 1 and 3 resolve every `chapter N` (`REF`, `check-references.sh:55`) and every `[N-M]` tag in a referring file against the one book passed. A file that cites two books cannot be checked. Run against the companion SQLite guide, one such file gave 24 tag citations: 10 unresolved, and the other 14 resolved silently against the wrong book's paragraphs.

**Proposed fix:** scope a citation by its nearest attribution. For example, count a tag only when its block names the book's display name (or a configured alias), and report the rest as "attributed elsewhere", the way check 2 already reports quotations sourced to a named file.

#### Occasion

The next check or revision of any bookcraft book. The concrete one is the second teaching guide, which has 58 units whose quotations go unchecked today and serves a course starting November 9.


</details>

<details><summary>#65: createbook: verify file-sourced quotations and make blocks() fence-aware (original body)</summary>

Two gaps in check 2 of `plugins/bookcraft/skills/createbook/scripts/check-references.sh`. They are grouped because they sit in the same file and the same check, and whoever next opens check 2 will be looking at both.

#### Verify a quotation sourced to a named file against that file

Check 2 treats a quotation whose nearest preceding attribution is a named `.md` file as sourced there, so it does not search the book for it. The run lists each such quotation (`:947-954`). The file names below are illustrative:

```
note: 2 quotations were attributed to a named file rather than
      a chapter, so check 2 did not look for them in the book:
      OUTLINE.md:114: sourced to source-notes.md
      OUTLINE.md:588: sourced to revisions.md
```

A quotation attributed to a chapter is verified against that chapter. A quotation attributed to a file is verified against nothing, so it can misquote the file it names and no check notices. The exemption already requires the named file to exist and resolves it by basename, so the remaining step is to read it.

- Read the named file and confirm the quotation appears in it, the way a chapter-attributed quotation is confirmed against its chapter.
- Decide the severity when it does not. A quotation misattributed to a file is the same class of defect as one misattributed to a chapter, which fails.
- Resolve a `file.md:NN` attribution's line number too, or state why the line is not checked. Basename resolution cannot tell two files with the same name apart.
- Keep the count-and-name reporting either way, so an exemption that verifies nothing never reads like one that verified something.

**Cost:** a reader who follows a quotation to the file it names can find the file no longer says it, with nothing in the check having flagged the drift. **Occasion:** the next time `check-references.sh` is extended.

#### Give `blocks()` code-fence awareness

`blocks()` (`:161`) does not know about code fences, so check 2 reads a fenced bulleted example as prose. Each list item is its own block, so a fenced list is split per line, and the `lead` inheritance can reach into a fence.

`tag_paragraphs()` (`:301`) and `tag_citations()` (`:350`) already skip fences, and document why: `updatebook/SKILL.md` carries `[0-9]` inside a bash block, and reading a fence as prose reports a grep command as a broken citation.

- Skip fenced blocks in `blocks()`.
- Check that `lead` cannot attach across a fence boundary.
- Confirm the three functions agree on what a fence is.

**Cost:** a false REVIEW item from a fenced example, which is the noise check 2's attribution rules exist to remove. **Occasion:** the first book whose referring files carry fenced examples.

Related: #24, which records that `check-references.sh` has no fixture coverage. A fixture for either half here would be the first.


</details>


### The ticket's comment

One comment, from 2026-10-17, records that #82 (PR #96) deferred the book model's paragraph
half to this issue: each paragraph's tag, its mark, and fences. It restates ruling R9 for
whenever that half lands:

- **A mark fills its line.** The binder strips only whole-line marks, and `check-book.sh` fails
  any other comment. `check-provenance.sh` takes a mark from anywhere on a line (`MARK.search`).
- **A fence follows CommonMark:** three or more backticks or tildes, closed by the same
  character at least as many times. Every checker today toggles on a backtick fence alone.
- **A mark after a blank line covers the unit above it**, which is this issue's fix for blind
  spot 1.
- **Digits are ASCII only.** Python's `\d` matches other scripts' digits; `[0-9]` never did.

## Plan

Line numbers are on `fd1d571`.

### 1. A mark after a blank line covers the unit above it (#51 § 1, lands first)

- [x] `units_of()` (`check-provenance.sh:687`) stops dropping the unit at the blank line
  (`:714-715`): a mark that follows one blank line belongs to the unit before it, as R9 rules
  and as `check-book.sh` and `/makebook` already read it.
- [x] Change the example in `createbook/SKILL.md § Chapter file format` (`:71-74`) to put the
  mark directly under its unit.
- [x] A fixture holding a misquoted paragraph, a blank line, then its mark. It passes on `main`
  and fails with the fix.

### 2. A bare-number `§ N` locator matches its number exactly (#51 § 2)

- [x] `heading_hit` (`check-provenance.sh:818`, the prefix test at `:841`): when the locator is
  a bare number, the heading's leading number token must equal it, so `1` matches `1.` or `1 `
  and never `10.`. Word locators keep prefix matching.
- [x] A fixture citing `§ 1` against a source that has `## 10.` and no `## 1.`.

### 3. A citation is checked against the book it names (#51 § 3)

- [x] Checks 1 and 3 of `check-references.sh` (`REF` at `:80`, and the `[N-M]` tags) count a
  citation only when its nearest attribution names this book, and report the rest as
  attributed elsewhere, the way check 2 already reports quotations sourced to a named file.
- [x] A fixture: a referring file that cites two books.

How a citation is attributed was settled on 2026-10-18 as D3 below, and it is not "the nearest
attribution" for every kind: a tag follows the file's declared book, a chapter reference the
book named in its block, and check 2's chapter-attributed quotations take the same scoping.

### 4. Check 2 reads the file a quotation names (#65)

- [x] Read the named file and confirm the quotation appears in it, the way a
  chapter-attributed quotation is confirmed against its chapter. The exemption sits at
  `check-references.sh:789-816`.
- [x] Decide the severity when it does not appear.
- [x] Resolve a `file.md:NN` attribution's line number too, or state why the line is not
  checked.
- [x] Keep the count-and-name report (`:958-966`), so an exemption that verifies nothing never
  reads like one that verified something.

### 5. `blocks()` knows about fences (#65)

- [x] Skip fenced blocks in `blocks()` (`check-references.sh:185`).
- [x] `lead` cannot attach across a fence boundary.
- [x] `blocks()`, `tag_paragraphs()` (`:325`) and `tag_citations()` (`:374`) agree on what a
  fence is, by R9's CommonMark rule.

### 6. Fixtures and release

- [x] Each fix above has a fixture that fails without it, with its row in
  `scripts/test-fixtures.sh`. A fixture for check 2 is that check's first.
- [x] Bump bookcraft's version in `.claude-plugin/plugin.json` (now `1.15.0`), and record the
  change in `createbook/NOTES.md`.

## Decisions

The operator accepted these on 2026-10-18. They answer the five open questions the branch
started with.

- **D1. The book model's paragraph half stays deferred; its fence rule lands here.**
  `book_model.py` gains one CommonMark fence tracker, and every fence reader in the two checkers
  calls it, so step 5's "agree on what a fence is" holds by construction. The whole-line mark
  test is the model's existing `MARK_LINE`. The rest of the paragraph half (each paragraph's
  tag, its mark) waits for a consumer: the three readers cut paragraphs three different ways (a
  unit ends at its mark, `blocks()` splits list items and table rows, `tag_paragraphs()` keys by
  tag), and reworking all three ahead of November 9, inside a check with no fixture, is the risk
  this avoids. #98 will call the fence tracker too, and needs nothing else from the model.
- **D2. R9's mark and digit rules apply where a fix already touches the line.** That is the
  mark test in `units_of()`, the number test in `heading_hit`, `REF`, and `FILEREF`'s line
  number. No sweep of the other `\d` sites: for a book `check-book.sh` passes, neither rule
  changes a verdict, so a sweep is diff without a fixture that could fail. The fence rule
  applies at every fence reader in both checkers (D1).
- **D3. A citation is attributed by what the measurements show each kind needs.**
  - `book.json` gains `cited_as`, the names other files use for this book. A name is matched
    case-insensitively, as a phrase.
  - A referring file may declare the books it cites, one whole-line comment per book, with one
    marked as the book its bare citations cite. A file with no declaration is read exactly as
    before.
  - **Tags (checks 3 and 4)** belong to the declared file's default book. A run against any
    other book reports them as attributed elsewhere, with a count, and resolves none. A name
    near a tag never moves it.
  - **Chapter references (check 1)** belong to the book named nearest in their own block, and
    to the default book when the block names none. Check 1 reads blocks rather than lines to do
    it. A missing chapter FAILs when the name shares the reference's sentence, and REVIEWs when
    the name sits only elsewhere in the block, the rule check 2 already applies to a citation
    the script inferred.
  - **Check 2** scopes a chapter-attributed quotation the same way, and reports one attributed
    to another book's chapter as attributed elsewhere.
  - Why it splits, measured 2026-10-18 on the second teaching guide's course material, by a
    session with access to it. Tags: every tag-carrying file that cites the companion SQLite
    guide names it, so the names reach #51's case; nearest-name attribution misreads 27 tags on
    20 lines where the SQLite guide is mentioned as a resource beside a teaching-guide tag; and
    the material writes about 3,000 tags bare by convention. Chapter references: 8 sit in blocks
    naming the SQLite guide and all 8 mean it, but only 3 put the name beside the reference, so
    the block is the right scope; a default-book rule would have passed all 8 against the wrong
    chapters. The same material's changelog notes are the case the rule gets wrong: about 47 of
    102 chapter references in blocks naming one book mean the other. Nothing passes those notes
    to a check, and the fixture pins that shape at REVIEW.
- **D4. A quotation sourced to a named file is checked against that file.** Not found, it FAILs
  in a key row and REVIEWs in prose, as one attributed to a chapter does
  (`check-references.sh:843-857`). The `:NN` line number is not checked, because any edit above
  it moves it and what the attribution claims is the wording. When more than one visible file
  carries the name, each is read, and the report says how many did.
- **D5. `check-book.sh`'s fences stay with #73.** Nothing regresses: it already misreads a `~~~`
  block, and this branch only stops the other two checkers doing so.

## Open Questions

None open.

## Deferred

- **The book model's paragraph half**: each paragraph's tag and its mark, read once for every
  tool. Deferred by D1 until a consumer needs the structure rather than the rules.
- **A word locator ending in a number still matches by prefix.** `§ Worked Reasoning #1`
  resolves against `### Worked Reasoning #10 - ...` after item 1 is gone, the same shape as
  #51 § 2 one step over. Step 2 fixes only the bare-number locator.
- **A loose list's earlier items go unchecked.** `units_of()` starts a new unit at each item
  after a blank line, so a mark after a list with blanks between its items covers only the last
  item, while `check-book.sh`'s sweep reads the whole list as one unit. The quotations in the
  earlier items are the ones left out.
- **The binder's `fenced_lines` still toggles on a backtick line** (`build-book.py:1022`), for
  attaching a chapter's scripts. It is the binder's last line-based fence reader; its
  markdown-it pass already reads fences by CommonMark.
