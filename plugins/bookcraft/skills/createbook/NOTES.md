# /createbook: provenance and what is actually measured

Not loaded at runtime. Read this before changing any number in the rule files in `reference/`: `chapter-prose.md`, which every chapter follows, and the profile files `guide.md` and `narration.md` (§ The rule files split, 2026-09-24).

## Where the spec came from

`reference/chapter-prose.md` was forked from the `/ne` skill on 2026-09-10, on the operator's decision that the book work had outgrown it. Before the fork, `createbook/SKILL.md` cited `ne/SKILL.md` by line in ten places and every chapter agent read that file, so the two skills could not move independently: a rule `/ne` needed for a standalone piece and a rule a chapter needed had to be the same rule, and each book run kept pushing book-shaped changes back into `/ne`.

`/ne` was reverted in the same session to what it was before that pressure started, and it is no longer a dependency of anything here. The two files are free to diverge, and they will. Nothing in this folder reaches outside it for a rule.

**What the fork inherited** is `/ne` as it stood at `2f9326c` plus one uncommitted session's work, which is the state that wrote the reference book. That includes the H2 part headings added at `f0957e5`, the standalone rule scoped for book chapters at `4ad2bad` and `0b15f0a`, the number and ordinal rules narrowed at `f2c0209` and `bc24e7a`, the anchor rule narrowed at `2f9326c`, and the markdown allowance recorded below. All of it is now local.

**What the fork changed** is the set of rules that used to travel as a delta table in `SKILL.md`, telling a chapter agent how a chapter departs from a standalone piece. Those are written into the spec itself now, at `chapter-prose.md § What the reader arrives with` for what the reader arrives with, `narration.md § Open` for the opening, `narration.md § Close` for the close, `chapter-prose.md § Glosses` and `chapter-prose.md § Spend these deliberately` for glossing only the terms the outline assigns, `chapter-prose.md § Spend these deliberately` and `chapter-prose.md § Every budget is per chapter` for the per-chapter budgets, `chapter-prose.md § Paragraph tags` for the paragraph tags, and `chapter-prose.md § The plan` for what the outline has already decided. Two sentences in `chapter-prose.md § Prerequisites` and `chapter-prose.md § Before sending` now say to report an over-large chapter back rather than write around it, since at book scale that is a fact about the outline. Session mode was dropped, having no meaning inside a book.

**One number was reconciled rather than copied.** The shape rule allocates about 1,300 words to the parts and 300 to the frame, which was calibrated when the cap was 1,750 and the aim 1,600. Those two figures matched exactly. When the cap moved to 2,000 the aim moved to 1,800 and the allocation did not, leaving 200 words unaccounted for. `chapter-prose.md § Shape` then said the 1,600 was the prose allocation and the slack above it was what a fenced block spends. That was a statement of intent rather than a measurement, and all four figures came out of the spec on 2026-09-13; see § The ceiling removed.

## What the numbers rest on

The short version of a longer record. `/ne`'s own `NOTES.md` holds the full derivation where that skill is installed; this section is what a reader of these ceilings needs, and it does not depend on that file being present.

The spec descends from a 2,500-word text-explainer prompt derived from nine YouTube transcripts (150,793 words) in the "explained slowly / for sleep" AI-and-ML genre, plus one daytime webinar kept as a contrast case. Fourteen patterns were verified adversarially against the raw transcripts, then compressed into a skill at a 1,750-word cap.

**Measured against that corpus:** two patterns, and only two, are strong across all five channels. Same-breath gloss, meaning never use a term before explaining it and let the label land after the behaviour. And wrong-model-first, meaning voice the naive fix, concede what works, then fail it on a concrete case. Both are load-bearing in `reference/chapter-prose.md`. Most of the rest was one channel's accent, since a single channel supplied five of the nine files and its habits sat on the median.

**Asserted, not measured: every numeric ceiling in the spec.** No sentence over 45 words, at most 6 new terms, at most 2 checkable names, at most 3 numbers, paragraphs 40 to 90 words, headings of six words at most. These were carried from a 1,000-word draft and scaled by arithmetic when the length target moved. They are reasonable and they validated as followable; they are not findings.

**Also asserted:** the plan step, the standalone rule, the headings section, the paragraph-tag rule, and the phrasing bans in the Never section. None was derived from the corpus.

That distinction matters because asserting a rule without checking whether the source satisfies it is the exact error this work kept surfacing. The clearest instance: an earlier fragment-placement rule required a short sentence to follow a 30-plus-word sentence and precede a 15-plus-word one. Across the five transcripts it was drawn from, holding 513 sentences of four words or fewer, only 12 satisfy it. The rule was arithmetically incapable of reproducing its own source.

**Validation, and what it does not cover.** Five generated pieces came in at 1,039 to 1,489 words with zero formatting violations, zero em dashes and no ceiling breached; the fifth ran 67 sentences, none over 45, mean 18.5. Every one of those was a standalone piece rather than a book chapter, and all five predate both the markdown allowance and the 2,000-word cap. The reference book is the only book-scale evidence, and it passes `check-book.sh` on structure, which is a different claim from reading well. It was twenty chapters when this entry was written and is eighteen now, after the resource-first rewrite recorded below; its chapter lengths are measured at § The ceiling removed, 2026-09-13.

Before tightening any ceiling here, measure it. Loosening one is not gated the same way.

## Where the part headings came from

Added on operator judgment that continuous prose with no headings is harder to read than prose with them. Scoped to one heading per part: no heading over the opening, the sober pair or the close, and no level below H2. Inside a book the chapter's H1 sits above all of them, which `/makebook` reads as the title.

**The corpus cannot speak to this either way, which is why the ban it replaced had less standing than its wording implied.** All ten sources are speech, and speech has no headings. The derivation chain also passed through an audio-narration prompt before being re-targeted to text, so the original "no headings" rule was either a fossil of the audio form or an assertion made at the re-target. Which of the two could not be determined: the derivation working notes are absent from this machine and from both sibling checkouts. That absence bounds only what was checked, so treat the question as open rather than settled.

**Three of the four constraints on a heading are derived rather than invented,** which is what keeps this from being a free-form addition:

- *A heading is never a term's first appearance.* Same-breath gloss is one of only two patterns measured across all five channels, and it requires the gloss inside the sentence that first uses the term. A heading is not a sentence, so a heading introducing a term breaks the strongest finding in the corpus.
- *Headings count against every budget.* `chapter-prose.md § Spend these deliberately` already says to count the checkable names on the page rather than the ones you meant to spend, and a heading is on the page.
- *The heading must be redundant with the part's first two sentences.* `narration.md § Every part does five things` already assigns the naming job to those sentences. A heading carrying anything they do not is a heading that rewards skipping the prose.

The fourth, six words at most, is asserted with nothing behind it, on the same terms as every numeric ceiling above.

**The accepted cost, stated rather than papered over.** Headings do admit skipping, which is what the rule they replaced existed to prevent, and nothing here removes that. What the spec relies on instead is already in it: parts run in dependency order, each exits on a named weakness, and the next opens on that exact noun, so a reader who jumps a heading lands on a noun defined in the part they skipped and the skip fails quickly rather than quietly. That is a mitigation, not a refutation.

**One alternative was considered and rejected.** A fourth heading over the sober pair and the close would stop the last part's heading from appearing to own the tail. It was dropped because a heading doing that job is a summary label, and `chapter-prose.md § Never` already bans "In conclusion", "To summarize" and "Key takeaways" for the same reason. The spec instead says a heading marks where a part begins rather than labelling everything below it.

**One gain that was not the motivation.** The shape rule, two or three parts and never one or four (`chapter-prose.md § Shape`), was invisible to any script until the parts became headings. It is now a grep, and `scripts/check-book.sh` enforces it. Zero headings also passes there, so chapters written before this change still validate.

## The markdown ban lifted, and the ceiling raised to pay for it

Operator decision, 2026-09-10, in two steps in one session, and the last change made before the fork. The rule had banned all markdown below the part headings. It now permits a bulleted or numbered list, a table, a fenced code block and a bolded phrase, each only where a reader would lose something if the passage were written out as a sentence. Block quotes, inline code spans and italics stay banned. The mechanism walk stays chained prose whatever else is allowed, which is the one carve-out that keeps the original rule's intent: the walk was the thing bullets would have destroyed.

**The counter had to change before the rule could.** A paragraph tag is an address other files cite, and the reference book's tags alone are cited fifty-six times outside the book, so a list dropped into a finished chapter must not renumber every paragraph after it. `check-book.sh` therefore treats a list, a table and a fenced block the way it already treated a figure: the block advances no paragraph number. Without that, permitting a table would have silently renumbered chapters and broken every citation into them.

