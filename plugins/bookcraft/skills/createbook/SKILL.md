---
name: createbook
description: Write a whole book from a one-line description of what the book should be. Plans a chapter outline, then narrates every chapter into its own markdown file, named so that a plain filename sort is the reading order. The finished folder is ready for /makebook. Use when asked to "write a book on X", "create a book about X", or to turn a subject into a multi-chapter set of narrations.
argument-hint: <what the book should be> [output-folder]
---

# /createbook

Create a book about: $ARGUMENTS

A book here is a folder of markdown files, one file per chapter, named so that sorting the filenames gives the reading order. Each chapter is written against `reference/chapter-prose.md` and the file for the book's profile, `reference/guide.md` or `reference/narration.md`, all in this skill's own folder, so a chapter reads as explanatory prose rather than a set of notes. The finished folder is the input `/makebook` expects.

**The prose specification lives here, in full, in three files.** `reference/chapter-prose.md` holds the rules every chapter follows, and `reference/guide.md` and `reference/narration.md` hold each profile's own. Together they are the authority on shape, voice, budgets and the before-sending checks, and no rule about the prose comes from outside this folder. It was forked from the `/ne` skill and has since departed from it, so `/ne` is history rather than a dependency and the two are free to diverge. What still comes from outside is the pair of format constraints `/makebook` imposes on any chapter it binds, below. `NOTES.md` records what the fork changed and which of the numbers were ever measured. Copying `createbook/` and `makebook/` into another repo is enough to write and bind a book there.

## Arguments

| Argument | Meaning |
|---|---|
| First (required) | A description of the book: subject, and where useful the reader and the angle. "A practical guide to Docker for first-year CS students." Name no reader and the skill asks for one; see § 1. |
| Second (optional) | Output folder. Defaults to `books/<book-slug>/` at the repo root. |
| `--source <path>` (repeatable) | A resource the book is written against: a repo file, a folder, a PDF. See § The sources are an argument. |
| `--minutes <N>` (optional) | How long the reader has. Sizes the book. See § Sizing the book. |
| `--no-tags` (optional) | Write the book without paragraph tags. See § Paragraph tags; tagging is otherwise on. |

With no first argument, ask what the book should be about and stop.

## The sources are an argument

**A book here is a guide to a set of resources first, and to its subject second.** The resources are the authority; what the model knows fills what they leave out; the reader can tell which is which. That is what `reference/chapter-prose.md § The sources come first` asks of the prose and what steps 2 and 5 below build the machinery for.

**Ask for the sources when none are given.** A book written with no resources at all is entirely filled in, which is a legitimate book and a different one, so it is the operator's call rather than a default to slide into. Say what you are asking and why: without sources there is nothing to check a claim against, and every chapter's header will read `Fills in: everything`.

**Never store a URL.** Online material is read at drafting time and then referenced by the terms a reader would search for, in the ledger and in the chapter's concept list. A link rots between the writing and the reading, and a snapshot is a second copy that goes stale silently. Anything web-derived is filled-in tier by construction: it was true when it was read, nothing can recheck it later, and the mark says `fill`.

**What can actually be verified afterwards is a repo file or a PDF**, because `check-references.sh` and a later `/updatebook` can open those again. The ledger in step 2 records which sources are re-openable and which are not, so nobody later mistakes a remembered web page for a citation.

## The two constraints everything else follows from

Both were measured against `${CLAUDE_PLUGIN_ROOT}/skills/makebook/scripts/build-book.py`, not assumed.

**Chapter numbers must be zero-padded.** `/makebook` collects chapters with `sorted(src.glob("*.md"))` (`build-book.py:load_chapters`), which is a plain lexicographic sort. Unpadded numbers misorder: `bk-1-a.md`, `bk-10-c.md`, `bk-2-b.md` is the sorted order Python actually returns. Pad to two digits, or to three if the book runs past 99 chapters.

**The H1 must be the file's first line.** `/makebook` reads the chapter title from `lines[0]` and only when it starts with `# ` (`build-book.py:load_chapters`). Anything else, a blank first line or YAML frontmatter included, drops the file to a prettified filename instead. `prettify` strips only a *leading* number (`build-book.py:prettify`), so `docker-basics-03-layers.md` would title the chapter "Docker basics 03 layers" on the contents page.

A chapter heads its parts with H2s (`reference/chapter-prose.md § Headings`), so the H1 naming the chapter is the file's first line and its only heading of that level.

## Chapter file format

```markdown
# Layers and the Build Cache

| | |
|---|---|
| **Act on this** | Order the Dockerfile so the lines that change least often come first. |
| **Draws on** | `Dockerfile`; `docs/build.md` § Caching; the `docker build` output measured 2026-09-10 |
| **Fills in** | How the cache key is computed, which the project's own docs do not describe. |

## In short

Carried in: **image** (ch. 1), the packaged filesystem a container starts from. **Dockerfile**
(ch. 2), the recipe whose lines are run in order to build one.

Week three covers the build cache: why one edit rebuilds in two seconds on one line of a
Dockerfile and in four minutes on another. Each line produces a layer, a stored snapshot of the
files that line changed. A rebuild reuses every layer above the edited line and redoes every
layer below it. The cache key, a fingerprint of a line and the files it reads, decides which
layers can be reused, and the chapter ends on where that fingerprint stops matching.

[3-1] Every image you have ever pulled arrived in pieces, and the pieces are the
reason a rebuild that changes one line finishes in two seconds...

<!-- src: Dockerfile; fill (the framing) -->

## What a layer holds

[3-2] ...

<!-- src: docs/build.md § Caching -->

[3-3] ...

<!-- src: fill -->

## Where the cache stops helping

[3-4] ...

<!-- src: docker build output, measured 2026-09-10 -->

## Suggested reading

Concepts this chapter stops short of. Each is a term to search, with the reason.

- **Content-addressable storage**: why two images that share a layer share it on disk.
```

This is a `guide` chapter, the profile a new book gets. First line is the H1, taken from the outline. One blank line. Then the header table (`reference/chapter-prose.md § The chapter header`): three rows under `guide`, and four under `narration`, which adds a `This chapter` row above `Act on this`. Then `## In short`, required under `guide` and present under `narration` where the book declares `overview`. It is the first H2 in the body and carries no tag and no mark (`reference/chapter-prose.md § In short`). Then the prose, whose two or three parts each carry an H2, and whose every paragraph opens with its tag and is followed by its provenance mark. The file ends with `## Suggested reading` and its list of concepts. A chapter may also carry a list, table, fenced code block, bolded phrase or inline code span where `reference/chapter-prose.md § Never` allows one, and a figure reference on a line of its own. A `guide` chapter may also carry an H3 inside a part and up to four labelled callouts (`reference/guide.md § Headings`, `reference/guide.md § Callouts`). Nothing else: no H3s under `narration`, no frontmatter, no trailing metadata block.

**A list, a table, a fenced block, a figure, a provenance mark and the `## In short` section each take no tag and advance no paragraph number**, the same way a heading does not. A tag is an address other files cite, so dropping a table into the middle of a finished chapter must not renumber everything after it. `check-book.sh` counts them this way, so the rule is enforced rather than remembered.

**The header and the concept list are the reader's second reading**, the one who is not following the argument tonight but wants a fact out of the chapter or wants to know what it left out. Neither is optional in a book that declares them, and neither replaces the prose: a header that could stand in for the chapter means the chapter became a briefing.

**`## In short` is a third reading**, and it points the other way: the reader who has not read this chapter at all, or who read the ones before it long ago. It is the one part of the file derived from the finished chapter rather than from a source. Under `guide` it is the chapter's only summary, so it opens by saying what the chapter covers and may use the chapter's own terms with a short definition (`reference/guide.md § In short`). Under `narration` it may use no term the chapter glosses (`reference/narration.md § In short`).

The two levels do different jobs and must not be confused. The H1 is the chapter title `/makebook` reads from `lines[0]`, and it is the only H1 in the file. The H2s are the part boundaries, chosen by the chapter agent against `reference/chapter-prose.md § Headings` and the profile file, and the outline does not fix them the way it fixes the terms and anchors.

## Paragraph tags

In a tagged book, which is the default, every paragraph opens with a tag naming it, then one space, then the prose:

```
[<chapter>-<paragraph>] The paragraph text begins here.
```

`[3-14]` is the fourteenth paragraph of chapter 3. The point is address: a book is long, "the bit about the cache key" is not a location, and a tag lets a person or a model say exactly which paragraph is under discussion. It is the same reason a verse gets a number.

