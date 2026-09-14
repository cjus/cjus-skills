# The judgement

This file is the authority on what a verdict means. One agent reads one chapter's worklist and applies it; every agent applies the same one, which is the only reason verdicts from chapter 3 and chapter 17 can sit in the same report.

## The question

For each unit in the worklist: **do the sources the mark names carry the claims the paragraph attributes to them?**

A unit is a paragraph, table, list or fenced block, with the `<!-- src: ... -->` mark that follows it. The mark's components each name a source, and the worklist has already resolved every one of them to a file plus a locator. Your job starts after that: open what the pointer names and read it against the prose.

The failure this exists to catch is a chapter written from its brief rather than from its material. `/createbook` states the rule it breaks (`createbook/SKILL.md` § 5): "Every claim in a chapter is written from the source, not from the prompt. The agent opens what it was given. A brief is a plan for a chapter, and a chapter that rests on the brief rather than on the material is a chapter of confident paraphrase with nothing behind it." A summary of a source passed down a chain is a claim nobody afterwards can check, and a mark that came with it resolves perfectly, quotes nothing, and sits beside a sentence its source never supports.

Nothing below this line is checkable by machine. `check-provenance.sh` will confirm the source exists, the page exists, and the quotation marks are honest, and then print OK over a sentence the page does not carry.

## What is in scope, and what is not

**In scope:** the claims the paragraph attributes to the sources named in `units[].sources`.

**Out of scope, and reporting one of these is a defect in your output:**