**A fence's contents are not markdown,** which the counter handles first. A SQL comment inside a fenced block starts with two dashes and reads as a list item; a query holding a pipe reads as a table row. The fence rules run before the block rules for that reason, and an unclosed fence is its own reported failure, since everything after it would otherwise be swallowed as code and the inline-span count would come back clean.

**The ceiling moved because the word count includes what a fenced block holds.** `check-book.sh` counts a chapter's body after stripping the paragraph tags and standalone figure references, and nothing else, so a block showing a command and its output spends the prose budget. A six-line SQL block measured 52 words in a fixture. Counting it is the deliberate choice, because a block is on the page and costs the reader time, and a ceiling errs safely high; raising the cap to 2,000 is what stops that landing on the glosses. A chapter carrying no block has no more room than prose alone ever had.

**Not measured.** No validation run has been made at 2,000 words, and the five recorded above all came in under 1,500 against the old cap, so nothing here shows what a chapter written to the new figure reads like. The eleven-minute reading time then carried by `chapter-prose.md § Length` is arithmetic at the same 175 words a minute the ten-minute figure assumed, not an observation.

**Superseded 2026-09-13.** The eighteen chapters of the reference book are the run that was missing here: they were drafted under the 2,000 cap and average 1,895 words, measured at § The ceiling removed below. The cap they were written against is gone, and § Length now states no length and no reading time at all.

## Where the glossary came from

Operator request, 2026-09-10, for the reference book. It is a feature of the process rather than of any one book's prompt, and the reason is mechanical rather than editorial.

**A prompt cannot deliver a glossary that reaches the bound book.** Both tools treat every top-level `.md` in the folder as a chapter: `check-book.sh` collects with `find "$dir" -maxdepth 1 -name '*.md'` and `/makebook` with `sorted(src.glob("*.md"))` (`build-book.py:load_chapters`). A `glossary.md` written by an agent following a prompt either fails the filename pattern and the shape rules, or is quieted with an `exclude` entry, at which point the binder skips it too and the PDF ships without it. The second way looks like success, which is worse. So both tools now skip the glossary by name, whether or not `exclude` mentions it.

**The term list is the outline's ledger rather than a fresh reading.** The ledger is fixed before drafting so chapters can be written in parallel, and it already names every term and its owning chapter. Re-deriving the list from twenty finished chapters would produce a second list that disagrees with the first. The definitions come from the same-breath gloss each chapter is already required to carry (`chapter-prose.md § Glosses`), so a definition exists at a known address before the glossary is written; in a tagged book the paragraph tag names that address exactly.

**Deriving the glossary at bind time was considered and rejected.** The index is harvested that way and gets away with it, because an index entry needs only a term and a location. A gloss is a clause inside a sentence with no delimiter, so parsing definitions out of finished prose would be guesswork, and definitions are editorial content that should be reviewable in the repo.

**The parser is strict, and one of its rules was written after it failed.** An entry that wrapped across lines parsed with no chapter and the literal "(ch. 14)" absorbed into its definition, because the pattern allowed spaces but not a newline before the chapter reference. That is exactly the silent-wrong-output the strictness exists to prevent, so the pattern now takes any whitespace there. Malformed entries, duplicate terms, an empty file and a reference to a chapter the book does not have all stop the build rather than rendering.

**The index stops at the glossary.** `body_end` in the fixed-point loop now ends at the glossary page when there is one, so a term is never indexed to the glossary page that defines it. Measured on a three-chapter fixture: the index reads 3, 4 and 5 for its three terms, with no page 6, and page 6 is the glossary.

**Checked in two places on purpose.** `check-book.sh` re-implements the entry grammar in awk because step 7 runs long before anyone binds, and the skill says not to bind unless asked. `/makebook`'s parser is the authority; the awk is the early warning, and both files say so.

## The resource-first rewrite, 2026-09-10

Operator decision, after reading the reference book against what it was
supposed to do for a reader short on time. The finding that drove it: the guide
is well written and hard to use. Measured on it before the change, 30,409 words
across twenty chapters, about 174 minutes at the 175 words a minute this spec
assumes, zero tables, zero lists, zero fenced blocks, zero bold, and exactly one
resolvable file path in the whole book while naming its source documents in
prose about seventy times. Chapter 1 contained zero occurrences of the course
code and zero of "data modeling".

**The reader model was the cause and the markdown ban was only its symptom.**
The ban had already been lifted the day before (see above) and the twenty
chapters were drafted under it, so the zero counts are explained; what the lift
did not touch was `§ The reader`, whose reader reads once, straight through, and
"can look back but won't". Every rule that cost the guide its usefulness
descended from that reader rather than from the ban.

**What is asserted here and what is measured.** Measured: every figure in the
paragraph above, and the two sample chapters in
the resource-first rewrite, at 1,502 and 1,575 words of prose with 452 and 454
words of table. Asserted, on the same terms as every other ceiling in this file:
three to six concept-list items, the header's four rows, nine minutes a chapter
as the sizing divisor, and six to ten chapters as the default. None of those is
a finding. The sizing divisor became eleven minutes on 2026-09-13. Its input
average is now measured rather than assumed; that eleven minutes is the right
divisor is still asserted. See § The ceiling removed.

**No validation run exists for the new format.** Two chapters were written by
hand to show the shape, and both pass `check-book.sh`, which is a claim about
structure and not about reading well. Nobody has yet written a book end to end
under these rules, so the sizing arithmetic in `SKILL.md § Sizing the book` is
arithmetic rather than an observation.

**One thing the rewrite deliberately did not change.** Wrong-model-first and
same-breath gloss stay exactly as they were. They are the only two patterns
measured across all five source channels, and reading chapters 10 and 15 of the
reference book against the new goal found the wrong model to be the highest-value
passage in each: the misconception a reader actually holds, conceded and then
failed on a concrete case they can reuse. The first draft of this analysis had
them down as per-chapter overhead, and that was wrong.

**Citations into `chapter-prose.md` are by rule name now, not by line.** The
rewrite would have silently repointed thirty-eight of them across seven files.
Nine citations into `check-book.sh` did go stale in the same session, and three
of those had been pointing at the wrong lines since before the branch, which is
the argument for the change rather than against it.

## The reference rules, 2026-09-11

Added `§ Reference`, narrowed the existing rules that prohibited it, and moved the new
checks into `§ Before sending` as counted items rather than judgments. No count is given
for the narrowings because they were not counted; they are enumerated at
the branch plan for that change, phase 3. The whole change came out of
reading two chapters of the reference book, not out of the literature the ticket opened
with.

**Measured, and the population for each is stated because these are small numbers.**

- *Chapter 1*, 23 prose paragraphs, 80 sentences: 20 sentences (25%) open on
  It/That/What/Both/Each/Nothing/This. Of those 20, **9** are bare references,
  **7** already have their noun attached, **4** are wh-clefts.
- *Chapter 7*, 24 prose paragraphs, 87 sentences: 18 (21%) open on the same class. Of
  those 18, **7** are bare ordinary references, **3** are bare demonstratives carrying a
  same-breath gloss, **4** are noun-attached, **4** are wh-clefts.
- Across both chapters, a rule reading "a sentence-initial this/that/it names its noun"
  would fire on 38 sentences and be right about **16**. That is why `§ Reference` carries
  three explicit exemptions instead of one flat rule.
- The three gloss cases in chapter 7 (`[7-3]`, `[7-11]`, `[7-17]`) are same-breath gloss
  working as designed. Same-breath gloss is one of only two patterns measured across all
  five source channels, recorded above, so a flat referent rule would have damaged the
  best-evidenced rule in the spec.
- *"The diagram"*: chapters 1 to 6 use "diagram" or "ERD" in prose **4 times**
  (`[1-13]`, `[4-12]`, `[5-11]`, `[6-29]`) and define it **zero** times. Chapter 7's
  prose says "ER" **once**, at `[7-13]`, unexpanded inside a quotation, and
  "entity-relationship" **zero** times, while opening at `[7-1]` on "The diagram".
- *The handoff ledger against the term ledger*, all 16 handoff nouns checked by hand:
  **one** ("the junction table", chapter 8 to 9) is a technical term glossed on an
  earlier chapter's term-ledger row before being handed forward. Six are technical and
  assigned to nobody: the query plan, the diagram, the marks, the fact row, the model,
  the scan. This is why `§ What the reader arrives with` now says the two grants are
  independent, and why `SKILL.md § 2` now requires the **Opens on** row to be checked
  against the term ledger and `§ 3` requires the count of unglossed handoff nouns to be
  reported at the blocking gate. The cross-check stayed prose rather than becoming a
  script: an automated substring match reported "the query plan" as glossed because the
  ledger holds "query planner" eleven chapters later, and "the join" because it holds
  "inner join". Sixteen rows read by hand took a few minutes and got it right.