- **The chapter half is the chapter's own number,** the one in the filename. It makes the tag unique across the whole book, which is what lets a tag be cited without also naming a file.
- **The paragraph half counts 1, 2, 3 through the chapter body** and restarts at 1 in the next chapter. Count every paragraph in order, including the opening one.
- **Headings take no tag.** The H1 and the H2s are not paragraphs. The counter ignores them and does not skip a number for them.
- **No leading zeros, and a plain ASCII hyphen.** The filename pads its chapter number so that a lexicographic sort orders the book; a tag gets typed into a conversation instead, so `[3-7]` rather than `[03-7]`. Two spellings would give one paragraph two names.
- **A chapter is tagged throughout or not at all,** and so is a book.
- **A revision may add a paragraph with a lettered tag**, `[3-14a]` after `[3-14]`, so no existing tag moves (`reference/chapter-prose.md § Paragraph tags`). This skill never writes one; `/updatebook` does, and every checker that reads a tag accepts the form.

**Tagging is on unless the operator passes `--no-tags`.** Turn it off for a book meant to read as an ordinary book, where an address at the head of every paragraph is noise the reader did not ask for. Keep it on for anything that will be discussed rather than only read: a reference, a course guide, a document someone will argue with a model about. Ask if the argument gives no signal, since it is cheap to ask now and costs a rewrite later.

**Whichever way it goes, record it in `book.json` as `"tags": true` or `"tags": false`.** That is what lets `check-book.sh` check the book strictly without being handed a flag, and what tells a later session which kind of book it is holding. A book that declares nothing is checked in the weakest mode available, and the checker says so on its summary rather than letting the weaker run read as a pass.

**The tag is not markdown, and it reaches the bound book.** `[3-14]` is a CommonMark shortcut reference link only when a matching `[3-14]: url` definition exists, and chapter prose has none, so it renders as literal text. Verified against `/makebook`'s own renderer (`build-book.py:markdown_renderer`) rather than a stand-in: the tag survives into the HTML, the PDF and the EPUB, and through `strip_markdown` as well. That is intended. A reader citing a paragraph from the PDF reads the same address the markdown carries.

**The reported prose figure measures prose, so `check-book.sh` strips the tags before counting.** Left in, `wc -w` scores each tag as a word and a chapter's reported length drifts up by its paragraph count.

## Filenames

```
<book-slug>-<NN>-<chapter-slug>.md
```

- `<book-slug>` comes from the book title, lowercased, non-alphanumerics collapsed to single hyphens. Hold it to about four words so filenames stay readable.
- `<NN>` is the zero-padded chapter number, starting at `01`.
- `<chapter-slug>` is the chapter title through the same slug rule.
- Dashes only. No spaces, no underscores, no capitals.

**The book slug may not contain a digit, and the checker enforces it.** The chapter number is found by taking the filename's first digit run, so `docker-101-guide-01-layers.md` offers two candidates and the read is ambiguous. The chapter slug may still hold digits (`...-07-normalization-from-1nf-to-bcnf.md`), because everything after the number is unambiguous. **An appendix is the exception, and is read before this rule is tried:** `<book-slug>-appendix-N-<slug>.md` numbers in its own sequence, so its N is an appendix number rather than a chapter one. Every tool that reads a number out of a filename branches on that first, which is what keeps appendix 1 from colliding with chapter 1.

This is a hard rule rather than a preference, and it is why a course book about DB300 is titled "Teaching DB300 Data Modeling" and slugged `teaching-data-modeling`. Shorten the slug; the title keeps the number.

Example, for "Docker for First-Year Students":

```
docker-first-year-01-what-a-container-actually-is.md
docker-first-year-02-images-and-layers.md
docker-first-year-03-the-build-cache.md
```

## The assertions file

A book rests on its sources and on everything it was told or settled along the way. `book.json` records the sources, and a later run can open them again. **`assertions.json`, beside it, records the rest**: every claim the book stands behind that a fresh run of this skill would not reproduce from the brief and the sources alone. That test decides what goes in, and it keeps the file small. A claim a source makes stays out, because the source is already its record. The model's own `fill` stays out until the operator adopts it.

The file is for the recreate. While a book is only patched, the prose holding those claims stays where it is and nothing is lost. A recreate writes every chapter fresh from the outline and the sources, and whatever lived only in the old prose goes with it: a premise that changed, a recommendation the operator acted on, a ruling with no source, an answer key that was derived and then corrected.

**Write it through the helper, never by hand.** The helper is the file's only writer, and its `check` is the only definition of the format. Where this section and `check` disagree, `check` is right.

```bash
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/assertions.sh <command> books/<book-slug> [options]
```

| Command | What it does |
|---|---|
| `init` | Creates the file with its `created` and `brief` blocks and no entries. Refuses a folder that already has one |
| `add` | Appends one entry under the next ID |
| `supersede <id>` | Appends the replacement and writes both links in one step |
| `retire <id>` | Takes an entry out of force, with the reason |
| `correct <id>` | Changes one answer in a `settled` entry's set, recording the date and the answer it replaced |
| `expect <id>...` | Turns `legacy` entries into `expected`. `--all` turns every one that holds, which is what a recreate does |
| `list` | The table to show the operator at a gate. Show this, never the raw JSON |
| `check` | Every rule of the format. Exits 0 when the file passes, 1 when it does not, 2 when there is nothing to check |

`assertions.sh <command> --help` lists the flags, and each flag writes the key of the same name, with a hyphen for the underscore. **Every write checks the whole file before and after**, so the helper cannot leave a file `check` rejects, and a flag left off comes back as the key it would have written. A file declaring a newer `format` than this bookcraft knows stops every command with a message to update bookcraft.

**The file never names a chapter number or a paragraph tag**, because a recreate renumbers both. An entry says what is true, never where the book says it.

| Block | Rule |
|---|---|
| `format` | `1` |
| `created` | `date` and `how`: `createbook`, or `backfill` with `from` (what it read), `candidates` and `confirmed`. Required even with no entries, because it is what tells a file that searched and found nothing from one written to get past a presence check |
| `brief` | `argument`, the `/createbook` argument verbatim. `reader`, the persona as one sentence. `reader_origin` and `profile_origin`, each `argument`, `operator` or `inferred`. `reader_inferred`, where part of a given persona was inferred, names that part. The profile's value stays in `book.json`. A backfill may write the argument as `null` and an origin as `unrecorded`, because a book written before this file existed never saved them, and a paraphrase recorded as the argument is what the field exists to prevent |
| `next_id` | The ID the next entry gets. Entries are retired, never deleted, so every ID below it is present and a mark citing one never comes to mean a different claim |
| `entries` | The entries, below |

| Kind | Holds | For example |
|---|---|---|
| `given` | A fact the operator supplied that no source file holds | A class roster, read from a portal behind sign-in |
| `ruling` | A decision on how to treat the sources or the scope: which source wins, a conflict left open, something included or excluded | The live site outranks the older PDF. No compensation figures |
| `premise` | A fact the book's plans are built on, sourced or not. Changing one is a rewrite (`updatebook § When to stop editing in place`), not a patch | The class size. The date of the first session |
| `adopted` | A recommendation the book made that the operator accepted or acted on | An exam window worked back from a testing center's lead time |
| `measured` | A live measurement: what was run, on what, and the result | A command's output on this machine |
| `settled` | A misreading a review corrected, or a derived answer that was checked. Kept so a fresh reading does not make the same mistake | A corrected answer key. A PDF whose printed page numbers are offset from its page index |

| Field | Rule |
|---|---|
| `id` | A whole number the helper allocates. Never reused, even after its entry is retired |
| `kind` | One of the six above |
| `statement` | The claim, in one sentence |
| `origin` | `by` (`operator`, `book` or `measurement`), an optional `how`, and `date`. A `given` entry is by the `operator`, and `measurement` is a `measured` entry's origin and no other kind's |
| `applies_to` | `prose` when sentences rest on the entry and their marks should cite it. `book` when it governs the whole book, such as an exclusion or a ruling on which source wins |
| `citation` | On a `prose` entry only. `expected`, or `legacy` when the prose resting on the entry was written before the file existed, so no mark cites it yet. Only a backfilled file carries `legacy` |
| `status` | `holds`, `superseded` with `superseded_by`, or `retired` with `retired_reason`. The replacement carries `supersedes`, the two links must agree, and an entry supersedes only an older one |
| `reaches`, `search` | Required on a `premise`: what it reaches, and phrases that find prose built on it, so a superseded premise can be swept for. A replacement needs phrases of its own, since the old ones find the old value |
| `measurement` | Required on a `measured` entry: `ran`, `on` and `result` |
| `acted_on` | Required on an `adopted` entry: what the operator did with the recommendation |
| `corrects`, `answers` | Optional on a `settled` entry. `corrects` holds the reading the entry replaces. `answers` is a set of `item` and `answer` pairs, no item twice. A corrected item also carries `corrected`, the date, and `was`, the answer it replaced, so the old mistake stays on record for a fresh derivation that makes it again |

