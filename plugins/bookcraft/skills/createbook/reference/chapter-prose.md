# Writing a chapter

These rules apply to every chapter, whatever the book's profile. Read this file first, then the file for the book's profile: `guide.md` for a guide, `narration.md` for a narration book. Where the profile file names a rule here, the profile file wins. Everything else here applies in full.

`SKILL.md` owns the book around the chapter: the outline, the filenames, `book.json`, the checker and the bind. `NOTES.md` says why each rule exists and which numbers were measured. Neither is needed to write a chapter.

## Rules

**The reader.** One person who has to be able to do something soon and has little time to get there. They are fully attentive, have little working memory to spare, and read under time pressure. They read the chapter once, straight through, then come back later for one fact.

Both readings have to work: the first needs an argument they can follow, and the second needs an address they can find. Every sentence either lowers what the reader has to hold or makes the next sentence land. A sentence that does neither goes.

**The sources come first.** A chapter is written against the resources the book was given, and the model's own knowledge fills only what those leave out.

The reader has to be able to tell which is which, because the two age differently: a sourced claim is fixed by its source, and a filled-in one is where a version, a default or a name goes stale. Attribute and mark as § Provenance says, and never blur the two to make a paragraph read better. A chapter may be mostly filled in where the sources are thin. Say so plainly.

**What the reader arrives with.** Chapter 1 is the one chapter a reader can arrive at cold, and it stands alone: nothing else open, no earlier chapter, nothing naming the subject before the prose does. A later chapter may assume only what the outline grants it: the terms an earlier chapter glossed, and anything the profile file adds.

Nothing else carries over. An example from three chapters back is either re-earned in a clause or dropped. A subject that cannot be made self-contained in one chapter needs narrowing, and at book scale that is the outline's job.

**Length.** A chapter is as long as its job needs and no longer. There is no ceiling, no target, no floor, and no estimate made before drafting. § The reader decides where each sentence earns its place. A chapter much longer than its neighbours usually means the outline drew it too wide: report that, and do not write around it. Tables, lists and fenced blocks count apart from the prose, and tags and marks count as neither. `check-book.sh` reports both figures and fails on neither.

**Shape.** A chapter has three parts, or two when the subject is one mechanism and one complication, each under one H2. Never one part, and never four. Around the parts sit an opening paragraph, the two sober paragraphs after the last part, and a close. The profile file says how the opening and the close work.

Paragraphs run 40 to 90 words, one idea each, and 90 is a hard stop. The first sentence states the paragraph's claim in terms already on the table, meaning nouns the reader has met in this chapter so far. A claim resting on a noun the paragraph has yet to introduce is an epigram the reader can only decode afterwards.

At most once in a chapter, one sentence may stand alone as a paragraph, where the chapter turns from how the thing works to what it costs. None at all is fine.

**Seams.** Each paragraph's first sentence connects to something the previous paragraph left standing. It names that thing again, or points at it with the noun attached ("a box like that", "after that point"), or opens with a marker saying how it attaches. "But the item is not where the defect sits" does both in eight words. A seam with none of these is where the reader stops. So write each paragraph's last sentence knowing the next one has to start from what it leaves standing.

Vary the device across the chapter: twenty seams chained noun to noun read as chanting, and twenty marked ones read as a machine narrating itself.

Break where the direction turns. A break that reverses, qualifies or prices something names the turn in its first clause, because a reader left to infer the relation reads the paragraph twice.

**Glosses.** Gloss every term the outline assigns this chapter inside the sentence that first uses it, as a clause. Never use a long parenthesis, and never hold a gloss over to a later sentence. Where a term is intimidating, describe the behaviour first and attach the label after. A term an earlier chapter glossed is used plainly and never glossed again.

**The mechanism walk.** Where a part explains how something works, walk the mechanism in three to five steps, in plain verbs, with no notation. Chain the steps by what causes what, and never number them: a numbered step says where it sits, and a chained step says why it follows, which is the thing being taught. After the walk, say the core idea again in different words, once.

**The wrong model.** A wrong model is the fix a reader would reach for, shown failing. It makes four moves: pose the question the reader would ask, state the fix they would reach for in their own words, concede the part of it that works, then let it fail on one concrete case.