- *The device that works*: both of chapter 7's part seams hand off on the exact noun
  (`[7-8]` to `[7-9]`, `[7-15]` to `[7-16]`). The one place the spec mandates a cohesion
  device, it holds, which is the same contrast the ticket measured book-wide as 65%
  carryover at part seams against 26% at paragraph seams.

**Measured, and it is the argument against a scorer.** A probe for definite noun phrases
with no antecedent found both real instances in chapter 7 and **26 false positives**,
about 7% precision. Two other throwaway scripts written in the same session also
misreported: an opener classifier under-counted the defect 7 times across two chapters.
Every genuine instance in this work was found by a person reading. Both true positives
were also reachable structurally, from `OUTLINE.md` rather than from prose, which is
where the cheap check belongs.

**Asserted, on the same terms as every other ceiling in this file.** That the reference
rules' words come out of the walk or the second anchor. The three licences a definite
noun phrase may carry. The portable sentence's "works on its own terms" requirement in
`§ Every part does five things`, that every noun in the carried sentence has appeared
already. A figure first attached to that rule, four extra words, and a superlative beside
it were removed rather than recorded, on the same reasoning that removed this section's
hundred-word cost claim in `3fe8415`: a number nobody counted does not become evidence by
being labelled asserted. That marking
a relation reduces rereading, which is the ticket's literature rather than anything
measured here. And the claim that countable rules are followed where judgment rules are
not: that is an inference from chapter 7 passing `check-book.sh` on structure while
failing `§ Spend these deliberately`'s human-actor requirement, and one chapter is not
a finding.

**Not done.** No validation run exists for these rules, and this now stacks on the
resource-first format, which `NOTES.md § The resource-first rewrite` already records as
unvalidated. A chapter that reads better after this change cannot tell you which of the
two did it.

## The paragraph seam, 2026-09-12

`§ Shape`'s paragraph rule now says what a paragraph's **last** sentence owes the next
one. It previously ruled the entry only, which left the seam governed from one side.

**Measured.** Content-word carryover across the book's 411 tagged paragraphs is **65%**
at part seams against **26%** at paragraph seams, and adjacent sentences run **33%**.
The spec fixes a handoff noun at part and chapter seams and fixed nothing at paragraph
seams, so the two figures are a natural experiment on the spec's own text rather than a
property of English: where it mandated the device the number is high, and where it was
silent the number is low. Both of chapter 7's part seams hand off on the exact noun,
recorded above.

**Refuted twice, and the rule was cut down each time.** The obvious rule, a carried
noun at every paragraph seam, does not survive: a chapter has roughly twenty paragraph
seams against two part seams, so a device that reads as deliberate twice reads as
chanting twenty times, and a paragraph break exists partly to signal that the topic
moved. The first draft of the rule then said "one of the two, never both", and that does
not survive either. Its stated reason was about sameness across a chapter, which is a
different claim from doubling at one seam, and the seams that do both in the v2 drafts
the operator had read and preferred are the best seams on their pages: "But the item is
not where the defect sits" (v2 `[8-6]`) carries a noun and a marker in eight words. The
rule as it stands asks for at least one of the two at each seam, welcomes both, and
names sameness down the chapter as the thing to avoid. No target carryover figure is
stated, and none should be: 65% is what two seams a chapter produce, not a number the
other twenty should be driven toward.

**Measured, on the instrument's own precision.** A script that classifies each seam as
noun-carried, marked, both or neither (last sentence of one paragraph against first
sentence of the next; content-word overlap; a marker within the first nine words)
reproduces the ticket's split at 59% part-seam carry against 22% at paragraph seams, so
it measures roughly what the ticket measured. It calls **51%** of the book's 343
paragraph seams "neither". A random sample of 20 of those, read by hand: **7** are
bare and **13** cohere through devices the script cannot see, among them additive
markers ("as well", "also"), enumeration ("the second conflict", "a second time"),
noun-attached demonstratives ("those same three sessions"), a noun carried from the
previous paragraph's body rather than its last sentence, and one plural the stemmer
split. So the book's bare-seam rate is roughly one in five, about four seams a chapter,
and the script over-reports it by about 2.5x. It is the fourth throwaway script in this
ticket to misreport, and the fourth time a person reading found the real ones.

**Measured, end to end.** Chapters 7 and 8 were drafted a third time by chapter agents
under the rule: the v2 prompts with only the output path and the "what is new" note
changed, the same sources, and no reading of any earlier version. Bare seams by hand:
chapter 7 v1 **4**, v2 **3**, v3 **0**; chapter 8 **0** in every version, so chapter 8
never had the defect and its v3 shows only that the rule did not damage a clean
chapter. Chapter 7 v3 runs 19 paragraphs and 1,558 prose words, and its 15 paragraph
seams are carried by box, box, domain, question, line, name, identified, party, library
and domain, and marked by but, so, the other, the other, but and put plainly, so no one
device runs the chapter. Both v3 drafts pass `check-book.sh` inside a copy of the full
book folder, and the handoff chain holds from chapter 6 through both of them into
chapter 9. Relation markers from `§ Voice`'s own list, per 1,000 prose words: chapter 7
v1 7.0, v2 10.5, v3 9.6; chapter 8 v1 7.6, v2 10.8, v3 8.1. Density did not rise from
v2 to v3 while the bare seams went to zero. The rule governs the seam, not the marker
count, and the count is not the measure.

**Checked against its source, 2026-09-12.** McNamara, Kintsch, Songer and Kintsch 1996,
from the ERIC record, since the publisher page refuses the fetch and neither Semantic
Scholar nor Crossref carries the abstract: "text coherence improved readers'
comprehension, but also that giving readers with sufficient background knowledge an
incoherent text that forced them to infer unstated relations engaged them in
compensatory processing, allowing deeper text understanding than might occur with a
coherent text." The reverse cohesion effect one council member raised is real, and it
is a result about readers with background knowledge. This skill writes for the
low-knowledge reader, by the operator's own statement of what it is for, and that is
the reader the paper says coherence helps. The finding supports the direction and marks
its boundary: what this spec produces is not the text to hand an expert.

**Asserted.** That the first sentence may rest on nouns the preceding paragraphs left
standing, which is a reading of "already on the table" the old wording did not settle
either way. That writing the exit deliberately reduces rereading, which rests on Gopen
and Swan 1990 and Sanders and Noordman 2000, neither checked against its source here.

**Not done.** The operator read and approved `chapter-07-v3.md` on 2026-09-12, not
blind, since they knew it was the new draft; `chapter-08-v3.md` is unread. The seam
readings above are not theirs, and the one reader who has compared versions (v1 against
v2) was not blind either.
Both marking sheets from this ticket are still blank, so "mandated aphorism versus
missing cohesion" was never settled by reread data. The word cost of the rule is
unmeasured and not separable from run-to-run variance: chapter 7 v3 came in 54 words
under v2 and chapter 8 v3 came in 158 over.

## The ceiling removed, 2026-09-13

Operator decision. A chapter is as long as it has to be to be effective, so the
2,000-word prose ceiling and every target derived from it come out of
`chapter-prose.md`, `SKILL.md`, `check-book.sh` and `/updatebook`. The job the
ceiling was doing, catching a chapter the outline drew too wide, stays; it is
now a thing to notice by reading, and `check-book.sh` reports chapter lengths
and fails on none of them.

**Where the number came from is recorded above and is not deleted.** § The
markdown ban lifted holds the raise from 1,750 to 2,000 and its reasoning, and
§ What the numbers rest on holds the 1,750 the spec was originally compressed
to. Both now describe a ceiling that no longer exists.

**Measured, on the reference book's eighteen chapters, 2026-09-13.**
Prose per chapter runs 1,675 to 1,984 words, totalling 34,106 and averaging
1,895. Fifteen of the eighteen sit above the 1,800-word aim the spec carried,
one sits exactly on it, and the longest stops 16 words under the ceiling itself.
A distribution pressed that hard against a limit is a limit shaping the writing
rather than catching an outlier. That is the evidence the decision wanted, and
it is why this removal is a loosening, which § What the numbers rest on does not
gate the way it gates a tightening.

**What replaced the failing check.** `check-book.sh` still counts prose and
structure apart, and still strips the tags, standalone figure references and
provenance marks before counting. It now prints a second line carrying the mean
chapter and the longest one by name, and nothing about length can fail a run.
The longest chapter is the figure a reader wants when asking whether one chapter
outgrew its claim, and having the script name it beats making them read down a
column of eighteen numbers. Verified on a fixture whose first chapter runs 2,310
words of prose: the previous script failed it at exit 1 naming the ceiling, and
this one exits 0 and reports `longest 2310`.

