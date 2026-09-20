# Writing a chapter

Every rule for the prose inside one chapter. A chapter agent reads this file and follows all of it. `SKILL.md` owns the book around the chapter: the outline, the filenames, `book.json`, the checker and the bind.

The rules were forked from the `/ne` skill and are maintained here now, so a chapter agent needs nothing outside this folder. `NOTES.md` records where the numbers came from and which of them were measured rather than asserted.

## Rules

**The reader.** One person who has to be able to do something soon and has not got long to get there. Fully attentive, with little working memory to spend, reading under time pressure rather than at leisure. They read the chapter once, straight through, and then come back to it later wanting one fact out of it. **Both readings have to work**, and they pull in opposite directions: the first wants an argument that carries them, the second wants an address they can find. That is what the chapter header, the provenance marks and the concept list are for, and it is why nothing in this file asks the prose itself to become a briefing. Every sentence either lowers what they have to hold or makes the next one land, and a sentence doing neither goes.

**The sources come first.** A chapter is written against the resources the book was given, and the model's own knowledge fills what those leave out. The reader has to be able to tell which is which, because the two age differently: a sourced claim is fixed by its resource, and a filled-in one is the place a version, a default or a name goes stale. Attribute in the prose, mark it for the tooling, and never blur the two to make a paragraph read better. **A chapter may be mostly filled in** where the resources are thin on its topic; that is a fact to state, not a defect to hide.

**What the reader arrives with.** Chapter 1 is the one chapter a reader can arrive at cold, and it stands alone in full: nothing else open, no earlier chapter, no thread, and nothing naming the subject before the prose does. Everything that chapter needs is inside it, and it opens the book without announcing that it is doing so. Every later chapter may assume the chapters before it, and may assume only what the outline grants it: the terms an earlier chapter glossed, and the noun the previous chapter closed on. **A handoff noun is a pointer, not a definition, and the two grants are independent.** Where the noun this chapter opens on names something no earlier chapter glossed, this chapter glosses it inside the sentence that first uses it, in the opening paragraph, and it costs nothing against the six new terms because the outline assigned it to nobody. Check this before drafting: the noun is on the outline's handoff row, and the term ledger either names it on an earlier chapter's row or it does not. Nothing else carries over, so a later chapter that reaches back for an example three chapters old either re-earns it in a clause or drops it. A subject that cannot be made self-contained inside one chapter is one to narrow, and at book scale the narrowing is the outline's job rather than the chapter's.

**Length.** A chapter is as long as it has to be to do its job, and no longer. There is no ceiling, no target, and no estimate made before drafting: the subject and the reader decide where it ends. There is no floor either, so under-filling is fine and padding is not. What governs every sentence is the rule at § The reader, that a sentence either lowers what the reader has to hold or makes the next one land, and one doing neither goes. That test does the work a word count was standing in for, and it applies at any length.

**Length still carries a signal, and the signal is read rather than thresholded.** A chapter that runs well past its neighbours is usually the outline drawing one chapter too wide, which is a finding to report back rather than write around; § Prerequisites and § The plan already say that about an aside that wants a second one and a claim that will not fit in one sentence. Reading is what separates a subject that genuinely needed the room from a chapter that lost its shape, and no number could tell you which one you have.

A table, a list and a fenced block are counted apart from the prose, because they are consulted rather than read line by line, and a table of ten facts does not cost ten sentences' worth of attention. `check-book.sh` reports the two figures separately and fails on neither. The paragraph tags and the provenance marks are not prose either and are not counted; the checker strips both before it counts.

**Shape.** Three parts, or two when the subject is one mechanism and one complication. Never one, which has nothing to hinge on, and never four, which gives the reader a fourth handoff and a fourth named weakness to carry. The parts carry the chapter and the frame sits small around them: an opening paragraph, two sober paragraphs and a close. With three parts the first runs longest on paper only because the anchor and the wrong model take roughly 160 words off the top, and carrying none of that freight is why the middle part is where the fullest mechanism belongs.

Paragraphs run 40 to 90 words, one idea each, and 90 is a hard stop. The first sentence carries the claim **in terms already on the table**: a claim resting on a noun the reader met two sentences ago lands, and the same claim resting on a noun the paragraph is about to introduce is an epigram the reader can only decode afterwards.

**On the table means the chapter so far, not this paragraph**, so what a paragraph's last sentence leaves standing is what the next one's first sentence has to work with, and the exit is written with that in mind rather than left to fall where it lands. A first sentence picks up something the previous paragraph left standing, by naming it again or by pointing at it with the noun attached (a box like that, after that point), or it carries a marker saying how it attaches, and the two together are often the best seam on the page: "But the item is not where the defect sits" does both in eight words. A seam with neither is where the reader stops, and it is the commonest seam in a chapter written without this rule. What to avoid is sameness across the chapter rather than doubling at a seam, since fifteen or twenty seams chained noun to noun read as chanting and as many marked ones read as a machine narrating itself, so vary which device carries each one. The part and chapter seams are fixed by the outline and are not yours to choose (see § Every part does five things); these are the fifteen or twenty the outline says nothing about, and they are where a reader who understood every sentence still cannot say what the chapter argued.

Where to break is the other half of it. Break where the direction turns, and **name the turn where it is not obvious**: a break that reverses, qualifies or prices something takes its marker in the first clause after it, because a reader who has to infer the relation infers it by reading the paragraph twice. At most once, one sentence may stand alone as a paragraph, where the chapter turns from how the thing works to what it costs; a second spends the first one's effect, and none at all is fine. That sentence is the most compressed thing on the page and is the one most likely to be reread, so it is a choice rather than a quota.

**Every part does five things.** Name what it's about inside its first two sentences, and open the later parts on the exact noun the previous one ended on, so the handoff carries the reader's memory for them. Walk the mechanism in three to five steps, plain verbs, no notation, chained by what causes what and never numbered: a numbered step says where it sits, a chained step says why it follows, and why is what you're teaching. Gloss every term the outline assigns this chapter inside the sentence that first uses it, as a clause, never a long parenthesis, never held over; where the term is intimidating, describe the behaviour and attach the label after. Say the core idea again in different words, once, after the walk. Then say in plain words what this part established, in one sentence a reader could carry out of the chapter. **Plain means the sentence works on its own terms**: every noun in it has appeared already, and a reader who has just finished the part understands it without reading back. A compressed line that only decodes once you know the part is an epigram rather than a portable sentence, and this is a place where spending a few extra words pays. Then exit on the weakness that breaks it, named with the specific noun for what breaks, inside the paragraph holding the win. Never exit on success.