**No other key is allowed anywhere in the file.** A misspelt key is the likeliest error, and `check` names the nearest key that exists.

## Procedure

### 1. Derive the book

From the argument, settle the title, the slug, the reader, and the angle. The reader is load-bearing: a chapter is written for one specific tired person (`reference/chapter-prose.md § The reader`), so "first-year CS students" and "senior engineers new to containers" produce different books from the same subject.

**When the argument names no reader, ask before going further.** Three questions: who they are, what they must be able to do when they finish, and what they can be assumed to know already. The last is the one that changes the book, since it sets what every chapter may leave unglossed. **Ask now, for the reason the other two underspecified inputs are asked about now** (§ Sizing the book, § Paragraph tags): it is one answer at this point and a rewrite of every chapter after. Where the operator declines to answer, infer a persona and mark it inferred at the gate (§ 3).

**This asks for the domain persona, not the reading posture.** The posture at `reference/chapter-prose.md § The reader` — attentive, short on working memory, reading once straight through and returning later for one fact — is fixed by design for every book this skill writes. It is not the operator's to change here and not a chapter agent's to renegotiate. What the argument supplies, and what the three questions above ask for, is who that person is and what they already know.

**Settle the profile here too.** Two rule sets exist, `reference/guide.md` and `reference/narration.md`, each read on top of `reference/chapter-prose.md`, and which one a book is written under is a book-level fact, not a chapter's choice:

| Profile | For | Reads like |
|---|---|---|
| `narration` | A book read once, straight through, in order. An explainer, a primer, a long-form argument. | Chapters chained noun to noun, headings redundant with the prose, every part exiting on a weakness. |
| `guide` (the default) | A book opened at one chapter the week it is needed, scanned under time pressure, returned to with a specific question. A preparation guide, a runbook, a handbook. | Chapters that stand alone, headings that carry the point, callouts marking what kind of sentence you are reading, numbered procedures, reference matter in appendices. |

**The test is whether the reader opens the book at chapter one.** Someone preparing to teach week nine opens chapter nine, on a Saturday, having read chapter eight a month ago. Everything the narration rules buy that reader costs them instead, which is the finding `NOTES.md § The guide profile` records.

**Decide it before the outline and never after the chapters exist.** It is one word in `book.json` at this point and a rewrite of every chapter afterwards, which is why it goes to the operator at the gate (§ 3) alongside the tag decision and for the same reason. Where the argument does not say and the subject does not obviously answer it, **write `guide`** and say at the gate that you did.

**`guide` is the default this skill writes, and `narration` is what the checker assumes when the key is absent.** Those are two different defaults and both are deliberate. A new book gets `"profile": "guide"` in `book.json` because a book built from a set of sources is nearly always opened at the chapter somebody needs, and the reader this skill is for is short on time rather than settling in. `check-book.sh` still reads an absent key as `narration`, because every book written before profiles existed has to keep passing untouched, and re-checking one under rules it was not written to would fail it on a `## In short` section nobody had asked for. So the default changes what gets **written**, never how an existing book is **read** (`NOTES.md § The guide profile`).

**Choose `narration` where the book really is read start to finish** — an explainer, a primer, a long-form argument whose chapters build one case. Say so at the gate the same way.

### Sizing the book

**Nothing caps a chapter's length** (`reference/chapter-prose.md § Length`), so sizing is an estimate made for the operator at step 3 and never a budget handed to a chapter agent. The only book-scale evidence is the reference book: eighteen chapters running 1,675 to 1,984 words of prose, averaging 1,895, measured with `check-book.sh` on 2026-09-13. At the 175 words a minute the spec assumes, that is about eleven minutes a chapter.

**Read that average as a floor rather than a prediction.** Those chapters were written under a 2,000-word ceiling that no longer exists, and fifteen of the eighteen ran past the 1,800-word aim it carried while the longest stopped 16 words short of the ceiling itself. That distribution says what chapters ran when something was stopping them, which is not the same as what they will run now (`NOTES.md § The ceiling removed, 2026-09-13`).

**Size from what the reader has, not from how broad the subject is.**

| The operator gave you | Do this |
|---|---|
| `--minutes N` | Chapters ≈ `N / 11`, rounded to the nearest whole. Ninety minutes is eight chapters, three hours is sixteen. |
| Sources but no minutes | Size to what the sources actually oblige the book to carry, from the ledger in step 2, and report the resulting read time at step 3 so the operator can push back. |
| Neither | Ask. Then default short: **six to ten chapters**. |

**The default is short, and this is a change from how this skill used to size a book.** It sized by breadth, which asks how much there is to say rather than how much the reader has time to hear, and a survey-shaped default is how a preparation guide becomes a three-hour read that nobody finishes. Breadth belongs in the concept list at the end of each chapter, where it costs the reader nothing.

**Time is a target and never a gate.** Do not cut a chapter the sources oblige the book to carry in order to hit a number, and do not pad to reach one. Where the two genuinely conflict, say so at step 3 and let the operator choose: the honest options are a longer book, a narrower subject, or more of the material pushed into the concept lists.

### The read-time estimate

**It counts every word on the page**, not only the prose: tables, lists, chapter headers, concept lists, the overview section and any slide notes. All of it is on the page and the reader goes through all of it.

| Where | What to divide by 175 |
|---|---|
| Step 3, before the chapters exist | Chapters × about 1,900 words of prose — **an estimator's constant, never a drafting target** — **× 1.8 for everything else on the page** |
| Step 9, from the finished book | `check-book.sh`'s `prose` and `structure` figures added together |

**The 1,900 is an input to this arithmetic and nothing else.** It is the reference book's measured average (§ Sizing the book), here to turn a chapter count into a read time before any chapter exists. It is not a length a chapter should come out at, not a line for the outline, and not a number to put in a chapter agent's prompt. `reference/chapter-prose.md § Length` sets no ceiling, no target and no floor, and `check-book.sh` reports both word figures without capping either. **A plan that says a chapter stays at about 1,900 words has turned this estimate into a budget**, which is what § Sizing the book forbids; the fix is to strike the number, not to hold the chapters to it.

**The 1.8 is one measurement on one book and it is the weakest number here.** The reference book ran 61,723 words across eighteen chapters with 34,281 of them prose, so the prose was 55.5% of the page and everything else was the rest (`NOTES.md § What the read-time estimate counts`). Report the estimate as a range where it matters, and prefer step 9's real figures to step 3's factor whenever both exist.

**This is a change, and the old estimate was understating.** It divided prose alone by 175, so a book whose header tables, session grids and concept lists came to nearly half its words was reported at a little over half its real reading time. Nothing about the book changed; the number was measuring the wrong thing.

### 2. Plan the outline, and write it down

Write `OUTLINE.md` in the book folder before any chapter exists.

**The source ledger comes first, before the chapter list.** It is the artifact everything else in this skill derives from, and writing it is how you find out whether the book you were asked for is the book the resources support.

| Column | Holds |
|---|---|
| **Source** | The file, document or search terms. A repo path with its section, a PDF with its page count, or the terms for something read online. |
| **Re-openable** | Yes for a repo file or a PDF, which `check-references.sh` and a later `/updatebook` can read again. No for anything web-derived, which is filled-in tier by construction. **Every `Yes` row becomes an entry in `book.json`'s `sources` map at step 4**, keyed by the shorthand the marks will use, which is what lets `check-provenance.sh` open it again. |
| **What the book owes it** | The specific claims, figures, tables or policies this source is the authority for. Not a summary of the source: a list of what the book takes from it. |
| **Paid by** | The chapters that carry them, filled in once the chapter list exists. |

Then, below it, two things the ledger produces:

- **What the sources do not cover.** The gaps, named as concepts. These become the chapters' concept lists (`reference/chapter-prose.md § Suggested reading`), so writing them here is what stops twenty chapters each inventing their own edge.
- **What the book fills in, and where.** The stretches the model's own knowledge supplies. A chapter that is mostly filled in is recorded here as such rather than discovered at drafting.

**Under `guide`, a teaching chapter has a shape worth offering.** `reference/guide.md § A shape for a teaching chapter` sets out four sections: at a glance, the concepts in teaching order, the lesson script, and grading, with any key in an appendix. **Offer it and never enforce it.** It fits a chapter that prepares someone to run a session and fits nothing else, and a chapter that fills every heading with a sentence each has produced furniture. Where a chapter's job is different, let its shape be different.

