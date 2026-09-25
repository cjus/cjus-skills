---
name: updatebook
description: Revise a book /createbook already wrote, in place. Edits only the chapters an instruction reaches, carries the outline and the glossary along with it, and leaves every other chapter byte-identical so the paragraph tags other files cite keep pointing where they did. Takes the book folder and the update instructions. Use when asked to correct, amend, extend or add to an existing book rather than write a new one.
argument-hint: <book-folder> <what to change>
---

# /updatebook

Update the book in the first argument, according to the second: $ARGUMENTS

A book here is what `/createbook` produces: a folder of chapter markdown, an `OUTLINE.md`, a `book.json`, usually a `glossary.md`, and sometimes a `diagrams/`. This skill changes one that already exists. It does not write a new one, and it does not rerun `/createbook`.

**The rules for the prose are `/createbook`'s, not this skill's.** A revised sentence meets the same bar as a written one, so `${CLAUDE_PLUGIN_ROOT}/skills/createbook/reference/chapter-prose.md`, with the book's profile file beside it (`guide.md` or `narration.md` in the same folder), is the authority on shape, voice, budgets and the before-sending checks, and `${CLAUDE_PLUGIN_ROOT}/skills/createbook/SKILL.md` is the authority on the structure around a chapter. Nothing here restates a rule from either file. What this skill owns is the part neither of them covers: which files an instruction is allowed to touch, and what an edit obliges you to carry with it.

## Arguments

| Argument | Meaning |
|---|---|
| First (required) | The folder holding the book. `"books/reference-guide"`. |
| Second (required) | What to change, in the operator's words. `"add a chapter on partitioning"`, `"chapter 5's SQLite version has moved"`. |

With either missing, ask for it and stop.

## Why in place rather than a rerun

**A paragraph tag is an address, and addresses are cited from outside the book.** Counted in the source repo on 2026-09-10: the reference book's tags are cited 30 times outside the book folder, across two prep files, and its chapter numbers are cited 74 more times across seven assessment files. Regenerating the book renumbers those. A renumber is not a diff a reader can follow: every citation still resolves, silently, to a different paragraph.

Three things follow, and they are the whole skill:

- **A chapter the instruction does not reach comes back byte-identical.** Not similar. Identical, and provably so.
- **`OUTLINE.md` is the record the book was written against**, so a change to a chapter's scope, its terms or its anchors moves the outline in the same run or the record stops being one.
- **The glossary is derived from the outline's term ledger** (`createbook/SKILL.md § 6. Write the front matter and the glossary`), so a term that arrives or retires reaches `glossary.md` in the same run.

## Procedure

### 0. Validate the folder, and record what it looked like

```bash
BOOK="$1"
test -f "$BOOK/book.json" || { echo "not a /createbook book"; exit 1; }
test -f "$BOOK/assertions.json" || { echo "no assertions.json: backfill it first"; exit 1; }
git status --porcelain "$BOOK"
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/assertions.sh check "$BOOK"
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-book.sh "$BOOK"
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-provenance.sh "$BOOK"
```

- **No `book.json` means stop.** `/createbook` writes one at its step 4, so a folder without it is either a `/makebook` folder that was never a book in this sense or the wrong path. Say which you suspect and ask; do not proceed on a guess.
- **No `assertions.json` means stop and backfill** (`createbook/SKILL.md § Backfilling the assertions file`). The file records what the book was told or settled that no source holds, and this skill writes to it at step 2. The backfill needs the operator, and its file has to be committed before the edit begins, for the two reasons in the next bullet: step 0 refuses uncommitted changes, and step 5's `git diff` would carry the new file beside the edit. **So the order is backfill, confirm, commit, then step 0 again.** No flag skips it, even for a one-word fix.
- **Uncommitted changes in the folder mean stop and surface them.** The proof in step 5 that untouched chapters are untouched is a `git diff` against the starting state, and pre-existing edits poison it. The operator decides whether to commit, stash, or continue.
- **Both checkers run before the edit as well as after.** A failure that was already there is not yours, and finding that out afterwards costs an hour. Record `check-book.sh`'s summary line and `check-provenance.sh`'s census lines, its `assertions` line among them; step 5 compares against them, and the provenance census is the half that moves without moving the exit code.
- Outside a git repo, record `shasum "$BOOK"/*.md` instead and diff the two lists at step 5. `md5sum` or `cksum` does the same job.