**Spend these deliberately, allocating each in the plan below rather than while drafting.** Two anchors at most, real and checkable and tied to the mechanism across two sentences rather than one, since the name, its role and the case it explains never fit in one sentence here. What spends an anchor is a name the argument rests on, whether a person, an institution, a product, a file, a command and what it printed, or a number: check it, find it wrong, and a claim in the chapter has to be revised. A name that only says what the chapter is about spends nothing, the company whose system you are explaining or the language it is written in, since finding that one wrong tells the reader they are holding a different chapter rather than a broken one. Count every checkable name on the page rather than the ones you meant to spend, then charge the ones the argument rests on. The first is required and early: a named person with their role, or an institution with the year it acted, where one genuinely exists; otherwise the specific case, file, failure or number. The second is optional and belongs late, where consequence would otherwise be pure assertion. The outline's anchor ledger says which anchors this chapter owns and which are spent elsewhere in the book, and an anchor another chapter already spent is not available here.

**A source the book was given spends nothing.** Naming the file, page or section a claim came from is attribution, not an anchor, however checkable it is. The budget exists to keep unearned checkable names off the page, and a citation is the opposite case: it is the reader's route back to the authority, and the whole value of a resource-first book is that it points. Cite the source every time the claim rests on it, in as many paragraphs as need it. What still spends an anchor is a name the **argument** rests on rather than one the sourcing does.

One full wrong model, only ever one, in the first part where the reader still holds it: pose the question they'd ask, state the fix they'd reach for in their own words, concede the part of it that works, then let it fail on one concrete case. The concession isn't optional, since a naive fix knocked down without it reads as a strawman and the reader defends instead of updating. That costs about 130 words and asks the reader to hold a picture they then have to discard, which is why it doesn't repeat; later parts get the cheap form, two wrong pictures and then the real one. Those 130 words will not fit one paragraph against the 90-word stop, so break them across two: the question, the fix and the concession, then the failure. The break lands where the direction turns, which here is the moment the fix stops working, so it falls where the rule above would put it anyway.

At most one analogy, a physical scene with a human actor mapped back in running sentences inside the same paragraph, and none when the mechanism is already concrete. This one doesn't rise with length: a second scene makes the reader hold two pictures at once. At most three numbers and no bare ones, each walked through successive values with the operation in words or converted to a human unit; cut any number the reader can't feel. What spends the budget is a quantity the reader has to weigh: a measurement, a proportion, a rate, a version, or a count offered as a finding, and an anchor that is a number counts against the three. Plain enumeration of what the subject is made of spends nothing, neither one of the three nor an anchor, and needs no walking through successive values: the five weeks of a course, the four labs inside it. The budget exists to keep unfelt quantities off the page, and nobody needs help feeling five weeks.

**A set of figures reproduced from a source spends nothing either, and belongs in a table.** Where a resource publishes a set the reader will need whole, four assignment weights or five modules or a session grid, reproduce it rather than narrating the two figures the budget would allow. Splitting a set costs the reader the thing they came for, and a partial quotation of a table is the worst of both: it reads as complete and is not. The three-number budget governs the quantities the **prose** asks the reader to weigh, and a figure sitting in a reproduced table is not one of them. At most six new terms in the whole chapter, counting any noun phrase the reader can't yet define, including a name you coined for a role or a step. A term an earlier chapter glossed is used plainly and counts against nothing. Two deflations at most, understating a claim within two sentences of making it. Two honesty hedges at most, one of which is the simplification flag required below.

**Every budget is per chapter and none of them pools.** Six terms, two anchors, three numbers, one analogy and one wrong model are what this chapter gets, whether the book runs to eight chapters or twenty. Spending a neighbour's allowance is what the outline's ledgers exist to catch.

**Prerequisites go in the clause that needs them,** with one exception. If a part genuinely cannot start until the reader holds something they don't, take a single aside of no more than 130 words, immediately before the part that needs it. Teach the prerequisite and nothing else, with no proper name and no date of its own, and return by naming the idea that needed it in the first sentence after, so the reader feels the debt paid rather than a thread dropped. It belongs to the part that needed it rather than standing as a section of its own. Something an earlier chapter already taught is not a prerequisite and takes no aside. If the chapter wants a second aside it is carrying two subjects, which is a fact about the outline rather than about the chapter: report it rather than writing around it.

**Open.** Chapter 1 opens the book, in one paragraph, on one of four: something happening this minute in the reader's body or device that already is the subject; two or three things they do without thinking, then the reveal; the claim that the subject is older, closer or stranger than they assume; or the concession that it's overkill and the answer turns on their situation. Every later chapter opens on the noun the previous chapter closed on, which the outline fixed, with no fresh hook and no re-introduction of the subject or of the book. Either way, reach the concrete thing by the second sentence, and end by naming the question the first part answers without saying that's what you're doing. No greeting, no promise of what they'll learn.

**The sober paragraphs,** after the last mechanism: where this bites in practice, what it costs when it's wrong, where you wouldn't reach for it. The first opens the cost and the second settles it, because an alarm left open costs you the reader's trust. No pitch, no ladder of stakes.

**Close** in one paragraph: one portable sentence for what this chapter established, the verdict, where "it depends" is legitimate provided you say what on, then the noun this chapter hands forward in the last clause, which the outline fixed and the next chapter opens on. Don't replay the parts. The reader finished them a minute ago, and each already ended on its own sentence. Only the last chapter of the book closes the book, and it is the one chapter that hands forward nothing.

### Headings

The chapter's title is an H1 and it is the first line of the file, before the prose. It is the title the outline assigned and the title the binder reads; nothing else in the chapter is an H1.

Below it, each part carries one heading and nothing else does, so two parts means two headings and three means three. The opening paragraph, the sober pair and the close carry none, and there is no level below H2. Two H2s are not parts: `## In short`, which opens the chapter directly under the header table, and `## Suggested reading`, which closes it. Both are described below, and the checker takes both out before it counts the parts. A heading marks where a part begins rather than labelling everything below it, which is why a chapter can end several paragraphs past the last one without wanting another.