**Asserted, not measured.** That eleven minutes a chapter is the right sizing
divisor now. It is arithmetic on the 1,895 average at the 175 words a minute the
spec assumes, and that average came from chapters written under the ceiling this
ticket removed, so it is a floor rather than a prediction. `SKILL.md § Sizing
the book` says as much where the divisor is used.

**Not done.** No book has been written without the ceiling, so nothing here
shows what chapters run when nothing is stopping them, nor whether reading
catches an over-wide chapter as reliably as the threshold did. The first book
written under this change is the test.

## Ten chapter agents stopped at once, 2026-09-12

Ten chapter agents writing the reference book were stopped together by a usage
limit, part way through the run. All ten were recovered by resuming each one by
name and telling it what its own file already held, rather than by spawning a
replacement. Two of the ten had stopped mid-edit and came back the same way.

**Resume by name; never respawn.** A replacement agent starts with no memory of
the plan it had already made, so it re-derives the chapter's claim, its cuts and
its term spending, and writes a different chapter from the one the outline
assigned. Read the file on disk first, because that is what says where the
stopped agent got to, and put what it holds into the resume message. The same
rule for the same reason governs any long-running agent whose partial work is
already on disk.

**What a stopped agent left behind was a partial file and never a corrupt one**,
across these ten. Each writes its chapter with the Write tool, so a file was
either absent or whole. Nothing here establishes what a stop partway through a
multi-step edit does in general; the two mid-edit cases recovered, and two cases
are what that claim rests on.

Claim: the skill's "batches of about four" is a safe rate, and this run exceeded
it (as recorded in the ticket body, paraphrasing the original session)
Status: unsupported
Correction: withdrawn. Running ten agents at once rather than four changes when
the token spend lands, not how much of it there is, so the batch size cannot on
its own explain reaching a usage limit. No token accounting was available for
that run and none has been taken since, so nothing measured says what a safe
rate is, or whether the four at `SKILL.md § 5. Draft the chapters` is one. That guidance stands on
the context-window reasoning it was written for, which this incident does not
touch.

## The overview section, 2026-09-20

Ticket #26. Every chapter gains `## In short` directly under the header table:
a carried-in line naming what the chapter reintroduces from earlier ones, then
a walk through what it argues. It is opt-in through `"overview": true` in
`book.json`, absent by default, so every book written before it passes
untouched.

**The failure it fixes was counted, not assumed.** Seventeen of the eighteen
chapters in the reference teaching guide open on a definite noun phrase handed
forward by the chapter before: `The diagram`, `The marks`, `The join`, `The
scan`. Chapter 10 is the only opener that does not. Read in order that works.
Read by jumping to one chapter, the article points at a referent the reader
never had. `chapter-prose.md § Reference` already named this as the worst case
for its own rule; this section is the first thing that does anything about it.

**Three decisions, all the operator's, all recorded because each had a losing
alternative that would have looked fine.**

The carried-in line opens with the literal `Carried in: ` and the checker finds
it by that prefix and nothing else. Inferring it from its first `**term**
(ch. N)` was rejected because both failure modes read as passes: a walk opening
on a glossed term gets swallowed, and a carried-in line whose first term lost
its bold gets skipped.

The cap of three is enforced and the walk's no-glossed-term rule is not. The
difference is that the line is found by a fixed prefix and a count has nothing
to compare, while the walk's rule would need `OUTLINE.md`, which the checker
does not read, and a comparison that does not survive scripting: substrings
over-match and whole words miss inflections. § The reference rules records the
same lesson from the other direction, where a substring match called "the query
plan" glossed by "query planner".

The cross-check resolves each carried-in term against `glossary.md` and
requires an earlier chapter. It runs only where the book declares `overview`
and `glossary` both, because only a glossary says which chapter taught what.

**The section has no end marker, and that is a real limit rather than an
oversight.** It ends where the chapter's opening paragraph begins, and that
paragraph carries no heading, so the next H2 is the part heading below it and
stopping there would swallow it. The sweeps end the section at the first
paragraph tag, failing that at the first paragraph a provenance mark names,
failing that at the next part heading, and failing all three at the end of the
file. A book offering none of the first three lands on the last and counts its
whole chapter as overview, which shows up as a chapter reporting almost no
prose. A book carrying provenance and no tags lands on the third and leaves one
paragraph per chapter whose mark nothing checked, and a missing mark there is
self-concealing: it is the very thing the sweep would have used to find the
boundary. Either way the run prints a note naming the chapter count and what it
cost, rather than letting a moved figure read as a measured one. Declaring
`tags` ends the section exactly, and every book this skill writes declares them.

**Recognising the section is structural; checking it needs the declaration.**
The heading is the section when it is the first H2 and the chapter header table
is the last thing with content before it, because a normal chapter has its
opening paragraph in that gap and a part heading cannot sit there. A book that
uses those two words for a part heading later on fails both tests and is swept
exactly as it was.

Both halves of that split were learned by getting them wrong. Gating on the
heading being present alone failed a pre-existing book that used the words for
a part, on a position rule it never opted into. Gating everything on the
declaration instead broke the no-jq fallback, which is a supported
configuration: `book.json` is only readable where `jq` is, so on a machine
without it the key read as absent, the section became ordinary prose, and every
paragraph in it was reported as missing its tag. A declared book failed on a
machine where an undeclared one passed.

**The prefix is matched twice, loosely and then exactly.** `Carried in:` finds
the line and `Carried in: ` validates it. Matching only the exact form meant a
missing space read as a chapter carrying nothing in, which switched off both
the ceiling and the glossary cross-check: a five-term line naming a term the
book never defined, pointing at a chapter that does not exist, passed clean on
a one-character typo.

**The empty case had to be found twice.** A book where no chapter carries a term
in is legal and ordinary, and every single-chapter book is one. bash 3.2 treats
`"${arr[@]}"` on an empty array as unbound under `set -u`, so the cross-check
aborted the run before its summary line: not a wrong answer but no answer.
`fixtures/overview-nothing-carried/` exists to hold that shape, because the
fixture beside it carries terms in every chapter and can never reach the path.

**Measured while writing the checker, 2026-09-20.** The carried-in line is a
paragraph rather than a physical line. Reading only its first line counted the
terms on that line and ignored the rest, which passed a four-term line whose
first two happened to wrap, and collected only half the terms for the
cross-check. Both bugs were silent and both were found by a fixture whose
carried-in line wrapped.

## The reader at the gate, 2026-09-20

Ticket #23. The reader persona was already carried end to end — settled at
step 1, recorded at the top of `OUTLINE.md`, passed into every chapter agent's
prompt — and was the only one of the three underspecified inputs with neither
an ask nor a line at the confirmation gate. Sizing and tagging both had both.
This adds the gate line and the ask, in that order of importance.

**The gate line is the load-bearing half, and the reason is that a presence
check cannot catch the failure.** Asking "was a persona identified" fires only
when the field is empty, and from a subject plus a folder of sources a
plausible persona is almost always available. What costs a book is a confident
wrong one, which reaches every chapter looking exactly like a persona the
operator supplied. Printing the derived value is what catches it, and step 3
is where the correction is still one message rather than twenty chapters — the
argument that section already makes for its own existence.

**Asserted, not measured.** The case behind the ticket is the reference teaching
guide, whose persona came from the invocation string rather than from anything
the skill elicited, and whose `about-this-book.md` opens on that sentence plus
the sprint dates the sources supplied. A vaguer argument would have produced a
book with an inferred reader and no point at which anyone checked it. That
account is the ticket's, recorded here because it is the motivating case; the
book is not in this repo and nothing about it was re-measured for this change.

**Two decisions, both the operator's, 2026-09-20.**

The gate line marks provenance rather than printing the persona bare. The
decision was taken while a persona had two origins, the argument or inference;
the ask below adds a third, the operator's answer to it, and the shipped line
names all three. The bare value was the alternative, and it
would have kept step 3's display list uniform, since its six other entries are
all bare values. It loses because the marker is the whole point: an inferred
persona that prints identically to a supplied one gets read past.

The ask lives inside step 1 rather than in a section of its own. Sizing and
tagging, whose form the ask copies, both sit in their own sections, so the
alternative was the more consistent one. It loses to keeping the reader's
handling in one place, which is where an operator reading step 1 looks for it.

**The wording holds a boundary two things called "the reader" share.**
`chapter-prose.md § The reader` fixes the reading posture and is settled by
design; this ticket touches the domain persona only. The second of the two new
step 1 paragraphs says so outright, because the paragraph above the new ask
cites the posture file and an agent reading quickly would otherwise have two
readers and one name.

## The guide profile, 2026-09-20