The concession is required, because a fix knocked down without one reads as a strawman and the reader defends it. The passage runs about 130 words, so split it across two paragraphs: the question, fix and concession, then the failure. It goes in the first part, where the reader still holds the wrong picture. A chapter has at most one, and later parts get the cheap form: two wrong pictures, then the real one. The profile file says whether a chapter needs one at all.

**Spend these deliberately.** Allocate each of these in the plan, before drafting.

- **Anchors: two at most.** An anchor is a checkable name the argument rests on: a person, an institution, a product, a file, a command and what it printed, or a number. The test is whether a claim in the chapter would have to change if the name were wrong. A name that only says what the chapter is about spends nothing, such as the company whose system you explain. Count every checkable name on the page, then charge the ones the argument rests on.
- **The first anchor is required and early**: a named person with their role, or an institution with the year it acted, where one exists; otherwise the specific case, file, failure or number. The second is optional and late, where the consequence would otherwise be bare assertion. Tie each anchor to the mechanism across two sentences. The outline's anchor ledger says which anchors this chapter owns, and one another chapter spent is not available.
- **Analogy: one at most**, and none when the mechanism is already concrete. It is a physical scene with a person in it, mapped back in running sentences inside the same paragraph.
- **Numbers: three at most, and none bare.** Walk each through successive values with the operation in words, or convert it to a human unit, and cut any the reader cannot feel. A number spends the budget when the reader has to weigh it: a measurement, a proportion, a rate, a version, or a count offered as a finding. An anchor that is a number counts against the three. Plain enumeration of what the subject is made of, such as five weeks or four labs, spends nothing.
- **New terms: six at most.** Count every noun phrase the reader cannot yet define, including a name you coined for a role or a step.
- **Deflations: two at most**, meaning a claim understated within two sentences of making it.
- **Honesty hedges: two at most**, and one of them is the simplification flag § Never requires.
- **The wrong model: one at most** (§ The wrong model).

**A source the book was given spends nothing.** Naming the file, page or section a claim came from is attribution, not an anchor, so a citation never costs the budget, however often § Provenance calls for one.

**A set of figures from a source spends nothing either, and goes in a table.** Where a source publishes a set the reader will need whole, such as four assignment weights or a session grid, reproduce the whole set in a table. Never narrate two of its figures and drop the rest: a partial set reads as complete. The three-number budget is for quantities the prose asks the reader to weigh.

**Every budget is per chapter, and none of them pools.** Six terms, two anchors, three numbers, one analogy and one wrong model are what each chapter gets, whether the book has eight chapters or twenty. The outline's ledgers catch a chapter spending a neighbour's allowance.

**Prerequisites** go in the clause that needs them, with one exception. If a part cannot start until the reader holds something they lack, write one aside of 130 words at most, immediately before that part. Teach the prerequisite and nothing else, with no proper name and no date of its own. It sits inside the part that needs it, never as a section of its own.

In the sentence after the aside, name the idea that needed it. Something an earlier chapter taught is not a prerequisite. A chapter that wants a second aside has two subjects, which is a finding to report to the outline.

**The sober paragraphs.** After the last part, two paragraphs: where this bites in practice, what it costs when it goes wrong, and where you would not reach for it. The first opens the cost and the second settles it, because an alarm left open costs the reader's trust. No pitch, and no ladder of stakes.

### Headings

The chapter's title is an H1 on the file's first line. It is the title the outline assigned and the one the binder reads, and nothing else in the chapter is an H1.

Each part has one H2. The opening paragraph, the sober pair and the close take no heading. Two other H2s are not parts: `## In short`, directly under the header table, and `## Suggested reading`, which ends the chapter. The checker leaves both out when it counts parts.

- **A heading is never a term's first appearance.** A term is glossed in the sentence that first uses it, and a heading is not a sentence. Name the part in ordinary words, or in a term this chapter or an earlier one already glossed.
- **Every budget counts a heading.** A checkable name in one spends an anchor, and none of the building words in § Never may appear in one.
- **Six words at most**, saying what the section is about, not what the reader will get from it. No numbering, no gerund labels, and nothing that announces.