A heading is never a term's first appearance. A term is glossed inside the sentence that first uses it and a heading is not a sentence, so a heading naming something the reader cannot yet define hands them the label before the behaviour. Name the part in ordinary words, or in a term this chapter or an earlier one already taught. Every budget still counts it, because a heading is on the page: a checkable name there spends an anchor exactly as it would in a sentence, and none of this file's own vocabulary may appear in one.

Write it as a noun phrase of six words at most, saying what the part is about rather than what the reader will get from it. No questions, no gerund labels, no numbering, nothing that announces. It has to be redundant, so that a reader who ignores every heading loses nothing: the part's first two sentences already name what it is about, and still open on the noun the previous part ended on. A heading carrying something the prose does not is a heading that rewards skipping the prose. The handoff keeps working underneath, which is the whole defence here, since a reader who jumps one lands on a noun the part before it defined and finds the skip failing quickly rather than quietly.

### The chapter header

Directly under the H1, before the first paragraph, a chapter carries a four-row table. It is the reader's second reading made possible: the one who is not reading the argument tonight but wants to know what this chapter settles and whether they can trust it.

| Row | Holds |
|---|---|
| **This chapter** | What it covers, in one or two sentences, plus the scope it belongs to where the book has one (a week, a session, a subsystem). |
| **Act on this** | The thing the reader would do differently having read it. One or two sentences, imperative. Where a chapter genuinely asks nothing of the reader, say what it settles instead; do not invent an action. |
| **Draws on** | The sources this chapter rests on, each specific enough to open: a file with its section, a document with its page. Not a list of everything consulted, only what the chapter's claims rest on. |
| **Fills in** | What the chapter supplies that the sources do not, and plainly that the sources do not. Where a chapter is mostly filled in, this row says so. |

**The header is not a summary and never replaces the close.** It says what the chapter is for; the close still lands the claim. A header that could stand in for the chapter means the chapter is a briefing.

**Write it last, from the finished chapter.** Written first it becomes a plan, and the drift between a plan and what got written is exactly the thing a reader trusts it not to have.

The header takes no paragraph tag and no provenance mark. It is a table, so it advances no paragraph number, and its sources are the ones its own rows name.

### In short

Directly under the chapter header table and before the opening paragraph, an H2 reading `## In short`. The header table serves the reader who has read the chapter and wants a fact back out of it; this section serves the one who has not read it at all, or who read the chapters before it a month ago and no longer holds what the handoff was carrying.

That second reader is why it exists. Every later chapter opens on the noun the previous chapter closed on, and that noun arrives with a definite article already attached (§ Reference). Read in order it lands. Read by jumping to one chapter, which is how a finished book is actually used, the article points at a referent the reader never had, and the opening paragraph is the worst place in the chapter to lose them.

It does two things, in order: a carried-in line, then the walk.

```markdown
## In short

Carried in: **star schema** (ch. 11), a fact table in the middle with dimensions one join away.
**Grain** (ch. 12), the one sentence saying what a single row means.

A feature store looks like a new kind of thing, and it is the same shape you drew last week...
```

**The carried-in line** names the concepts this chapter reintroduces from earlier ones, so the reader has the vocabulary back before the prose starts spending it.

- **It is the section's first paragraph and it opens with the literal `Carried in: `.** The checker finds the line by that prefix and by nothing else. Left to infer it, the checker would have to take the first paragraph carrying a `**term** (ch. N)` pattern, which quietly swallows a walk that happens to open on a glossed term and quietly skips a carried-in line whose first term was typed without its bold. Both failures read as a clean pass. The prefix costs one stiff phrase at the top of a section the reader is scanning anyway, and buys a parse that cannot drift.
- **The candidate set is the outline's term ledger,** which already records, per chapter, the terms an earlier chapter glossed and this one may therefore use plainly. It is the record to draw from, and it is far too long to use whole.
- **At most three, and the checker enforces it.** Above three it is a failure rather than a note. It is a ceiling and never a target: trim to the terms this chapter's own claim actually rests on, take zero where the chapter genuinely reintroduces nothing, and never invent an entry to fill the line. Chapter 1 always has none, having nothing behind it. The count is enforced because every chapter has more candidates in the ledger than it needs, and an unenforced ceiling is how this line grows back into the header table it exists not to duplicate.
- **The words come from the glossary entry rather than a fresh definition.** The glossary already holds `**term** (ch. N) definition` and already describes its job as the reminder rather than the teaching. A third wording beside the chapter's own gloss and the glossary entry is how a book comes to say three slightly different things about one term.
- **Cited as `(ch. N)`, matching the glossary's own format.** A paragraph tag is a more precise address and a more brittle one, since renumbering a chapter moves it (§ Paragraph tags).
- **A chapter that carries nothing in omits the line entirely.** Not `Carried in: none`, and not a bare prefix. A section whose first paragraph does not open with the prefix is a chapter carrying nothing in, which is legal and common, and the checker reads it that way rather than as a fault.
- **Written last, in the same pass as the glossary,** and from the finished chapters, for the same reason the header is written last: written first it is a plan, and the drift between the plan and the chapter is exactly what this section promises not to have.

**The walk** is what the chapter argues, in the order it argues it, for someone who has not read it.

- **The walk may use no term this chapter glosses.** Carried terms are exempt: a term the line above has just restored is on the table, and the walk spends it plainly. The `This chapter` header row may say "the three levels" and "cardinality", because its reader has read the chapter. The walk says "how much of the database is in view" and "how many at most, and is none allowed". Without this rule the two converge and every chapter carries two summaries in different registers.
- **This is the describe-the-behaviour-then-attach-the-label move with the label left off**, which § Every part does five things already requires of an intimidating term. The difference is only that the walk never gets to the label.
- **The rule is written and reviewed, and it is not checked by script.** Follow it while drafting, and confirm it afterwards by reading the section against this chapter's row in the term ledger. Nothing in `check-book.sh` enforces it, by decision rather than by omission, so a violation is caught by reading and never by a non-zero exit. The record it would check against is the outline, which the checker does not read, and the comparison does not survive being scripted in any case: matching substrings flags a walk that never used the glossed term, and matching whole words misses every inflection of one that did.

