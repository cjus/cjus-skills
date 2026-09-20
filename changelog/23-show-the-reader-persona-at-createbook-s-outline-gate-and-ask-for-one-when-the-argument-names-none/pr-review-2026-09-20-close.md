# Review round two (close gate), 2026-09-20 — PR #33

Reviewed: commits `64fdded`, `972321f`, `5826d32`, **plus** the uncommitted working-tree
state (the `NOTES.md` correction and the untracked `pr-summary-2026-09-20.md`). That
combined state is what merges, and it is what is judged here.

This is a **delta review**. Round one (`pr-review-2026-09-20.md`) verdicted APPROVE; its
four taken findings and two deferrals are settled and are not re-raised. What follows is
the verification of those fixes plus what the delta introduced.

## Summary

The branch adds two things to `/bookcraft:createbook`: the reader persona now appears at
the step 3 confirmation gate, stated as a sentence and marked with where it came from, and
step 1 now asks for a persona when the invocation argument names none. Round one found a
gap at the seam between the two phases — the ask created a third provenance origin that the
gate wording had no label for — and `5826d32` closes it. The plugin goes 1.1.0 → 1.2.0.

## Round one's fixes: all four landed, and none introduced a new problem

**The third provenance origin (was 🟡).** Fixed correctly, and the fix is coherent across
all three places it has to be:

- `SKILL.md:230` now reads "the argument, the operator's answer to the ask at § 1, or your
  own inference from the subject and the sources" — three origins, in one order.