**What was measured, and it is one book.** The reference teaching guide
(18 chapters, read end to end on 2026-09-20) is the whole
evidence base for this profile, and every figure below is a count over that
book alone. One book is not a corpus. The direction each number points is what
the profile rests on; none of the magnitudes should be quoted as a property of
books in general.

| Measured on the reference book | Figure |
|---|---|
| Words on the page | 61,723 |
| Of which prose paragraphs | 34,281 (55.5%) |
| Slide notes | 8,733 (14.1%) |
| Tables | 8,564 (13.9%) |
| Chapter header tables | 5,187 (8.4%) |
| Concept lists | 2,562 (4.2%) |
| Chapters opening on the previous chapter's handoff noun | 17 of 18 |
| Figures-page entries that were slides | 66 of 76 |
| "the export carries no key" caveat | 22 occurrences across 13 chapters |
| Parenthetical citations in one chapter's prose | 30 in 1,945 words |
| Glossary entries filed under `#` by a leading backtick | 2 |

**What is asserted rather than measured.** Every rule in
`guide.md` is a judgement about what a scanning
reader needs, argued from the counts above and from the instructional-design
literature, and **none of it has been tried on a reader.** Specifically
asserted: that headings carrying the point beat redundant ones; that four
callout labels are the right four and that four is the right number of them;
that a numbered procedure helps where a chained mechanism walk does not; that
appendices are where reference matter belongs. The narration profile's own
rules were derived from a transcript corpus and are not better evidenced on
this question, because that corpus was audio and this reader is not listening.

**The one rule kept because it had evidence.** A heading is never a term's
first appearance survives into the guide profile unchanged, since it is the one
rule in `§ Headings` with a measurement behind it (`§ Where the part headings
came from`). Everything else in that section was relaxed.

**Why two profiles rather than one loosened set.** A single set tuned for both
readers is slightly wrong for each, and more practically: every book written
before this existed had to keep passing untouched. Absent has to mean
narration, so the checker's default could not be anything else, and
`check-book.sh` reads the profile from `book.json` and never infers it from the
chapters. Inferring it would turn a failure into a silent reclassification,
which is the shape of the jq bug in `§ Phase 0` of this branch's plan: a check
that got weaker and reported a pass.

**The written default moved to `guide` on 2026-09-20, and the read default did
not.** The sentence above holds for `check-book.sh` unchanged. What changed is
what `/createbook` puts in a new `book.json`: the template now carries
`"profile": "guide"`, on the operator's judgement that a book built from a set
of sources is nearly always opened at the chapter somebody needs. The two
defaults are now different on purpose, and the distinction is the whole reason
the change is safe. Flipping the read default instead was measured and rejected:
forcing the `fence/` fixture to `guide` turns a passing book into two
`FAIL ... no "## In short" section` lines, because the guide profile sets
`ovw_mode=required`. Every book written before this date would have failed the
same way. Nothing about the rule sets themselves changed, and no existing
`book.json` was touched.

### Five decisions the ticket left open

Each was settled on the reasoning below rather than by the operator, and each
is cheap to revisit because nothing outside this plugin depends on it yet.

- **Appendix filenames are `<book-slug>-appendix-<N>-<slug>.md`, and appendices
  are tagged `[A<N>-<n>]`.** Sorting decided the filename: `a` sorts after
  every digit, so a plain filename sort is still the reading order, which is
  the constraint `SKILL.md § Filenames` puts on the whole folder. Tagging
  decided itself: an appendix holds exactly the material a chapter cites, so it
  needs addresses, and an `A` prefix keeps a renumbered chapter from colliding
  with one.
- **The reading edition takes both a flag and a `book.json` key**, flag
  winning. That is the order `check-book.sh` already uses for the tag decision,
  and two tools reading a declaration the same way is worth more than either
  ordering is on its own.
- **A declared-but-unreadable `book.json` stays a note rather than a failure.**
  The jq guard now stops the run where jq is present and broken, which was the
  dangerous case. What is left is jq genuinely absent, and the no-jq fallback
  is a documented, supported configuration: failing it would make the plugin
  unusable without jq to close a hole that now prints its own warning.
- **`slide_figures` names a folder, and the compact row applies in both
  editions.** A divider slide orphaning half a page is a defect in any edition,
  so gating the fix on the reading edition would have left it unfixed where
  most books bind.
- **Source display names use the object form**, `{"path", "display"}`, rather
  than a parallel `source_names` map. One entry per source cannot drift out of
  sync with itself. The bare string form stays valid and unchanged.

### What the read-time estimate counts

**It now counts every word on the page**, where it counted prose alone. On the
reference book the prose was 55.5% of the words, so the old estimate reported
about 194 minutes for a book that runs about 352 at the same 175 words a
minute. Nothing about the book changed; the number was measuring the wrong
thing, and a reader planning an evening around it was being told roughly half.

**The 1.8 factor at `SKILL.md § The read-time estimate` is the weakest number
in this plugin.** It is `1 / 0.555` from one book. It exists because step 3 has
to estimate before any chapter is written, and it is superseded by real figures
at step 9, where `check-book.sh` has counted both halves. Prefer the step 9
number wherever both exist.

### The glossary defect was three symptoms of one cause

`build_glossary` never took the markdown off a term, so a term written as a
code span sorted under its backtick, was filed under the `#` heading, and
printed its backticks literally. One `gloss_sort_key` fixed all three. The EPUB
had its own glossary builder with the same three symptoms, which is why the fix
had to land twice: **the two builders are separate because their markup is**,
and a term filed under P in one edition and under `#` in the other is exactly
the divergence that split them.

## The estimator's constant read as a budget, 2026-09-20

**Observed once, reported by an operator mid-book.** A session writing a book
under this skill put "each week chapter stays ~1,900 words" in its plan. Nothing
in the plugin asks for that. `chapter-prose.md § Length` sets no ceiling, no
target and no floor, `check-book.sh` reports both word figures and fails on
neither, and step 5's brief hands a chapter agent paths and the prose spec with
no word figure in it. The number was invented by the session out of the one
place the plugin still prints it.

**The cause was distance between a number and its guard.** `SKILL.md § Sizing
the book` says the sizing estimate is "never a budget handed to a chapter
agent", and that sentence is correct and was already there. But the 1,900 itself
lives one subsection further down, in § The read-time estimate's table, where it
appears as a bare multiplicand with nothing next to it saying what it is not. A
reader arriving at the table for the arithmetic does not necessarily carry the
guard down from the prose above it.

**What changed.** The table cell now carries "an estimator's constant, never a
drafting target" inline, and a paragraph under the table restates the guard with
the failure named in the words it actually appears in — a plan saying a chapter
stays at about 1,900 words has turned the estimate into a budget — and says the
fix is to strike the number rather than hold the chapters to it. Naming the
symptom sentence is the point: a guard phrased only as a principle does not
match against the line a session is about to write.

**Not done, and this is the weak part.** One report, from one session, and no
book has been written since the wording changed. Whether an inline caveat stops
a number from being read as a target is not something this entry can claim. It
is the same open question § The ceiling removed left behind, one layer up: that
entry removed the limit and this one removes a number that was standing in for
it.

## The rule most worth keeping

Scope discipline in the Never section earned its place: an earlier version twice wrote that 513 fragments came from "the nine transcripts" when the figure was measured over five. A real number widened past its measured population is an invented number. That guard is why `chapter-prose.md § Never` requires the sentence carrying a figure to name the population it covers.

## Copies

Unlike the skill it forked from, nothing here is synced to another repo. `/ne` ships byte-identical in three separate repos, and a change to one is a three-repo port. This folder has no such obligation: `createbook/` and `makebook/` are self-contained and ship together in this plugin, so an install carries the pair.

## The fixture suite, 2026-09-23

Ticket #6. The fixture folders were the only verification these checkers had, and
nothing ran them but a person remembering to. This adds
`bookcraft/scripts/test-fixtures.sh` and the repo's first CI workflow.

**Measured, and the reason the suite is not exit-code-only.**
`fixtures/provenance/` exited 1 under `check-book.sh` from the day it was written.
The cause was neither a provenance defect nor an intentional negative case: both
chapters carried one part heading, and a chapter's shape is two or three, so the
folder failed a structural rule neither chapter was written to exercise. The
provenance signal was never in that exit code at all. A suite asserting only
`provenance=1` would have passed it indefinitely while reporting nothing. Both
chapters were split into two parts; the folder now exits 0 under `check-book.sh`
and still exits 1 under `check-provenance.sh` with the same 6 failures and 1
review its `book.json` has always asserted, all seven against chapter 2.

So every expectation in the manifest names a string the output must carry.
Verified by silencing the H3 rule in `check-book.sh`: `guide-under-narration/`
still exited 1, on its remaining four failures, and only the missing
`body carries an H3 or deeper` caught it.