**Read every source before writing the ledger.** A ledger built from filenames is a guess, and every chapter brief below inherits it. This is the step that costs real time and the one that pays for itself: a claim the sources do not actually support is cheapest to catch here, before twenty chapters rest on it.

For every chapter the outline then carries:

- **Number, title, and filename.**
- **The brief:** two or three sentences on what this chapter explains, specific enough that someone else could write it.
- **Draws on:** the ledger rows this chapter pays, which become the chapter header's Draws-on row.
- **Fills in:** what this chapter supplies that the sources do not, which becomes its Fills-in row.
- **Concept list:** the gaps this chapter ends on, taken from the ledger and checked against the term ledger so no item names something a later chapter teaches.
- **Scope** (`guide` only): where this chapter sits in the book or the course, such as the week, the session or the stage. The opening paragraph and the first sentence of `## In short` both name it, for a reader who opens the book at this chapter (`reference/guide.md § Opening`). A guide outline records no handoff nouns: its chapters do not chain.
- **Opens on** (`narration` only): the exact noun this chapter's first paragraph starts from. For chapter 1 this is the book's hook. For every later chapter it is the noun the previous chapter closed on. **Check it against the term ledger.** Where the noun is a technical term no earlier chapter's row glosses, record on this chapter's row that it glosses the noun on arrival, at no cost against its six (`reference/narration.md § What the reader arrives with, under narration`): the handoff grants the word and never the definition, and an outline that hands forward an unglossed term is how a chapter comes to open on a definite noun phrase the reader has never met. Measured on the reference book's own outline: of sixteen handoff nouns, one was glossed on an earlier row before being handed forward and six are technical terms glossed on nobody's row, the rest ordinary words bar one technical term covered by an adjacent gloss a chapter earlier. Those six are what the gate at § 3 counts, so count technical terms rather than nouns.
- **Closes on** (`narration` only): the noun this chapter hands forward, and the named weakness it exits on. Each part exits on a weakness rather than a success (`reference/narration.md § Every part does five things`); at book scale that weakness is what the next chapter answers.
- **New terms:** the terms this chapter is responsible for glossing, and the terms it may use freely because an earlier chapter already glossed them.
- **Anchors and numbers:** the checkable names, cases, and figures this chapter owns.
- **Shared content owned:** the sequence, grid or schedule this chapter owns for a scope other chapters touch, or the chapter that owns it when this one only points at it. Empty for most chapters.

Also record, once at the top: the book title, subtitle, reader, **where the reader came from**, **the profile**, and the running term ledger in chapter order. Provenance is recorded rather than remembered because § 3 has to state it and § 3 may run in a later session than this one: an outline that records the persona but not its origin leaves the gate reconstructing from memory the one thing it exists to check.

**Under `narration`, fixing the handoff nouns in the outline is what lets chapters be written in parallel.** Without it, chapter 7 cannot start until chapter 6 exists, because it has to open on chapter 6's closing noun. A `guide` chapter opens on its own scope, so it depends on no neighbour's wording.

The term and anchor ledgers exist because the budgets are per chapter and none of them pools: at most six new terms and at most two checkable anchors in a chapter (`reference/chapter-prose.md § Spend these deliberately` and `§ Every budget is per chapter`). Without a ledger every chapter re-glosses "container" and spends its anchors on the same example.

**Content spanning several chapters is assigned to exactly one owning chapter, and every other chapter points at it.** A sequence, grid or schedule covering a scope that more than one chapter touches is a third kind of shared content, and unlike the terms and anchors above it has no budget to exhaust: each chapter whose scope overlaps it can write the whole thing, and each one will. Name the owner on its outline row, and record on the others that they refer to it rather than restate it. Measured on the reference book: three week-4 chapters were each briefed to propose a four-evening teaching sequence for the same week, caught mid-draft at the cost of edits to three chapters plus a new section in the outline.

### 3. Confirm the outline with the operator

**Resolve the ledger before showing it.**

```bash
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-provenance.sh --ledger-only books/<book-slug>
```

It reads `OUTLINE.md` alone: every row marked re-openable names a file that is on disk, and every locator written into a row resolves against the source that row names. It needs no `book.json`, which step 4 has not written yet, and it reads no chapter, because none exists.

**Run it here rather than at step 7, because the ledger is the contract every chapter brief is derived from.** An error in a row is not one chapter's error. It is handed to every agent drawing on that row, at the same time, and each writes prose around it. Five reached the fan-out on one 21-chapter run: three page locators off by one, an anchor attributed to the wrong document, and a ledger row contradicting a prose note two lines below it. They were caught only because § 5 tells each agent to open its sources instead of writing from the brief, which turns the drafting agents into independent checks on the contract. That is luck rather than design, and it costs a chapter agent's whole context each time. This check costs about a second and does not grow with the chapter count.

**Fix what it reports before the gate, not after.** A locator corrected here is corrected once; the same locator corrected at step 7 is corrected in every chapter that copied it, and in `OUTLINE.md` and `book.json` besides.

**What it does not reach:** a row whose prose is wrong about a source it correctly names, and a row that contradicts a note elsewhere in `OUTLINE.md`. Both need a reader. Resolving the ledger narrows what the gate has to be read for; it does not replace reading it.

Then show the source ledger, the chapter list, the title, the reader, **the profile**, the output folder, whether the book is tagged, and the estimated read time (§ The read-time estimate). Say that the estimate is a floor, for the reason at § Sizing the book. Stop and wait.

**Lead with the ledger, not the chapter list.** The chapter list is what the operator expects to review and the ledger is what they can actually correct: a source you were not given, a source you read wrongly, a gap you propose to fill that they would rather you left open. A wrong chapter list costs twenty chapters, and a wrong ledger costs the same twenty plus every claim inside them.

**State the reader as a sentence, and say where it came from.** "Written for a second-year apprentice electrician who has wired domestic circuits but never opened a three-phase board" invites the correction. `Reader: apprentice electricians` does not, because a label reads as something already settled. In the same breath, say where that persona came from: the argument, the operator's answer to the ask at § 1, or your own inference from the subject and the sources. **A persona can be part given and part inferred**, and that case is the quiet one: an argument naming "apprentice electricians" and nothing else fires no ask, because a reader was named, while what they can be assumed to know is still yours to guess. Say which part you supplied rather than calling the whole persona given. All of this is on the outline's top line (§ 2), so read it from there rather than from memory.

**An inferred persona is what this line is for.** Checking that a persona exists fires only when the field is empty, and from a subject plus a folder of sources a plausible reader is almost always available, so the failure that costs a book is a confident wrong persona rather than a missing one. By the time chapters exist it is at the top of the outline (§ 2) and in every chapter agent's prompt (§ 5), reading exactly like a persona the operator supplied. A wrong reader is not a wrong chapter. It is every chapter pitched at the wrong person, which is the one defect a rewrite cannot localise.

**State the profile and what it changes.** One line: `narration` or `guide`, and the one-sentence version of why this book is one rather than the other. Say where it came from on the same terms as the reader — the argument, the operator's answer, or your own read of the subject — because an inferred profile has the same failure mode an inferred persona does. **This is the cheapest correction in the whole run and the most expensive one to miss**: one word here, every chapter afterwards.

**Under `guide`, a book past the six-to-ten default needs the shortest path named.** Where the outline runs longer, ask the operator which chapters a reader short of time can skip, and record the answer; it lands in `about-this-book.md § How to read it` at step 6. A guide nobody finishes is the failure § Sizing the book names, and for this reader the fix is a path through the book rather than a shorter book.

**Say plainly what the book will fill in**, and flag any chapter that will be mostly filled in. That is a decision the operator may want to make differently, by supplying another source or by cutting the chapter.

**Under `narration`, say how many handoff nouns are technical terms glossed by no row.** Each one is an opening paragraph the reader will reread, and this gate is the last place the fix is free: after the chapters exist it is a rewrite of every opening paragraph that inherited the hole. Read the sixteen or twenty rows against the ledger by hand rather than reaching for a script, which is how the substring match that called "the query plan" glossed by "query planner" got caught.

This is the one blocking gate in the skill, and it earns its place: the outline is cheap and the chapters are not, so a wrong outline caught here costs one message instead of twenty chapters. The tag decision belongs at this gate for the same reason. It is one word to change here and a rewrite of every chapter afterwards, since a book is tagged throughout or not at all.

### 4. Write `book.json`

**This is the whole file for an ordinary book.** Write it as it stands, with the `sources` map filled from the step 2 ledger:

