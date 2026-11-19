# PR review: bookcraft: a primer profile, subject first, selected and sized to a reading budget

Reviewed: the uncommitted working tree against `feature/130-bookcraft-fix-the-block-quote-check-inside-code-fences-and-warn-on-stray-bound-files` (stacked branch). Ticket: cjus/cjus-skills issue 128. No earlier `pr-review-*.md` in this plan folder, so this is a first review.

Verification run: `plugins/bookcraft/scripts/test-fixtures.sh --strict` passes 22 of 22. `check-book.sh fixtures/primer` exits 0 with exactly the two expected REPORT lines. `check-provenance.sh fixtures/primer` exits 0 (no `sources` map, as the summary says). I also ran two probes on a scratch copy of the fixture (results under Important 2 and 3). Leak sweep: no banned terms, no other repo or `org/repo#N` references, and nothing names the trial's source book. Attribution: none. Em dash: none in `primer.md`, the fixture or the changelog folder (the one in the diff is pre-existing SKILL.md prose on an unchanged clause).

## Summary

The PR adds a third `/createbook` profile, `primer`, and makes it the default for new books. It has a standalone rule file (`reference/primer.md`), primer branches in `check-book.sh` (closing heading, shape rule lifted, H3 allowed, H4 still fails, appendices allowed, paragraph ceiling reported and never failed) and a new paragraph-clustering report under every profile. It also adds a § Under the primer profile in `createbook/SKILL.md`, a primer clause in `updatebook/SKILL.md`, and a two-chapter fixture.

## What is working well

- **The checker changes are small and exact.** Overriding `sugg_heading` and `para_max` once, straight after the profile is parsed, means every sweep that already keys off those variables (tag counter, unit walk, provenance walk, closing-section position and items, shape-rule subtraction) picks up the primer heading without a single extra branch. I traced each `profile = guide` / `!= guide` site. The appendix guard (`= narration`), the H4 rule (`guide || primer`), the shape exemption (`!= primer`), and keeping the callout branch and `## In short` summary checks guide-only are all right for primer.
- **The clustering report is honest about what it is.** It is report-only and gated at eight paragraphs, and its comment gives the evidence for its threshold. Proving it adds nothing to the existing guide fixtures through the unchanged `guide-reports` count of 7 is a good use of an exact-count assertion.
- **`primer.md` reads as a real standalone brief.** It says what it borrows from `chapter-prose.md` (§ Provenance, § Paragraph tags) and uses nothing else from it. The Teach / Mention / Leave split and "teach or point, never list" are stated as rules an agent can act on, not as aspirations.
- **The outline row's `Opens with` field** comes with its reason (seven of eight trial chapters opened on a recap), so it isn't presented as a stylistic preference.
- **Two defaults kept apart.** The PR preserves the "what gets written vs how an absent key reads" distinction, so existing books stay on `narration` untouched.

## Issues found

### Critical

**C1. Step 4 still says a new book gets `guide` and that there is no third profile**

Location: `plugins/bookcraft/skills/createbook/SKILL.md:447-468`, `:485` (and the related `:506`, `:510`)

What I see:

> **This is the whole file for an ordinary book.** Write it as it stands ... `"profile": "guide"`, `"tags": true`, `"overview": true`, `"edition": "reading"`

> **`profile` selects the rule set**: `reference/guide.md` or `reference/narration.md` ... `"guide"` is what the template carries and what a new book gets unless the operator chose otherwise at step 3 (§ 1). `"narration"` is the other value and there is no third.

Also `:506` "Set it [`overview`] `true` for every new book", and `:510` "`tags` ... `true` unless `--no-tags` was given".

The risk: this is the step that actually writes `book.json`, and it now contradicts the PR's headline objective, "make it the default for new books". § 1 says to write `primer` when nothing says otherwise, and § Under the primer profile patches the template. But step 4 says to write the template "as it stands", says `guide` is what a new book gets unless the operator chose otherwise, and says flatly that no third value exists. In the commonest case the operator didn't choose and the default was inferred. An orchestrator following step 4 literally then writes a guide `book.json` with `overview: true` and `tags: true`, and the checker grades the book as a guide. That fails every primer chapter on `## In short` and on the shape rule. Before this PR the paragraph was correct. The PR made it wrong.