**Measured: the fixture count in the ticket was wrong, and that is the drift the
completeness check exists to stop.** The ticket named four folders. There were
eight under `createbook/fixtures/` when it was written, seven of them older than
the ticket, plus one under `check-claims/`. A folder covered by neither a manifest
row nor a `run.sh` now fails the run, so a fixture added without an assertion
cannot go quiet the way these did.

**Asserted, not measured: that the manifest's expected codes hold without `jq`.**
They do not, and the suite refuses to grade them in that configuration rather than
guessing. `fixtures/guide/` passes only because its profile declaration is read;
with no `jq` the declaration is invisible, the narration rules apply, and the
folder correctly fails. The absent-`jq` path is covered in
`fixtures/jq-unrunnable/run.sh` instead, as a third half beside the working-`jq`
and unrunnable-`jq` ones.

**Measured while writing that third half.** Hiding `jq` means a `PATH` with no
`jq` on it, and pruning whole directories will not do: on a stock Linux `jq` sits
in `/usr/bin` beside `awk`, `sed` and `grep`, so pruning that directory removes
the tools the checker needs. Building a symlink farm of everything on `PATH`
except `jq` is what works. The first version ran a `$(basename)` subshell per
entry and took 32 seconds; one `ln -s` per directory, letting `ln` refuse to
clobber so `PATH` precedence survives, takes 1.5. The whole suite runs in under
six seconds.

## The rule files split, 2026-09-24

Ticket #28, Phase 1. `reference/chapter-prose.md` held every rule for both profiles:
about 9,000 words of narration rules, then about 2,400 words saying which of them a guide
should ignore. `SKILL.md § 5` already warned that an agent told only to read the file reads
the narration rules first and at length. So the file was split three ways:

| File | Holds | Read by |
|---|---|---|
| `reference/chapter-prose.md` | The rules every chapter follows: the reader, the sources, shape, seams, glosses, the budgets, the header, the carried-in line, tags, provenance, voice, reference, § Never and the shared checks | Every chapter agent |
| `reference/narration.md` | The handoff chain, the five things a part does, the required wrong model, redundant headings, and the `## In short` walk | Narration chapters |
| `reference/guide.md` | The guide profile as a rule set of its own, with before-and-after examples | Guide chapters |

A guide chapter agent now reads about 7,800 words where it read about 11,700, and none of
them are rules it is told to ignore.

**The core kept its name** so that a citation of a rule that did not move still resolves.
Only citations of moved rules changed, and only their filename. `scripts/check-citations.py`
confirmed every `<file> § <rule>` citation resolves after the move.

**The reasoning moved here, and the rules stayed.** The rule files are what an agent reads
at draft time, so they hold the rule and at most a clause of why. The longer arguments are
in § Why the core rules say what they say and § Why the guide rules say what they say,
below. `narration.md` is the exception: its text moved from `chapter-prose.md` unchanged,
reasoning included, because this ticket is about guide books and rewriting the narration
rules would change books nobody asked to change.

**The core and the guide file are written in the style they ask for.** The ticket measured
two verbal habits in the old spec and found them again in the reference guide's chapters.
"Rather than" ran at 5.4 per 1,000 words in the spec and 3.6 in the book; "carries" at 4.1
and 2.0. The ticket called that a correlation, not a measured cause, and said the split
would make it cheap to test. Counted on 2026-09-24, before and after:

| | Words | "rather than" | "carry" and its forms |
|---|---|---|---|
| Old `chapter-prose.md` | 11,668 | 63 | 62 |
| New `chapter-prose.md` plus `guide.md` | about 7,800 | 1 | 12 |

The one "rather than" left is inside the `Warning.` label's own description. Whether the
next guide book shows fewer of either habit is the test, and it has not been run. Every
paragraph in both files is also held to the 90-word stop and every sentence to 45, which
the old file broke in several places.

**One inconsistency was fixed in passing.** `§ A shape for a teaching chapter` offered five
sections, four of them H2 parts, while `check-book.sh` fails a chapter with four parts. The
key now goes to an appendix, so the shape has three parts and passes the checker.

### Why the core rules say what they say

Each entry names the rule in `reference/chapter-prose.md` and gives the argument that used
to sit beside it.

- **The reader.** The two readings pull in opposite directions: the first wants an argument
  to follow, the second wants an address. That is what the chapter header, the provenance
  marks and the concept list are for, and it is why no rule asks the prose itself to become
  a briefing.
- **Length.** Length still carries a signal, read and never thresholded. A chapter running
  well past its neighbours is usually the outline drawing one chapter too wide, and only
  reading can tell a subject that needed the room from a chapter that lost its shape. A
  table of ten facts does not cost ten sentences' worth of attention, which is why structure
  is counted apart from prose.
- **Shape.** Never four parts, because four give the reader a fourth handoff and a fourth
  named weakness to carry.
- **Seams.** A seam with no device is the commonest seam in a chapter written without the
  rule, and the paragraph seams are where a reader who understood every sentence still cannot
  say what the chapter argued. Pairing a named referent with a marker is often the best seam
  on the page.
- **Glosses.** Describing the behaviour before attaching the label is one of the two patterns
  with measured evidence behind it (§ What the numbers rest on).
- **The wrong model.** The passage costs about 130 words and asks the reader to hold a
  picture they then discard. The concession is what stops the reader defending the naive fix
  instead of updating. It is the other evidenced pattern.
- **Spend these deliberately.** An anchor takes two sentences because the name, its role and
  the case it explains never fit in one. A name that only says what the chapter is about
  spends nothing, because finding it wrong tells the reader they hold a different chapter,
  not a broken one. A citation spends nothing because the budget exists to keep unearned
  checkable names off the page, and a citation is the reader's route back to the authority.
  A second analogy does not rise with length, because it makes the reader hold two pictures
  at once. A partial quotation of a source's table reads as complete and is not, which is
  why a published set is reproduced whole.
- **Prerequisites.** Naming the idea that needed the aside, in the sentence after it, lets
  the reader feel the debt paid instead of a thread dropped. The aside belongs to the part
  that needed it, so it never stands as a section of its own.
- **Headings.** A heading being a term's first appearance hands the reader the label before
  the behaviour, which inverts the gloss rule. That is the one heading rule with a
  measurement behind it (§ Where the part headings came from).
- **The chapter header.** It makes the second reading possible: the reader who is not
  reading the argument tonight but wants to know what the chapter settles. Written first,
  the drift between a plan and what got written is exactly what a reader trusts it not to
  have.
- **In short, the carried-in line.** The literal prefix exists because inferring the line
  from its first bolded term swallows a walk that opens on a glossed term and skips a line
  whose first term lost its bold, and both read as a clean pass. The ledger row is far too
  long to use whole, and an unenforced ceiling is how the line grows back into the header it
  exists not to duplicate. A third wording beside the chapter's gloss and the glossary entry
  is how a book comes to say three slightly different things about one term. `(ch. N)` is
  used over a paragraph tag because a tag is more precise and more brittle. The history is
  at § The overview section, 2026-09-20.
- **Paragraph tags.** A tag is an address other files cite, so nothing that is not a
  paragraph may advance the count: a table added to a finished chapter must not renumber
  the paragraphs after it.
- **Provenance.** A sourced claim is fixed by its resource, and a filled-in claim is where a
  version, a default or a name goes stale. Marking every unit turns "recheck everything the
  sources did not say" into a query instead of a reread of twenty chapters. A comment left
  open swallows the rest of the file, and a mark that misses the grammar is invisible to
  that query, which is why `check-book.sh` enforces both.
- **Suggested reading.** A link rots, and the reader is going to a search box anyway, so the
  list gives them the words that make the search work. Fewer than three items usually means
  nobody looked for the edge; more than six is a syllabus. A mostly filled-in chapter needs
  the list most, because the reader has just been told the sources were thin.
- **The plan.** It catches parts that each work on their own and never add up, which is
  nearly impossible to see once drafting has started.
- **Voice.** There is no target for the mean sentence length because naming a referent and
  marking a relation both cost words and both buy back more than they cost.
- **Reference.** This is the cheapest reread in the book to introduce and the hardest to see,
  because the writer always knows what the word meant. How many words the reference rules
  add has never been measured; only the direction is established, so the spec carries no
  figure for it.
- **Never, on markdown.** An older rule held that easy to read and easy to skim are
  opposites. It was written for a reader who only ever read straight through; this reader
  comes back for a fact, so a table they can land on is a service. The guard that matters is
  prose by default, with every structure answering for what a sentence would have lost.
- **Never, on synonyms.** Cycling synonyms costs double in a book, because a reader who met
  the term once now has to learn that a second term exists.
- **Never, on the listed words.** They mark prose as generated before the argument gets a
  hearing.