Read `book.json`'s `tags` while you are in there. **A book declaring `"tags": false` has no addresses**, which makes most of § Adding prose moot for it.

**Read `profile` in the same pass, and hold the edit to the rule set it names.** Absent means the narration rules, `createbook/reference/narration.md`; `"guide"` means `createbook/reference/guide.md`. Either way `chapter-prose.md` applies underneath, and the profile file wins where it names one of its rules. This is the one book-level fact most likely to be missed here, because the rules it changes are the ones an editor applies from memory rather than by looking them up: a guide chapter opening on no handoff noun is correct, a guide header with no `This chapter` row is correct, an H3 inside a part is correct, and a labelled callout is correct. **Editing a guide under the narration rules reads as tidying up.** It silently reverts the thing the profile was set to buy, and `check-book.sh` cannot catch it, because it passes a chapter that merely stopped using what the profile allows.

`check-book.sh` prints the profile first on its summary line, so the run you record at this step already tells you which set you are under. Read it rather than inferring it from the chapters.

### 1. Read the outline, then target

`OUTLINE.md` is the index into the book: a brief per chapter, the handoff chain, the term ledger and the anchor ledger. Read it in full first, and `assertions.sh list "$BOOK"` beside it, since an instruction that touches an entry is one step 2 has to classify. It is one file and it tells you which chapters an instruction can possibly reach, which is what keeps this skill from reading twenty chapters to change one.

Then narrow:

```bash
grep -rn "<the noun the instruction names>" "$BOOK"
```

Recursive over the folder rather than over a list of paths, so it reaches `diagrams/` when there is one and does not error when there is not.

Read in full only the chapters that survive both. Opening a chapter and deciding it does not change is a correct outcome and costs nothing; the diff in step 5 proves it was not touched.

**One fact usually lives in more places than the chapter that owns it.** Sweeping the reference book for `3.51.0` on 2026-09-10 found it in chapter 5, in chapter 18, three times in `OUTLINE.md`, and once in `diagrams/README.md`: six places across four files, for one version number. So grep the whole folder including `diagrams/`, and grep the `.svg` files rather than only the markdown, because a figure carries text that no markdown search reaches and a figure is the part of the page a reader trusts most.

### 2. Classify the change before making it

What an edit obliges you to carry is decided by which of these it is. Read the row, then read the section it names.

| The instruction | Tags | What else has to move |
|---|---|---|
| **Corrects a fact** | Nothing moves, if the sentence is rewritten where it stands | Every other place the fact appears, the outline's verified list and anchor ledger among them, and any figure that draws it |
| **Rewrites a passage** | Nothing moves while the paragraph count holds | The outline's brief, if the chapter's claim moved |
| **Adds prose** | Nothing moves: a new paragraph takes a lettered tag. See § Adding prose | A citation whose sentence moved, where a paragraph was split |
| **Cuts prose** | The tail of that chapter renumbers. See § Cutting prose | Every citation of a moved tag |
| **Changes a premise** | The chapter is rewritten, and its tags renumber | Its `premise` entry, superseded first with `search` phrases for the new value, so `check-provenance.sh` sweeps every passage built on the old one. Then every such passage, in every chapter it reaches. See § When to stop editing in place |
| **Supplies a fact no source holds, rules on the sources or the scope, or adopts a recommendation** | As the edit it comes with | An entry in `assertions.json`: added, or superseded where it replaces one, in this run and before the prose changes (`createbook/SKILL.md § The assertions file`). A measurement re-run supersedes its `measured` entry |
| **Adds or retires a term** | Nothing moves | The term ledger row, and `glossary.md`. See § The glossary |
| **Adds a figure** | Nothing moves: a figure line takes no tag and advances no count (`chapter-prose.md § Paragraph tags`) | `diagrams/README.md`, and the figure numbers after it in the same chapter |
| **Adds a chapter** | Appending is free; inserting rewrites every later filename and every tag inside it | See § Adding a chapter |
| **Removes a chapter** | Breaks every citation into it, and renumbers everything after it | Stop and confirm with the operator first |