The profile file sets the rest: what a heading should say, and whether a part may have H3s.

### The chapter header

Directly under the H1, before any other content, a chapter has a table. It serves the reader who is not reading the argument tonight but wants to know what the chapter settles and whether to trust it.

| Row | Holds |
|---|---|
| **This chapter** | What it covers, in one or two sentences, plus the scope it belongs to where the book has one (a week, a session, a subsystem). |
| **Act on this** | What the reader would do differently having read it, in one or two imperative sentences. Where the chapter asks nothing of the reader, say what it settles; never invent an action. |
| **Draws on** | The sources the chapter's claims rest on, each specific enough to open: a file with its section, a document with its page. Only what the claims rest on, not everything consulted. |
| **Fills in** | What the chapter supplies that the sources do not, stated plainly. Where the chapter is mostly filled in, say so. |

A guide chapter has no `This chapter` row, because its `## In short` does that job (`guide.md § The chapter header`).

- **The header is not a summary, and it never replaces the close.** It says what the chapter is for. A header that could stand in for the chapter means the chapter has become a briefing.
- **Write it last, from the finished chapter.** Written first, it becomes a plan and drifts from what got written.
- **It takes no paragraph tag and no provenance mark.**

### In short

Directly under the header table and before the opening paragraph, an H2 reading `## In short`. It serves the reader who has not read this chapter, or who read the chapters before it long ago. It has two pieces, in order: a carried-in line, then a summary. The profile file sets the rules for the summary.

```markdown
## In short

Carried in: **star schema** (ch. 11), a fact table in the middle with dimensions one join away.
**Grain** (ch. 12), the one sentence saying what a single row means.

A feature store looks like a new kind of thing, and it is the same shape you drew last week...
```

The carried-in line names the concepts this chapter picks up from earlier ones, so the reader has the words back before the prose uses them.

- **It is the section's first paragraph, and it opens with the literal `Carried in: `.** The checker finds it by that prefix and nothing else.
- **Three terms at most, and the checker enforces it.** It is a ceiling, never a target. Choose from this chapter's row in the outline's term ledger, and take only the terms this chapter's claim rests on. Chapter 1 has none, and never invent an entry to fill the line.
- **Word each entry from its glossary entry**, not a fresh definition, and cite it as `(ch. N)`, the glossary's own format.
- **A chapter that carries nothing in has no line at all**: not `Carried in: none`, and not a bare prefix.
- **Write it last, in the same pass as the glossary**, from the finished chapters.

The section takes no paragraph tag, no provenance mark and no source reference, and its words do not count as prose. `check-book.sh` reports their total on its summary line.

### Paragraph tags

In a tagged book, every prose paragraph opens with `[<chapter>-<n>] ` and then the prose: the chapter's own number, a plain hyphen, and a count that runs 1, 2, 3 through the chapter and restarts in the next one. The opening paragraph is 1. No leading zeros on either half.

Headings take no tag. Neither does a list, a table, a fenced block, a figure reference, a callout, `## In short` or `## Suggested reading`. None of them advances the count, so a table added to a finished chapter renumbers nothing.

**A revision adds a paragraph with a letter, so no tag moves.** A paragraph added after `[5-12]` is `[5-12a]`, the next one `[5-12b]`, and `[5-13]` is untouched. The letters run a, b, c with no gap, and nothing comes before a chapter's first paragraph. A chapter written fresh has no lettered tags: only `/updatebook` adds them, and a rewrite of the chapter renumbers them away (`updatebook/SKILL.md § When to stop editing in place`).

`SKILL.md` owns whether a book is tagged at all. The checker strips tags before it counts words.

### Provenance

A chapter records where its sentences came from in three places.

**In the prose, where it matters.** A claim resting on a source names that source in the sentence carrying it: the grading outline's own checklist, the syllabus on page four. Attribute at the point of use, and use the source's own words where the wording is the claim. Where a passage goes beyond the sources and a reader could act on the wrong authority, say so in a clause: *no course document explains this*. Do not hedge every sentence. The profile file may narrow this rule.

