---
name: check-claims
description: Check a book's paraphrased claims against the sources its provenance marks name, with one agent per chapter reading the real source. Catches the failure no script can: a mark that resolves perfectly, quotes nothing, and sits beside a sentence its source does not support. Takes a book folder and optionally a chapter scope. Use when asked to verify a book's attributions, check whether its sources say what it says they say, or after a regeneration or an /updatebook run.
argument-hint: <book-folder> [--chapters N,M]
---

# /check-claims

Check the paraphrased claims in: $ARGUMENTS

A book written by `/createbook` marks every unit with where its claims came from. Three mechanical checks already run over those marks (`check-provenance.sh`): the named source is declared and on disk, the locator resolves, and every quotation of 25 characters or more appears in a source the mark names.

**None of them reaches a paraphrase.** A mark can name a real file, point at a real page, quote nothing, and sit beside a sentence that page never supports. Only a model reading both settles it, and that is this skill.

The cost of getting it wrong is why it exists. The reference book is what an instructor reads before standing in front of a room; a wrong attribution in it is repeated aloud and then keyed on an exam. And paraphrase is the common case: that guide carries 583 marks against 229 machine-checkable quotations.

## Arguments

| Argument | Meaning |
|---|---|
| First (required) | The book folder. `books/reference-guide` |
| `--chapters N,M` | Check only these chapters. What an `/updatebook` run passes, since it already knows which chapters its edit reached |

With no folder, ask for one and stop.

## What this is not

- **Not a gate.** It reports and nothing fails on a finding. The quotation check one rung below was built as a hard failure, fired ten times against the reference book and was wrong ten times; it reports now for that reason, and a paraphrase judgement is softer still.
- **Not a prose review.** `reference/judgement.md` puts prose explicitly out of scope.
- **Not cheap, and not automatic.** One agent per chapter reading real sources is minutes of wall time and real tokens. Nothing runs it for you; `/createbook` and `/updatebook` name it and leave the decision where it belongs.

## Procedure

### 1. Validate, and emit the worklist

```bash
BOOK="$1"
test -f "$BOOK/book.json" || { echo "not a /createbook book"; exit 1; }
WL="$(mktemp -d)"   # or the session scratchpad, which survives the turn
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-provenance.sh \
  --emit-worklist "$WL" [--chapters N,M] "$BOOK"
```

**Read the exit code and the census, and stop on a failure.** A failed locator is a pointer aimed at something that is not there, so judging a paraphrase against it spends a reading pass on a question whose premise is already known to be false. The emitter says so on its own `WORKLIST` line when `fail` is non-zero. Report the failures and stop; they are cheaper to fix first.

A book whose `book.json` does not declare `"provenance": true`, or declares it with no `sources` map, has nothing to check. The script says so and exits 0; pass that through and stop.

### 2. Read the index, and only the index

`$WL/index.json` carries one row per chapter: its number, its file, the path to its worklist, and how many units and pointers it holds. It carries no prose, deliberately.

**Do not read the chapter worklists yourself.** They hold the book's whole prose, which is 49,509 words for the reference book, and pulling them into this session is the thing the per-chapter split exists to prevent.

### 3. Run one agent per chapter

In batches of about four, matching `/createbook`'s drafting step. Each agent's prompt carries, in full:

1. **Read `${CLAUDE_PLUGIN_ROOT}/skills/check-claims/reference/judgement.md` and apply it exactly.** That file is the authority on what a verdict means, what is in scope, the mapping rule, the evidence bar and the output shape. Do not restate its rules in the prompt; a prompt that restates them risks stating them differently, and the whole point of one spec is that chapter 3 and chapter 17 are judged the same way.
2. **The path to this chapter's worklist**, from `index.json`.
3. **The path to write its findings JSON to**, `$WL/findings-<chapter file stem>.json`.
4. **The book folder**, so it can see a chapter in context if a paragraph's claim needs the surrounding prose to read fairly.
5. **That every pointer's `paths` are absolute and its `read` mode says how to open it**: `open` for an ordinary Read, `pages` for a PDF with the page numbers given, `inline` for a deck whose text is already in the file because the Read tool cannot open a `.pptx`.
6. **That it reports only the path and its counts**, never the findings themselves. The findings are read off disk.

**Do not downgrade these agents to a cheaper model.** They judge whether a claim a student will be taught is supported by its source, which keeps them on the session's own tier, and the output is not cheaply verifiable from outside: checking a verdict means redoing the reading that produced it. This is the same rule `createbook/SKILL.md § 5. Draft the chapters` applies to chapter prose, for the same reason.

**An agent that stalls is resumed, not respawned.** `SendMessage` it by name and tell it to stop checking further units and write the file with what it has, saying in `notes` how far it got. A respawn discards everything it established.

### 4. Assemble the report

