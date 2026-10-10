## PR review: createbook: explain each concept to the learner, with no per-chapter quotas

Reviewed at the `/pr:close` gate: draft PR #75 for ticket
`74-createbook-explain-each-concept-to-the-learner-with-no-per-chapter-quotas`, four commits
ahead of `main` (`2463162`, `a1fb2ca`, `5101c7b`, `2772875`) plus the uncommitted working-tree
changes to `NOTES.md`, `PLAN.md`, `CHANGELOG.md` and `pr-summary-2026-10-09.md`.

This is a re-review. It reviews the delta since `pr-review-2026-10-09.md`, which approved with
three Important findings. It does not re-audit the rule files from scratch. Items that review
deferred are settled and are carried below only so triage receives them.

### Summary

Since the last review, the branch fixed the three Important findings and most of the
suggestions (`a1fb2ca`). It recorded the Phase 10 blind set as ready (`5101c7b`), added the PR
summary (`2772875`), and, uncommitted, recorded the operator's ruling: the four blinded
versions were spot-checked rather than scored, and the revised rules become the default.
`NOTES.md` is the durable record of that ruling. `PLAN.md`, `CHANGELOG.md` and the PR summary
are updated to match it.

### The three earlier findings: all hold

- **guide.md's "what a chapter may assume" paraphrase.** Fixed. `guide.md:15` now reads "a term
  an earlier chapter glossed is free, so is anything on the fluent side of the reader's
  knowledge boundary, and anything else is glossed here." It agrees with the core again, so the
  guide profile's precedence no longer forks the rule. No other paraphrase of the rule remains
  in `guide.md`.
- **The sample stop drafted before `book.json`.** Fixed. The two sample paragraphs now close
  § 4 (`SKILL.md:471-473`) and open "With `book.json` written". The stated reason is "the
  sample's marks and source names come from the `sources` map". `SKILL.md:401` now says "the
  sample at the end of § 4 is the second", § 5 item 14 says "from § 4" (`SKILL.md:496`), and
  `NOTES.md:1110` says "after `book.json` is written (`SKILL.md § 4`)". A grep for `sample` and
  `blocking stop` across the plugin finds no reference left at § 3.
- **Likely questions writing into the concept list.** Fixed. `chapter-prose.md:63` now ends "The
  question after that lies past the book's edge, which the concept list marks, and never add an
  item to hold it." The git-revert commentary at `:76` now says "the rewrite leaves it out". No
  rule in the file sends anything into the ledger-owned list any more.

The suggestions taken in `a1fb2ca` also check out. The index pair keeps its example. The
direction search spares a numbered procedure the reader performs. "Term budget" is gone from
`SKILL.md`. Coverage items can be marked inferred. `/updatebook` carries the Teaches row. The
README notes narration's wrong model. `NOTES.md` credits `qe` with three steps and says "at
least two" wrong claims.

### What is working well

- **NOTES.md records Phase 10 honestly, as a judgment and not as a blind verdict.** The
  heading says "prepared and not run". The ruling paragraph says "That is the verdict, and its
  evidence is the operator's judgment from a spot check. No blind comparison of the two rule
  sets exists." The earlier "Settled by the operator" paragraph keeps the original decision
  ("the blind comparison below runs before the branch closes") and adds the change after it,
  instead of rewriting what was decided. That is the right way to amend a record.
- **The "Asserted, not measured" list was left alone.** The ruling did not quietly promote "That
  the four steps help a chapter's reader" or "That removing the quotas does no harm" to
  measured. A spot check is not evidence for either, and the list still says so.