- **Before sending.** The countable rules hold and the rules stated as judgements quietly go
  unfollowed, which is why the reference sweep is written out as a list. Nothing triggers a
  cut by arithmetic, because § Length sets no ceiling; the cut order exists because trimming
  evenly across sentences eats the glosses and the hedges first, and those do the teaching.
  The aside, the header, the concept list and the marks are not prose the reader walks
  through, so cutting them saves nothing and costs the second reading.

### Why the guide rules say what they say

The evidence for the guide profile, and its limits, are at § The guide profile, 2026-09-20.
These are the arguments that sat beside its rules.

- **Why two profiles.** The narration rules were derived from audio narration, where a
  listener cannot look back. Every one of them is right for a reader who starts at the first
  sentence and goes to the last. Applied to a book opened at one chapter, they produce linked
  essays with a lookup layer bolted on, which is well written and hard to use.
- **Opening.** The handoff opening bought continuity for a reader going straight through,
  and it costs that reader nothing to lose, because the outline still orders the chapters.
  It was costing the reader who opens chapter 13 on a Saturday, for whom a definite article
  pointing at chapter 12's last noun is a referent they never held.
- **Headings.** The narration rule required a heading to be redundant with the prose, so a
  reader who ignored every heading lost nothing. Its defence was that the handoff keeps
  working underneath. A guide has no handoff, so the defence is gone and the rule with it.
  A reader looking for what to do about late submissions needs a heading that says so.
- **Callouts.** Nothing on a narration page says which kind of sentence you are reading, so
  a warning, a grading rule and an aside about the room all render as body prose. A reader
  going straight through infers the kind from the argument; a reader scanning cannot. The
  label is literal for the reason the carried-in prefix is: a checker left to infer it has
  to guess, and both of its guesses read as a clean pass.
- **Section ends.** A reader who opens one part, reads it and closes the book should not be
  left holding only the thing that breaks it.
- **The wrong model.** The rule was right about explanation and wrong about reference.
  Where the misconception is real the passage is the best teaching a chapter can do; where
  it is not, the rule forces a strawman that costs 130 words and the reader's trust.
- **Provenance in prose.** The narration rule produced thirty parenthetical citations in
  under two thousand words of one reference chapter, which is a paragraph nobody can read at
  speed. Attribution did not weaken: the mark beside every unit is exhaustive where the
  prose was selective. A caveat repeated twenty-two times across thirteen chapters is noise
  the reader learns to skip.
- **Appendices.** The narration rules gave no home to the material a guide accumulates, so
  answer keys and rubric pairs landed in whichever chapter was being written when they came
  up, where no reader will look for them.

**What the audit of the split found.** An independent read of the old file against the three
new ones found eight rules lost, six weakened and four contradictions, nearly all on the guide
side: rules a guide chapter used to inherit by default had moved into `narration.md` with
their narration-only neighbours. All were restored except one change, kept on purpose. Under
`guide` a part walks a mechanism only where it explains one (`guide.md § What a part does`),
because a part that delivers a procedure, a lesson script or a grading rule has none, and
the old inherited rule was forcing one.

## The handoff chain leaves the guide path, 2026-09-24

Ticket #28, Phase 2. The guide profile had dropped the rule that a chapter opens on the
previous chapter's closing noun, but `SKILL.md § 2` still wrote an **Opens on** and a
**Closes on** row for every chapter, `§ The plan` still called the opening noun fixed, and
step 8 still read the seams for it. The outline recorded both nouns, the agents used them,
and the reference guide's chapters opened on "The blanks are the fields...", "The scan is
what week four ended on" and similar: each "the" pointing at something a reader who jumped
straight to that chapter never saw.

Under `guide` now: the outline records a **Scope** row and no handoff nouns; step 5 hands
the agent the chapter's scope and its neighbours' titles, never a noun; the opening
paragraph orients the reader; the close lands the chapter's main point or the next step and
hands nothing forward; parts do not hand off either; and step 8 reads openings and closes
for those two jobs. Narration is untouched.

**One close in the reference guide was false**: chapter 1 ended "Everything in this chapter
is a date" after covering prerequisites, pass-offs, withdrawal grades and the roster. That is
why `guide.md § Close` requires the close to be true of the whole chapter, and why step 8
reads each close against its chapter.

**Asserted, not measured**: that an orienting opening reads better for this reader than a
handoff. Phase 7's blind comparison is the first test.

## In short under guide, 2026-09-24

Ticket #28, Phase 3. Three changes, all under `guide` only.

**The summary may use the chapter's own terms, with a short definition in the same clause.**
The narration rule that the walk may use no glossed term turned the summary into a riddle in
the chapters that most needed one: the reference guide's chapter 10 summary covered
functional dependencies, candidate keys and attribute closure without naming any of them.

**It stops near 120 words or five sentences, and it never reuses the chapter's sentences.**
The reference guide's summaries ran 150 to 400 words, and in five chapters a summary shared
20 to 44 six-word runs with the opening paragraph. The 120 is a judgement, not a
measurement; the ticket said so and so does this note. `check-book.sh` reports a summary over
120 words and any eight-word run it shares with the chapter below it. Eight words, not six,
because a six-word run catches stock phrases a summary and a chapter can share innocently;
that threshold is asserted too.

**The `This chapter` header row merged into it.** A guide chapter stated its main point four
times: in that row, in the summary, in each part's last sentence and in the close. The
header tables and `## In short` sections together were about 14% of the reference guide,
all of it before the first paragraph. The spec named the walk's ban on glossed terms as the
one rule keeping the row and the summary apart, and the first change above removes it, so
keeping both would leave two summaries of one chapter. No script reads the row, so the change
was the spec, the guide fixtures and `SKILL.md`'s example. An appendix with no summary may
keep the row.

## The stops checked, and the reports, 2026-09-24

Ticket #28, Phase 4. The spec called the 90-word paragraph and the 45-word sentence hard
stops, and nothing checked either. In the reference guide the sentence stop held (4 of 2,071
over) and the paragraph stop did not (46 of 576 over, 13 of them past 120, the longest at
207), and 28 of the 46 sat in chapters 1 to 4, among the most revised.

**The paragraph stop fails a `guide` book and is reported under `narration`.** The operator
chose failing on 2026-09-24, once the reference guide was set to be recreated rather than
patched, which removed the one named cost. A paragraph is counted exactly, by the same state
machine as the tag sweep. Narration reports instead, so every narration book written before
the check still passes: `fixtures/fence/` has a 108-word paragraph and now draws one report.

**Everything else new is a report, and none fails.** A sentence boundary is a script's guess
(a word ending `.`, `!` or `?` before a word that does not start in lowercase, except
`p.`, `ch.`, `e.g.` and a few others), so the sentence stop and the callout length are
reported. The summary's length and shared runs, the recurring phrases and the header keys
are reported because each needs a reader to judge.