**Length is uncapped, and the word count is reported rather than thresholded.** `check-book.sh` carries the section's count on its summary line, the way the prose and structure figures are already carried separately, so drift stays visible without a number deciding anything. The rule at § The reader governs here as it does everywhere else.

The section takes no paragraph tag, no provenance mark and no source reference. It advances no paragraph number, so a section added to a finished chapter does not renumber the tags other files cite. It names no source because it has none to name: it is derived from the finished chapter rather than from anything the book was given, which is the same reason the concept list carries no mark. Its words are not counted as prose.

### Paragraph tags

In a tagged book, every prose paragraph opens with `[<chapter>-<n>] `, then the prose: the chapter's own number, a plain hyphen, and a count that runs 1, 2, 3 through the chapter and restarts in the next one. Count the opening paragraph as 1. No leading zeros on either half.

Headings take no tag, and neither does a list, a table, a fenced block or a figure reference: none of them is a paragraph, and none of them advances the count. A tag is an address other files cite, so a table dropped into a finished chapter must not renumber everything after it.

The tags are not prose, and the checker strips them before it counts (§ Length). `SKILL.md` owns whether a given book is tagged at all; when it is, this is how a chapter carries them.

### Provenance

Three marks, because three different readers need to know where a sentence came from and they want it at three different grains.

**In the prose, where it matters.** A claim that rests on a source names that source in the sentence carrying it: the grading outline's own checklist, the syllabus on page four, the session grid. Attribute at the point of use rather than in a footnote, and use the source's own words where the wording is the claim. Where a stretch of the chapter goes beyond what the sources say, say so in a clause, in the reader's interest rather than as a disclaimer: *no course document explains this*, *that is standard practice rather than anything the syllabus asks for*. Do this where a reader would otherwise act on the wrong authority, not on every sentence. Blanket hedging is the failure this replaces, not the form it takes.

**In the header,** the two rows above: what the chapter draws on, and what it fills in.

**Beside every unit, for the tooling.** After each paragraph, table, list and fenced block, on its own line:

```
<!-- src: course-outline § Session Calendar; syllabus p. 4 -->
```

- **It is stripped at bind time and no reader ever sees it.** That is what lets it be exhaustive where the prose is selective.
- **Name the sources the unit rests on**, separated by semicolons, each specific enough to find. Where a unit is the model's own knowledge, the whole mark is `<!-- src: fill -->`. Where it is both, name the sources and add `fill` for the part that is: `<!-- src: syllabus p. 4; fill (the consequence) -->`.
- **It advances no paragraph number and is not counted as prose.** A mark dropped into a finished chapter must not renumber the tags other files cite.
- **It is the only comment a chapter carries,** and it is one line. `check-book.sh` enforces both, because a comment left open swallows the rest of the file and a mark that misses the grammar is invisible to the sweep that asks what a book filled in.
- **The header and the concept list take no mark.** The header names its own sources; the concept list is by definition what the sources did not cover.

**Why the exhaustive one exists at all:** a sourced claim is fixed by its resource, and a filled-in claim is where a version, a default or a name goes stale. Marking every unit turns "recheck everything the sources did not say" into a query rather than a reread of twenty chapters.

### Suggested reading

Every chapter ends with `## Suggested reading`, an H2 after the close and the last thing in the file.

It carries **concepts and terms, not links**. Each item is a thing to search for and one clause saying why the reader might. No URLs anywhere: a link rots, and the reader is going to a search box regardless, so give them the words that make the search work.

```markdown
## Suggested reading

The course documents name these and define none of them. Each is a term to search, with the reason.

- **Participation constraint, total and partial**: the formal name for optionality, and the vocabulary a textbook will use where this course says nothing.
```

- **The items are the gaps this chapter declined to fill,** which the source ledger already names. This is not a reading list of everything adjacent; it is the edge of what the book covers, drawn honestly.
- **Three to six items.** Fewer than three usually means the edge was not looked for. More than six is a syllabus rather than a boundary.
- **A short lead sentence before the list** says what kind of gap these are. It carries no tag, since nothing cites into this section.
- **Never name something the book covers.** An item a later chapter teaches sends the reader out of the book for what they already own, and the outline's ledgers are what tell you which those are.
- **A chapter that is mostly filled in still has one,** and it is more useful there than anywhere else, because the reader has just been told the sources were thin.

The section takes no paragraph tags and no provenance marks, and its list is structure rather than prose, so none of it reaches the prose figure.

### The plan

Write the plan before any prose. It is working notes: never shown, never quoted, no part of the chapter. It isn't finished until every line here has an answer, and the prose doesn't start until it's finished. The failure it catches is parts that each work on their own and never add up to anything, which is nearly impossible to see once you are inside the drafting.

**The outline has already made half of this plan, and those halves are given rather than chosen.** The noun this chapter opens on, the noun it closes on, the weakness it exits on, the terms it glosses, the terms it may use freely and the anchors it owns are all fixed, because the whole book is drafted against them at once and a chapter that re-derives one breaks the chapter on either side of it. Take them as they stand. What is left is the plan below.

**The claim, in one sentence.** What the reader believes at the end of this chapter that they didn't at the start. The close has to land it, so a claim naming two things means the chapter has two subjects and one of them goes. A claim that cannot be stated in one sentence is a chapter the outline split wrongly, and that is worth reporting back rather than writing around.

**The concepts, in dependency order.** What the reader has to hold before the next thing can work. Order by that dependency and never by how the subject is usually taught, since the usual order is the one that quietly assumes the prerequisite. Name what they walk in with, which for chapter 1 is nothing and for every later chapter is what the outline says earlier chapters taught, so the first concept above that line is where the chapter starts.

**The cuts.** Anything you can't place in the order comes out. Cutting is the normal result here rather than a sign the plan went wrong: a concept with no job in this argument belongs to a different chapter, and the outline probably already gave it one.

**One job per part, and a handoff noun for every seam between them.** The job is the sentence the reader carries out. The handoff is the noun the next part opens on, so three parts have two seams and the last part hands off to the chapter's own close. Both get chosen now, because deciding a handoff once you are already writing the seam is exactly what produces parts that chain cleanly and still don't add up. The heading falls out of the job and gets written here too, which doubles as the check that the job is one thing, since a job needing two nouns to name it is two parts.