- `README.md:166` names the same three in the same order ("your argument, your answer to
  the question it asked, or its own inference"), so the user-facing promise matches the
  spec an agent follows.
- `SKILL.md:161`'s decline path closes the loop the other way: "Where the operator declines
  to answer, infer a persona and mark it inferred at the gate (§ 3)." An operator who is
  asked and refuses lands on the third label rather than falling between two.

I traced every path an agent can take. Argument names a reader → no ask → "the argument".
Argument names none, operator answers → "the operator's answer". Argument names none,
operator declines → inference, explicitly labelled by § 1. All three terminate on a label
that exists. One residual case is below as 🟡 1.

**The `NOTES.md` claim that was wrong about its own diff (was 🟡).** Fixed and verified:
`NOTES.md:489-492` now says "The second of the two new step 1 paragraphs says so outright,
because the paragraph above the new ask cites the posture file". Checked against the file —
`SKILL.md:159` cites `chapter-prose.md § The reader`, `:161` is the ask and never mentions
the boundary, `:163` is the paragraph that draws it. The claim is now exactly as wide as
the diff.

**"always" → "almost always" (was 🟢).** Landed in both `SKILL.md:232` and `NOTES.md:461`.
Matches `PLAN.md`'s "nearly always". No remaining absolute in either file.

**Arguments table cites § 1 (was 🟢).** `SKILL.md:19` now carries "Name no reader and the
skill asks for one; see § 1", matching the `--source` / `--minutes` / `--no-tags` rows that
each cite their section. The `§ 1` / `§ 2` / `§ 5` spellings extend a convention the file
already had at `:210` ("the gate at § 3"), so nothing new was invented.

**The working-tree `NOTES.md` edit is the right shape.** It would have been easy to
retro-fit the operator's decision to the three-origin outcome. It does not: it records the
decision as taken ("while a persona had two origins, the argument or inference"), then
records that the ask added a third and the shipped line names all three. That keeps
`PLAN.md § Resolved`, which still states the decision in its two-origin form, true rather
than stale — and keeping the decision and the outcome apart is what that file is for.

## What is working well

- **The scope boundary is held in the prose, not only in the plan.** `SKILL.md:163` states
  the persona/posture split outright and closes it with "not a chapter agent's to
  renegotiate". Verified the other direction too: the diff touches neither
  `reference/chapter-prose.md § The reader` nor § 5's prompt list, so nothing new reaches a
  chapter agent that could reopen the posture. The boundary in `PLAN.md § Scope boundary`
  is respected.
- **The ask copies a form the file already uses** (§ Sizing the book's "Neither → Ask",
  § Paragraph tags' "Ask if the argument gives no signal") and cites both as its reason,
  so an agent reads it as the same kind of instruction rather than a new mechanism.
- **The "state it as a sentence, not a label" instruction is taught with a worked example**
  on both sides — the apprentice-electrician sentence against `Reader: apprentice
  electricians`. That is the difference between a rule an agent follows and one it
  interprets.
- **The display-list edit is minimal.** One noun added to `SKILL.md:227`'s enumeration; the
  two governing paragraphs sit after the existing "Lead with the ledger" paragraph, so the
  gate's stated priority order is unchanged.
- **`NOTES.md`'s "Asserted, not measured" heading** on the reference guide account is exactly the
  discipline that file exists to enforce, and it names why (the book is not in this repo).

## Issues found

### Critical

None.

### Important

🟡 **The gate has no label for a persona the argument names only in outline**

📍 Location: `plugins/bookcraft/skills/createbook/SKILL.md:161` and `:230`

**What I see:**

The ask fires on a binary condition — "When the argument names no reader" — and the gate
offers three mutually exclusive origins, one of which is "the argument". A real invocation
sits between them. `"A practical guide to Docker for first-year CS students"` **names** a
reader, so no ask fires; but § 3 requires the reader be stated as a full sentence, and a
full sentence needs what the argument did not supply:

```
"Written for a first-year CS student who has used an IDE but never a terminal,
and has to run a class project in a container by Friday"
```

An agent following the text reports that persona's origin as "the argument". Yet the
clause that actually governs twenty chapters — what they can be assumed to know — was
inferred, and § 1 says so itself: "The last is the one that changes the book, since it sets
what every chapter may leave unglossed."

**The risk:**

This is the same class of gap round one found, one step further in. The marker exists to
make inferred content loud; here the loudest inferred content is printed under the quietest
label. The operator reads "from the argument", recognises the phrase they typed, and passes
a knowledge assumption nobody chose. `PLAN.md`'s objective is that "a persona the model
inferred rather than one it was given" not reach every chapter unseen — and in the thin
argument case, which is the common case, half of it still does.

This is **in scope**: it exists only because this PR introduced the sentence requirement and
the provenance marker. It is **not a regression** — `main` shows the operator nothing at all
— so it does not block.

**Suggested fix:**

One clause at `:230`, no new trigger and no change to § 1's condition (which would be scope
creep against `PLAN.md § Open Questions § Resolved`):

```markdown
In the same breath, say where that persona came from: the argument, the operator's
answer to the ask at § 1, or your own inference from the subject and the sources.
**Where the argument named the reader only in outline and you filled in the rest,
say which half is which** — "first-year CS students" came from the argument and
everything after "who" is yours. The knowledge clause is the one that changes the
book, so it is the one worth attributing.
```

**Learning note:**

A provenance marker is only as good as its narrowest true statement. When the states a
system can be in are a spectrum and the labels are a partition, the spec has to say which
label a middle state takes — or every agent picks a different one, and the label stops
carrying information at exactly the point it was supposed to.

---

🟡 **`pr-summary` reports a line count that does not match the diff**

📍 Location: `changelog/23-.../pr-summary-2026-09-20.md`, § Impact assessment

**What I see:**

> Seven files, 317 insertions and 5 deletions, of which the four under `plugins/` are
> **63 insertions and 5 deletions**

Measured with `git diff main...HEAD --numstat -- plugins/`:

| | plugin.json | README.md | NOTES.md | SKILL.md | total |
|---|---|---|---|---|---|
| insertions | 1 | 2 | 45 | 10 | **58** |
| deletions | 1 | 2 | 0 | 2 | **5** |

58, not 63. The 63 looks like insertions **plus** deletions (58 + 5) reported as
insertions. With the uncommitted `NOTES.md` correction included the figure is 60, so no
reading of the tree produces 63.

The seven-file / 317-insertion total is correct for `HEAD` but describes the tree before
this summary is itself committed; once `/pr:close` commits it and the `NOTES.md` fix, it is
eight files and roughly 419 insertions.

**The risk:**

This becomes the PR body — the durable record a future reader checks the branch against.
More pointedly, this repo's own `NOTES.md § The rule most worth keeping` is about exactly
this failure: "A real number widened past its measured population is an invented number."
A summary that gets its own diff's arithmetic wrong is the weakest possible place to spend
that credibility.

**Suggested fix:**

Correct to "58 insertions and 5 deletions" and restate the totals for the post-close tree,
or drop the plugins sub-count and keep only the claim that carries meaning: the four files
under `plugins/` are 58 added lines and the rest is branch documentation.

**Learning note:**

`--stat` reports changed lines, `--numstat` reports insertions and deletions in separate
columns. When a summary quotes both, quote them from the same command.

### Suggestions

🟢 **"The third case" is positional, and a neighbouring file counts to three differently**

📍 Location: `plugins/bookcraft/skills/createbook/SKILL.md:232`, with
`plugins/bookcraft/skills/createbook/NOTES.md:478`

`SKILL.md:232` opens "**The third case is what this line is for.**" Third in the preceding
list is "your own inference", and the paragraph is indeed about inference, so it resolves
correctly today. But it resolves by counting, and the list it counts into is one sentence
away in a file that gets edited. Reorder those three origins for any reason and this
paragraph silently points at the wrong one.

Meanwhile `NOTES.md:478` calls a **different** origin "a third": "the ask below adds a
third, the operator's answer to it". That is third *chronologically* and correct on its own
terms, but a maintainer reading both files in one sitting now has two "thirds" naming two
different origins.

Round one moved this line from "The inferred one" to "The third case"; naming and counting
at once keeps what that change bought without the fragility:

```markdown
**The third case, your own inference, is what this line is for.**
```

**Learning note:** in a spec an agent parses literally, an ordinal is a pointer with no
type checking. Where naming the thing costs three words, name it.

---

🟢 **Two documents cite different numbers for the same prior work, and one claim overreaches**

📍 Location: `changelog/23-.../CHANGELOG.md` ("the drift that #27 just finished removing")
and `changelog/23-.../pr-summary-2026-09-20.md` ("the documentation drift PR #28 had just
removed")

Both refer to the same work, with different numbers. #27 is the **issue**,
`cjus/cjus-skills#27 Fix documentation drift in the root README and hooks README`; #28 is
the PR that closed it. The `CHANGELOG` attributes the removing to the issue, which did no
removing. Per this repo's own convention, cite by full slug rather than a bare number, and
pick one of the two consistently.

The stronger point is the claim itself. `gh pr view 28 --json files` shows #28 touched
`README.md`, `plugins/pr/hooks/README.md`, `plugins/pr/reference/git-conventions.md`,
`plugins/pr/hooks/test-guard-default-branch.sh` and `.claude/settings.json`. It never
touched `plugins/bookcraft/README.md`. So leaving the bookcraft README stale could not have
"reintroduced" drift #28 removed — #28 never removed drift in that file. The justification
for the out-of-phase README touch stands perfectly well on its own ("both describe
user-facing behavior this branch changes"); the appeal to #28 adds nothing and is the only
part of it that is not literally true.

**Learning note:** a rhetorical appeal to prior work is still a factual claim, and it is the
kind a reader checks with one command.

---

🟢 **`CHANGELOG.md`'s Phase 1 entry still describes the pre-fix binary provenance**

📍 Location: `changelog/23-.../CHANGELOG.md`, first dated entry

> The sentence marks provenance — given in the argument, or inferred from the subject and
> the sources.

That is what `64fdded` shipped and what `5826d32` replaced. The later dated entry in the
same file records the three-origin fix, so a reader going top to bottom is not misled — a
changelog is chronological and this is how one is supposed to read. Noting it only because
`NOTES.md`, `SKILL.md` and `README.md` were all brought forward and this is the one
description of the shipped behavior that still reads in the two-origin form. A four-word
addition ("as shipped that day") on the Phase 1 paragraph, or nothing at all, depending on
how much weight the branch `CHANGELOG` is meant to carry after merge.

### ⏭️ Deferred to follow-up

None new. The two items round one deferred — recording the reader's provenance in
`OUTLINE.md`, and the persona/posture name collision reaching § 5 — are already recorded
in `PLAN.md § Deferred` with occasions attached, and nothing in this delta changes the
judgment on either. They carry forward unchanged and are not re-raised here.

## Questions

None blocking. One worth a sentence in the summary if the answer is interesting: was the
thin-argument case in 🟡 1 considered and judged acceptable, on the grounds that the full
persona sentence is printed either way and the operator can correct what they read? That
is a defensible position — the display catches it even where the marker does not — and if
it is the position, saying so beats a clause.

## Verdict

The branch delivers its objective. The gate shows the reader, marks where it came from, and
handles all three origins the two phases create; the ask fires on the documented condition
and hands its decline path back to the gate; the scope boundary is held in the prose and
nothing reaches a chapter agent that could reopen the posture. Round one's four fixes all
landed and none of them broke anything adjacent. The two 🟡 items are a narrowing of a new
marker and an arithmetic slip in the PR body — neither is a regression against `main`,
which showed the operator no reader at all.

VERDICT: APPROVE

Fix the two 🟡 items before `/pr:close` writes the body — one clause in `SKILL.md:230` and
one corrected number in the summary — and merge.
