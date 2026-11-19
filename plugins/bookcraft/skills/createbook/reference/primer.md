# Writing a primer chapter

A primer is a short book that gets one reader up to speed on a subject, built from the context the operator gave at creation time. You are writing one chapter of it. This file is the whole rule set for a primer chapter: read it instead of `chapter-prose.md`, not on top of it. It names the two pieces of shared machinery it borrows from `chapter-prose.md` where it uses them.

`SKILL.md` owns the book around the chapter: the outline, the filenames, `book.json`, the checkers and the bind. `NOTES.md` says why the rules here exist.

## The reader

The outline names the reader: who they are, what they already know, and what they should be able to do when they finish. They have a reading budget for the whole book, usually an hour or two. They are smart and busy. They read in order, start to finish. They do not need everything. They need the ideas that carry the most weight, explained well enough to stick.

Write for that person. Use what they already know plainly. Explain everything else.

## What the chapter is for

The outline gives this chapter a job, the concepts it **teaches**, the ones it only **mentions**, and what it **leaves** to the sources. Hold to that split.

- **Teach** a concept in full: the problem it solves, how it works, why it matters, and what goes wrong without it.
- **Mention** a concept in a sentence or two: what problem it addresses, and where the reader would go for more. A mention is a pointer, never a run of names. If a passage names several things the chapter does not teach, it is one short passage that leads somewhere, not a list of bare names.
- **Leave** a concept out entirely. The pull to cover everything the context covers is the main thing that turns a primer into a digest.

**Teach or point, never list.** A technique the chapter names gets a real explanation or one sentence saying what problem it addresses plus where to read more. Never a name on its own.

## Explaining

Write the explanation itself, to the reader.

- **Start from a problem the reader can see.** An idea is an answer, so show the question first: the thing that goes wrong, or is slow, or is confusing, without it. Where the context has a real demonstration (a command and its output, a before and after, a measured result, a worked example), use it. A demonstration beats a description.
- **Say why, not only what.** After the reader knows what a thing is and how it works, they need to know why it matters and what goes wrong without it. An example shows the idea at work, and a reader shown one still has to guess the reason, so give the reason too. This is a habit, not a template: do not march every concept through the same steps in the same order.
- **Choose the device per concept.** Prose for reasoning. A worked trace for a process the reader should be able to follow by hand. A small diagram drawn in text, in a fenced block, where a picture carries the idea. A small table for a comparison or a set of measurements. A list for a real set of items or a procedure the reader performs. A fenced block for code, a command or output, kept to the lines that make the point.
- **Define a new term when you first use it,** in a clause or in a sentence of its own. The outline says which terms are this chapter's to define and which an earlier chapter already defined. Use the earlier ones plainly, and never bold or define them again.
- **Make anything you show readable.** When the chapter shows output, a table or code, every part of it the reader needs to follow the point is explained where it appears. Trim what the point does not need, and mark the cut with `...`. Note a cut in a code excerpt only when the omission could mislead.
- **Answer the question the reader would ask next.** Then stop. The question after that belongs to the sources.
- **One name for one thing.** If you call it the cache, it stays the cache.
- **Order by what the reader must understand first,** never by the order the sources happen to use.

## Where facts come from

Facts have three possible origins, and they are not equal.

1. **The context**, the files the operator gave. It is the authority for every fact it covers.
2. **Trusted outside sources**, the pages in the book's research ledger (`research/ledger.json`) whose `chapters` include this one. Use them for general facts about the subject the context does not state, and for ideas about how to explain it. Every such fact is cited (§ Citing outside sources).
3. **Your own knowledge.** Use it freely to choose an example, an order or an analogy. Never let it be the only support for a fact the reader might rely on. A fact in neither the context nor the ledger is left out and noted in your findings file.

**When an outside source disagrees with the context, the context wins in the chapter.** Write the disagreement in your findings file, and never resolve it quietly in the prose.

- **Never invent** a person, a date, a quotation, a number, a result or an incident, and never write a URL that is not in the ledger, character for character. Command output and measurements shown in the chapter are copied from the context, never produced by running anything.
- **A number keeps the scope it was measured over.** If the context measured something on one input, at one setting, say so.
- **A measured result goes where the argument needs it.** Do not end each section on a result as a ritual.
- **Where the context disagrees with itself,** state only what both sides support, or leave the point out, and write the disagreement in your findings file.

## Marks

After every paragraph, list, table and fenced block, put one line saying what it rests on, including a table or block above the first paragraph. The grammar is `chapter-prose.md § Provenance`: context sources by the keys `book.json` gives them, `web <id>` for a ledger entry, `fill` for your own explanation, `assertion <id>` for an entry in `assertions.json`, joined with semicolons. The reader never sees these lines.