```json
{
  "subtitle": "...",
  "byline": "Claude Opus 5",
  "profile": "guide",
  "description": ["One or two paragraphs for the cover."],
  "tags": true,
  "provenance": true,
  "suggested_reading": true,
  "overview": true,
  "glossary": true,
  "edition": "reading",
  "exclude": ["OUTLINE.md"],
  "unsourced": ["measured"],
  "sources": {
    "syllabus": {"path": "../sources/data-modeling-syllabus.pdf", "display": "the syllabus"},
    "Week 5 deck": "../sources/week-5-deck.pptx",
    "[L1] to [L5]": ["...Week 1 Lab...", "...Week 2 Lab..."]
  }
}
```

**The byline is the one field not written as it stands.** Write the name of the model writing the chapters, as that model knows itself — `Claude Opus 5`, `Claude Sonnet 5` — rather than a person's name, because that is who wrote them. The template carries a name instead of a placeholder because a placeholder is a thing that gets copied onto a cover; read the value as the shape rather than as the string, and write your own. It prints under the title on the PDF cover and becomes the EPUB's author field, so it is metadata as well as cover text.

**Where the operator names a byline, use theirs without asking.** The field is theirs: a book they commissioned, own and may publish is one whose cover they get to sign, and an EPUB bound for a store wants the name on the account rather than the name of the model. The model name is the default for the case where nobody said, not a rule about what a byline may be.

**A later revision does not change it.** `/updatebook` reads `book.json` and never writes it, so a book revised by a different model keeps the byline of the one that wrote it. That is the honest reading of a byline and not an oversight: what the revision changes belongs in `about-this-book.md`, which is prose and can say both.

**A key outside the template is never a default.** Add one only when the sentence beside it is true of this book; JSON carries no comments, so the split is here rather than in the file.

| Key | Add it when | Leaving it out means |
|---|---|---|
| `"slide_figures": "diagrams/slides"` | The book carries lesson-script slide art in that folder | No slides; every image is a numbered figure |

**`"edition": "reading"` is in the template for a `guide` book, and left out of a `narration` one.** It is `/makebook`'s key (`makebook/SKILL.md § The reading edition`), and it only changes what a bind with no flag produces. A guide is handed to readers, and the paragraph tags and source rows are the operator's, so a guide binds the reading edition by default and the operator's copy is the one that takes a flag. A narration book leaves the key out and binds the default edition, with `--reading-edition` for the times you want the other. Where a guide's operator wants the tagged copy as the default, they drop the key.

**`profile` selects the rule set**: `reference/guide.md` or `reference/narration.md`, each on top of `reference/chapter-prose.md`. `"guide"` is what the template carries and what a new book gets unless the operator chose otherwise at step 3 (§ 1). `"narration"` is the other value and there is no third. **Write the key explicitly either way rather than relying on its absence**: an absent key reads as `narration` to `check-book.sh`, so a guide book that omits it is checked against the wrong rule set and passes, which is the silent failure the explicit key exists to prevent. The checker prints the profile first on its summary line so a run against the wrong set is visible.

**A `guide` book must also declare `overview`**, since `## In short` is required under that profile rather than opt-in. `check-book.sh` refuses a book that sets `"profile": "guide"` alongside `"overview": false`, because the two declarations contradict each other and guessing which the operator meant is not the checker's call.

**`sources` is what makes the marks checkable in the other direction.** Each key is the shorthand the marks use, spelled exactly as the book spells it; each value is a path relative to the book folder, a list of them where one shorthand names several files, or an object carrying a reader-facing name beside the path.

**The object form exists because a mark key is not a thing to show a reader.** A key is chosen for the tooling and is often a repo path: `check-provenance.sh` opens it, and the prose was then citing the same string, so a reader of the bound book was shown `CLAUDE.md § Teaching Calendar` in monospace and had nothing to do with it. Where a source carries a `display` name, **the prose cites the display name and the mark cites the key**:

```json
"sources": {
  "CLAUDE.md § Teaching Calendar": {
    "path": "../../../CLAUDE.md",
    "display": "the course calendar"
  }
}
```

The bare string form stays valid and unchanged, for every source whose key already reads as something a reader could be told. Add a `display` only where the key does not. `check-book.sh` flags a source key that looks like a repo path appearing in a chapter's prose, which is the case the display name exists to fix. Write it from the step 2 ledger, in the same pass that fixes the citation spellings, because the ledger already holds every re-openable source and its path. Without it a mark can be checked for grammar and nothing else, and `check-provenance.sh` says so rather than printing OK. `unsourced` extends the built-in `fill` with any other word the book uses for a component that names no external source.

**`provenance` and `suggested_reading` declare the resource-first format**: every unit carries a `<!-- src: ... -->` mark, and every chapter ends with its concept list. Both default to absent, which means a book written before the format existed still passes; `check-book.sh` holds a book to each only where it declares it, with no inference and no flag. Set both `true` for any book written against sources, which is every book this skill now writes by default.

**`overview` declares that every chapter carries `## In short`** (`reference/chapter-prose.md § In short`), directly under the header table and before the opening paragraph. It defaults to absent on the same terms and for the same reason: a book written before the section existed still passes untouched, and no flag infers it. **What makes the heading a section is where it sits**, first H2 with the header table immediately before it, so a book that uses those two words for a part heading later on is counted and swept exactly as it was. The declaration is what makes the section *checked*: the position rules, the ceiling and the glossary cross-check all need it, and without `jq` to read it they simply do not run. Set it `true` for every new book. Where the book also declares `glossary`, the checker additionally resolves each carried-in term against the glossary and requires it to point at an earlier chapter, so the two keys together buy more than either does alone.

**`glossary` declares that this book carries one**, which makes a missing `glossary.md` an error at bind time rather than a book that ships without the thing it promised. Drop the key for a book that wants none. See step 6.

**`tags` records whether this book carries paragraph tags**, `true` unless `--no-tags` was given. `/makebook` reads every key it wants through `cfg.get` and ignores the rest (`build-book.py:load_config`), so the key costs the bind nothing; `check-book.sh` reads it to decide what to check.

**`exclude` is not optional here.** `/makebook` turns every `*.md` in the folder into a chapter unless it is skipped (`build-book.py:load_chapters`), so `OUTLINE.md` would otherwise be bound into the book as a chapter. Any other non-chapter markdown added to the folder goes in the same list.

### 5. Draft the chapters

Run each chapter as its own subagent, in batches of about four, so the prose is written in parallel and stays out of this session's context. Each agent writes its own file with the Write tool, writes anything it found wrong with the outline to a findings file of its own, and reports only those two paths and the word count.

**Do not downgrade chapter agents to a cheaper model.** Chapter prose makes factual claims a reader will take as taught, and work whose output a reader takes as taught stays on the session's own tier; its quality is not cheaply verifiable from the outside either. The structural checks in step 7 catch format, never accuracy.

Each agent's prompt carries, in full:

1. **Read `${CLAUDE_PLUGIN_ROOT}/skills/createbook/reference/chapter-prose.md`, then the book's profile file, and follow every rule in both** for the body prose. The profile file is `reference/guide.md` for a `guide` book and `reference/narration.md` for a `narration` one. **Name the profile in the prompt and give the agent those two paths and no third.** The profile file wins where it names a rule in the core, and everything else in the core applies in full. Never hand a guide chapter `narration.md`, or the reverse: the two disagree on purpose, and an agent given both follows whichever it read at more length. Together the two files already cover everything a chapter does differently from a standalone piece.
2. The book title, the reader, and this chapter's brief. **Say that this reader is the book's domain persona and that it does not modify the reading posture**, which `chapter-prose.md § The reader` fixes and item 1 has just told the agent to follow. The two carry the same name and the agent meets both in one prompt, so an agent left to reconcile them will read the persona as licence to adjust the posture. Pass the persona's provenance too where it was inferred, since a chapter written against a guessed reader is the one this book is most likely to revise.
3. **Under `narration`, the noun to open on and the noun to close on**, from the outline. **Under `guide`, the chapter's scope** from the outline, and the titles of the chapters before and after it, so the opening can orient a reader who starts here. Never give a guide chapter a handoff noun: its opening orients the reader instead (`reference/guide.md § Opening`).
4. The terms already glossed by earlier chapters, to be used without re-glossing and without counting against this chapter's six.
5. The anchors and numbers already spent elsewhere, not to be reused.
6. The exact output path, and the file format above: `# Title` as the first line, the header table, the prose with its per-part H2s, and the concept list last. **Where the book declares `overview`, say that `## In short` is added at step 6 and that this agent does not write it.** The section is read off the finished chapter and takes its words from a glossary that does not exist yet, so an agent that writes it here invents the definitions the section exists to avoid inventing.
7. **When the book is tagged, this chapter's number and the instruction to tag every paragraph.** The rule itself is at `reference/chapter-prose.md § Paragraph tags`, but the chapter number is not in that file and the agent cannot infer it, so the prompt has to supply it. Under `--no-tags`, say the book carries no tags rather than leaving the item out, since the spec describes tagging as the normal case.
8. **The sources themselves, and the ledger rows this chapter pays.** Give paths the agent can open rather than summaries: the agent has to read the source to write a claim against it, and a summary passed down the chain is a claim nobody can check. Say which sources are re-openable and which were read online, since the second kind is filled-in tier however confident it feels.
9. **What this chapter fills in**, from the outline, and that saying so plainly is the requirement rather than a caveat to minimise.
10. **The concept list this chapter ends on**, from the ledger, with the instruction that it names concepts and search terms and never a URL.
11. **The findings path, `<book>/outline-findings/<chapter file stem>.md`, and the instruction to write anything wrong with the outline there rather than in the reply.** Say that nothing to report means no file. An agent told to report a problem and given nowhere to put it will put it in the return, which is where it is lost.