```bash
${CLAUDE_PLUGIN_ROOT}/skills/check-claims/scripts/render-report.py \
  "$WL" "$BOOK" --command "<what you ran>"
```

**A script renders the report, not you.** It reads every `findings-*.json` and does the arithmetic, so the report's counts are the agents' counts by construction. A number retyped out of an agent's reply is a number nobody can check, and this is the one place the whole pass could quietly invent a total.

**Read the files, not the agents' return messages**: the file is the artifact, and an agent showing `idle` has not necessarily written it yet. Poll for the file.

It writes `<book>/claim-checks/<YYYY-MM-DD>.md`, or `-round2` when that exists rather than overwriting, so the first round's reasoning survives to show whether a later fault was self-introduced.

**It checks the findings against the run's own `index.json`, and takes no chapter count from you.** The index is written by the same `--emit-worklist` run, so it already knows which chapters the run covered and how many units each was given; there is nothing to pass and nothing to get wrong. Pass `--worklist <dir>` only when the findings were written somewhere other than beside it.

**It refuses to paper over a chapter it could not use, and exits 1 when it had to.** Named in the report's own "What was not reached" section rather than dropped: a findings file that is missing, unparseable, that names a chapter this run did not emit, that examined fewer units than the worklist gave it, that uses a verdict word the spec does not define, whose counts do not sum to its own `units_checked`, or whose counts and findings disagree.

**A chapter that examined FEWER units than its worklist is kept, marked partial, and still fails the run.** Its row reads `10 of 36`, its findings are rendered in full, and "What was not reached" names it. This is the shape a resumed agent produces, per § 3 above, so it is supported rather than a defect, and its findings are the half worth keeping: an `unsupported` verdict in unit 4 of 36 is the one this skill escalates unconditionally.

The point of checking against the index is that a total assembled over a silently-dropped **chapter** reads exactly like a total over a complete run, and a chapter that examined 10 of its 33 **units** renders a row indistinguishable from a complete chapter. Both are the same failure at two depths, and neither is visible from inside a findings file.

**The folder is safe to put there.** Every tool that reads a book folder globs non-recursively (`build-book.py` uses `src.glob("*.md")`, `check-book.sh` uses `find -maxdepth 1`, `check-provenance.sh` uses `book.glob("*.md")`), so a subfolder is invisible to all three and needs no `exclude` entry, exactly as `diagrams/` already is. Keeping the report with the book rather than in a branch changelog is what lets successive runs show whether a finding was fixed or merely found again.

The report carries, in this order:

- **The counts**, per chapter and in total, for all six verdicts.
- **The findings**, `unsupported` first, then `overstated`, `misstated`, `unclear`, `unreadable`. Each with its chapter, tag, the sentence, what the source says, the gap, and what the agent read.
- **What was not reached**: chapters skipped, sources nobody could open, shorthands sampled rather than read whole.
- **The command that produced it**, so the run is reproducible.

### 5. Report to the operator

The totals, the count of findings by verdict, and the report's path. Name the two or three findings most worth reading first rather than reciting them all; the file is one click away.

**Say what the run did not cover.** A `supported` verdict on a 23-file shorthand where the agent read four is a weaker claim than one against a single page, and the agent recorded which in its `read` field. Carry that through to the report rather than flattening it into a count.

## Triage of what it finds

Findings are advisory, and most will not be worth acting on. Sort them into three bins:

- **FIX NOW** for an `unsupported` finding in material students are taught from. A wrong attribution in a teaching guide is repeated aloud, and this is the one bin that escalates unconditionally.
- **TICKET** for a pattern: one source that several chapters read the same wrong way, or a shorthand whose scope the book keeps overstating.
- **DROP** for the rest, which is the default. An `unclear` verdict is not a defect; it is a unit nobody can settle cheaply.

## What it cannot catch

- **A claim the book attributes to `fill` that is wrong.** `fill` names no source, so nothing can check it. `grep -rn 'src: fill' <book>` is the list of what goes stale, and rechecking it is a reading job with no worklist behind it.
- **A source that is wrong.** This checks that the book says what its source says. Where the source is itself mistaken, a `supported` verdict is correct and the book is still wrong.
- **A paragraph with no mark.** `check-book.sh` catches those in a book declaring `provenance`.
- **Its own false negatives.** An agent that reads a source carelessly returns `supported`, and nothing downstream disagrees. Rerunning a chapter is the only check on a chapter's run, which is why `--chapters` exists.

## Notes

- **This skill depends on `/createbook`'s folder; `/createbook` reaches for nothing here.** That one-way direction is deliberate, so `createbook/` and `makebook/` stay liftable into another repo on their own. Lifting this one means taking `createbook/` with it.
- A rule about what a verdict means belongs in `reference/judgement.md`. What belongs here is only how the pass is run.
- The worklist is regenerated in about a second and is throwaway. The report is not: it is the record of what was checked and when.
