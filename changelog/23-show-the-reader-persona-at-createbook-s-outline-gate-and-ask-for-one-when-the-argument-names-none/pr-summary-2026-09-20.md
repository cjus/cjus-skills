# Show the reader persona at createbook's outline gate, and ask for one when the argument names none

Closes #23.

## Overview

`/bookcraft:createbook` already treated the reader persona as a first-class value: step 1 settled it, `OUTLINE.md` recorded it at the top, and every chapter agent's prompt carried it. It was the only one of the skill's three underspecified inputs with neither an ask when the argument omits it nor a line at the confirmation gate — sizing and tagging both had both.

This adds the gate line and the ask, in that order of importance. **The gate line is the load-bearing half**, and the reason is that a presence check cannot catch the failure that costs a book. Asking "was a persona identified" fires only when the field is empty, and from a subject plus a folder of sources a plausible persona is almost always available. What costs twenty chapters is a *confident wrong* persona, which reaches every chapter looking exactly like one the operator supplied. Printing the derived value at the one blocking gate is what catches it, while the correction is still one message.

## Key changes

| File | Change |
|---|---|
| `plugins/bookcraft/skills/createbook/SKILL.md` | The reader joins § 3's display list, governed by two new paragraphs; § 1 gains the conditional ask and a paragraph holding the persona/posture boundary; § 2 records the reader's provenance in `OUTLINE.md`; § 5's chapter prompt names the persona/posture collision; the Arguments table cites § 1 |
| `plugins/bookcraft/skills/createbook/NOTES.md` | New entry, `§ The reader at the gate, 2026-09-20`, recording both decisions with the alternative each beat |
| `plugins/bookcraft/README.md` | Argument table and approval-gate line updated for the user-facing behavior |
| `plugins/bookcraft/.claude-plugin/plugin.json` | 1.1.0 → 1.2.0 |

## Code examples

**The gate line** (`SKILL.md § 3`). The reader is stated as a sentence rather than a `Reader:` label, because a label reads as something already settled and does not invite the correction the gate exists to collect:

```markdown
Show the source ledger, the chapter list, the title, the reader, the output
folder, whether the book is tagged, and the estimated read time …

**State the reader as a sentence, and say where it came from.** "Written for a
second-year apprentice electrician who has wired domestic circuits but never
opened a three-phase board" invites the correction. `Reader: apprentice
electricians` does not, because a label reads as something already settled. In
the same breath, say where that persona came from: the argument, the operator's
answer to the ask at § 1, or your own inference from the subject and the sources.
```

**The ask** (`SKILL.md § 1`), in the form the sizing and tagging asks already use, with a decline path that hands back to the gate:

```markdown
**When the argument names no reader, ask before going further.** Three questions:
who they are, what they must be able to do when they finish, and what they can be
assumed to know already. … Where the operator declines to answer, infer a persona
and mark it inferred at the gate (§ 3).
```

**The scope boundary, held in the prose** rather than only in the plan. Two different things in this skill are called "the reader", and step 1 cites the posture file one paragraph above the new ask:

```markdown
**This asks for the domain persona, not the reading posture.** The posture at
`reference/chapter-prose.md § The reader` — attentive, short on working memory,
reading once straight through and returning later for one fact — is fixed by
design for every book this skill writes. It is not the operator's to change here
and not a chapter agent's to renegotiate.
```

## Plan alignment

All three phases completed as planned, gate line first as `PLAN.md` required.

- **Phase 1, the gate line.** Done. Both open questions were answered by the operator before implementation and are recorded in `PLAN.md § Open Questions § Resolved`. The marker prints provenance rather than the bare value; the bare value would have kept § 3's display list uniform with its six other bare entries, and lost because an inferred persona that prints identically to a supplied one gets read past.
- **Phase 2, the ask.** Done, inside § 1 rather than in a section of its own. Sizing and tagging, whose form it copies, both have their own sections, so the alternative was the more consistent one; it lost to keeping the reader's handling in one place.
- **Phase 3.** Done. `NOTES.md` entry written, version bumped.

**One deviation, recorded as status in `PLAN.md` rather than as a new phase:** `plugins/bookcraft/README.md` was touched beyond the three phases. Its argument table called the reader optional "where useful" and said nothing about the new ask, and its approval-gate line said nothing about the reader. Both describe user-facing behavior this branch changes. Leaving them would have shipped the same class of drift #27 was filed for — and that ticket covered the root and hooks READMEs, not this one, so nothing else was going to catch it. Two lines.

