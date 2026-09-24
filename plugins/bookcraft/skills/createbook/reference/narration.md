# Writing a narration chapter

Rules for a book whose `book.json` sets `"profile": "narration"` or names no profile. Read `chapter-prose.md` first: every rule in it applies. This file adds the rules that chain a narration book together, and where it names a rule in `chapter-prose.md`, this file wins.

A narration book is read once, straight through, in order. These rules came from a corpus of audio narration, where a listener cannot look back (`NOTES.md § What the numbers rest on`), so each chapter hands the next one its opening noun, and each part hands the next part its first.

These rules were moved here from `chapter-prose.md` unchanged when the guide profile got a file of its own, on 2026-09-24. They have not been rewritten.

## Rules

**What the reader arrives with, under narration.** Beyond the terms an earlier chapter glossed, a later chapter may assume the noun the previous chapter closed on. **A handoff noun is a pointer, not a definition, and the two grants are independent.** Where the noun this chapter opens on names something no earlier chapter glossed, this chapter glosses it inside the sentence that first uses it, in the opening paragraph, and it costs nothing against the six new terms because the outline assigned it to nobody. Check this before drafting: the noun is on the outline's handoff row, and the term ledger either names it on an earlier chapter's row or it does not.

**The frame.** The parts carry the chapter and the frame sits small around them: an opening paragraph, two sober paragraphs and a close (`chapter-prose.md § Shape`). With three parts the first runs longest on paper only because the anchor and the wrong model take roughly 160 words off the top, and carrying none of that freight is why the middle part is where the fullest mechanism belongs.

**The part and chapter seams are fixed by the outline and are not yours to choose** (see § Every part does five things). The paragraph seams in `chapter-prose.md § Seams` are the fifteen or twenty the outline says nothing about, and they are where a reader who understood every sentence still cannot say what the chapter argued.

**Every part does five things.** Name what it's about inside its first two sentences, and open the later parts on the exact noun the previous one ended on, so the handoff carries the reader's memory for them. Walk the mechanism (`chapter-prose.md § The mechanism walk`). Gloss every term the outline assigns this chapter inside the sentence that first uses it (`chapter-prose.md § Glosses`). Say the core idea again in different words, once, after the walk. Then say in plain words what this part established, in one sentence a reader could carry out of the chapter. **Plain means the sentence works on its own terms**: every noun in it has appeared already, and a reader who has just finished the part understands it without reading back. A compressed line that only decodes once you know the part is an epigram rather than a portable sentence, and this is a place where spending a few extra words pays. Then exit on the weakness that breaks it, named with the specific noun for what breaks, inside the paragraph holding the win. Never exit on success.

**The wrong model is required.** One full wrong model, only ever one, in the first part where the reader still holds it, making the four moves in `chapter-prose.md § The wrong model`. That costs about 130 words and asks the reader to hold a picture they then have to discard, which is why it doesn't repeat; later parts get the cheap form, two wrong pictures and then the real one.

**Open.** Chapter 1 opens the book, in one paragraph, on one of four: something happening this minute in the reader's body or device that already is the subject; two or three things they do without thinking, then the reveal; the claim that the subject is older, closer or stranger than they assume; or the concession that it's overkill and the answer turns on their situation. Chapter 1 opens the book without announcing that it is doing so. Every later chapter opens on the noun the previous chapter closed on, which the outline fixed, with no fresh hook and no re-introduction of the subject or of the book. Either way, reach the concrete thing by the second sentence, and end by naming the question the first part answers without saying that's what you're doing. No greeting, no promise of what they'll learn.

That noun arrives with a definite article already attached, which is where `chapter-prose.md § Reference` bites hardest: the handoff grants you the word, never the definition (§ What the reader arrives with, under narration).

**Close** in one paragraph: one portable sentence for what this chapter established, the verdict, where "it depends" is legitimate provided you say what on, then the noun this chapter hands forward in the last clause, which the outline fixed and the next chapter opens on. Don't replay the parts. The reader finished them a minute ago, and each already ended on its own sentence. Only the last chapter of the book closes the book, and it is the one chapter that hands forward nothing.