**Findings go to a file, never into the return message.** An agent that opens its sources will sometimes find the outline wrong: a ledger row that contradicts the source, a page locator off by one, an anchor attributed to the wrong document. Those are worth more than the chapter that found them, because one bad ledger row is paid by every chapter drawing on it. They must not travel in the reply. A return carrying prose can exceed the harness's return cap, and a truncated return arrives empty rather than short, so the findings are lost with nothing saying they ever existed. Three agents' findings went that way on the reference book, had to be chased afterwards, and some were never recovered. Give each agent a path of its own, `<book>/outline-findings/<chapter file stem>.md`, and say that an agent with nothing to report writes no file. One path per agent rather than one shared file, because the batch drafts in parallel and four agents appending to one file interleave. The folder is invisible to everything that reads the book: `check-book.sh`, `check-provenance.sh` and `/makebook` each glob the book folder one level deep, which is why `claim-checks/` can already sit there.

**Read that folder when the batches finish, before step 6. An absent folder is the all-clear**, since an agent with nothing to report writes no file. Most of what would otherwise land there is already gone, because § 3 resolved the ledger before the gate; what reaches this folder is what only a reader could have found. A ledger row that is wrong is wrong in `OUTLINE.md` and in `book.json` too, so fixing it only in the chapter that noticed leaves it in place for every later run and for `/updatebook`.

**Every claim in a chapter is written from the source, not from the prompt.** The agent opens what it was given. A brief is a plan for a chapter, and a chapter that rests on the brief rather than on the material is a chapter of confident paraphrase with nothing behind it. This is why chapter agents get paths.

**The chapter agent writes a plan before any prose (`reference/chapter-prose.md § The plan`), and the outline has already made part of it.** The spec says so itself, and the prompt should say it again with the specifics, or a chapter agent will re-derive decisions the outline fixed and quietly break the parallel drafting that depends on them. The outline row supplies the chapter's term budget and its anchors, and under `narration` its opening and closing nouns; the agent must take those as given rather than choosing its own. What the agent still owes is the rest of the plan at chapter scale: the one claim this chapter lands, the concepts inside it in dependency order, the cuts, and where the wrong model sits if the chapter has one. A chapter whose claim cannot be stated in one sentence is a chapter the outline split wrongly, and that is worth reporting back rather than writing around.

**No chapter is ever briefed to read another chapter of this book.** What an agent is given about a sibling is that sibling's outline row, never its file. Batches draft in parallel, so a prompt saying "read the finished chapter 4 so you do not repeat it" races the agent writing chapter 4, and when the two sit in one batch the file is usually still absent when the reader looks. The agent then finds nothing, writes as though the chapter did not exist, and produces exactly the repetition the instruction was meant to prevent, with nothing in the run saying it happened. Everything a chapter needs to know about its neighbours is already in the prompt and was fixed at step 2: the handoff nouns or the neighbouring titles at item 3, the terms already glossed at item 4, and the anchors and numbers already spent at item 5. Those cost nothing to read and do not move while the batch runs.

**Nothing in the prompt needs to describe how a chapter differs from a standalone piece.** Those differences used to travel as a delta table against `/ne`; they are now written into the spec itself, at `chapter-prose.md § What the reader arrives with` for what the reader arrives with, `guide.md § Opening` and `narration.md § Open` for the opening, `guide.md § Close` and `narration.md § Close` for the close, `chapter-prose.md § Glosses` and `chapter-prose.md § Spend these deliberately` for glossing only the assigned terms, and `chapter-prose.md § Paragraph tags` for the tags. A prompt that restates them risks stating them differently, which is the failure the fork was meant to end.

### 6. Write the front matter and the glossary

**`about-this-book.md` in the book folder**, for every book written against sources. It is what the header rows are at book scale, and it is the one place a reader learns what they are holding before they start:

- **What this book is for**, and what someone who finishes it can do. Two or three sentences.
- **What it was built from**, the source ledger's first column in prose, each entry specific enough to open.
- **What it fills in**, and where the sources were thin enough that a chapter is mostly the model's own knowledge.
- **What it does not cover**, the honest edge, pointing at the per-chapter concept lists rather than repeating them.
- **How to read it**, when the book has a shorter path through it worth naming.

`/makebook` binds it after the contents, and both tools skip it by name the way they skip the glossary, so it needs no `exclude` entry. It carries no paragraph tags, no provenance marks and no concept list: it is not a chapter and none of the chapter rules reach it.

**Write it from the ledger after the chapters exist**, for the reason the header is written last. Written first it is a plan, and the gap between the plan and the book is exactly what a reader trusts this page not to have.

Then the glossary, only for a book that carries one. Skip to step 7 otherwise, and leave `glossary` out of `book.json`.

**The term list is the outline's term ledger, not a fresh reading of the chapters.** The ledger already names every term the book glosses and which chapter owns it, fixed before a word was drafted so chapters could be written in parallel. Re-deriving it by reading twenty finished chapters produces a second list that disagrees with the first, and then two documents claim to say what the book defines.

**Each definition restates the chapter's own gloss.** `reference/chapter-prose.md § Glosses` requires every assigned term to be glossed inside the sentence that first uses it, so a definition already exists at a known place, and in a tagged book the paragraph tag names that place exactly. Read that sentence and write the entry from it. A glossary entry that says something the chapter does not is worse than no entry, because the reader who checks will not know which one the book meant.

`glossary.md` in the book folder, one entry per paragraph:

```markdown
# Glossary

**access method** (ch. 4) The strategy the query planner picks to reach the rows
a query asks for, such as a full scan or an index lookup.

**anomaly** (ch. 10) An update, insertion or deletion that leaves a table saying
two different things at once.
```

- **A definition is a sentence or two, and it is the reminder rather than the teaching.** The chapter does the teaching; this entry is what a reader needs when the term surfaces four chapters later and the name alone has gone.
- **The chapter number is the chapter that glosses the term**, which the ledger gives directly. `/makebook` prints it in the PDF and links it in the EPUB, and a number the book does not have stops the build.
- **Sorting does not matter here.** `/makebook` sorts case-insensitively and groups under letter dividers. Write the file in ledger order if that is easier to check against.

The file is back matter, never a chapter. Both the checker and `/makebook` skip it by name, so it needs no `exclude` entry.

Then `## In short` in every chapter, for a book declaring `overview`. It comes last in this step because it draws on everything the step has just produced.

**It is added to the finished chapters rather than drafted with them.** A chapter agent cannot write it: the summary has to be read off the finished chapter, and the carried-in line takes its words from the glossary, which did not exist until a moment ago. That is why step 5's prompt tells the agent to leave it out, and why this is not a rule the chapter agents could have been trusted with in parallel.

**Work one chapter at a time, in chapter order**, with the finished file and that chapter's row in the term ledger in front of you. The ledger row gives the candidate carried-in terms, the glossary gives their words, and the chapter itself gives the summary. The carried-in line is specified at `reference/chapter-prose.md § In short`: the `Carried in: ` prefix, the cap of three and the `(ch. N)` citation. The summary follows the profile file. **Under `guide`** (`reference/guide.md § In short`), its first sentence says what the chapter covers and where it sits, it may use the chapter's terms with a short definition, it stays near 120 words, and it reuses no sentence of the chapter. **Under `narration`** (`reference/narration.md § In short`), the walk may use no term the chapter glosses.

**Chapter 1 takes the summary and no carried-in line,** having nothing behind it to carry.

**Where the book carries no glossary,** the carried-in words come from the chapter's own gloss sentence, which is what the glossary entry would have been written from in any case. The prefix, the cap and the summary's rules all still apply; only the cross-check in step 7 goes quiet, because it has nothing to resolve against.