**The allocation.** Which paragraph holds the wrong model, which holds each anchor, where each number and each new term first appears. Once, here, not while drafting.

Then read the concept order against the claim. If the order doesn't arrive at the claim, the shape is wrong, and fixing it now costs one line of notes.

### Voice

Second person, plain words, contractions, present tense for scenes. Warmth is lexical, so word choice and rhythm are load-bearing rather than decorative. **Mark the relation between two sentences wherever it is not obvious**, with the ordinary words that do it: but, so, because, and yet, for example, which means, the cost is. These are not announcements and nothing here bans them; a marker tells the reader how to attach the next sentence before they have read it, which is the work a reread would otherwise do. 45 words is a hard stop nothing earns its way past, and there is no target for the mean, because naming a referent and marking a relation both cost words and both buy back more than they cost: a long sentence shows two things are one thing, and it has done that once the second lands, so a clause hung on after with a colon, an and, or a which is the next sentence. The sentence carrying the most runs over first, so split that one and let the break do the emphasis. Vary sentence length deliberately, since uniform length is the loudest machine tell. No ordinal sequencing, so nothing that numbers a step or scaffolds the prose into first, second and finally: a numbered step says where it sits where a chained step says why it follows. An ordinal already inside a thing's name is not sequencing and stays, so third normal form and the fourth lab are both fine; where that label is intimidating, describe the behaviour and attach the bare form after, which the gloss rule asks for anyway. Watch for prose sliding into list-writing: three or four parallel items inside a sentence is a list wearing prose, so hold those to about three in the chapter and never two in a paragraph.

### Reference

Every rule here is about one thing: a word that points has to have something to point at, by the time the reader reaches it. This is the cheapest reread in the book to introduce and the hardest to see, because the writer always knows what the word meant.

**A definite noun phrase claims the reader has met the thing.** Writing "the diagram", "the building", "the query plan" tells the reader this is the one they already know about. Where they do not, they stop and look for where they missed it. So the first time a chapter names something with "the", one of three has to be true: the noun has appeared already in this chapter, or the sentence glosses it as it goes, or it is something the reading situation supplies on its own, which covers the reader, the course, the week, the page, the room you are standing in. Nothing else. An indefinite costs one letter and fixes it: *a diagram*, then *the diagram* forever after.

This bites hardest at the opening, because a chapter opens on the noun the previous chapter handed it and that noun arrives with a definite article already attached. See § What the reader arrives with: the handoff grants you the word, never the definition.

**A sentence-initial this, that or it points at the sentence before it.** Where the thing it points at is further back than that, or is a whole paragraph rather than a noun, name the noun instead. Three cases are not this defect and must not be rewritten:

- **The label landing after the behaviour.** "That is optionality, whether an end is allowed to be empty" is the same-breath gloss doing its job, and the demonstrative is the hinge it turns on. Naming the noun first would put the label before the behaviour and invert the one pattern in this file with real evidence behind it. See § Every part does five things.
- **A cleft.** "What matters here is the timing" moves the emphasis; it refers to nothing and resolves nothing.
- **A demonstrative with its noun attached.** "That instinct", "this term", "both dates" are already resolved.

**An example introduces its furniture before it uses it.** A scene the reader is asked to picture needs its pieces named the first time they appear, in the order a person would meet them, and the rule above applies to every one of them. Dropping the reader into "Room 12 says nothing by itself, because the building next door has a room 12" asks them to build a street, a building and a numbering scheme out of a definite article. Set the scene in a clause, then run it.

**These rules add words, and where a chapter has to come down the words come from somewhere.** How many has never been measured, so carry no figure for it: a marker, a named referent and a staged example each cost words, and the direction is all that is established. Where a chapter has to come down they come out of the walk, which can lose a step, or out of the second anchor, and never out of a gloss or a hedge; § Before sending fixes the cut order and this does not change it. A chapter that cannot carry the mechanism and the referents together is one the outline drew too wide, which is worth reporting back rather than writing around.

### Never

No italics, callouts, block quotes or other markdown in the body beyond the part headings described above, and prose paragraphs by default. A bulleted or numbered list, a table, a fenced code block, a bolded phrase or an inline code span is allowed where it genuinely carries the idea better than the sentence would, and nowhere else: the test is that a reader loses something if you write it out as prose, not that it would be tidier. Reach for a table when two or more things are being compared on the same axes, or to reproduce a set of figures a source publishes whole; for a list when the items are a real set the reader has to hold all of at once; for a fenced block when the exact characters matter and paraphrasing them would be a different thing (a command and what it printed, a schema, an error as it appeared); for bold when one phrase in a passage has to survive a reader who is scanning; and for an inline code span when naming a file, a path, a column, a flag or a command the reader would type, which is the form they will search for. Keep a fenced block to the few lines the point needs, and name the thing in the prose first, so a reader who skips the block still has the idea; the block shows what was said, it does not say it. The walk through the mechanism is never any of them: it stays chained prose, because a numbered step says where it sits and a chained step says why it follows, which is the thing being taught.

Keep them earned rather than rare. The old rule here held that easy to read and easy to skim are opposites, and it was written for a reader who only ever read straight through. This one comes back to find a fact, so a table they can land on is a service rather than a leak, and the guard that matters is the one above: prose by default, and every structure answering for what a sentence would have lost. A chapter that breaks into bullets every page has still become the briefing this exists to avoid. No em dash; the colon is usually the kindest punctuation you have. Never open a sentence with "Now,", never use "right?", never write "In conclusion", "To summarize", "Key takeaways" or "TL;DR". Never claim that what follows matters instead of saying it: no "worth noting", no "importantly", no "the key point is", no sentence whose whole content is that the next one counts. **This bans empty emphasis and nothing else.** A relation marker is not an announcement, and neither is a clause saying what a part just established: every marker on § Voice's list stays available here, and that list is the only place it is written down, so the ban and the licence cannot drift apart. Never greet, never promise what the reader will learn, never close on a call to action.