**Most rows are edits, and three things are not.** A changed premise, a chapter that needs several new paragraphs at once, and a change to the chapters' boundaries or order each call for a rewrite: of one chapter, or of the book. § When to stop editing in place says which, and it is worth reading before the first edit rather than after the tenth.

### 3. Make the edit, and make it the smallest one that satisfies the instruction

**Edit, never rewrite, at this level.** Use the Edit tool on the passage. Writing a chapter file whole reflows prose the instruction never reached, and a chapter that was supposed to come back byte-identical comes back merely equivalent. That distinction is invisible in a summary and obvious in a diff. The one time this skill writes a chapter file whole is a chapter rewrite, and § When to stop editing in place says when an edit has become one.

**Do not delegate the prose to a subagent.** The edit is small, local, and depends on the surrounding paragraphs you have just read, which is exactly the context a spawn discards. Chapter prose also makes claims a reader takes as taught, and `createbook/SKILL.md § 5. Draft the chapters` keeps that work on the session's own tier. The two exceptions are a whole new chapter and a chapter rewrite, which are `/createbook`-shaped jobs and use that same section's chapter prompt.

**A callout holds one idea** (`guide.md § Callouts`). A callout takes no tag, which makes it look like a free place to add text, and that is how a `Warning.` comes to hold a definition, a points split, a scheduling gap and a contact. A second idea is a second callout under the label that fits it, or a paragraph.

**Every budget is still per chapter and still does not pool** (`chapter-prose.md § Every budget is per chapter`). An edit that adds a term, an anchor or a number spends this chapter's allowance, and the outline's ledgers are where you check what is already spent. Moving prose into a neighbouring chapter is not a fix: it changes a chapter the instruction never reached.

**Nothing caps a chapter's length** (`chapter-prose.md § Length`), so an edit that adds prose is not on a clock and does not have to buy its words back from somewhere else in the chapter. What an edit still may not do is leave the chapter carrying more than the one claim the outline gave it. Where it does, cut inside that chapter in the order at `chapter-prose.md § Before sending`, and report a chapter that cannot be brought back to one claim rather than writing around it.

**In a book that declares `provenance`, the mark moves with the prose.** An edit that changes what a paragraph claims changes where that claim came from, and a mark left behind is worse than no mark: it is a citation pointing at a source that no longer says this. So:

- **A new paragraph, table, list or fenced block gets its own mark**, or `check-book.sh` fails the chapter.
- **An edited unit's mark is re-read against the edit.** A paragraph that was `<!-- src: fill -->` and now rests on a source stops being `fill`, and one that has drifted past what its source says either gets re-sourced or says `fill` for the part that is.
- **A deleted unit takes its mark with it.** An orphaned mark reads as belonging to the paragraph above it.
- **A unit resting on an entry cites it**, as `assertion <id>` (`chapter-prose.md § Provenance`). Where the entry is `legacy`, a paragraph the edit rewrites gains that citation. Once every paragraph resting on the entry cites it, run `assertions.sh expect "$BOOK" <id>`. Until then it stays `legacy`, because an `expected` entry no mark cites is reported as one the book dropped.
- **Open the source.** The mark is not evidence; the source is. A claim edited to match a source you did not re-read is the defect this whole format exists to prevent, and no check in step 5 can see it.

**`fill` is where a book goes stale, and this is the query that finds it.** A sourced claim is fixed by its resource; a filled-in one carries a version, a default or a name the model knew at drafting time. `grep -rn 'src: fill' <book>` is the list of what to recheck when a book is picked up again, which is the reason the exhaustive mark exists at all. `check-provenance.sh` reports the same population as a count on its census line, so a `fill` figure that climbs across an edit says the book moved claims off its sources.