**The recurring-phrase report counts four-word runs once per chapter**, keeps only runs with
at least two words that are not function words, and lists the ten found in the most
chapters. The stock phrasings the ticket found ("suggests itself" in four chapters, "The
instinct is a good one" in three) are what it is for. It also finds a book's own
vocabulary, which recurs by design; the cap keeps that from burying the rest.

**The header check reports a repo-path key only where it has no display name**, because
Phase 6 makes `/makebook` swap a named key for its name in the header and the endnotes.

**Measured against the two real guide books, 2026-09-24.** An independent review ran the new
checker over both: 46 and 7 paragraph-stop failures, the 46 matching the ticket's own count,
and every paragraph spot-checked carried the reported word count. Output was identical under
BSD awk, gawk 5.2.1 and mawk 1.3.4. The run is slower, about 30 seconds where it was 19.5 on
a 105,000-word book, from the extra sweeps per chapter.

**One known gap, disclosed and not fixed.** In a guide book declaring neither tags nor
provenance, `## In short` has no marked end and runs to the first part heading, so the
opening paragraph sits inside it: it escapes the paragraph stop and its words count toward
the summary reports. The run's existing fallback note now says so. Every book this skill
writes declares tags, which ends the section exactly.

**Fixtures.** `fixtures/guide-reports/` is a passing guide book that draws every report, and
its manifest row names each one and asserts that a key with a display name is not reported.
`fixtures/paragraph-stop/run.sh` runs one chapter under both profiles and asserts the fail
and the report.

## What a guide's reader is handed, 2026-09-24

Ticket #28, Phase 6. The reference guide was bound in the default edition, so every
paragraph opened on a tag like `[16-1]` and every chapter opened on the `Draws on` and
`Fills in` rows written for the operator. Three changes, the first in this skill and the
other two in `/makebook`.

**A guide book declares `"edition": "reading"`.** The template in `SKILL.md § 4` carries it
for `guide` and a narration book leaves it out. `/makebook` already read the key, so its
"every run writes both formats" contract stands: a guide bind with no flag writes the
reader's PDF and EPUB, and the operator's tagged copy is `--no-reading-edition` with its
own `--out`. The operator chose this over one run writing four files on 2026-09-24. This
reverses the older advice here to leave the key out and pass the flag, which assumed the
tagged copy was the one most binds wanted; for a guide it is the one fewest readers want.

**Display names replace source keys in the chapter header, in both editions.** Four of the
reference guide's `Draws on` rows named `CLAUDE.md § Teaching Calendar` although
`book.json` gave it a display name, because the binder never swapped one in, and
`check-book.sh` skipped table rows on the reasoning that the reading edition moves them.
`build-book.py`'s `swap_display_names` now does the swap on the header before either
edition renders it, so the endnotes get it too, and `check-book.sh` reports a path-like
header key that has no display name to swap.

**The swap touches only path-like keys, and only in the `Draws on` and `Fills in` rows**,
and the first three versions did not. A key like `syllabus` already reads as a name, and
the header writes it as one; swapping it for a display name starting with "the" printed
"the the syllabus" in 34 header rows of the two real guide books. Now only a key passing
`check-book.sh`'s repo-path test is swapped, and an article already in front of a key is
kept in place of the name's own. On rows, the first two versions did not stay put either. The first ran on everything above the first H2, which in a narration
chapter with no `## In short` includes the opening paragraph. The second ran on every table
row, and the branch review found it printing "Check your the syllabus" in the `Act on this`
row, the one row a reader of the reading edition still sees, because `syllabus` is a key
whose display name is "the syllabus". A key that is an ordinary word appears in the author's
prose as that word, so only the rows that name sources are the swap's to change.
`makebook/fixtures/display-names/run.sh` lifts the function out of `build-book.py` and runs
it under plain `python3`, so CI covers it without a bind; each earlier version fails it.
**Not covered:** a key in a code span followed by `:` or `#`, such as `` `CLAUDE.md:42` ``,
is left as written, and `check-book.sh` does not report it because the key has a name.

**The page markers are out of the finished PDF's text layer.** They are how every page
number is found, and `pdftotext` returned `ZQCH016QZ`, `ZQTOCSTARTQZ` and the rest. The
settled book is now rendered once more with `.probe{visibility:hidden}`, which keeps each
marker's box and paints no text, and the run compares the two renders page by page with
the marker strings removed before keeping the clean one.

**Verified by hand, 2026-09-24, and not by the fixture suite.** Bound `fixtures/guide/`
before and after: 13 pages both times, 9 markers in the text layer before and none after,
and the two texts identical once the markers were stripped. Bound `fixtures/guide-reports/`
in both editions: the header row read "the course calendar § Week 3" in the default
edition, the endnote read the same in the reading edition and its EPUB, and
`notes/policy.md`, which has no display name, printed as written. The suite did not bind
then, because CI installed Python and `jq` and not the Chromium the binder drives. The
display-name swap was covered anyway, by the fixture above. Since #32 it binds
`fixtures/guide/` on every run (`makebook/fixtures/bind/`), but asserts only that both
formats are written, the cover fits on page 1, the EPUB has rasterised cover art and the
two stamps agree. The hidden markers are still checked by nothing.

## assertions.json, 2026-09-25

Ticket #46. A book rests on its sources and on everything it was told or settled along the way, and until this the second kind had no home. It lived in chapter prose, in outline revision notes keyed by paragraph tag, and in commit history, so a recreate from the outline and the sources dropped it. `SKILL.md § The assertions file` is the format, and `scripts/assertions.sh` is its only definition.

**Measured, by the ticket, on the reference guide** (guide profile, eighteen chapters, three appendices), and not re-measured here:

- 60 commits touched the book folder, and 21 of them changed a chapter while leaving `OUTLINE.md` alone.
- 15 revision notes sat on the outline's chapter rows, and 12 of those named the change by paragraph tag, which a recreate renumbers.
- 755 provenance marks: 476 name `fill` and 77 name `measured`. Another 42, across four labels, name an `unsourced` label that stands for a fact rather than a method: a live site read on one date, an email, a message thread, a page behind sign-in. No check ever opened anything behind them.

Each of the four cases the ticket names is something a recreate from the outline and the sources gets wrong:

- a premise that changed, the class size
- a recommendation the operator acted on, an exam window
- rulings with no source
- an answer key that was derived and then corrected

**Asserted, with the reasoning, and not yet measured against a real backfill:**

- **JSON, written by one helper whose `check` is the format.** No schema file ships and no validator joins the venv, so the file has one definition. `check-provenance.sh` imports `load` by path rather than parsing it a second way, the same way it borrows `check-references.sh`'s quote pairing.
- **`next_id`, and no gaps below it.** Uniqueness alone lets the newest entry be deleted by hand and its ID handed to the next `add`, and a mark citing the old ID then resolves cleanly to a different claim. Entries are retired, never deleted.
- **`legacy` beside `expected`.** A backfill writes over prose that no mark can cite yet. Reporting every uncited entry would list nearly every backfilled entry on every run until the recreate, and a report that always fires is one nobody reads. After a recreate, `expect --all` makes every carried entry `expected`, and the uncited report becomes the list of what the new book dropped.
- **The premise sweep is REVIEW, never FAIL**, for the reason the quotation check is (§ at the top of `check-provenance.sh`). A phrase can match a sentence that is not built on the premise, and a gate that fires on false positives teaches its reader to pass it. The reference guide's backfill has since measured it; see below.
- **The sweep and the uncited report ignore `--chapters`**, for the reason the paragraph-tag list already did. Each is a claim about the whole book, and a superseded premise in a chapter outside the scope is exactly what the sweep exists to find.
- **One writer at a time.** Every write rewrites the whole file, so two chapter agents in one parallel batch would silently lose an entry. Agents report what they measure in their findings file, and the session writes it.
- **`unsourced` is for a method, never a fact.** A label is never opened by any check, so a fact behind one is a claim the tooling has agreed not to see. As an entry it is resolved by every mark that cites it.

**Settled by the operator, 2026-09-25**, with the options weighed in the branch's `PLAN.md`:

- **A recreate is `/createbook --recreate <old-folder> <new-folder>`, into a new folder.** An existing-folder argument keeps meaning "add chapters", so one misread folder can never turn an append into a rewrite. Rewriting in place would leave the old chapter files for `/makebook` to bind beside the new ones.
- **A backfill confirms by triage.** Solid candidates are grouped by kind for striking, and doubtful ones are asked one by one. A backfill arrives uninvited on the first run after this ships, AskUserQuestion carries at most four questions, and a uniform table invites rubber-stamping, which is the failure `SKILL.md § 3` names for a persona: "a label reads as something already settled".

**The fixture** is `fixtures/assertions/`. Its `run.sh` rebuilds the committed file from the helper's own commands and requires it byte-identical, fails `check` on ten malformed files by name, and runs `check-provenance.sh` over the folder and over mutated copies: a superseded, a retired and an unreadable citation, a missing file, a reserved source name, a newer format, a premise changed twice, and a book with no marks. Breaking the sweep and the `legacy` filter in a copy of the checker failed it, so it catches both.

**Measured on the reference guide's backfill, 2026-09-25**, run with this branch's scripts, before any chapter cited an entry:

- **Candidates.** 41 were gathered and 40 confirmed. The one left out was the book's own recommendation, which the operator had not yet acted on, so it stays `fill`. Four were asked individually, and the other 36 were confirmed from tables grouped by kind with nothing struck. The written file holds 20 measurements, 9 rulings (one of them written and then retired), 4 given facts, 2 settled entries (one an answer key of 56 items with one replayed correction), and the premise pair.
- **Fact labels.** 49 mark components named an `unsourced` label that stands for a fact, across four labels, against 42 when the ticket counted. Their facts became 7 entries. The marks keep their labels until a rewrite cites the entries.
- **Found only by looking.** The `/createbook` argument, which the book folder never held, survived verbatim in a prompts file beside it. One exclusion the argument states had been lifted in practice two days after the book was written, and nothing recorded that. Checking the exclusion against the prose is what found it.
- **The sweep's precision and recall.** The four phrases the operator first approved matched 22 lines, and 21 of them were built on the old value. The one borderline hit was a ledger row. Grepping the bare value word turned up the rest, mostly arithmetic that never repeats the canonical phrase: "twenty of those", "at twenty", "above twenty", "twenty times". Ten phrases drawn from that grep raised the count to 35 lines: 33 built on the old value, the borderline row, and one false positive, "all twenty of those evenings". So the first four phrases found 21 of 33 premise lines, and backfill step 3 now proposes phrases from the bare-value sweep for that reason.