Suggested fix: make the step 4 template a primer one, or show two templates, a primer and a handbook. Then rewrite `:485` to name three values and say `"primer"` is what a new book gets. Add `primer` to the `edition` paragraph at `:483` ("left out of a primer, which binds the default edition"). Qualify `:506` and `:510` with "under the handbook profiles".

Learning note: when you change a default, grep the whole document for every sentence that restates the old one ("a new book gets", "there is no third", "for every new book"). A skill file is the program, so a stale restatement is a stale branch, and readers pick whichever restatement sits closest to the step they are on.

### Important

**I1. Other SKILL.md paragraphs the PR left contradicting the primer section**

Location: `plugins/bookcraft/skills/createbook/SKILL.md:311`, `:325`, `:527`

What I see:
- `:325` § The read-time estimate tells the gate to estimate "Chapters × about 1,900 words of prose × 1.8". That comes to about 19.5 minutes a chapter. The primer section (`:266`) sizes at about ten minutes a chapter and puts a 60 to 90 minute budget at the same gate. An eight-chapter primer would be shown to the operator as roughly 156 minutes against a 90-minute budget, on one screen.
- `:311` the `--minutes N` row says chapters ≈ `N / 11`, and the primer section says divide by ten. That's harmless on its own, but it is a second number for the same thing.
- `:527` item 2 tells the orchestrator to say the persona "does not modify the reading posture, which `chapter-prose.md § The reader` fixes and item 1 has just told the agent to follow". Under primer, item 1 has told the agent to read `primer.md` and never `chapter-prose.md`, and `primer.md § The reader` describes its own reader. `:229` likewise calls the `chapter-prose.md` posture "fixed by design for every book this skill writes".

The risk: the primer section's opening carve-out lists the header table, `## In short`, part counts, handoff nouns and the anchor and term budgets. It doesn't cover read-time arithmetic or the reader posture, so these paragraphs still apply as written and pull against it.

Suggested fix: add "Under `primer`, use the reading budget and ten minutes a chapter; the 1,900 × 1.8 constant is a handbook figure" to § The read-time estimate (or to the primer section, naming § The read-time estimate explicitly). Make item 2's posture sentence handbook-only, with "under `primer`, the reader is `primer.md § The reader`". Scope `:229` the same way.

Learning note: a carve-out written as "where a step below speaks of X, Y, Z" is only as good as its list. When the override is broad, it's safer to name the exceptions at their sites than to enumerate them once, up front.

**I2. Primer outline-row fields don't line up with the step 5 prompt items, so "Owns" and the assertion entries never reach a chapter agent**

Location: `plugins/bookcraft/skills/createbook/SKILL.md:278-293`, `:530`, `:534-536`; `plugins/bookcraft/skills/createbook/reference/primer.md:36-42`

What I see: "Each chapter row in a primer outline carries" is a full replacement list (Number/title/filename, Job, Teaches/mentions/leaves, Context, Defines/uses plainly, Owns, Opens with, Try it). It drops the handbook row's **Carries**, **Fills in** and **Concept list**. But step 5 items 9, 10 and 11 read exactly those fields, and nothing says they change under primer. Meanwhile **Owns** has no prompt item at all. The closest is item 5 ("anchors and numbers already spent elsewhere"), and the primer section says "items about ... anchor budgets do not apply", which an orchestrator can reasonably read as switching item 5 off. `primer.md § Facts` says "A measured result goes where the argument needs it" and never says to leave another chapter's owned results alone.

The risk: two of the plan's "what the outline decides" items (each chapter owns its demonstrations and results, and assertion entries are cited in marks) are decided in the outline and then never handed to the agents writing in parallel. That is the parallel-agent convergence the `Opens with` field exists to prevent. Without Carries, a primer's units can't cite `assertion <id>`, and `check-provenance.sh` will report every `expected` entry as dropped.

Suggested fix: add **Carries** (and, if wanted, **Fills in**) to the primer row. Then say in the primer section's prompt paragraph which items map where: "item 5 carries the other chapters' Owns, not to be shown again; items 9 and 10 come from Carries and Fills in; item 11 is the concept half of `## Sources and further reading`". Add one line to `primer.md § Facts`: "A demonstration or result another chapter owns is pointed at, never shown again."

Learning note: when a step defines its own version of a data structure that a later step consumes, check field by field that every consumer still has its input.