### 4. Carry the outline, the glossary and the figures

Whatever the change touched:

- **The chapter's brief in `OUTLINE.md` § Chapters**, when what the chapter explains moved.
- **The handoff chain, under `narration`**, when the noun a chapter opens or closes on moved. Both neighbours are affected, and the seam is checked by reading at step 5. A `guide` outline has no handoff chain.
- **The term ledger and the anchor ledger**, when a term or an anchor arrived or retired.
- **`assertions.json`**, through `assertions.sh` and never by hand, when step 2 said the instruction writes an entry, or when step 3 turned a `legacy` entry `expected`. A re-run measurement supersedes its `measured` entry. An outline written before the file existed may still carry a verified-facts section, and that moves with it until a rewrite retires it.
- **`glossary.md`**, per § The glossary.
- **`diagrams/README.md`**, when a figure arrived, retired, or stopped being true.
- **The chapter header's rows**, four under `narration` and three under `guide`, when the edit changed what the chapter covers, what it asks the reader to do, which sources it rests on, or what it fills in. Under `guide`, what the chapter covers lives in the first sentence of `## In short`, so that moves instead. The Draws-on row has to name every source the chapter's marks now name, and nothing they do not.
- **The chapter's `## Suggested reading` list**, when the edit closed a gap the list names or opened one it does not. An item naming something the book now teaches sends the reader out of the book for what they already own.
- **`about-this-book.md`**, when the edit changed what the book was built from or what it fills in. It is the header's claims at book scale, and it goes stale the same way.
- **The source ledger in `OUTLINE.md`**, when a source arrived, retired, or turned out to say something else. This is the row that decides what every later `/updatebook` run believes it can check against.

### 5. Check, in five parts, and read all five

```bash
git diff --stat "$BOOK"
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/assertions.sh check "$BOOK"
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-book.sh "$BOOK"
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-references.sh "$BOOK" <referring-file>...
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-provenance.sh "$BOOK"
```

1. **The file list must be the file list you intended.** This is the only proof that untouched chapters are untouched, and it is the reason step 0 demanded a clean folder. A file in the diff that you did not mean to change is the finding; go and look at it. `assertions.json` belongs in the list exactly when step 2 or step 3 wrote to it. **Read its diff beside the chapters'**, since each change there is a claim the book now stands behind, and `assertions.sh check` must pass.
2. **`check-book.sh` must pass, and its `content-checked` count must equal its chapter count.** A run that examined fewer chapters than it found says nothing about the rest, and it says so on its own summary. Compare the `prose`, `structure`, `tagged` and `glossary` figures against the lines you recorded at step 0.
3. **`check-references.sh` for every file that cites this book**, including the book's own `OUTLINE.md` and `diagrams/README.md`. It runs four checks and reports them separately so the weaker cannot stand in for the stronger: a cited chapter exists, a quotation attributed to a chapter is in that chapter, a cited `[N-M]` names a paragraph the book defines, and that paragraph is still the paragraph it was at the baseline. **The fourth is the one that matters here**, because it is the only check that sees the failure this skill is built around, and it needs no argument: the baseline defaults to `HEAD`, which step 0's clean-folder rule makes exactly the book as it stood before your edit.
4. **`check-provenance.sh` reads the marks in the other direction**, out at the sources they name, which is the direction an edit breaks. A paragraph rewritten against a different page of the syllabus keeps its old `p. 4` and nothing else notices; a source re-exported from Canvas can lose the heading a mark cites. It fails on a source `book.json` does not declare and on a locator that does not resolve, and it reports quotation mismatches as `REVIEW` because against the reference book a hard failure there was wrong ten times out of ten. **Compare its census against step 0's**: a rise in `unverifiable` or `unparsed` means fewer of the book's quotations were settled than before, and neither moves the exit code. On the `assertions` line, a new `uncited` entry is one the edit dropped, and a passage the sweep finds is prose still built on a premise the edit superseded. **A rise in `unverifiable` does not always mean the edit moved a claim onto unreadable ground, and reading it that way is how this number misleads.** A quotation counts as unverifiable when **any** source its mark names is unreadable, so an edit that breaks a quotation against a perfectly readable co-named source lands in the same bucket, masked by the unreadable one. That masking case is the live majority: 12 of the reference book's 28 unverifiable quotations name a readable source alongside an image-only PDF. So when the number climbs, read the named lines and find the quotation, rather than assuming a source went dark.
5. **Read the seams.** No script sees continuity. Read the closing paragraph of the chapter before the one you changed, the changed chapter's opening and closing paragraphs, and the opening of the chapter after. Under `narration` the failure this catches is a handoff noun that drifted. Under `guide` it is an opening that stopped orienting a reader who arrives there first, or a close that is no longer true of the whole chapter (`createbook/SKILL.md § 8. Read the seams`). Both are invisible to everything above.