### 7. Check the folder

```bash
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-book.sh books/<book-slug>
```

It checks what is mechanically checkable: filenames match the pattern, chapter numbers are zero-padded and contiguous from 01, the sorted filename order is the chapter order, every file's first line is an H1 and the body holds no second one, the body's part headings are H2s and number two or three, no body carries the markdown the spec still bans (block quotes), no code fence is left unclosed, no HTML comment is left open, no file carries an em dash, and no two chapters share a title. It does not count or ration the lists, tables, fenced blocks and bold that `reference/chapter-prose.md § Never` allows, because whether one earns its place is a judgment about the prose around it. On the tags it checks that every paragraph in a tagged chapter carries one, that the chapter half is this chapter, that the paragraph half counts from 1 with no gap or repeat, and that neither number is padded. On a `glossary.md` it checks that every entry reads `**term** (ch. N) definition`, that no term is defined twice, and that no entry points at a chapter the book does not have.

Where `book.json` declares `provenance`, it checks that every paragraph, table, list and fenced block is followed by a `<!-- src: ... -->` line, and that every mark is one line and matches that grammar. Where it declares `suggested_reading`, it checks that each chapter ends with `## Suggested reading`, that nothing follows it, and that it carries items. Where it declares `overview`, it checks that each chapter carries `## In short`, that it is the first H2 in the body with the header table immediately before it, and that a carried-in line names at most three terms. Where the book declares `glossary` as well, it additionally resolves each carried-in term against the glossary and requires the chapter it points at to be earlier than this one, which catches a reminder pointing forward and one naming a term the book never glossed. All three are exempt from the paragraph-tag count and from the prose figure, and so is the chapter header. It exits non-zero on any failure.

**Under `guide`, a paragraph over 90 words fails the book**, named by its tag. The spec has always called 90 a hard stop, and a paragraph is counted exactly, so the checker holds a guide to it. Under `narration` the same paragraph is reported rather than failed, so every narration book written before the check existed keeps passing.

**Reports are lines to read, and none of them fails a run.** Each starts `REPORT`, and a count of them follows the summary line:

| Report | Profile | What it points at |
|---|---|---|
| A paragraph over 90 words | `narration` | The stop above, which a guide fails on |
| A sentence over 45 words | both | `reference/chapter-prose.md § Voice`. A sentence boundary is a script's guess, so this never fails |
| A callout over four sentences | `guide` | `reference/guide.md § Callouts`: one idea per callout |
| A `## In short` summary over 120 words | `guide` | `reference/guide.md § In short` |
| A run of eight or more words shared by `## In short` and the chapter | `guide` | The summary reusing the chapter's sentences |
| A four-word phrase recurring in three or more chapters | both | A passage written from a template, most often the wrong model's |
| A repo-path source key with no display name in the chapter header | both | A path the bound book would print, since `/makebook` can only swap a key that has a name |

**Read every report before binding.** Most name something to fix. The recurring-phrase report also finds a book's own vocabulary, which is meant to recur, and only a reader can tell a term from a tic.

**Prose, structure and the overview are reported separately and none is capped.** The summary line carries all three, and a second line carries the mean chapter and the longest one by name. The overview figure is the total words in the `## In short` sections, kept apart from the prose because the section is a summary of the chapter rather than part of its argument, and folding it in would make every chapter read as longer than it argues. A table is consulted rather than read, so folding it into a figure meant to measure sentences would push chapters into narrating tables the reader wanted whole. The numbers are there for a human to notice a book turning into a briefing, or one chapter the outline drew too wide, and neither of those is a judgment a threshold could make.

**The glossary checks duplicate `/makebook`'s parser deliberately.** That parser is the authority and rejects the same faults at bind time, but bind time is too late: this step runs long before anyone binds, and step 9 says not to bind unless asked, so a glossary broken here would otherwise sit undetected until the PDF was wanted. If the two ever disagree, `/makebook` is right.

**No flag is needed when `book.json` declares `tags`,** which is why step 4 writes it. The checker reads the declaration and holds the book to it: `true` fails a book with no tags, `false` fails a book that has them. `--require-tags` and `--no-tags` say the same two things on the command line and override the file, for a folder whose `book.json` is missing or not yet written.

**A book that declares nothing is checked in the weakest mode**, inferring the expectation from the chapters, which catches the chapter that forgot its tags while its neighbours have them but reads a book where *every* chapter forgot as an untagged book. The checker prints a note saying so, because a run that quietly got weaker reads exactly like a run that passed. `jq` is what reads the declaration, so a machine without it also falls back to inference and to that note.

The heading count is the one place the shape rule is mechanically checkable: two or three parts and never one or four (`reference/chapter-prose.md § Shape`) is invisible to a script until the parts carry headings. The two H2s that are not parts, `## In short` at the top and `## Suggested reading` at the bottom, come out of the count before the rule runs. A body with zero H2s also passes, because chapters written before parts were headed at all are still correct prose and still bind.

**Read the `content-checked` count, not just the exit code.** The summary line reports how many chapters reached the content checks against how many were found, and the run fails when those differ, naming each file it never opened and why. A file whose filename is rejected gets no content check at all, so a book with bad filenames can report filename errors and nothing else. That count is the difference between "this book passed" and "this book was examined". The `tagged` figure on the same line reads `<tagged>/<checked> (<mode>)`, where the mode is `required`, `forbidden` or `inferred`. A tagged book should read `n/n (required)` and an untagged one `0/n (forbidden)`; anything ending `(inferred)` means the book never declared itself.

This guard exists because it was needed. An earlier version read the chapter number with a `sed` that returns its input unchanged on no-match, so a digit in the book slug produced a non-numeric value, the arithmetic that followed aborted the loop, and the script printed `OK structure is sound` and exited 0 having examined nothing. Measured at the time: three chapters each missing an H1 and carrying a banned H3 passed silently. A checker that can report OK without running is worse than no checker, because it is trusted.

A clean run means the folder will bind correctly. It says nothing about whether the book is any good.

The checker needs only bash, coreutils and awk. It reads `book.json`'s `exclude` list through `jq` when `jq` is present, and falls back to skipping `OUTLINE.md` alone when it is not. **A `jq` that is on PATH but will not run stops the check outright**, rather than falling back: every declaration would read as absent and the book would be held to the weakest mode while `book.json` plainly declared otherwise, which is indistinguishable on the summary line from a book that declared nothing.

**If this book replaces one that already existed**, run `check-references.sh` as well and read § When the book supersedes one that already exists. Neither this checker nor the seam read looks outside the book folder, so a stale citation in an answer key or a syllabus survives a clean run here.

**Then check the marks against the sources they name**, which `check-book.sh` cannot do, because it reads nothing outside the book folder:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-provenance.sh books/<book-slug>
```

It resolves every component of every mark through `book.json`'s `sources` map and asserts three things in ascending order of worth: the named source is declared and on disk, the locator resolves (`p. 4` inside the PDF's page count, `slide 9` inside the deck's, `§ Join Algorithms` a heading the file carries, `Q19` an item the quiz defines, `[16-4]` a paragraph this book defines), and every quotation of 25 characters or more appears in one of the sources its unit's mark names. The first two fail a run; the third reports and counts.

**The quotation check reports REVIEW rather than failing, and that was measured.** Against the reference book a hard failure fired ten times and was wrong ten times: four quotations differed from the source in punctuation alone, because this book bans the em dash its sources use; three were the book quoting a reader's imagined sentence; one quoted the book's own recommendation; one was a substitution the mark itself declares in a parenthetical no script can read. None is separable from a real misquotation by machine, so it prints them and leaves the judgment to a person.

**Read the last three census lines, not the exit code.** They report how many components were `fill`, how many locators went unparsed, and how many quotations could not be searched at all. A source with no text layer is the case that matters: the reference book's syllabus, Canvas setup guide and CSC220 syllabus are images of text, so 28 of its quotations are unverifiable by any tool and the run names the number rather than passing them. An absence found in a document nothing can read is not evidence. **A quotation counts as unverifiable when *any* source its mark names is unreadable, not only when all of them are** — 12 of those 28 name a readable source too, and a search that could not open one of the named sources cannot tell "not there" from "not readable".

**A page locator that resolves is not a page locator that is right.** The assertion is that the number falls inside the PDF's page count, which is the most a script can settle without reading the page. Where a PDF's printed page numbers differ from its page index, and one cover page is enough to cause that, a citation to the wrong page resolves clean. Three did on the reference book, each landing the reader a page early: the mark reads `p. 6`, the checker counts to the PDF's sixth page, and the page printed `6` is the seventh. Nothing in the folder records which of the two a mark meant, so the check cannot be tightened. Open the source when writing the mark, and prefer a locator the file carries in its own text, such as a heading or a numbered item, wherever the source offers one.

**What it does not reach is a paraphrase.** A mark can resolve perfectly, quote nothing, and sit beside a sentence the named section does not support. Only a model reading both can settle that, and `--emit-worklist` is what hands it the work:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-provenance.sh \
  --emit-worklist <dir> [--chapters 7,8] books/<book-slug>
```