**I3. `primer.md` is not usable on its own: `check-book.sh` fails two things it never mentions, and one SKILL.md claim about the checker is false for primer**

Location: `plugins/bookcraft/skills/createbook/reference/primer.md:52-59`, `:69-85`; `plugins/bookcraft/skills/createbook/scripts/check-book.sh:1142-1145`, `:1223-1233`, `:929-977`; `plugins/bookcraft/skills/createbook/SKILL.md:297`

What I see:
1. **The closing section must be a bulleted list.** `primer.md` describes `## Sources and further reading` as sources "each with what to open it for" and concepts "each a term to search", but never says it is a list. I rewrote the fixture's closing section as two sentences and got `FAIL ... "## Sources and further reading" carries no items`.
2. **Block quotes fail** under primer (the `elif` branch at `:1223`). `primer.md`'s device list and voice list never mention them. A primer that quotes its context, which "Never invent ... a quotation" invites, will reach for one.
3. **A unit before the first paragraph is never checked for a mark.** The provenance sweep only starts counting at the first prose paragraph (`started`), and the comment gives the reason: "anything before the first tagged paragraph is the chapter header". A primer has no header. `primer.md:27` and the outline's `Opens with` list explicitly invite opening on a demonstration (a command and its output, a measurement). I prepended an unmarked fenced block to fixture chapter 1, under `"provenance": true`, and the run passed with no missing-mark failure. The PR introduces this gap in the sense that the exemption had a reason under the handbook profiles and has none under primer. Meanwhile SKILL.md `:297` tells the operator the checker "still fails ... a missing mark".

The risk: the brief is that a chapter agent handed `primer.md` alone can pass the checker. Items 1 and 2 send the agent into a fix loop on rules it was never given. Item 3 lets an unmarked opening demonstration (the unit most likely to carry a measured figure) through the one sweep meant to catch it.

Suggested fix: in `primer.md § Shape and length`, say "a bulleted list" for the closing section and add "No block quotes." In `check-book.sh`, pass the profile into the provenance awk and start with `started = 1` under primer, since there is no header to exempt:

```bash
prov_report=$(printf '%s\n' "$body" | awk -v sugg="$sugg_heading" -v ovws="$ovw_start" -v ovwe="$ovw_end" -v primer="$([ "$profile" = primer ] && echo 1 || echo 0)" '
  BEGIN { started = primer }
  ...
```

Then add a fixture case (a leading unmarked fenced block must fail under primer).

Learning note: "standalone" is a testable claim. Diff the checker's FAIL messages for the profile against the rule file, and every FAIL with no matching sentence is a rule the agent will only learn by failing.

**I4. The fixture's chapter-1 negative assertion is vacuous, and the new branches it doesn't reach are untested**

Location: `plugins/bookcraft/scripts/test-fixtures.sh:89`; `plugins/bookcraft/skills/createbook/fixtures/primer/`

What I see: `!primer-fixture-01-what-a-primer-chapter-may-carry.md: 4 of`. Chapter 1 has six paragraphs, so the eight-paragraph floor means it can never draw a clustering report. If it somehow did, the line would read "N of 6", and only N = 4 would trip this fixed-string match. The summary presents the assertion as showing that chapter 1 draws no clustering report, but it holds by construction and couldn't catch a regression. (`reports: 2` already pins the total, which is the real guard.) Chapter 2 sits at 75%, far from the 40% line, so neither the share threshold nor the floor is exercised at its boundary. Two new branches have no case at all: H4 failing under primer, and an appendix being accepted under primer.

The risk: the clustering thresholds are the numbers most likely to be tuned ("it can move if the report proves too eager"), and a change to `40` or `8`, or an off-by-one in `-ge`, would pass this suite unchanged.

Suggested fix: give chapter 1 eight or more paragraphs with three of them at 85 words or more (37.5%). The negative then becomes `!may-carry.md: 3 of 8` and tests the threshold rather than the floor. Optionally add a third chapter at exactly 40% (positive), and an H4 / appendix probe, either as a second small fixture or a `run.sh` that mutates a copy, as other fixtures here do.

Learning note: a negative assertion should name the output the code would produce if it regressed. If you can't say what string a regression would print, the assertion is guarding nothing.

**I5. `updatebook/SKILL.md` still applies handbook rules a primer edit must not follow**

Location: `plugins/bookcraft/skills/updatebook/SKILL.md:104`, `:106`, `:129-130`, `:242`