Never cycle synonyms for one thing. A handler that becomes the processor and then the callback tells the reader there are three of them, and here that costs double, since a reader who has met the term once is now learning a second term exists. Repeat the exact noun every time, including where the repetition reads badly. This binds across the book as well as inside the chapter: a term the outline assigned an earlier chapter is used in that chapter's words, not in a fresh synonym of your own. Saying the core idea again in different words, once, after the walk is a different move and it stays.

Never build a portable sentence out of a formula. "X is the Y of Z", "X becomes a trap", "the language of", "the currency of": these sound precise and leave the reader hunting for the claim that was supposed to be in them. Write the claim instead. The same goes for the openers that promise a deeper point and then deliver an ordinary one, "The real question is", "at its core", "fundamentally", "what really matters", and for the staged candour of "Honestly?", "Here's the thing" and "Look", where someone actually being candid would just say the thing.

Never hang a participle on the end of a sentence to add a claim and no information: "ensuring reliability", "highlighting its importance", "reflecting the broader pattern". Never write "from X to Y" unless X and Y sit on one real scale. Never reach for "serves as", "stands as", "boasts" or "features" where "is" or "has" carries it, and never use "not only X but Y" or "it's not just X, it's Y". Pick another word than delve, crucial, pivotal, vibrant, intricate, tapestry, showcase, underscore, testament, seamless, robust, foster, leverage, or landscape used abstractly, all of which mark the prose as generated before the argument gets a hearing.

Never invent a person, date, quote, statistic or incident. Name and date at 95% confidence or drop it; with a solid name and a shaky year, hedge the year to its decade, never the reverse. Flag one simplification plainly, per chapter.

**A real number carries the scope it was measured over, and widening that scope invents it.** A count taken across five files is a fact about those five and never about all nine; a rate measured on two channels is not a claim about three. Before a number reaches the page, name the population it actually covers and make the sentence say that population, because the digits get rechecked and the scope doesn't. If you cannot state the population from the record in front of you, cut the number.

Never let this file's vocabulary reach the page. Part, hinge, walk, anchor, aside, handoff, thesis, deflation, spine and mode are words for building the chapter, never words in it. The ban is on the word and its inflections, whatever sense you meant: an industry that walks a claim back leaks as surely as a paragraph that walks a mechanism, so write that it backs away. Name the actual thing.

### Before sending

Count rather than estimate, sentences first, since that is the ceiling that gets missed: no sentence over 45, no paragraph over 90, six new terms at most and every one glossed at first use, two anchors at most, three numbers at most, every part exiting on a named weakness, one H1 on line 1 and no other, one H2 per part and none over the frame, no heading naming a term the prose has not already glossed, every list, table, fenced block and bolded phrase written out beside the thing a reader would lose if it were a sentence instead, and any that has no such answer turned back into prose, none of the building words present in any inflection, and none of the generated-prose words listed in the Never section. In a tagged book, every prose paragraph carries its tag, the chapter half is this chapter, and the count runs from 1 with no gap and no repeat. The pattern bans in the Never section, the participle tails and the formulas, are left to the drafting pass rather than counted here.

Then the five things the resource-first format adds, none of which the prose checks above would catch:

- **Every unit carries a provenance mark**, and each mark names something a reader could open or says `fill`. Walk the file top to bottom rather than trusting memory: the mark that gets forgotten is the one after a table, because the table felt finished.
- **Every sourced claim is checked against its source, not against whether the source exists.** Open the file, find the sentence, confirm it says what the paragraph says it says. A resolvable citation that carries a claim the source never made is the defect this format exists to prevent, and it is the one a checker cannot see.
- **The header's four rows match the finished chapter.** The Draws-on row names every source the marks name and nothing else; the Fills-in row is true of what actually got written.
- **The `## In short` walk uses no term this chapter glosses,** read against this chapter's row in the outline's term ledger, with the carried-in terms exempt. This pass is the only thing that checks it: `check-book.sh` finds the carried-in line, counts it and resolves it against the glossary, and nothing anywhere checks the walk's vocabulary. Confirm on the same read that each carried-in entry is worded from its glossary entry rather than freshly defined, and that the terms named are the ones this chapter's claim rests on rather than the first three on the ledger row.
- **The concept list names nothing the book covers**, checked against the outline's term ledger, and every item is a term rather than a link.

List the budgeted things instead of recalling them, since recall is what overspends them: write out every checkable name, every number and every new term with the paragraph each sits in, mark the names and numbers the argument rests on, then read the ceilings off that list. The marking is the whole check for the two anchors, because a name goes on the page for its own reasons and only the argument decides whether it is charged. Check the new terms against the outline's ledger while the list is in front of you, since a term an earlier chapter owns is free here and a term no chapter owns is one this chapter has quietly invented. Sentences are budgeted the same way and never checked by eye, since rhythm hides length and the run-on that reads well is the one over 45: copy out the longest sentence of each part, and the anchor sentence, and count each singly. Beside every number write the artifact it came from and the population it covers, and confirm the sentence says that population.

Then check the chapter against the plan, which is the only record of what you set out to write. Every part still does the job it was given and still hands off on the noun it was given; nothing the plan cut has crept back in; the close lands the claim. A part that drifted off its job is what the reader feels as a chapter that doesn't add up, and the drift only shows against the plan, never against the prose you just wrote. Then check the two seams the outline fixed: the first paragraph opens on the noun the previous chapter closed on, and the close hands forward the noun the next chapter opens on.

Then the reference sweep, which is counted rather than judged, because the rules this file states as judgments are the ones that quietly go unfollowed while the countable ones hold. Walk the file top to bottom and write the list out; do not do this from memory, since the writer is the one person who cannot feel a missing referent.

- **Every "the" that names something for the first time.** For each, write beside it which of the three licences it has: the noun appeared earlier in this chapter, the sentence glosses it, or the situation supplies it. Any with none is the defect. Start with the opening paragraph, since the handoff noun lands there with a definite article and no definition.
- **Every sentence opening on this, that or it.** Beside each, the noun it points at and how far back that noun sits. Further than the previous sentence is the defect. Mark the ones that are a gloss landing its label, a cleft, or a demonstrative with its noun attached, and leave those alone.
- **The analogy, if the chapter spent one.** It has a human actor in it, its pieces are named before they are used, and it is mapped back inside the same paragraph. A scene with no person in it is not the thing this budget bought.
- **Every paragraph's first sentence, read against the paragraph that precedes it.** Each one picks up something that paragraph left standing, by name or by a demonstrative with its noun attached, or carries a marker saying how it attaches, or does both. Write which beside each seam; a seam with neither is the defect, and a column that reads the same all the way down is the other one. A first sentence that only makes sense once the paragraph is finished is an epigram, and the fix is to move the claim onto nouns already on the table rather than to delete the sentence.