**In the header**, in the Draws on and Fills in rows.

**Beside every unit, for the tooling.** After each paragraph, table, list, fenced block and callout, on a line of its own:

```
<!-- src: course-outline § Session Calendar; syllabus p. 4 -->
```

- **Name the sources the unit rests on**, separated by semicolons, each specific enough to find. A unit that is the model's own knowledge is `<!-- src: fill -->`. A unit that is both names its sources and adds `fill` for the rest: `<!-- src: syllabus p. 4; fill (the consequence) -->`.
- **It is stripped at bind time**, so no reader sees it. That is what lets it be exhaustive.
- **It advances no paragraph number** and does not count as prose.
- **It is the only comment a chapter has, and it is one line.** `check-book.sh` enforces both.
- **The header, `## In short` and the concept list take no mark.**

### Suggested reading

Every chapter ends with `## Suggested reading`, an H2 after the close and the last thing in the file. It lists concepts and terms, never links: each item is a thing to search for, with one clause saying why the reader might.

```markdown
## Suggested reading

The course documents name these and define none of them. Each is a term to search, with the reason.

- **Participation constraint, total and partial**: the formal name for optionality, and the vocabulary a textbook will use where this course says nothing.
```

- **The items are the gaps this chapter declined to fill**, which the outline's source ledger names. It marks the edge of what the book covers, not everything adjacent.
- **Three to six items.**
- **A short lead sentence before the list** says what kind of gap these are. It takes no tag.
- **Never name something the book covers.** Check against the outline's term ledger.
- **A chapter that is mostly filled in still has one.**
- **No URLs anywhere.**

The section takes no paragraph tag and no provenance mark, and none of it counts as prose.

### The plan

Write the plan before any prose. It is working notes: never shown, never quoted. The prose does not start until every line below has an answer.

**The outline has already made part of the plan, and that part is given.** The terms this chapter glosses, the terms it may use freely and the anchors it owns are fixed, because the whole book is drafted against them at once. The profile file lists anything else the outline fixes. Take all of it as it stands.

**The claim, in one sentence.** What the reader believes at the end of this chapter that they did not at the start. The close has to land it. A claim naming two things means two subjects, and one of them goes. A claim that will not fit in one sentence means the outline split the chapter wrongly: report it.

**The concepts, in dependency order.** What the reader has to hold before the next thing can work. Order by that dependency, never by how the subject is usually taught. Start from what the outline says earlier chapters taught; for chapter 1, that is nothing.

**The cuts.** Anything you cannot place in the order comes out. That is a normal result: a concept with no job in this argument belongs to another chapter.

**One job per part.** The job is the sentence the reader takes away from that part. Write the part's heading here too. A job that needs two nouns to name it is two parts.

**The allocation.** Which paragraph holds each anchor, each number, each new term's first use, and the wrong model if the chapter has one. Decide it here, once.

Then read the concept order against the claim. If the order does not arrive at the claim, the shape is wrong, and fixing it now costs one line.

### Voice

Second person, plain words, contractions, and present tense for scenes. Warmth comes from word choice and rhythm.

- **Mark the relation between two sentences wherever it is not obvious**, with ordinary words: but, so, because, and yet, for example, which means, the cost is. A marker tells the reader how to attach the next sentence before they read it. It is not an announcement, and § Never does not ban it.
- **45 words is a hard stop for a sentence**, and there is no target for the mean. When a sentence runs long, split the one doing the most, and let the break do the emphasis. A clause hung on after a colon, an "and" or a "which", once the point has landed, belongs in the next sentence.
- **Vary sentence length on purpose.** Uniform length is the loudest machine tell.
- **No ordinal sequencing in prose**: nothing that numbers a step or scaffolds the prose into first, second and finally. An ordinal inside a thing's name stays, so third normal form and the fourth lab are fine.
- **Watch for prose sliding into lists.** Three or four parallel items inside one sentence is a list in disguise. Hold those to about three in a chapter, and never two in one paragraph.

### Reference

A word that points must have something to point at by the time the reader reaches it.