What I see: the PR adds "`"primer"` means `primer.md` and nothing underneath it" at `:56`. Further down, the edit rules still say: every budget is per chapter, with the six-term count (`:104`); "Nothing caps a chapter's length (`chapter-prose.md § Length`)" (`:106`, but `primer.md` has a ~2,000-word ceiling); redo "the chapter header's rows" and the "`## Suggested reading` list" (`:129-130`); and "Redo the chapter's header, `## In short` and concept list" (`:242`).

The risk: the plan's checklist item is "`updatebook/SKILL.md`: the primer rule set". An editor of a primer told "nothing caps length" can grow a chapter past the primer ceiling, and one told to redo the header may add one, which is exactly the "editing toward the handbook rules" mistake `:56` now warns about.

Suggested fix: one sentence after `:56` ("Under `primer`, § Budgets, the header rows, `## In short` and the length paragraph below do not apply; the closing section is `## Sources and further reading`, and the chapter ceiling is `primer.md § Shape and length`'s"), or scope each of the four sites.

### Suggestions

- **S1. `check-provenance.sh` stops at `## Sources and further reading` under every profile** (`check-provenance.sh:293`, `:729`). Under guide or narration that heading is an ordinary part, and every mark after it would now go unread. It's unlikely in practice, but the walk could be keyed on the profile the book model already exposes (`book_model.py:398`). Since the closing section carries no marks, the stop only changes behaviour in this unwanted case anyway.
- **S2. The sentence report contradicts `primer.md` under primer** (`check-book.sh:826-830`). It says "a sentence stops at 45", while `primer.md:65` says "past about 35 words, it is probably two" and has no stop. Set `sent_max=35` in the primer block with primer wording, as was done for the paragraph line.
- **S3. Document the new reports in step 7's table** (`SKILL.md:618-626`). It enumerates every report and lacks both the clustering report (all profiles) and the primer paragraph-ceiling row. Step 7's prose (`:610`, `:612`, `:638`) also still says two or three parts and `## Suggested reading` without a primer qualifier.
- **S4. Refuse `primer` with `"overview": true`**, the way guide refuses `"overview": false` (`check-book.sh:300-307`). Otherwise a mis-written primer `book.json` fails every chapter on a missing `## In short` instead of naming the contradiction.
- **S5. The summary line still says `suggested reading:`** under primer (`check-book.sh:1526`). Something like `closing section:` would match the profile.
- **S6. The `check-book.sh` header comment** (`:13-16`) names `chapter-prose.md`, `guide.md` and `narration.md` as the rules it enforces and should add `primer.md`.
- **S7. README `:9` (edited by this PR)** still ends "every chapter header reads `Fills in: everything`", which no longer describes the default profile, since a primer has no header.
- **S8. The closing section and marks.** `primer.md § Marks` says a mark goes "after every ... list", which literally includes the closing list. Add "the closing section carries none" so agents don't add noise marks the checker silently ignores.

### Deferred to follow-up

None. Every finding above is introduced by this branch. Items I considered and dropped as arguable: the pre-existing italics mention in the check-book comment with no matching check, and the clustering report firing on handbook books whose `chapter-prose.md` band (40 to 90) overlaps the 76-word near mark. That second one is a deliberate decision recorded in NOTES.md and is report-only.

## Questions

1. Is the primer outline row meant to replace the § 2 row entirely, or to be added to it? The answer settles I2. If it is added, saying so fixes Carries and Fills in, but Owns still needs a prompt item.
2. Should a primer keep the coverage ledger (§ 2) at all? Its `Teaches` column and the primer row's `Teaches, mentions, leaves` share a name and mean different things (outcome items vs selected concepts). Item 13 reads "from its Teaches row".
3. Is the ~2,000-word chapter ceiling meant to be reported by the checker? It is a ticket checklist item stated as a rule, and the summary line only shows the longest chapter.

## Verdict

VERDICT: REQUEST_CHANGES

The regression: the PR's objective is to make `primer` the default for new books, but SKILL.md step 4, the step that writes `book.json`, still says to write the guide template as it stands, that `guide` is what a new book gets, and that no third profile exists. Fix C1, then I1 to I5, which are each a sentence or two of SKILL.md / `primer.md` / `updatebook` text plus the small provenance-sweep change and a sharper fixture.
