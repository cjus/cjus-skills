# Writing a guide chapter

Rules for a book whose `book.json` sets `"profile": "guide"`. Read `chapter-prose.md` first: every rule in it applies. This file adds the rules a guide needs, and where it names a rule in `chapter-prose.md`, this file wins.

A guide is read one chapter at a time, in the week the reader needs it. Someone preparing week nine opens chapter nine on a Saturday, having read chapter eight a month ago or never. They scan for what to do on Monday, and they come back later with one question. Every rule below is for that reader.

A guide is still prose by default, and it still argues. A chapter that has turned into a slide deck has failed.

## Rules

### Opening

**The opening paragraph orients the reader.** In plain words, say where this chapter sits in the book or the course, and what it settles. Write it for a reader who opened the book here, and reach the concrete thing by the second sentence. Saying what the chapter settles is a statement about the chapter, not a promise of what the reader will learn, so § Never's ban does not apply; "you will learn" is still banned.

**Never open on something only an earlier chapter explains.** A definite noun pointing at what the last chapter ended on is a referent this reader never had (`chapter-prose.md § Reference`). What a chapter may assume is still set by `chapter-prose.md § What the reader arrives with`: a term an earlier chapter glossed is free, and anything else is glossed here.

```text
Before:  The scan is what week four ended on, and this week it is the thing
         the class has to learn to read.

After:   Week five is the first time the class reads a query plan, and the
         first thing they meet in one is a full table scan. This chapter
         settles when a scan is the right choice and when it means an index
         is missing.
```

"The scan" and "week four ended on" point into a chapter this reader may never have opened. The rewrite names the week, the situation and the question, using nothing from earlier chapters.

**The opening never repeats `## In short`.** The reader may have read the summary a moment ago, so the opening starts the argument in its own words.

**Chapter 1 may open on a scene or a surprising claim** if the material offers one. More often, a guide's first chapter says what the book is for and how to read it, and that is a fine opening.

### Headings

**A heading tells a scanning reader what the section covers.** The test: could a reader find this section from the contents page, when looking for the thing it covers? A heading that passes names that thing. It may state the section's point, and it may be a question. It never teases.

| Teaser | Label that passes the test |
|---|---|
| The verb that does not exist | Why the tool has no undo |
| The shape the room argues about | One table or two |
| What the second copy holds | What the backup table stores |

The teasers come from a real guide. The labels show the test at work; they are not those sections' actual subjects.

**H3 is allowed inside a part.** Two levels only: H2 for a part, and H3 for a named division inside it, such as the stages of a procedure or a set of cases. A part that wants four H3s is two parts. An H3 gets the same six words an H2 does.

### What a part does

- **It names what it is about in its first two sentences.** A reader who lands on the part from the contents page starts here.
- **It explains a mechanism as chained prose** (`chapter-prose.md § The mechanism walk`), and puts a procedure the reader performs in a numbered list (§ Procedures).
- **It glosses the terms the outline assigns** (`chapter-prose.md § Glosses`).
- **It says, in one plain sentence, what it established.** Every noun in that sentence has appeared already, so it works on its own.
- **It may then exit on the weakness that breaks what it established**, where there is a real one, named with the specific noun for what breaks, inside the paragraph holding the win. Where there is none, it ends on the sentence above (§ Section ends).

Parts do not hand off to each other. A later part opens on its own subject, not on the noun the previous part ended on. Its heading marks the turn, so its first paragraph is exempt from the seam test in `chapter-prose.md § Seams`; every other paragraph seam still has to connect.

A part that delivers a procedure, a script or a grading rule has no mechanism to walk. `chapter-prose.md § The mechanism walk` applies where a part explains how something works.

### Section ends

**A part may end on a one-sentence takeaway.** The sentence says what the part established, in words that work on their own: every noun in it has appeared already. A reader who opens one part, reads it and closes the book leaves with that sentence.

**Where there is a real weakness, ending on it is still the better move.** A guide that ends every part on a tidy summary has lost its honesty.

**The phrase bans in `chapter-prose.md § Never` stay.** The takeaway is a sentence, never a heading over a bulleted recap. Where it should stand out, use `> **Decide.**`, or let the sentence stand alone as the part's last paragraph. That spends the chapter's one standalone sentence (`chapter-prose.md § Shape`), which under this profile may sit at the end of a part instead of at the turn to cost.

### Callouts

**Four labelled block quotes, and no other block quote.**