**A definite noun phrase claims the reader has met the thing.** "The diagram" tells the reader this is one they already know. The first time a chapter names something with "the", one of three must be true. The noun appeared earlier in this chapter; the sentence glosses it as it goes; or the reading situation supplies it, meaning the reader, the course, the week, the page or the room. Otherwise use "a": *a diagram*, then *the diagram* after. This bites hardest in the opening paragraph.

**A sentence opening on this, that or it points at the sentence before it.** Where the thing it means is further back, or is a whole paragraph, name the noun. Three cases are not this defect, and must not be rewritten:

- **The label landing after the behaviour.** "That is optionality, whether an end is allowed to be empty" is § Glosses at work.
- **A cleft.** "What matters here is the timing" moves the emphasis and points at nothing.
- **A demonstrative with its noun.** "That instinct" and "both dates" are already resolved.

**An example introduces its pieces before it uses them.** Name each piece the first time it appears, in the order a person would meet them. "Room 12 says nothing by itself, because the building next door has a room 12" asks the reader to build a street and a numbering scheme from one definite article. Set the scene in a clause, then run it.

**These rules add words.** Where a chapter has to come down, the words come out of the walk or the second anchor, never out of a gloss or a hedge. § Before sending has the cut order.

### Never

**Markdown.** Prose paragraphs by default. No italics. No block quotes, except the callouts the profile file allows. No headings beyond those § Headings and the profile file describe. No other markdown: no links, footnotes, horizontal rules or inline HTML, and no image except a figure reference on a line of its own. A list, a table, a fenced block, a bold phrase or an inline code span is allowed only where the reader would lose something if you wrote it as prose:

- **a table**, when two or more things are compared on the same axes, or to reproduce a set a source publishes whole;
- **a list**, when the items are a real set the reader has to hold at once;
- **a fenced block**, when the exact characters matter: a command and what it printed, a schema, an error as it appeared. Keep it to the lines the point needs, and name the thing in the prose first, so a reader who skips the block still has the idea;
- **bold**, when one phrase has to survive a reader who is scanning;
- **an inline code span**, for a file, a path, a column, a flag or a command the reader would type.

The mechanism walk is never any of these: it stays chained prose. A chapter that breaks into bullets every page has become a briefing.

**Punctuation and stock phrases.** No em dash; the colon is usually the kindest punctuation you have. Never open a sentence with "Now,", and never use "right?". Never write "In conclusion", "To summarize", "Key takeaways" or "TL;DR".

Never claim that what follows matters instead of saying it: no "worth noting", no "importantly", no "the key point is", no sentence whose whole content is that the next one counts. This bans empty emphasis and nothing else: every relation marker in § Voice stays available. Never greet, never promise what the reader will learn, and never close on a call to action.

**One name per thing.** Never cycle synonyms. A handler that becomes the processor and then the callback tells the reader there are three of them. Repeat the exact noun every time, even where the repetition reads badly. This holds across the book: a term an earlier chapter owns is used in that chapter's words. Saying the core idea again in different words after the walk is a different move, and it stays.

**No formulas.** "X is the Y of Z", "X becomes a trap", "the language of" and "the currency of" sound precise and hide the claim. Write the claim. The same goes for openers that promise a deeper point ("The real question is", "at its core", "fundamentally", "what really matters") and for staged candour ("Honestly?", "Here's the thing", "Look").

**No generated-prose tells.** No participle hung on the end of a sentence to add a claim and no information: "ensuring reliability", "highlighting its importance". No "from X to Y" unless X and Y sit on one real scale. No "serves as", "stands as", "boasts" or "features" where "is" or "has" works, and no "not only X but Y" or "it's not just X, it's Y". Never use delve, crucial, pivotal, vibrant, intricate, tapestry, showcase, underscore, testament, seamless, robust, foster, leverage, or landscape used abstractly.

**Nothing invented.** Never invent a person, date, quote, statistic or incident. Name and date at 95% confidence or drop it; with a solid name and a shaky year, hedge the year to its decade, never the reverse. Flag one simplification plainly in each chapter.

**A number keeps the scope it was measured over.** A count taken across five files is a fact about those five, never about all nine. Before a number reaches the page, name the population it covers and make the sentence say that population. If you cannot state the population from the record in front of you, cut the number.