Then three tests. Somewhere a plausible wrong answer has to fail on a concrete case, and if none does you wrote a summary, so go back and spend the words. Read every paragraph's first sentence in order: together they should compress the chapter, with no two neighbours built the same way. And list every recurring thing the chapter names, with each word used for it beside it, since one thing wearing two names is the cheapest defect here to introduce and the hardest to catch by reading.

**When a chapter has to come down, cut whole paragraphs in this order:** the second anchor, the analogy, the last part's walk down to a single step, then the sober pair folded into one, keeping the half that settles it. Nothing triggers this by arithmetic, since § Length sets no ceiling to breach. What triggers it is a chapter you have read and found to be carrying more than its one claim needs, which is a judgment rather than a count, and the order exists because trimming evenly across sentences eats the glosses and the hedges first. The aside is not on that list, because a prerequisite the reader needed is still needed after the cut. Neither is the header, the concept list or any provenance mark: none of them is prose the reader walks through, so cutting them saves nothing and costs the reader the second reading.

**Turning a passage into a table is not a way to make a chapter shorter.** Structure is reported apart from the prose because it is consulted rather than read, and a paragraph reformatted as rows is the same words on the same page with the argument taken out of them. Reproduce a set the source publishes; do not shred your own prose into one. A chapter that has outgrown the one claim it was given is telling you the outline is wrong: report it, so the chapter can be split, rather than cutting until it fits, since the glosses and the hedges are the two things doing the teaching.

## The guide profile

Everything above is the **narration profile**, and it is what a book gets when `book.json` names no profile. A book that sets `"profile": "guide"` is held to the rules below instead, wherever they differ. **Every rule above that is not named here still applies**, unchanged and in full: the budgets, the voice, the reference rules, the paragraph tags, the provenance marks, the concept list, and every phrase ban in § Never.

**Why there are two profiles rather than one loosened set.** The rules above were derived from a corpus of audio narration (`NOTES.md`), and a listener cannot look back. Every one of them is right for a reader who starts at the first sentence and goes to the last. A preparation guide is read differently: opened at one chapter the week it is needed, scanned for the thing to do on Monday, and returned to under time pressure with a specific question. Applying the narration rules to that book produces linked essays with a lookup layer bolted on, which is well written and hard to use. The guide profile changes the rules that fight the second reading and nothing else.

**This is a profile, not a licence.** Each change below names what it buys the reader. A guide is still prose by default, still argues rather than lists, and a chapter that has become a slide deck has failed this profile exactly as it would have failed the other one.

### Opening

**No handoff noun and no ban on re-orientation.** A later chapter may open however it needs to, including by saying where the reader is and what this chapter assumes. § What the reader arrives with still governs what may be *assumed*: a term an earlier chapter glossed is free, anything else is glossed here. What lifts is the requirement that the first sentence pick up the previous chapter's closing noun.

The rule bought continuity for a reader going straight through, and it costs exactly that reader nothing to lose, because the outline still orders the chapters. What it was costing was the reader who opens chapter 13 on a Saturday, for whom a definite article pointing at chapter 12's last noun is a referent they have never held. § Reference already calls that the most expensive reread in the book.

**`## In short` is required**, not optional. Under narration it is opt-in through `book.json`; under `guide` a chapter without it fails. It is the advance organizer, and it is the section carrying the orientation the opening paragraph no longer has to.

**Chapter 1's four hooks are optional.** Open it on the hook if the hook is there. A guide's first chapter is more often the one that says what the book is for and how to read it, and forcing a scene onto that is how a front matter section ends up written twice.

**A chapter still closes on a handoff noun where the outline gave it one**, because the outline is still what orders the book. The difference is that the *next* chapter is no longer obliged to open on it.

### Headings

**A heading may carry the point, and may be a question.** The narration rule required a heading to be redundant with the prose, so a reader who ignored every heading lost nothing. That is right for a book read once through and wrong for one whose second reading is by scanning: a reader looking for the thing to do about late submissions needs a heading that says so, and "The term and its two edges" gives them nothing to scan by.

The redundancy rule's defence was that the handoff keeps working underneath. Under this profile there is no handoff, so the defence is gone and the rule goes with it.

**H3 is allowed under a part.** Two levels, never three: H2 for a part, H3 for a division inside it. An H3 is for a part that genuinely has named sub-parts a reader will look for by name, most often a procedure with stages or a set of cases. A part that wants four H3s is two parts.

**Every other heading rule stays.** A heading is never a term's first appearance, which is the one rule in § Headings with measured evidence behind it (`NOTES.md`). Every budget still counts a heading, so a checkable name in one still spends an anchor, and none of this file's own vocabulary may appear in one. Six words at most still holds for an H2; an H3 gets the same six.

### Callouts

**Four labelled block quotes, and nothing else.** The narration ban on block quotes lifts for exactly these four shapes and stays for everything else:

```markdown
> **Decide.** The thing the reader has to choose, and what turns on it.
> **Warning.** What goes wrong, stated before they do it rather than after.
> **In the room.** What this looks like live, with people in front of you.
> **Grade this.** The rule to apply when marking, or the line to hold.
```

- **The label is literal and it is the first thing in the quote**: `> **`, the word, a full stop, `**`, then a space, then the sentence. `check-book.sh` finds a callout by that grammar and by nothing else, for the reason § In short gives about the carried-in prefix: left to infer it, the checker would have to guess, and both of its guesses read as a clean pass.
- **Any other block quote fails, and so does an unlabelled one.** The set is closed. A fifth kind of callout is a change to this file, made once, rather than a decision a chapter makes while drafting.
- **A callout is one to four sentences and carries no paragraph tag**, because it is not a prose paragraph and must not advance the count other files cite. It takes a provenance mark like any other unit.
- **At most four in a chapter, and they are not a budget to spend.** A chapter with a callout every page has turned the signal off: the reader stops seeing them exactly when one matters. Nothing requires a chapter to carry any.
- **`makebook` renders them as boxed asides** with the label as the box title, in both PDF and EPUB.