### Headings

Write a part heading as a noun phrase of six words at most, saying what the part is about rather than what the reader will get from it. No questions, no gerund labels, no numbering, nothing that announces. It has to be redundant, so that a reader who ignores every heading loses nothing: the part's first two sentences already name what it is about, and still open on the noun the previous part ended on. A heading carrying something the prose does not is a heading that rewards skipping the prose. The handoff keeps working underneath, which is the whole defence here, since a reader who jumps one lands on a noun the part before it defined and finds the skip failing quickly rather than quietly.

There is no level below H2. The opening paragraph, the sober pair and the close carry no heading. A heading marks where a part begins rather than labelling everything below it, which is why a chapter can end several paragraphs past the last one without wanting another.

### In short

Under narration the section is opt-in, through `"overview": true` in `book.json`. Its summary is called the walk: what the chapter argues, in the order it argues it, for someone who has not read it.

The section exists because every later chapter opens on the noun the previous chapter closed on, and that noun arrives with a definite article already attached (`chapter-prose.md § Reference`). Read in order it lands. Read by jumping to one chapter, which is how a finished book is actually used, the article points at a referent the reader never had, and the opening paragraph is the worst place in the chapter to lose them.

- **The walk may use no term this chapter glosses.** Carried terms are exempt: a term the line above has just restored is on the table, and the walk spends it plainly. The `This chapter` header row may say "the three levels" and "cardinality", because its reader has read the chapter. The walk says "how much of the database is in view" and "how many at most, and is none allowed". Without this rule the two converge and every chapter carries two summaries in different registers.
- **This is the describe-the-behaviour-then-attach-the-label move with the label left off**, which `chapter-prose.md § Glosses` already requires of an intimidating term. The difference is only that the walk never gets to the label.
- **The rule is written and reviewed, and it is not checked by script.** Follow it while drafting, and confirm it afterwards by reading the section against this chapter's row in the term ledger. Nothing in `check-book.sh` enforces it, by decision rather than by omission (`NOTES.md § The overview section, 2026-09-20`).

**Length is uncapped, and the word count is reported rather than thresholded.** `check-book.sh` carries the section's count on its summary line, so drift stays visible without a number deciding anything.

### The plan

**The outline also fixes the handoffs.** The noun this chapter opens on, the noun it closes on and the weakness it exits on are given, alongside the terms and anchors `chapter-prose.md § The plan` lists, because a chapter that re-derives one breaks the chapter on either side of it.

**One job per part, and a handoff noun for every seam between them.** The handoff is the noun the next part opens on, so three parts have two seams and the last part hands off to the chapter's own close. Both get chosen now, because deciding a handoff once you are already writing the seam is exactly what produces parts that chain cleanly and still don't add up.

**The allocation places the wrong model**, which this profile requires, in the first part.

### Before sending

After the checks in `chapter-prose.md § Before sending`:

- **Every part exits on a named weakness**, and every later part opens on the noun the previous part ended on.
- **The two seams the outline fixed.** The first paragraph opens on the noun the previous chapter closed on, and the close hands forward the noun the next chapter opens on. Check both against the plan: a part that drifted off its job is what the reader feels as a chapter that doesn't add up.
- **Somewhere a plausible wrong answer has to fail on a concrete case**, and if none does you wrote a summary, so go back and spend the words.
- **The `## In short` walk uses no term this chapter glosses**, read against this chapter's row in the outline's term ledger, with the carried-in terms exempt. This pass is the only thing that checks it: `check-book.sh` finds the carried-in line, counts it and resolves it against the glossary, and nothing anywhere checks the walk's vocabulary. Confirm on the same read that each carried-in entry is worded from its glossary entry rather than freshly defined, and that the terms named are the ones this chapter's claim rests on rather than the first three on the ledger row.