```markdown
> **Decide.** The thing the reader has to choose, and what turns on it.
> **Warning.** What goes wrong, stated before they do it rather than after.
> **In the room.** What this looks like live, with people in front of you.
> **Grade this.** The rule to apply when marking, or the line to hold.
```

- **The label is literal and comes first**: `> **`, the word, a full stop, `**`, a space, then the sentence. `check-book.sh` finds a callout by that grammar and nothing else.
- **Any other block quote fails**, and so does an unlabelled one. A fifth label is a change to this file.
- **One idea per callout, in one to four sentences.** A callout that needs a second idea is two callouts, or a paragraph. `check-book.sh` reports a callout over four sentences.
- **Use the label that fits the idea.** A warning says what goes wrong. A rule for marking is `Grade this`, and a choice is `Decide`. Never reach for `Warning` because a point feels important.
- **At most four in a chapter**, and never a budget to spend. A chapter with a callout on every page has turned the signal off.
- **A callout takes no paragraph tag, and it takes a provenance mark** like any other unit.
- **`/makebook` renders each one as a boxed aside**, with the label as its title.

```text
Before:  > **Warning.** Pass-offs are graded on the day and cannot be made up.
         > Each is worth 5% of the grade. The lab schedule has no slot for them
         > in week four, so book a room early; the department office holds the
         > keys. The course assumes you demonstrate each task before students
         > attempt it.

After:   > **Grade this.** A pass-off is graded on the day it happens, and a
         > missed one cannot be made up.

         > **Warning.** Week four's lab schedule has no slot for pass-offs, so
         > book a room before the week starts.
```

The first version packs a grading rule, a weight, a scheduling gap, a contact and a teaching note under one label. The rewrite keeps the two ideas that need a box, each under the label that fits. The weight belongs in the grading table, and the teaching note belongs in the prose.

### Procedures

**Use a numbered list for anything the reader does in order**: setting up a tool, running an exam session, working through a grading pass. The reader performs it with the book open, and a numbered step is an address they can return to after looking away.

**A mechanism stays prose.** The test is whether the reader performs the sequence or only understands it. A sequence the reader does takes numbers; one they understand is chained prose (`chapter-prose.md § The mechanism walk`). Where a passage is both, write the mechanism in prose and the procedure as a list below it. `chapter-prose.md § Voice` bans ordinal sequencing in prose, not in a list that is a real procedure.

### The wrong model

**Optional, at most one per chapter, and only where a source or the classroom names the misconception.** A chapter that exists to deliver a procedure has no wrong model to correct.

**Where one is written, it makes the four moves** in `chapter-prose.md § The wrong model`, concession included, in the part where the misconception arises.

**The four moves are a shape, not a script.** Write each passage in words that fit its case. Stock phrasings give the template away when they recur from chapter to chapter: "suggests itself", "The instinct is a good one", "The obvious move is". `check-book.sh` reports any phrase that recurs across three or more chapters.

### The chapter header

**Three rows: `Act on this`, `Draws on` and `Fills in`.** A guide chapter has no `This chapter` row, because `## In short` does that job. `chapter-prose.md § The chapter header` describes each row.

**`Act on this` stays on the page.** It is what the second reading lands on.

**`Draws on` and `Fills in` are the operator's rows.** They stay in the file and move to endnotes in the reading edition, which a guide binds by default (`makebook/SKILL.md § The reading edition`). `check-provenance.sh` and the review passes still read them.

**An appendix with no `## In short` may keep a `This chapter` row**, since nothing else in it says what it holds.

### In short

**Required in every chapter**, and optional in an appendix. It is the only summary a guide chapter has before its prose.

It opens with the carried-in line in `chapter-prose.md § In short`, where the chapter picks up earlier terms. Then comes the summary:

- **The first sentence says what the chapter covers**, and the scope it belongs to where the book has one: the week, the session, the stage of the course.
- **The rest says what the chapter settles, in the chapter's own terms.** A term the chapter glosses may appear, with a short definition in the same clause.
- **About 120 words or five sentences at most**, not counting the carried-in line. `check-book.sh` reports a summary over 120 words.
- **Never reuse the chapter's sentences.** Write the summary fresh from the finished chapter: a reader who reads it and then the chapter should never meet the same sentence twice. `check-book.sh` reports any run of eight or more words the summary shares with the chapter below it.