**None of the five reaches a paraphrase that drifted, which is the failure step 3 warns about in its own words: "a claim edited to match a source you did not re-read".** `/check-claims` is the pass that does, sending one agent per chapter to read the sources the marks name:

```bash
/bookcraft:check-claims "$BOOK" --chapters <the chapters your edit reached, an appendix as AN>
```

**Pass `--chapters`.** This skill already knows which chapters it touched and proves it with the step 5 diff, so the scoped run is one to three agents rather than eighteen. That scoping is the whole reason the pass is affordable here, and an `/updatebook` run is the moment it earns most: an edited sentence keeps the mark the old sentence had, and nothing above notices. It is advisory and gates nothing, so a finding is triaged, never a reason to hold the edit.

**Two things about the output are worth knowing before you read it.** A drifted citation is reported as `FAIL` when the chapter also changed length, or when its file was renamed, which is what inserting a chapter does to every later file. It is a `REVIEW` when neither happened. The count is a proxy rather than a proof: inserting a paragraph and cutting another in the same chapter leaves it unchanged while sliding every tag between the two, so a `REVIEW` says a rewording is likely and asks you to confirm which. And check 2 distinguishes a quotation of the book from a quotation of something else only by what the text says it is quoting, so read its `REVIEW` lines with that in mind. It takes the attribution to be whichever signal sits closest before the quotation: a named file like `course-outline.md:59` means the quotation is sourced there and the book is never searched for it, and the closing summary says how many went that way. A chapter reference means the book is searched. What stays beyond reach is a quotation attributed in prose to a document the script cannot name, and the convention that keeps those out of the report is `createbook/SKILL.md`'s § When the book supersedes one: wording the new book does not use is stated without quotation marks rather than quoted. Two fixes to the scanner, and then applying that convention to the reference book's `OUTLINE.md`, together took its own run from eight `REVIEW` lines to none on 2026-09-10. The convention alone accounts for two of the eight, so reach for it when a line names wording the book has replaced, and not when the reported text is not a quotation at all.

**Commit before you run it, and the check stops working.** Once the edit is in `HEAD` the baseline is the edited book, so every citation compares equal and check 4 reports zero drift over a book that just renumbered. Run it while the edit is still uncommitted, or pass `--since <the commit before yours>`.

**Read the `REPORT` lines as well as the exit code, and compare them with step 0's.** `check-book.sh` fails a guide book on a paragraph over 90 words (`chapter-prose.md § Shape`) and reports one under narration. It reports a sentence over 45 words (`chapter-prose.md § Voice`), a callout over four sentences, and a `## In short` summary that has grown past 120 words or picked up a run of the chapter's own sentences (`createbook/SKILL.md § 7. Check the folder`). An edit that adds a report the step 0 run did not have is an edit that wore the chapter down, which is how the reference guide's paragraphs grew.

### 6. Report

