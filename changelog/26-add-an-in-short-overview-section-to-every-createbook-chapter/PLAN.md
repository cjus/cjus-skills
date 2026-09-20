# Add an `## In short` overview section to every createbook chapter

Start date: 2026-09-20 07:37:04 MDT
Objective refreshed from the ticket: 2026-09-20 (ticket updated 13:48 UTC, before any work landed)

## Overview

A chapter currently opens with the four-row header table and then its first paragraph, both
written in the book's own vocabulary. Add an `## In short` section between them for a reader
who has not read the chapter, or who read the earlier ones a month ago.

The section does **two things, in order**:

1. **A carried-in line**, opening with the literal `Carried in: `, naming the concepts this
   chapter reintroduces from earlier ones, so the reader has the vocabulary back before the
   prose spends it. Drawn from `OUTLINE.md`'s term ledger, trimmed to at most three, worded
   from the glossary entry, cited `(ch. N)`.
2. **The walk**: what the chapter argues, in the order it argues it, for someone who has not
   read it.

The rule that keeps the walk from becoming a second header table: **the walk may use no term
this chapter glosses.** Carried terms are exempt — a term the carried-in line has just
restored is on the table for the walk to spend plainly.

The section carries no paragraph tag, no provenance mark and no source references, so
`check-book.sh` needs four exemptions, a cross-check against `glossary.md`, a cap of three on
the carried-in terms, a presence check gated on a new `"overview": true` key in `book.json`, and
a word count on its summary line. The key is absent by default so books written before this still pass.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**Issue:** [#26](https://github.com/cjus/cjus-skills/issues/26) — Add an `## In short` overview section to every createbook chapter
**Labels:** status:in-progress, priority:high, feature

### The concrete failure it fixes

Seventeen of the eighteen chapters in the reference teaching guide open on a definite noun phrase
handed forward by the chapter before: `The diagram`, `The marks`, `The join`, `The scan`. Read
in order that works. Read by jumping to one chapter, which is how a guide actually gets used,
the article points at a referent the reader never had. Chapter 10 is the only opener that does
not do it. `chapter-prose.md` already names this as the worst case for its own reference rule:
"This bites hardest at the opening, because a chapter opens on the noun the previous chapter
handed it and that noun arrives with a definite article already attached."

### The section

`## In short`, directly after the chapter header table and before the opening paragraph. No
source references, no paragraph tag, no provenance mark.

```markdown
## In short

Carried in: **star schema** (ch. 11), a fact table in the middle with dimensions one join away.
**Grain** (ch. 12), the one sentence saying what a single row means.

A feature store looks like a new kind of thing, and it is the same shape you drew last week...
```

Length is uncapped. `check-book.sh` reports the section's word count on the summary line, the
way prose and structure are already reported separately, so drift stays visible without a
threshold deciding anything.

### The carried-in line

- **Named from the term ledger.** `OUTLINE.md` already carries, per chapter, the terms it may
  use freely because an earlier chapter glossed them. That is the candidate set, and it is too
  long to use whole.
- **Trimmed to the terms this chapter's own claim rests on, at most three**, which matches the
  order of the existing budgets. Zero where a chapter genuinely reintroduces nothing, and never
  an invented entry to fill the line. Chapter 1 always has none.
- **The words come from the glossary entry rather than a fresh definition.** `glossary.md`
  already holds `**term** (ch. N) definition` and already describes its job as "the reminder
  rather than the teaching" (`SKILL.md:307`). A third definition beside the chapter gloss and
  the glossary entry is how a book comes to say three slightly different things about one term.
- **Cited as `(ch. N)`**, matching the glossary's own format. A paragraph tag is a more precise
  address and a more brittle one, since renumbering a chapter moves it.
- **Written last**, in the same pass as the glossary and from the finished chapters, for the
  same reason the header is written last.

### The rule that keeps the section from duplicating the header

**The walk may use no term this chapter glosses.** Carried terms are exempt.

The `This chapter` header row serves a reader who has read the chapter and wants to find
something in it again, so it may say "the three levels" and "cardinality". The walk serves a
reader who has not, so it says "how much of the database is in view" and "how many at most, and
is none allowed". Without this rule the two converge and every chapter carries two summaries in
different registers.

This is the describe-the-behaviour-then-attach-the-label move `chapter-prose.md` already
requires when glossing an intimidating term, with the label left off.

### The four checker exemptions

`check-book.sh` rejects the section as written today. Each of these is a change:

- **Heading count.** `check-book.sh:519-523` subtracts only `## Suggested reading` before
  requiring 0, 2 or 3 part headings, so a new H2 fails every three-part chapter. Subtract this
  one too.
- **Paragraph tags.** The section takes none and advances no count, the way the header table and
  the concept list do not. A tag here would shift every tag after it, and tags are cited from
  outside the book.
- **Provenance marks.** The section carries none. It is derived from the finished chapter rather
  than from a source, so it has nothing to name.
- **Position.** It must be the first H2 in the body, directly after the header table.
  `## Suggested reading` keeps its own rule that it is the last (`check-book.sh:497-505`).

### The one new check

Every term the carried-in line names appears in `glossary.md` with a chapter number lower than
this one. That catches a reminder pointing forward, and one naming a term the book never
glossed. Runs only for a book declaring both `overview` and `glossary`.

### Sequencing

The reference teaching guide is not being retrofitted. It is due a full rewrite under its own
ticket, and the section arrives with that rewrite, so this has to land and be installed before
that work starts.

`updatebook` and `check-claims` need nothing.

## Plan

- [x] Phase 1: Spec the section in `createbook/reference/chapter-prose.md` — **both halves**.
      The carried-in line (its rules, the ledger as candidate set, the at-most-three trim,
      glossary wording, `(ch. N)` citation, written-last, and **the `Carried in: ` prefix rule
      settled below at § Settled rules, ready to install verbatim**), the walk, and the
      no-glossed-term rule **with the carried-term exemption, also settled at § Settled rules
      and written rather than checked**. Plus why the section deliberately breaks the body
      rules: it cites nothing and it is a summary.
      **Both § Settled rules blocks install verbatim; the destination file carries no em dash,
      and neither do they.**
- [x] Phase 2: Thread it through `createbook/SKILL.md` — the chapter file format example, the
      step 5 agent prompt, a **step 6 note that the section is written with the glossary**
      (`SKILL.md:275`, "Write the front matter and the glossary"), and `"overview": true` in
      the step 4 `book.json` block, absent by default.
- [x] Phase 3: `createbook/scripts/check-book.sh` — the four exemptions: heading count
      (`check-book.sh:519-523`), paragraph tags, provenance marks, and the position rule
      (first H2 in the body, header table immediately before it).
- [x] Phase 4: `check-book.sh` — the glossary cross-check. **The line is found by the literal
      `Carried in: ` prefix on the section's first paragraph and by nothing else**; a first
      paragraph without it means the chapter carries nothing in, which is legal. Every
      carried-in term must exist in `glossary.md` at a lower chapter number. **Sequencing constraint:** the chapter loop runs
      at `check-book.sh:177-576` and the glossary is parsed at `:599+`, so carried-in terms must
      be collected during the chapter loop and validated after the glossary map is built. The
      existing awk block at `:600-640` already extracts `term` and `ch` per entry, so this
      extends that map rather than adding a new parser. Gated on `overview` **and** `glossary`.
      **Also the cap:** at most three bolded terms on the carried-in line, a hard failure above
      three, gated on `overview` alone since counting needs no definitions (§ Settled rules).
- [x] Phase 5: `check-book.sh` — presence check gated on `"overview": true`, plus the word count
      on the summary line (`:680`) alongside `prose:` and `structure:`.
- [x] Phase 6: Verify — a pre-`overview` book still passes untouched, and a book with the key
      set is checked on all five rules. Follow the existing `fixtures/fence/` and
      `fixtures/provenance/` pattern: a fixture folder with its own `book.json`.
- [x] Phase 7: `NOTES.md` entry and the 1.1.0 version bump (bookcraft is at `1.0.2`), this being
      an additive format change.

**Scope guard for phases 3 to 5.** `check-book.sh` keeps `book.json` as its only configuration
source. No phase teaches it to read `OUTLINE.md`. The walk's no-glossed-term rule is written and
reviewed by decision (§ Settled rules), and the one mechanical cross-check reads `glossary.md`,
which the checker already parses at `:600-640`.

## Ticket Action Items

- [x] `createbook/reference/chapter-prose.md`: the section's spec, **both halves**, including its own voice rules
- [x] `createbook/SKILL.md`: chapter file format example
- [x] `createbook/SKILL.md`: step 5 agent prompt
- [x] `createbook/SKILL.md`: step 6 note that the section is written with the glossary
- [x] `createbook/SKILL.md`: `"overview": true` in `book.json`, absent by default
- [x] `createbook/scripts/check-book.sh`: heading count exemption
- [x] `createbook/scripts/check-book.sh`: paragraph tags exemption
- [x] `createbook/scripts/check-book.sh`: provenance marks exemption
- [x] `createbook/scripts/check-book.sh`: position rule
- [x] `createbook/scripts/check-book.sh`: glossary cross-check for carried-in terms
- [x] `createbook/scripts/check-book.sh`: at-most-three cap on carried-in terms
- [x] `createbook/scripts/check-book.sh`: presence check gated on `"overview": true`
- [x] `createbook/scripts/check-book.sh`: word count on the summary line
- [x] `NOTES.md` entry and a 1.1.0 version bump

## Status

All 7 phases and all 13 ticket action items complete. `## Open Questions` is empty.

Two review rounds ran at close: round one returned `REQUEST_CHANGES` with three defects, round
two returned `APPROVE` and found two regressions the first round's fixes had introduced. All five
are fixed, and the last commit landed after the approving verdict. Verification is a 17-case
adversarial battery plus both `jq` paths; four fixture folders, of which `fixtures/provenance`
exits 1 on `main` as well.

## Settled rules

Ready to install verbatim at phase 1, into `reference/chapter-prose.md`.

### The carried-in line's shape

**The carried-in line is the section's first paragraph and it opens with the literal
`Carried in: `.** The checker finds the line by that prefix and by nothing else. Left to infer
it, the checker would have to take the first paragraph carrying a `**term** (ch. N)` pattern,
which quietly swallows a walk that happens to open on a glossed term and quietly skips a
carried-in line whose first term was typed without its bold. Both failures read as a clean pass.
The prefix costs one stiff phrase at the top of a section a reader is scanning anyway, and buys
a parse that cannot drift.

**Each term is one sentence: `**term** (ch. N), ` and then the glossary's own words, ending in
a period.** The first follows the prefix on the same line; the rest follow as further sentences.
The words are the glossary entry's, not a fresh definition, for the reason at § The carried-in
line: a third wording beside the chapter gloss and the glossary entry is how a book comes to say
three slightly different things about one term.

**A chapter that carries nothing in omits the line entirely.** Not `Carried in: none`, and not
an empty prefix. Chapter 1 always omits it. A section whose first paragraph does not open with
the prefix is a chapter carrying nothing in, which is legal and common; the checker reads it that
way rather than as a fault.

### The walk's vocabulary

**The walk may use no term this chapter glosses.** Carried terms are exempt: a term the
carried-in line has just restored is on the table for the walk to spend plainly. The
`This chapter` header row serves a reader who has read the chapter and wants to find something
in it again, so it may say "the three levels" and "cardinality". The walk serves a reader who
has not, so it says "how much of the database is in view" and "how many at most, and is none
allowed". Without this rule the two converge and every chapter carries two summaries in
different registers.

**This rule is written and reviewed, and it is not checked by script.** The chapter agent
follows it and a reader confirms it against the chapter's own ledger row. Nothing in
`check-book.sh` enforces it, by decision rather than by omission, so a violation is caught by
reading and never by a non-zero exit.

The reason is that the record it would check against is `OUTLINE.md`, which `check-book.sh`
never reads: the checker's only configuration source is `book.json`, and books exclude the
outline by default. Teaching it to parse the outline would add a second configuration path for
one rule. The stronger reason is that the comparison does not survive being scripted.
`SKILL.md:215` already records what happens: "Read the ... rows against the ledger by hand
rather than reaching for a script, which is how the substring match that called 'the query
plan' glossed by 'query planner' got caught." A checker that matches substrings flags a walk
that never used the glossed term, and a checker that matches whole words misses every
inflection of one that did. Both outcomes are worse than the rule being read.


### The carried-in line's cap

**At most three terms on the carried-in line, and the checker enforces it.** Above three it is a
failure and not a note. Zero is legal and common, chapter 1 always has none, and a chapter that
genuinely reintroduces nothing omits the line rather than padding it to a quota: the cap is a
ceiling and never a target.

**The check counts the bolded terms on the line.** Counting the bold spans rather than the
`(ch. N)` references catches the entry that was typed without its reference, which would
otherwise slip the glossary cross-check and the cap together.

**It runs for a book declaring `overview`, and unlike the glossary cross-check it does not also
need `glossary`,** because counting needs no definitions. A book with the section and no
glossary is still held to its cap.

This one is checked where the walk's rule is not, and the difference is worth naming so neither
gets revisited as an inconsistency. The line is found by a literal prefix, so nothing is
inferred; counting bold spans is exact, with no substring to over-match and no inflection to
miss; and the cross-check above already parses this line, so the count is nearly free. The
objection that keeps the walk's vocabulary out of the checker is that the comparison does not
survive being scripted. A count has nothing to compare.

The rule earns enforcement because it is the failure this section is most prone to. Every
chapter has more candidate terms in the ledger than it needs, and an unenforced ceiling is how
the carried-in line grows back into the header table it exists not to duplicate.


## Open Questions

None. All three are settled at § Settled rules and recorded at § Resolved Questions, and no
question blocks phase 1.

## Resolved Questions

- ~~Is the at-most-three cap checked, or written?~~ **Resolved 2026-09-20: checked.** Written as
  a rule at § Settled rules, a hard failure above three, gated on `overview` alone. It lands in
  phase 4, which already parses the carried-in line.

- ~~Is the walk's no-glossed-term rule checked mechanically, or written and reviewed?~~
  **Resolved 2026-09-20: written and reviewed.** Written as a rule at § Settled rules. This
  keeps `check-book.sh` reading `book.json` alone and adds no `OUTLINE.md` parser, so phases 3
  to 5 stay exactly as scoped.

- ~~What marks the carried-in line, so the checker can find it?~~ **Resolved 2026-09-20: the
  literal `Carried in: ` prefix is required.** Written as a rule at § Settled rules and fixed
  into phases 1 and 4. The alternative — inferring the line from its first `**term** (ch. N)` —
  was rejected because both of its failure modes read as passes.

- ~~Does `/createbook` write `"overview": true` into `book.json` for new books?~~ **Yes, by
  established precedent.** `SKILL.md:238` sets the pattern for exactly this case: `provenance`
  and `suggested_reading` "default to absent, which means a book written before the format
  existed still passes... Set both `true` for any book written against sources, which is every
  book this skill now writes by default." Phase 2 puts `"overview": true` in the step 4 template
  and absence remains the opt-out for pre-existing books.