```text
Before:  Each rule in this chapter is the arrow two slides later, and one of
         them gets heard as small when it means irreducible. By the end there
         is a procedure you can run in chalk.

After:   Week six covers normalization. A functional dependency, meaning one
         column's value fixes another's, is the arrow on the slide. A
         candidate key is a smallest set of columns that fixes every other
         column. Attribute closure finds one: start from a set of columns and
         keep adding whatever they fix.
```

The first version avoids naming the three terms the chapter teaches, so it reads as a riddle. The second names them, defines each in a clause, and runs 49 words.

### Close

**Close on the chapter's main point, or on what the reader should do next because of it.** Either way the close lands the claim from the plan (`chapter-prose.md § The plan`), in one paragraph. Where the honest answer is "it depends", say on what. Guide chapters do not chain: the close hands nothing forward, and the next chapter does not open on it.

**The close must be true of the whole chapter.** "Everything in this chapter is a date" is false after a chapter that also covered prerequisites, pass-offs and the roster.

```text
Before:  Before you touch anything in the gradebook, you need the thing the
         calendar does not carry, which is the points.

After:   Before the first class, the calendar should hold every date in this
         chapter: the prerequisite check, each pass-off day and the
         withdrawal deadline.
```

The first version is built to deliver a noun to the next chapter. The rewrite tells the reader what to do with this one.

**Telling the reader what to do next is allowed here**, although `chapter-prose.md § Never` bans closing on a call to action. The ban is on empty exhortation, and a guide's close is instruction. The rest of § Never still applies: no "In conclusion", and no recap of the parts.

### Provenance in prose

**The provenance mark does the attributing; the sentence stays quiet.** `chapter-prose.md § Provenance` asks for attribution in the prose where it matters. Under this profile, that means two cases only: the sentence quotes the source, or the reader has to open the source to act. Everywhere else, the `<!-- src: ... -->` mark records the source and the prose says nothing.

**A book-level caveat is stated once**: in `about-this-book.md`, and once above the appendix it applies to. Never repeat it in each chapter.

**Name a source by its display name, never by its repo path.** `book.json` may give each source a reader-facing name beside its path. The prose uses that name, and the mark uses the key. A reader cannot open `../../../CLAUDE.md` and should never be shown it (`SKILL.md § 4`).

### Appendices

**An appendix is a chapter-kind file holding reference matter**: answer keys, rubric pairs, an open-decisions table, a source ledger. It is bound after the chapters and before the glossary.

- **Filename: `<book-slug>-appendix-<N>-<slug>.md`**, numbered from 1. It sorts after every chapter, so a plain filename sort is still the reading order (`SKILL.md § Filenames`).
- **Tagged as `[A<N>-<n>]`**, so appendix 2's fourth paragraph is `[A2-4]`. The `A` keeps an appendix's addresses apart from a chapter's.
- **No parts, no opening paragraph, no close and no handoffs.** An appendix is not an argument, and the part-count rule skips it.
- **The chapter header, `## In short` and `## Suggested reading` are optional**, used only where they earn their place. Provenance marks are not optional.
- **An appendix never teaches.** A concept explained for the first time in an appendix is in the wrong file.

### A shape for a teaching chapter

Offered, never enforced, for a chapter that prepares someone to teach a session. Nothing checks it.

1. **At a glance**: the header table and `## In short`, which every chapter has anyway.
2. **The concepts, in teaching order**, each with its definition, the failure to watch for, and the assessment item it feeds.
3. **The lesson script**: what to say, what to ask, what to watch for, and roughly how long each takes.
4. **Grading**: the rubric, the line to hold, and what to do about the cases that sit on it. Where the session has a key, put it in an appendix and point to it from here.

Items 2 to 4 are the chapter's three parts. **This is a shape, not a template.** A chapter that fills every heading with one sentence has produced furniture. Where a session has no grading, that part goes.

### Before sending

After the checks in `chapter-prose.md § Before sending`:

- **The opening orients a reader who arrived at this chapter first**, and points at nothing only an earlier chapter explains.
- **Every heading passes the test** in § Headings.
- **Every callout holds one idea**, in one to four sentences, under the label that fits it.
- **`## In short` says what the chapter covers in its first sentence**, stays near 120 words, and shares no sentence with the chapter.
- **The close lands the main point or the next step**, and it is true of the whole chapter.
- **A wrong model, if there is one, is in words that fit its case**, not in the stock phrasings § The wrong model lists.