## Review

Reviewed twice on 2026-09-20, both **VERDICT: APPROVE** with no blocking findings: `pr-review-2026-09-20.md` (round one, four findings fixed in `5826d32`) and `pr-review-2026-09-20-close.md` (the close gate, five further accuracy findings fixed before this summary was finalized). Two items were deferred and one dropped.

**The finding that mattered sat at the seam between the two phases.** Each half was correct in isolation: Phase 1 marks a persona as given or inferred, Phase 2 adds an ask. Together they create a third origin — the operator's answer to that ask — which is neither, and the gate wording had no label for it. An agent following the text literally would have reported a persona the operator had just dictated as "inferred", a false alarm at the one gate built to raise real ones. § 3 now names all three origins, and the README matches. A second review round widened it once more: a persona can be *part* given and part inferred, since an argument naming a reader but not what they know fires no ask while leaving the knowledge assumptions to the model.

A second finding caught a `NOTES.md` claim that was wrong about its own diff, asserting both new § 1 paragraphs draw the persona/posture boundary when only the second does. That file's authority rests on its claims surviving a check, so it was corrected rather than softened. Also fixed: `always` relaxed to `almost always` in both files, matching what `PLAN.md` actually claims, and the Arguments table now cites § 1 as its three sibling rows already did.

## Testing

**This is a specification an agent reads, not executable code.** The repo configures no `checks` in `.claude/pr-config.json` and has no `.github/workflows`, so no automated suite covers it and none was added. Verification is by hand:

1. **The ask fires.** Run `/bookcraft:createbook` with an argument naming no reader — "A short guide to the build cache" — and confirm it asks the three questions before proceeding, rather than inferring silently.
2. **The gate line appears, with the right provenance.** Confirm step 3 states the reader as a sentence, and check all three origins render correctly: a persona named in the argument, one supplied in answer to the ask, and one the model inferred after the operator declined to answer.
3. **The decline path works.** Decline the ask and confirm the run continues with an inferred persona *marked as inferred* at the gate.
4. **Cross-references resolve.** Every `§` reference added resolves: `§ Sizing the book`, `§ Paragraph tags`, `§ 1`, `§ 2`, `§ 3`, `§ 5`, and `reference/chapter-prose.md § The reader`. Verified by hand during review.

**Edge case considered and deliberately left as is:** an inferred persona is *stated* at the gate, not given its own confirmation prompt. § 3 already ends "Stop and wait", so the operator cannot pass the persona without passing the gate it sits in. A second confirmation inside the one blocking gate would make it two gates, and the skill has exactly one on purpose.

## Impact assessment

Four files under `plugins/`: 62 insertions and 7 deletions. The rest of the diff is this branch's own documentation under `changelog/`, which ships with the repo as history and changes no behavior. No dependencies affected.

**No breaking change.** Both additions are behavior a `createbook` run gains, and neither changes an existing output format, `book.json` field, filename convention or checker rule. Books already written are unaffected. The minor bump matches the precedent set by PR #32, which took 1.0.2 → 1.1.0 for the comparable `## In short` addition.

**Assertion audit: not applicable.** `docs.assertionsFile` is `null` in `.claude/pr-config.json`, so this repo keeps no assertions file. Nothing to audit and nothing added.

## Deferred work

**None.** Both items the reviews deferred were resolved in this branch instead, at the operator's direction during the `/pr:close` step 6b triage. That is a scope change the operator made; the objective is unchanged.

**`OUTLINE.md` now records the reader's provenance**, not just the reader. § 3 has to state where the persona came from, and § 3 can run in a later session than § 2, so an outline holding the persona but not its origin left the gate reconstructing from memory the one thing it exists to check. § 3 now reads it off the outline's top line rather than recalling it.

**§ 5's chapter prompt names the persona/posture collision at the point an agent meets it.** Item 1 of that prompt tells the agent to follow every rule in `chapter-prose.md`, whose `§ The reader` *is* the reading posture; item 2 then hands it "the reader" meaning the domain persona. Same name, same prompt, and an agent left to reconcile the two reads the persona as licence to adjust the posture. Item 2 now says outright that it does not, and passes the provenance where the persona was inferred.

Nothing parses `OUTLINE.md`'s top line, so neither change reaches `check-book.sh` or `book.json`.

**One item dropped:** batching § 1's three asks into one message. The reviewer raised it and recommended dropping it; the asks fire on different conditions, so grouping them would mean asking questions that do not apply.
