# Stop /pr:close from linking issues other than the ticket

Start date: 2026-09-25 16:11:44 MDT

Ticket: #42 (status:todo -> status:in-progress)

## Overview

`/pr:close` step 4 checks that the PR closes the ticket, but never that it closes nothing else,
and the way it writes the body can leave the PR closing nothing at all.

This branch makes the close's verify fail when the PR resolves any issue other than #N, puts the
rule against literal closing keywords in the skill that writes the summary, and writes the summary
and the closing line to the PR body in a single edit, so no intermediate body without the link
can win a race against the final one.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#42: Stop /pr:close from linking issues other than the ticket**

`/pr:close` step 4 only checks that the PR closes the ticket. It never checks that the PR closes
nothing else, and the way it writes the link can leave the PR closing nothing at all.

- [ ] **Fail the verify when the PR resolves any issue other than #N.** The verify in
      `plugins/pr/skills/close/SKILL.md` ("Verify on every path") checks only that
      `closingIssuesReferences` contains #N. A summary that quotes a closing line for another
      issue would close that issue on merge, and the verify would still pass.
- [ ] **Move or mirror the "no literal closing keywords with an issue number in the summary" rule
      into `plugins/pr/skills/summary/SKILL.md`.** Today the rule lives in close step 4, but
      `/pr:summary` writes the text it governs.
- [ ] **Write the summary and the closing line in one body edit, not two.** Step 4 replaces the
      body with the summary, then appends the closing line in a second edit a few seconds later.
      On PR #38, GitHub resolved those two edits out of order. The final state reflected the
      replace, which had no link, so `closingIssuesReferences` read `[]` for over a minute after
      the push. The body was intact and still ended with the closing line. The `true` read
      straight after the append was left over from the older body. Re-saving the identical body
      brought back `[30]` within one read, and a later push kept it, so the push itself did not
      drop it. The older create-then-append flow has the same two-edit shape.

**Symptom (first two items):** a summary quoting a closing line with another issue's number
closes that issue on merge, while step 4's verify passes.

**Symptom (third item):** step 4 reports the link verified while the PR resolves no closing
reference. Only step 8b's check after the push catches it. If 8b reads its stale `true` too, the
PR merges without closing the ticket.

**Occasion:** every `/pr:close` that writes a body. The summary for #30's fix (PR #38) quoted its
own ticket's closing line in inline code, and its step 8b hit the ordering race.

Surfaced by PR #38's Phase 7 close review and its step 8b.

## Plan

- [x] Phase 1: Step 4's verify, and step 8b's backstop, fail when `closingIssuesReferences` holds
      any number other than #N, naming each stray issue.
- [x] Phase 2: State the no-closing-keywords rule in `/pr:summary`, which writes the text, and
      have close step 4 refer to it rather than carry it alone.
- [x] Phase 3: Write the summary and the closing line as one body in a single edit, on the create
      path and the replace path alike, then verify with the existing re-reads.
- [x] Phase 4: Bump the pr plugin's version so installed copies refresh, and run
      `plugins/pr/scripts/test-acceptance.sh`.

## Open Questions

- ~~Move the rule into `/pr:summary`, or mirror it in both skills? Mirroring keeps close's gate
  self-describing; moving leaves one place to maintain.~~ **Resolved 2026-09-25 (operator): move
  it.** `/pr:summary` states the rule in full. Close step 4 keeps a one-line pointer to it, not a
  second copy.
- ~~This branch's own PR is opened by the installed plugin (0.2.5), which predates the `[#N]`
  title prefix. Title it `[#42] …` by hand?~~ **Resolved 2026-09-25 (operator): yes.** When
  `/pr:pre-test` or `/pr:close` opens the PR, override its title with
  `[#42] Stop /pr:close from linking issues other than the ticket`, and check it again at
  `/pr:close`.

## Deferred

- `pr-lifecycle-state.mjs` could raise a gap when an open PR's `closingIssuesReferences` holds an
  issue other than the ticket. Out of scope: this branch's objective is close's verify. #44 made
  the same call for its title check and left it to `/pr:close`.