```
<!-- src: build-guide § Caching; web 4; fill (the example) -->
```

## Citing outside sources

- **Link a fact from an outside source where the reader meets it, on the words that state the fact**: the cache is [cleared after seven days](URL). Use the URL exactly as the ledger gives it.
- **Link each source once in a chapter**, at the first fact you take from it. Later facts from the same page need no second link, because the closing section accounts for them.
- **Name the source in the sentence only when it matters who said it**: a judgement, a piece of history, a number someone else measured. Otherwise keep the sentence about the subject. A chapter that keeps saying "the documentation says" has turned into a report on its sources.
- **Every ledger entry a mark cites is linked somewhere in the chapter, and every URL in the chapter's prose is a ledger URL.** `check-provenance.sh` fails the chapter otherwise. A URL inside a fenced block or an inline code span is code, such as a command that fetches a page, and is not read as a citation.

## Shape and length

- **First line: `# The chapter title`**, exactly as the outline gives it. No other H1, and no frontmatter.
- **Open with the move the outline assigns.** Never open by summarising earlier chapters. Never open by promising what the reader will learn.
- **Use `##` headings that say what a section is about,** as many as the chapter needs. An `###` inside a section is fine where it helps a reader find something. Nothing deeper.
- **A `## Try it` section is welcome only where the outline gives this chapter one.**
- **End when the explanation is done.** No summary of what was just said, no call to action.
- **Then `## Sources and further reading`, last, as a bulleted list.** The context sources this chapter drew on, by the names a reader would use, each with what to open it for. Then each outside source the chapter cited, in this form: `Title, publisher, [URL](URL), for what this chapter took from it`, so the URL prints once in full and stays clickable. Only sources the chapter actually cited. Then the concepts this chapter stopped short of, each a term to search with a clause on why. It takes no marks, and nothing follows it.

**Length is a ceiling, never a target.**

- **A chapter:** no more than about 2,000 words of prose. Shorter is fine, and usual. Nothing sets a floor.
- **A paragraph:** rarely over 100 words, and most well under. One or two sentences is a good paragraph. Let length follow the thought, so paragraphs come out different sizes.
- **A sentence:** past about 35 words, it is probably two.

A paragraph tag, where the book carries them, follows `chapter-prose.md § Paragraph tags`.

## Voice

Plain words, the way a good engineer explains something to a colleague. Address the reader as "you", and use "we" for what the reader and the book do together. Contractions are fine. A parenthesis is fine for a true aside.

Things that make prose sound machine-written, so avoid them:

- The em dash. Use a comma, a parenthesis, a colon or a new sentence. `check-book.sh` fails a chapter that carries one.
- A block quote. A primer has no callouts, and `check-book.sh` fails a `> ` line outside a fenced block. Italics too: use bold for a term at the moment you define it, and nothing else.
- Announcing importance instead of showing it: "it's worth noting", "importantly", "the key insight is".
- Instructions to the reader about how to read: "keep this in mind", "read this with care". Say the thing.
- More than one rhetorical question used as a pivot in a chapter, and never "What did X buy?".
- "Not just X, but Y", "X isn't about A, it's about B", and other contrasts built to impress.
- Grand openers and closers: "In the world of", "At its core", "In conclusion", "Ultimately".
- Words nobody says out loud: delve, crucial, pivotal, intricate, tapestry, showcase, underscore, testament, seamless, robust, foster, leverage, landscape used abstractly.
- A trailing "-ing" phrase that adds a claim and no information ("ensuring correctness").
- A list of three used for rhythm when there are really two things, or four.
- Fragment transitions ("Now the cache.") and set-up-then-reverse moves ("You might expect X. In fact, Y.") repeated as a habit.
- Every paragraph the same size, or every section built the same way.

## Before you finish

Read the chapter once as the reader, top to bottom, and fix anything you would stumble on. Then check:

- Every unit has its mark, and every fact about the subject is in the context source or the ledger entry its mark names. Open the source and look.
- Every outside fact is linked where the reader meets it, and every URL in the chapter appears in the ledger, character for character.
- Every term the outline gave this chapter is defined at first use, and no term an earlier chapter defined is defined again.
- Every concept the outline marks as taught is taught, and every name the chapter uses is taught or pointed at.
- The opening is the move the outline assigned.
- No em dash anywhere.

Write anything you found wrong, missing or contradictory in the outline or the context to your findings file. Nothing to report means no file.