What they buy is the thing § Never's old rule was refusing: nothing on a narration page says which kind of sentence you are reading, so a warning, a grading rule and an aside about the room all render as body prose. A reader going straight through infers the kind from the argument. A reader scanning for what to do cannot.

### Procedures

**Numbered lists are allowed, and preferred for anything the reader does in order.** Setting up a tool, running an exam session, working through a grading pass: these are procedures, the reader performs them with the book open, and a numbered step is an address they can return to when they look up from step four.

**The chained-not-numbered rule keeps its full scope, which is the mechanism walk.** § Every part does five things is unchanged: the walk through how something works stays chained prose, because a numbered step says where it sits and a chained step says why it follows, and why is the thing being taught. § Voice's ban on ordinal sequencing applies to prose and not to a list that is genuinely a procedure.

**The test is whether the reader performs it.** A sequence the reader *does* is a procedure and takes numbers. A sequence the reader *understands* is a mechanism and stays prose. Where a passage is both, write the mechanism in prose and the procedure as a list below it; they are different things for different moments and merging them serves neither.

### Section ends

**A part may end on a signalled one-sentence takeaway.** The narration rules require every part to exit on the weakness that breaks it and never on success, and they ban "Key takeaways" outright. Under `guide` the exit-on-weakness is optional and a part may instead end on the portable sentence, marked as what it is.

The weakness exit is still the better move where there is a real weakness, and a guide that ends every part on a tidy summary has lost the honesty the narration rules were protecting. What changed is that a reader who opens one part, reads it, and closes the book should not be left holding only the thing that breaks it.

**The phrase bans in § Never stay.** No "Key takeaways", no "In conclusion", no "To summarize", no "TL;DR". The takeaway is a sentence, written as a sentence, not a heading over a bulleted recap. Where it wants to be signalled, `> **Decide.**` is usually the callout that fits, or the sentence stands alone as the part's last paragraph, which § Shape already permits once per chapter.

### The wrong model

**At most one per chapter, and only where a source or the classroom names the misconception.** Under narration it is mandatory: § Before sending says that if no plausible wrong answer fails on a concrete case, you wrote a summary. Under `guide` it is available and never required.

The rule was right about explanation and wrong about reference. Where the misconception is real the passage is the best teaching a chapter can do, and where it is not, the rule forces a strawman: a fix nobody would reach for, conceded and knocked down, costing 130 words and the reader's trust. A guide's chapters are not all explanation, and a chapter whose job is to carry a procedure has no wrong model to correct.

**Where one is written it keeps its full shape**: the question, the fix in the reader's own words, the concession, then the failure on one concrete case. A wrong model without the concession is the strawman this rule exists to prevent.

### The chapter header and provenance in prose

**`This chapter` and `Act on this` stay on the page.** They are what the second reading lands on.

**`Draws on` and `Fills in` stay in the source file and move to endnotes in the reading edition.** They are the operator's rows rather than the reader's: an inventory of sources at the head of every chapter is furniture the reader scrolls past to reach the prose. The rows are not cut, because `check-provenance.sh` and the review passes read them; they move. See `makebook/SKILL.md § The reading edition`.

**Provenance in prose is carried by the mark, not by the sentence.** § Provenance's "in the prose, where it matters" narrows to two cases under this profile: the sentence quotes the source, or the reader has to open the source to act. Everywhere else the `<!-- src: ... -->` mark carries it and the prose says nothing.

The narration rule produced thirty parenthetical citations in under two thousand words of one reference chapter, which is a paragraph the reader cannot read at speed. Attribution has not weakened: the mark beside every unit is exhaustive where the prose was selective, and it is the record the tooling reads.

**A book-level caveat is stated once**, in `about-this-book.md` and once above the appendix it applies to, and never repeated per chapter. A hedge repeated twenty-two times across thirteen chapters is not honesty, it is noise the reader learns to skip.

**A source is named by its display name, never by its repo path.** `book.json` may give each source a reader-facing name beside its path; the prose uses that name and the mark uses the key. A reader cannot open `../../../CLAUDE.md` and should never be shown it. See `SKILL.md § 4`.

### Appendices

**An appendix is a chapter-kind file holding reference matter**, bound after the chapters and before the glossary. It exists because the narration rules provide no home for the material a guide accumulates: answer keys, rubric pairs, an open-decisions table, a source ledger. Without one they land in whichever chapter was being written when they came up, which is where a reader will never look for them.

- **Filename: `<book-slug>-appendix-<N>-<slug>.md`**, numbered from 1, sorting after every chapter because `a` sorts after every digit. The reading order stays a plain filename sort, which is the constraint `SKILL.md § Filenames` sets for the whole folder.
- **Tagged as `[A<N>-<n>]`**, so appendix 2's fourth paragraph is `[A2-4]`. An appendix holds exactly the material a chapter cites, so it needs addresses; keeping the chapter half distinguishable keeps a renumbered chapter from colliding with one.
- **Skipped by the part-count rule and by the handoff rules.** An appendix has no parts, no opening paragraph, no close and no handoff noun. It is not an argument.
- **It carries the chapter header table, `## In short` and `## Suggested reading` only where they earn their place**, and none of the three is required. What it does carry is provenance marks, on the same terms as everything else.
- **An appendix is reference matter and never teaching.** A concept explained for the first time in an appendix is a concept in the wrong file: the chapters teach, the appendix holds what the reader looks up afterwards.

### A shape for a teaching chapter

Offered rather than enforced, for a chapter whose job is to prepare someone to teach a session. Nothing checks it and a chapter is free to want a different shape:

1. **At a glance.** The header table and `## In short`, which every chapter carries anyway.
2. **The concepts, in teaching order.** Each with its definition, the failure to watch for, and the assessment item it feeds.
3. **The lesson script.** What to say, what to ask, what to watch for, and roughly how long each takes.
4. **Grading.** The rubric, the line to hold, and what to do about the cases that sit on it.
5. **The key**, where the session has one, or a pointer to the appendix holding it.

**This is a shape, not a template**, and a chapter that fills all five headings with a sentence each has produced furniture rather than a chapter. Where a session genuinely has no grading, the section goes rather than standing empty.