- The files changed, and the chapters deliberately left alone.
- The `check-book.sh` summary lines from both runs, before and after. A run prints two: the counts line and the `chapter prose:` line.
- The `check-provenance.sh` census from both runs, and any line that moved. A rise in `unverifiable` or `unparsed` is worth a sentence even though neither fails a run, and a risen `unverifiable` is worth naming the quotation behind it: the count cannot tell a source going dark from a quotation breaking against a readable one that shares its mark with an unreadable source.
- Every tag that moved, and every citation repointed to follow it.
- Every entry the run added, superseded, retired or turned `expected`, by ID.
- **That the bound PDF and EPUB in the folder are now stale**, with the command to rebind:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/bookcraft-python \
  ${CLAUDE_PLUGIN_ROOT}/skills/makebook/scripts/build-book.py \
  "Book Title" "$BOOK" --type-size 14
```

**A `guide` book declares `"edition": "reading"`, so that command rebinds the reader's copy.** Where the folder also holds the operator's tagged copy, rebind it too with `--no-reading-edition` and the `--out` it was bound to (`makebook/SKILL.md § The reading edition`), and say which file is which in the report.

**`--type-size` is in that command because a rebind overwrites an existing edition.** `/makebook` binds at 14pt unless told otherwise, so a bare command re-editions any book bound at another size rather than refreshing it. Pass the size the folder's current PDF was actually bound at rather than inheriting a default that has moved twice; the reference book is 14pt. `makebook/SKILL.md` § Type size has the sizes.

**Do not bind unless asked**, matching `/createbook`'s last step (`createbook/SKILL.md § 9. Report`). A rebind rewrites two tracked binaries and `/makebook`'s own procedure wants the figure decisions made against the finished chapters first, so it is a separate decision by the operator.

## Adding prose

**A new paragraph takes a lettered tag, so nothing renumbers.** A tag is an address other files cite. Until 2026-09-24 the only way to add a paragraph to a tagged chapter was to renumber every tag after it and repoint every citation, so revisions grew existing paragraphs instead and wore the chapter down: one of the reference guide's paragraphs went from 81 words at its first bind to 207 in a single revision. Take the edit that fits what the new text is, in this order:

1. **A new idea gets its own paragraph, with the next letter.** Place it after the paragraph it follows, and tag it with that paragraph's number and the next free letter: after `[5-12]` comes `[5-12a]`, then `[5-12b]`, and `[5-13]` is untouched. Give it its own provenance mark. Nothing renumbers and no citation moves.
2. **More of the same idea may grow its paragraph, only while the paragraph stays at 90 words or fewer.** A paragraph that would pass 90 holds two ideas. Split it where the direction turns, keep the first half under its tag, and give the second half the next letter. Repoint any citation whose sentence moved into the new half; `check-references.sh`'s check 4 names each one. Where the paragraph already has a lettered follower, the new half would have to sit between the two, and no letter fits there without moving a tag someone cites: that chapter is due a rewrite (§ When to stop editing in place).
3. **A sentence that belongs in a neighbour may move there**, where both paragraphs stay within the stop.

**Never park new text in a callout, a table or a list because those take no tag.** A callout holds one idea (§ 3), and a table or a list holds a set, not an argument.

**A lettered paragraph never goes after the close, or before the first paragraph.** The last paragraph is the close (`narration.md § Close`, `guide.md § Close`), and a paragraph after it is a chapter with two closes, so add before the close, lettered after the paragraph it follows. Nothing comes before paragraph 1, so new opening material is an edit to paragraph 1 or a lettered paragraph after it.

**Lettered tags accumulate, and `check-book.sh` reports every chapter that has them.** Each one is a patch on the chapter as first written. A chapter collecting several, or needing several at once, is due a rewrite, which is what renumbers them (§ When to stop editing in place).

## Cutting prose

**A cut renumbers the rest of its chapter**, because tags run with no gap and a cut leaves one. Where the cut is part of a larger change to the chapter, make it inside a chapter rewrite instead. Otherwise, renumber and repoint:

```bash
# every tag in the chapter after the cut shifts back by one
# then: who cited one of them? everything but the chapter's own file is a citation
CH=<chapter-number>
CHAPTER=$(ls "$BOOK"/*-$(printf '%02d' "$CH")-*.md)
grep -rnoE "\[$CH-[0-9]+[a-z]?\]" --include='*.md' . | grep -v "^$CHAPTER:"
```

**Excluding the whole book folder here would be wrong**, which is why the filter names one file. `OUTLINE.md` and `diagrams/README.md` live inside the folder and cite tags like anything else: eight such citations sit in the reference book's own two files, counted 2026-09-10. Only the chapter being renumbered holds tags as definitions rather than citations. For an appendix, the chapter half is `A` and its number, and the filename holds `-appendix-N-`.

- Renumber every tag in that chapter after the cut. Tags before it do not move, so citations of them are unaffected. A lettered tag after the cut renumbers with the paragraph it follows: `[5-12a]` becomes `[5-11a]`.
- Repoint every citation of a moved tag, **in the same change**, inside the book folder as well as outside it. A citation left behind still resolves, which is what makes this the failure worth guarding: it points at a real paragraph that is no longer the one meant.
- **Then run `check-references.sh` before committing, and let it tell you which ones you missed.** Its check 4 compares every cited paragraph against the same paragraph at `HEAD`, so a renumber makes it name each stale citation and print the prose the tag used to reach beside the prose it reaches now. Measured against this book on 2026-09-10: renumbering chapter 6 by one paragraph left all 25 of `readiness-checklist.md`'s citations resolving, and the check reported 20 of them as failures. The grep above finds the citations; the check finds the ones you did not fix.
- Rerun `check-book.sh`, which catches a tag that kept its old number.

## When to stop editing in place

An edit is the right tool while the change is local. Past that, a rewrite costs less than the edits, and it reads better. There are three levels:

| Level | When | What moves |
|---|---|---|
| **Edit in place** | The change is local, and the chapter's claim still holds | Only the edited passage and what § 4 carries with it |
| **Rewrite one chapter**, keeping its number | A premise under the chapter changed, or it needs several new paragraphs at once, or it already carries several lettered tags | That chapter's tags renumber and citations into it are repointed. Every other chapter stays byte-identical |
| **Recreate the book** | The chapters' boundaries or order change, or the rules the book was written under do | Everything, through `/createbook --recreate` (`createbook/SKILL.md § Recreating a book`) and `§ When the book supersedes one that already exists` |

**A premise is a fact the chapter's plans are built on**: the class size, the number of sessions, the version a procedure assumes. When one changes, the passages built on it are wrong in their structure, not only in a number. Patching the number leaves plans built for the old premise with an aside about the new one. When the reference guide's class size moved from twenty to eleven, five chapters gained "your roster is eleven, so..." beside plans built for twenty, and one of them carried both four-evening schedules with the arithmetic for the outdated one. Rewrite every chapter the premise reaches, cut what no longer serves, and accept the renumber.

**"Several" is a judgement, not a measurement.** A chapter whose added paragraphs no longer read as additions, or whose new material changes what it argues, is due a rewrite. The lettered-tag report in step 5 is where to watch for one.

### Rewriting one chapter

1. **Read `assertions.json`, not `git log -p`.** A rewrite works from the outline row, the sources and the file, and the file is where every fact a revision established already sits, since step 0 would not have let this run start without it. `assertions.sh list "$BOOK"` shows each entry that holds. Where the rewrite follows a changed premise, supersede its entry before drafting (step 2).
2. **Update the chapter's outline row** for the change: the brief, the terms, the anchors, and the Carries row naming the entries it rests on.
3. **Draft the chapter with `/createbook`'s step 5 prompt** (`createbook/SKILL.md § 5. Draft the chapters`), with its number, the book's profile, its outline row, its sources, and the entries it carries along with every `book` entry. This is the one edit this skill hands to a chapter agent. Its paragraphs cite their entries, so each `legacy` entry this chapter alone rested on can now turn `expected` (step 3).
4. **Replace the file whole.** Its tags count from 1 again, and the lettered ones are gone.
5. **Repoint every citation into the chapter**, inside the book folder and outside it, by finding where the cited sentence now lives. A citation whose content is gone is reworded or removed. `check-references.sh`'s check 4 names each citation whose paragraph changed, so run it before committing, for the reason § Cutting prose gives.
6. **Redo the chapter's header, `## In short` and concept list**, and the glossary entries it owns (§ The glossary).
7. **Run the checks in step 5.** The diff shows this chapter, `OUTLINE.md`, the glossary where it changed and the repointed files, and nothing else.

### Recreating the book

When the chapters' boundaries or order change, or the rules the book was written under change, rewriting chapter by chapter keeps the old book's shape under the new rules. **Stop and name the command; this skill never runs it:**

```
/createbook --recreate "$BOOK" <new-folder>
```

It reads `assertions.json` first and carries every entry that holds, so nothing is carried into a new outline by hand. `createbook/SKILL.md § Recreating a book` has the rest, including why it writes into a new folder, and `§ When the book supersedes one that already exists` repoints the outside citations afterwards.

## Adding a chapter

`/createbook` already owns this at `createbook/SKILL.md § Adding to a book that already exists`, and it says the thing that matters: **append rather than insert.** Inserting renames every later file, rewrites the chapter half of every tag inside those files, and breaks every `ch. N` and `[N-M]` citation into them from outside the book.

What appending obliges here, beyond that section:

- **Under `narration`, the old last chapter has to gain a handoff.** Only the last chapter of a narration book hands forward nothing (`narration.md § Close`), so the chapter that used to be last now closes on a noun the new one opens on. That is an edit to its closing paragraph, and it makes the old last chapter a chapter the instruction reached. **Under `guide`, chapters do not chain**, so appending leaves the old last chapter untouched.
- **The outline gains a row in every ledger**: the chapters section, the term ledger, the anchor ledger, and under `narration` the handoff chain. An anchor another chapter already spent is not available to the new one.
- **The glossary gains the new chapter's terms**, per § The glossary.
- Write the chapter with `/createbook`'s step 5 prompt, carrying this chapter's number so its tags are right.

## The glossary

`glossary.md` is derived from the outline's term ledger, so the ledger moves first and the glossary follows it.

- **A term arrives:** a ledger row for the chapter that glosses it, then an entry reading `**term** (ch. N) definition`. The definition restates that chapter's own gloss, which `chapter-prose.md § Glosses` put inside the sentence that first uses the term, and in a tagged book the paragraph tag names that sentence exactly. An entry saying something its chapter does not is worse than no entry.
- **A term retires:** remove both. An entry with no chapter behind it is a definition the book does not make.
- **A term's owning chapter changes:** the `(ch. N)` moves with it.

`check-book.sh` catches a malformed entry, an entry with no definition, a chapter the book does not have, a duplicate term, and a `book.json` that declares a glossary the folder is missing. It cannot catch the three that matter most here: a glossed term with no entry, an entry for a term no chapter glosses, and a definition that has drifted from its chapter. Those are read against the chapter.

## What this skill does not do

- **It does not bind.** See step 6.
- **It does not judge the prose.** `check-book.sh` checks structure; a clean run means the folder will bind, and says nothing about whether the book reads well.
- **It does not recreate a book.** It says when one is due (§ When to stop editing in place) and names the command, and `/createbook --recreate` does the work.
- **It does not repoint references wholesale.** It repoints the citations its own edit moved. A book replacing another book is a different job, at `createbook/SKILL.md § When the book supersedes one that already exists`.
- **It does not verify that a repointed tag now names the right paragraph.** `check-references.sh` verifies that a cited `[N-M]` resolves, and that it still names the prose it named at the baseline. Neither answers whether the paragraph supports the sentence citing it, and a tag moved by hand from one real paragraph to another real one satisfies both checks. That one is verified by reading.

## Notes

- **This skill depends on `/createbook`'s folder and reads `/makebook`'s.** The three travel together. `/createbook` and `/makebook` still reach for nothing here, so that pair remains liftable on its own; lifting this one means taking all three.
- A rule about writing a chapter belongs in `createbook/reference/chapter-prose.md`. A rule about the book around the chapter belongs in `createbook/SKILL.md`. What belongs here is only what is true of changing a book that already exists.
- `NOTES.md` records which of the numbers above were measured, when, and against what.