- **The measurements state their limits.** The length figures say what was counted ("every word
  on the page with tables included"), and the arithmetic holds: 3,318 / 2,548 = 1.30 and
  4,050 / 3,037 = 1.33. The last bullet says "Neither has been through `/check-claims`, which
  the current versions had, three rounds deep". That is a confound recorded against the
  branch's own side, which is exactly what makes a record trustworthy.
- **PLAN.md follows the scope contract.** The Overview's acceptance paragraph is unchanged, as an
  immutable objective should be. The ruling is recorded as Phase 10's status, and the newly found
  outline-cap issue is parked under `## Deferred` rather than fixed in place.
- **`guide.md` really needed no change.** A grep of the plugin finds no wording that waits on the
  comparison, apart from one pre-existing line in `NOTES.md` (see Suggestions).
- **The summary's numbers are exact.** `git diff main --shortstat` against the working tree gives
  11 files, 1,101 insertions and 45 deletions, of which 836 are `changelog/` and 265 are the plugin.
- **Mechanical checks pass.** `scripts/check-citations.py` exits 0 with 203 resolved. The
  longest paragraph in `chapter-prose.md` is 90 words and the longest sentence 45, both at the
  limit and not over it. Neither rule file has an em dash. The cross-project audit and the
  cross-repo link sweep of every changed file are clean, and there is no attribution. CI passes
  on both legs (not re-run, per the brief).

### Issues found

#### Critical

None.

#### Important

🟡 **The PR summary's Overview still presents the blind comparison as the acceptance test**

📍 Location: `changelog/74-createbook-explain-each-concept-to-the-learner-with-no-per-chapter-quotas/pr-summary-2026-10-09.md:15-16`,
and `:117`

**What I see:**

> Ticket #74, which consolidates #34; #34's blind reader comparison is the acceptance test.

Line 117 lists the operator's rulings and ends "Phase 10 runs on this branch before close", with
nothing saying the ruling was later replaced. The correction comes at line 129, a full screen
later.

**The risk:**

`/pr:close` publishes this file as the PR body, so it becomes the merge record. Most readers
stop at the Overview. A reader who does so learns that the blind comparison was the acceptance
test, and nothing tells them it was not run. That is the misreading `NOTES.md` carefully
avoids, and the PR body is the one place it survives. This is not a regression against the
objective and does not affect the verdict. It is a one-sentence fix, and it belongs before the
body is published.

**Suggested fix:**

```text
Ticket #74, which consolidates #34. #34's blind reader comparison was the planned acceptance
test; it was prepared, and the operator settled acceptance by a ruling on a spot check instead
(Plan alignment, below).
```

At line 117, change the bullet to "Phase 10 runs on this branch before close; it was later
settled by ruling, below." That matches how `NOTES.md:1160-1161` handles the same sentence.
`PLAN.md:254-256` has the same unamended bullet. It is a working note, so amending it there is
optional.

**Learning note:**

When a plan changes, every summary of it has to change too, and the one that matters most is the
one readers see first. Correcting a claim in the body does not reach the reader who stopped
reading at the Overview.

#### Suggestions

🟢 **NOTES.md:909 now points at a test this PR records as not run.** The line, in § The handoff
chain leaves the guide path, reads "Asserted, not measured: that an orienting opening reads
better for this reader than a handoff. Phase 7's blind comparison is the first test." On `main`
that was a true statement of a pending plan. This PR closes the ticket the comparison was
consolidated into and records it as "prepared and not run", which makes the line stale. That is
why it passes the in-scope test. Suggest: "Phase 7's blind comparison, carried into #74, was
prepared and not run (§ Explaining to the learner, 2026-10-09)." The assertion stays an
assertion.

🟢 **The likely-questions sentence mixes a statement and an order.** `chapter-prose.md:63`: "The
question after that lies past the book's edge, which the concept list marks, and never add an
item to hold it." The "and" joins a statement to a command. Splitting it reads more cleanly to
an agent: "The question after that lies past the book's edge, which the concept list marks.
Never add an item to the list to hold it."

🟢 **Small polish in the new prose.**

- `NOTES.md:1165` runs to 103 characters, against the roughly 95-character wrap around it.
  `NOTES.md:1091` is the same, from `a1fb2ca`, and so is `pr-summary-2026-10-09.md:173` at 119.
  None of this shows in rendered Markdown.
- `NOTES.md:1179` uses a bare "§ Spend these deliberately". Writing it as
  `` `chapter-prose.md § Spend these deliberately` `` names the file the section lives in and
  lets `check-citations.py` verify it. The rule it cites does say what the sentence claims
  (`chapter-prose.md:95`).

#### ⏭️ Deferred to follow-up

These do not affect the verdict. Each is marked DROP. The first four were carried from
`pr-review-2026-10-09.md` unchanged and are settled there.

- **The analogy in two places**, `chapter-prose.md § These rules add words` against the cut
  order's analogy step. Pre-existing. theme: cut order. DROP.
- **Two-part teaching chapters**, `guide.md`'s teaching shape against core § Shape. Pre-existing.
  theme: chapter shape. DROP.
- **A narration handoff noun reported as a ledger miss** under the boundary rule. Arguable.
  theme: term ledger. DROP.
- **`<book>/sample/` is never removed** after the fan-out. No reader of the book folder sees it.
  theme: sample stop. DROP.
- **Old outlines still cap numbers in their rows**, `PLAN.md` § Deferred, found by the Phase 10
  redrafts. Behaviour for those books is unchanged from `main`, where the cap was the rule. An
  outline written under the new rules carries no cap: `SKILL.md § 2`'s "Anchors and numbers" row
  records ownership, not a limit. A recreate clears it, and the summary already says existing
  books are unaffected until recreated. The only occasion one could name is a recreate, which
  fixes the problem by itself, so there is no work to schedule. theme: outline migration. DROP.

### Questions

- **When were the word counts taken?** `NOTES.md:1175` heads the list "Measured on the
  redrafts, before anyone read them". The term counts are in the 12:06 `CHANGELOG.md` entry,
  before scoring. The length figures appear only in the 19:11 edit, after the spot check. A
  word count does not depend on when it was taken. If they were counted after the spot check,
  limit the clause to the term counts or drop it, so the record claims nothing it did not need.
- **Should the blind comparison be tracked anywhere after merge?** #34 (Validate the
  guide-profile rules with a blind reader comparison) closed on 2026-10-09, and #74 closes with
  this PR. After that, the only pointer to the scorable set is `NOTES.md`'s "the comparison can
  still be run there". Whether to track it is the operator's decision, and the ruling may
  already answer it. If it should be scheduled, it needs an issue that names an occasion.

### Verdict

VERDICT: APPROVE

The three earlier findings are fixed and hold. The Phase 10 ruling is recorded honestly as a
judgment, and nothing in the delta regresses the objective. Before publishing the PR body,
amend the summary's Overview sentence so it no longer presents the blind comparison as the
acceptance test.