It writes one JSON file per chapter, each holding that chapter's units and a pointer to every source their marks name, plus an `index.json` carrying counts and no prose. **One file per chapter is the point**: a reading pass gives each agent one chapter, so the book's prose never lands in a single context. Against the reference book that is 551 units and 49,509 words. `--chapters` scopes the emission, which is what an `/updatebook` run wants, since it already knows which chapters its edit reached. A chapter is named by its number and an appendix by `A` and its number, as in `--chapters 2,13,A1`: the two number in separate sequences, so `2` alone means chapter 2 and never appendix 2.

**It emits pointers, not excerpts, and the reading agent opens the source itself.** The line is what the Read tool can open: markdown and PDF directly, an image-only PDF through its `pages` parameter, which renders the page visually. A `.pptx` it cannot open, so a deck citation is the one kind carrying its text inline. The script's own docstring records why an excerpt is not on offer: none of its three source readers keeps text at a locator, and slicing one would mean trusting a page boundary the quotation check already refuses to trust.

**`/check-claims` is what runs the pass over that worklist**, one agent per chapter, writing its report to `<book>/claim-checks/<date>.md`. It is not run from here and nothing gates on it, for the same reason step 9 does not bind the PDF: it costs real time and the decision is the operator's. Name it when reporting at step 9, the way you name the `/makebook` command.

### 8. Read the seams

The checker cannot see continuity, so read the first and last paragraph of every chapter in order. What you read for depends on the profile.

**Under `guide`, read each opening as a reader who started the book there.** It names where the chapter sits and what it settles, and it points at nothing only an earlier chapter explains. A guide chapter opening on the previous chapter's last noun is the failure this read catches, and the checker cannot see it. Read each close against its whole chapter: it lands the main point or the next step, and it is true of everything the chapter covered (`reference/guide.md § Close`).

**Under `narration`, two failures show up here and nowhere else**: a chapter that re-introduces the subject as though the reader arrived cold, and a handoff noun that drifted, where chapter 5 closes on "the cache" but chapter 6 opens on "image layers".

Fix by rewriting the paragraph, not by regenerating the chapter.

### 9. Report

Give the folder, the profile, the chapter count, the prose and structure word counts, **the read time over the two added together** at 175 words a minute (§ The read-time estimate), how many chapters are mostly filled in, the glossary term count where there is one, anything the checker flagged, and the `/makebook` command to bind it:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/bookcraft-python \
  ${CLAUDE_PLUGIN_ROOT}/skills/makebook/scripts/build-book.py \
  "Book Title" books/<book-slug>
```

**Say which edition that command writes, and how to get the other.** A `guide` book declares `"edition": "reading"`, so the command binds the reader's copy: no tags, source rows in endnotes, display names in place of source keys. Give the operator's copy as a second command, with `--no-reading-edition` and its own `--out`, so the two do not overwrite each other (`makebook/SKILL.md § The reading edition`). Name both files in the report: the first is the one to hand readers, the second is the one to edit from and cite by tag. A `narration` book binds the default edition, and the report says so.

**That binds at 14pt, which is `/makebook`'s default.** Say so when reporting the command, and name the two editions a reader might want instead: `--type-size 17` for large print and `--type-size 11.8` for a compact one. The page count between those two differs by nearly double. `makebook/SKILL.md` § Type size has the sizes.

Do not run `/makebook` unless asked. Binding the PDF is a separate decision, and `/makebook`'s own procedure wants figures chosen against the finished chapters first.

## Adding to a book that already exists

Point the second argument at the existing folder. Read `OUTLINE.md` and every existing chapter's opening and closing paragraph before planning, so new chapters inherit the term ledger, and under `narration` the handoff nouns, rather than restarting them. Renumbering an existing chapter renames its file **and rewrites every tag inside it**, since the chapter half of a tag is the chapter number, so prefer appending; if a chapter must be inserted, renumber every file after it in one pass, retag each one, and rerun the checker, which catches a file whose tags kept the old number.

Renumbering also breaks any tag already cited elsewhere, in a conversation, a note or another document, the same way it breaks a `ch. N` citation. That is a second reason to append rather than insert.

**Match the book you are adding to.** Read `book.json`'s `tags` and write the new chapters the same way, since a book is tagged throughout or not at all. Where the book declares nothing, read a chapter to see which it is and add the declaration in the same pass. Changing a book's mind means retagging or untagging every existing chapter, so raise it with the operator rather than tagging half a book.

## When the book supersedes one that already exists

A book that replaces another leaves every reference to the old one pointing at nothing: answer keys citing it by chapter, a syllabus naming it, another book quoting it. Those references live outside the book folder, so nothing in step 7 or step 8 looks at them.

**Repointing a citation by number is the easy half, and it is the half that looks finished.** The hard half is that the old book's chapters and the new book's chapters are not the same chapters. A topic book and a book organised by teaching week do not map one to one, the new book says things in its own words, and a note quoting the old wording still reads as evidence after its pointer has been moved.

So the rule is: **verify a repointed reference against what the target says, not against whether the target exists.** Those are different claims and only one of them is worth anything.

```bash
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-references.sh [--since <ref> | --no-baseline] <book-folder> <referring-file>...
```

It runs four checks and reports them separately so a weaker one cannot stand in for a stronger. Every `ch. N` names a chapter the book has; every quotation attributed to the book appears in it; every `[N-M]` paragraph tag cited names a paragraph the book defines; and that paragraph is still the one it was at the baseline, which defaults to `HEAD`. Needs `python3`, and check 4 additionally needs the book to be in a git repository. Pass the book's own `OUTLINE.md` and `diagrams/README.md` as referring files too: tags are cited there like anywhere else, and only the chapter itself holds them as definitions.

**What no script here can catch is the one that matters most for a resource-first book: a claim attributed to a source that the source does not make.** The mark says where a sentence came from and nothing verifies that it came from there. That check is `reference/chapter-prose.md § Before sending`, done by reading, and it is the reason step 5 hands chapter agents paths rather than summaries.

**What it cannot catch, and you have to check by reading:** a reference that resolves to a real but wrong chapter. If nothing is quoted, `ch. 8` and `ch. 10` are equally valid to a script and only one is right. Read every repointed reference against the chapter it now names, and be most careful where the old and new numbering happen to overlap, because those are the ones that look correct. Check 4 narrows this for tags but does not close it: it sees a cited paragraph whose wording changed, so it catches a tag that slid under an insert, and it says nothing about a tag repointed by hand from one real paragraph to another real one.

**Wording quoted from the retired book has to be re-sourced or dropped.** The new book makes the same point differently, so the honest options are to quote the new sentence or to state the point without quotation marks. Leaving the old sentence under a new pointer attributes words to a chapter that never wrote them.

## Notes

- The book folder holds chapters, `OUTLINE.md`, `book.json`, `assertions.json` beside it (§ The assertions file), `about-this-book.md` where the book was written against sources, and `glossary.md` where it carries a glossary. Figures land in `diagrams/` only when `/makebook` runs and decides a figure earns its place.
- `books/` at the repo root is the default home for books that belong to no course. A book that supports a course belongs under that course instead, the way `courses/<course>/instructor-guide/` does.
- Paragraph tags reach the bound PDF and EPUB, because they are text rather than markup. That is deliberate: the address a reader cites from the printed page is the address the markdown carries. It is also the reason `--no-tags` exists, since a book meant only to be read shows the reader an address they have no use for.
- A chapter carrying more than the one claim the outline gave it is telling you the outline is wrong. Split it into two rather than writing around it, and never by cutting until it fits, which trims the glosses and the hedges first (`reference/chapter-prose.md § Before sending`).
- **The skill folder is the whole dependency.** `SKILL.md`, the three files in `reference/`, `NOTES.md` and `scripts/` are self-contained, and `/makebook` reaches back for nothing here either, so the pair can be lifted into another repo unchanged. Keep it that way: a rule that belongs to writing a chapter goes in `reference/`, in `chapter-prose.md` when every chapter follows it and in the profile file when only one profile does, and never in a sibling skill. The reasoning behind a rule goes in `NOTES.md`, so the files an agent reads at draft time stay short.