**This file's vocabulary never reaches the page.** Part, hinge, walk, anchor, aside, handoff, thesis, deflation, spine and mode are words for building a chapter, never words in one. The ban covers the word and its inflections in any sense: an industry that walks a claim back leaks as surely as a paragraph that walks a mechanism, so write that it backs away. Name the actual thing.

### Before sending

**Count; never estimate.** Sentences first, since that ceiling is the one that gets missed.

- No sentence over 45 words, and no paragraph over 90.
- Six new terms at most, each glossed at first use. Two anchors at most. Three numbers at most.
- One H1, on line 1, and no other. One H2 per part, and none over the opening, the sober pair or the close. No heading naming a term the prose has not glossed yet.
- Every list, table, fenced block and bold phrase justified by what a reader would lose as prose, and any without an answer turned back into prose.
- None of the building words in any inflection, and none of the generated-prose words in § Never.
- In a tagged book, every prose paragraph tagged, the chapter half this chapter, and the count running from 1 with no gap and no repeat.

**List the budgeted things; never recall them.** Write out every checkable name, every number and every new term with the paragraph it sits in. Mark the names and numbers the argument rests on, then read the ceilings off that list.

Check each new term against the outline's term ledger: a term an earlier chapter owns is free, and a term no chapter owns is one you invented. Copy out the longest sentence of each part, and the anchor sentence, and count each one word by word, because rhythm hides length. Beside every number, write the artifact it came from and the population it covers, and confirm the sentence says that population.

**The resource-first checks**, which none of the counts above catches:

- **Every unit has a provenance mark**, naming something a reader could open or saying `fill`. Walk the file top to bottom: the mark most often forgotten is the one after a table.
- **Every sourced claim is checked against its source**, not against whether the source exists. Open the file, find the sentence, and confirm it says what the paragraph says. A resolvable citation for a claim the source never made is the defect no checker can see.
- **The header's rows match the finished chapter.** Draws on names every source the marks name and nothing else, and Fills in is true of what got written.
- **The concept list names nothing the book covers**, checked against the term ledger, and every item is a term, not a link.
- **Each carried-in entry is worded from its glossary entry**, not freshly defined, and names a term this chapter's claim rests on, not merely one of the first three on its ledger row.

**Check the chapter against the plan**, the only record of what you set out to write. Every part still does its job, nothing the plan cut has crept back, and the close lands the claim.

**The reference sweep.** Write the list out: the writer is the one person who cannot feel a missing referent.

- **Every "the" that names something for the first time**, with its licence beside it: earlier in this chapter, glossed here, or supplied by the situation. One with none is the defect. Start with the opening paragraph.
- **Every sentence opening on this, that or it**, with the noun it points at and how far back that noun sits. Further than the previous sentence is the defect, except for the three cases in § Reference.
- **The analogy, if the chapter spent one**: a person in it, its pieces named before they are used, and the mapping back inside the same paragraph.
- **Every paragraph's first sentence against the paragraph before it**, with the seam device written beside each (§ Seams). A seam with none is the defect, and a column that reads the same all the way down is the other one. A first sentence that only makes sense once its paragraph is finished is an epigram: move its claim onto nouns already on the table, and keep the sentence.

**Two more tests.** Read every paragraph's first sentence in order: together they should compress the chapter, with no two neighbours built the same way. Then list every recurring thing the chapter names, with each word used for it: one thing with two names is the cheapest defect to introduce and the hardest to catch by reading.

Then run the checks in the profile file.

**When a chapter has to come down, cut whole paragraphs in this order:** the second anchor, the analogy, the last part's walk down to a single step, then the sober pair folded into one, keeping the half that settles it. A chapter found carrying more than its one claim needs is what triggers a cut; no word count does. Never cut the aside, the header, the concept list or a provenance mark.

**Turning a passage into a table does not shorten a chapter.** A paragraph reformatted as rows is the same words with the argument taken out. Reproduce a set the source publishes; never shred your own prose into one. A chapter that has outgrown its one claim means the outline is wrong: report it so the chapter can be split.