- **The prose.** Whether it reads well, whether the example is good, whether a heading is right. Not your job.
- **Whether a better source exists.** The book chose its sources; you check the ones it named.
- **Anything under `unchecked`.** Those components are `fill` (the book's own knowledge, declared as such) or in-book references like `[16-4]` and `chapter 7`. `fill` names no external source, so nothing can be checked against it, and an in-book reference is `check-references.sh`'s job. A paragraph is allowed to be mostly `fill`.
- **Claims about the book itself.** "Chapter 18 keys it so" is a claim about this book, not about a source.
- **A locator that FAILED to resolve.** `check-provenance.sh` fails the run on one of those, and the skill stops before you are spawned. **An unasserted locator is a different thing and it does reach you.** A locator in no grammar the script reads is counted rather than checked, the run still exits 0, and its pointer carries a note saying so. 31 of the reference book's 1,208 pointers are in that state. Treat such a locator as a hint about where to look rather than as an established address, and say in `read` what you actually used.

## The mapping rule

**A mark names its sources without saying which sentence came from which, so you have to work the mapping out, and you resolve ambiguity in the book's favour.**

Where a sentence could plausibly rest on an `unchecked` component, it does. The asymmetry is deliberate. This format asks a book to declare its fill honestly and the reference book does: 451 of its 1,822 components are `fill`. Reading an unattributed sentence as a failed source claim would invent findings out of exactly the honesty the format was built to encourage, and a report full of those is a report nobody reads twice.

So: a sentence is a candidate for a finding only when it is **specifically** attributed to a named source, by naming it ("the syllabus says", "the deck's slide 3"), by sitting in a paragraph whose only components are named sources, or by making a claim so specific that no `fill` component could cover it.

## The verdicts

Exactly six. Use no other word.

| Verdict | Means | What the reader does with it |
|---|---|---|
| `supported` | The source carries the claim. The paragraph may compress, reorder or reword it; that is what a paraphrase is. | Nothing |
| `overstated` | The source is about this and says less than the sentence does. A hedge dropped, a "may" become "does", a scope widened from some to every. | Soften the sentence, or re-source the extra |
| `misstated` | The source is about this and the sentence disagrees with it in some direction other than "more". A count that is wrong either way, a name, a date, an attribution of who says a thing. | Correct the sentence against the source |
| `unsupported` | The source does not carry this claim at all, including when it is about something else entirely. | Repoint the mark, cut the claim, or move it to `fill` |
| `unclear` | You read the source and cannot decide. Usually the mapping is ambiguous, or the source is about the topic without addressing this specific claim. | A person reads it |
| `unreadable` | You could not read the source. A rendered page too degraded to make out, a file that would not open. | A person reads it by hand |

**`misstated` exists because the first draft of this file did not have it and a run found the hole.** Checking chapter 5 on 2026-09-13, an agent found that "The syllabus says so twice" undercounts a syllabus that mentions SQLite three times, and reported in `notes` that no verdict word fitted, because the claim was wrong in the safe direction. An undercount is still a wrong number in a book an instructor reads aloud. If you find yourself writing "no verdict fits" about a mismatch, the verdict is `misstated`.

**`overstated` and `misstated` both mean the sentence is wrong and the source is right**, and they are split only because the first direction is the one that teaches a room something stronger than the truth. Where a mismatch is arguably both, choose `overstated`.

**A unit gets exactly one verdict, even when its mark names several sources.** Judge each source separately, then report the most severe result, by the order `unsupported`, `overstated`, `misstated`, `unclear`, `unreadable`, `supported`. Name that source in the finding's `source` field and say in `read` what the others gave.

This is the majority case rather than an edge, which is why it is spelled out: 310 of the reference book's 551 units name more than one distinct source, and one names 26. The alternative reading, one finding per failing source, makes `counts` exceed `units_checked`, which the renderer rejects, and the whole chapter's reading pass is lost to "What was not reached".

**`unreadable` is narrow.** An image-only PDF is readable: open it with the Read tool's `pages` parameter and the page renders visually. The worklist says so on the pointer. `unreadable` is for a render you genuinely cannot make out, not for a source that merely needed a different tool.

**Default to `unclear`, never to `unsupported`.** This is the opposite of the repo's usual "default to refuted" and the reason is measured. The quotation check one rung below this one was built as a hard failure, fired ten times against this guide, and was wrong ten times out of ten; it now reports rather than fails. A paraphrase judgement is softer than a quotation match, so it will be wrong more often, and a report whose findings are mostly wrong teaches its reader to skim past the one that is right.

## The evidence bar

**Every verdict other than `supported` carries its evidence, and a verdict you cannot evidence is `unclear`.**

For `overstated`, `misstated` and `unsupported`:

- **The sentence**, quoted exactly from the paragraph. Not a summary of it.
- **What the source says instead**, quoted exactly, or a statement that the source is silent plus what you read to establish that ("read all four pages; the phrase appears nowhere").
- **The gap in one sentence.** What the prose claims that the source does not.

For `unclear` and `unreadable`: what you read, and what stopped you.

**Naming what you read is not optional, and it is the field most likely to save a reader time.** "Read the whole page" and "read the Requirements section" are different claims about how far an absence extends. An absence found only in the place you looked bounds only that place.

## When the pointer is not enough

**The worklist is a pointer, not a substitute for the source, and two cases make that concrete.**

- **A deck's speaker notes are not in the worklist.** The inline text is slide text only; the notes live inside the `.pptx` and nothing extracts them. A chapter claiming a deck "carries no speaker notes of its own" is checkable only by opening the file.
- **Slide text loses the slide's structure.** `Ingest / Clean / Transform / Feature / Store` is equally consistent with five boxes and with four, where one box's label wrapped. A claim that counts boxes, arrows or columns is not decidable from the text alone.

In both cases, open the `.pptx` (it is a zip; the slide parts are `ppt/slides/slideN.xml` and the notes are `ppt/notesSlides/notesSlideN.xml`) rather than returning a verdict the evidence does not carry. Both cases are real: on the first full run, eight of the eighteen agents reported opening a deck for the first, and one settled a box count with the second. Say in `read` that you did.

## Multi-file shorthands

A shorthand may name many files: `every assignment page` names 23, `[L1] to [L5]` names five. A claim against one of those is a claim about all of them at once, and the worklist says so on the pointer.

- **Supporting such a claim means reading enough of them to be confident no counterexample exists.** Say in `read` how many you opened out of how many.
- **Refuting one is cheaper and stronger**: one counterexample settles it. Name the file.
- A `supported` verdict on a 23-file shorthand where you read four is weaker than one on a single page, and the report says so because you said so in `read`. Do not silently upgrade it by leaving `read` vague.

## What you return

One JSON object. Write it to the path the prompt gives you; return only the path and the counts.

```json
{
  "chapter": 5,
  "file": "data-modeling-teaching-guide-05-the-engine-on-their-laptop.md",
  "units_checked": 15,
  "counts": {"supported": 12, "overstated": 1, "misstated": 0, "unsupported": 1, "unclear": 1, "unreadable": 0},
  "findings": [
    {
      "line": 11,
      "tag": "[5-1]",
      "verdict": "overstated",
      "source": "syllabus p. 6",
      "sentence": "Four of the five lab stubs carry `import sqlite3`.",
      "source_says": "Tools: Python 3, SQLite/SQL",
      "gap": "The page names the tools; it says nothing about how many stubs import sqlite3, which is a claim about the lab files rather than about this page.",
      "read": "syllabus page 6, rendered as an image"
    }
  ],
  "notes": []
}
```

- **`units_checked` must equal the worklist's unit count**, and the counts must sum to it. A run that examined fewer units than it was given says nothing about the rest, so say which you skipped and why in `notes` rather than letting the totals disagree quietly.
- **`findings` holds every unit whose verdict is not `supported`**, and nothing else. A `supported` unit contributes to `counts` and no more.
- **`tag` is the paragraph tag** where the unit has one, taken from the head of the unit's text. Omit it for a table or list that carries none.
- **`notes`** is for anything true of the whole chapter: a source you could not open at all, a shorthand you sampled rather than read, a pattern you saw repeatedly.

## Before you return

- Every finding quotes a real sentence from the unit text you were given. Re-read them against the worklist; a quotation you reconstructed from memory is the fault this whole check exists to catch, committed by the checker.
- Every `unsupported` says what you read. An absence is bounded by where you looked.
- No finding is about prose, about a better source, or about an `unchecked` component.
- The counts sum to `units_checked`.
