# Stop /pr:close from linking issues other than the ticket

Start date: 2026-09-25 16:11:44 MDT

`/pr:close` verifies that the PR closes the ticket but not that it closes nothing else, and its
two-edit body write can leave the PR closing nothing. This branch tightens the verify, puts the
closing-keyword rule where the summary is written, and writes the body in one edit.

## Changes

### 2026-09-25: Operator decision, the closing-keyword rule moves to `/pr:summary`

- **Moved, not mirrored.** `/pr:summary` writes the text the rule governs, so it states the rule
  in full. Close step 4 keeps a one-line pointer, leaving one place to maintain.
- **This branch's PR is titled `[#42] …` by hand.** The installed 0.2.5 plugin predates the prefix,
  so the title gets overridden when the PR opens and checked again at `/pr:close`, as #44 did.

### 2026-09-25: Phase 1, the verify stops on any issue other than the ticket

- **Step 4's verify query gains a fourth element,** the closing references other than the
  ticket, and requires it to be `[]`. The stop names each stray. Step 8b re-runs the same query,
  so the backstop inherits it.
- **References are keyed on repository as well as number.** `closingIssuesReferences` carries
  `repository.owner.login` and `repository.name`, read off PRs #38 and #45. So `other/repo#42`
  no longer passes as ticket #42, and shows as a stray in that form. The kept-description
  pre-check moved to the same keying, since it has to ask the question the verify asks.
- **Re-reads cover strays too.** Straight after an edit, `closingIssuesReferences` still
  describes the previous body, so a stray there is not yet a verdict.
- **The remedy follows the body's author.** When the skill wrote the body, fix the summary and
  re-run. When the description is the operator's, report the stray and leave it to them.
- Tested the jq on six fixture payloads (none, ticket only, ticket plus a stray, a cross-repo
  #42, mixed-case repo, stray only) and against PR #45 live: `[9599,true,true,[]]`.
- README's `/pr:close` link bullet now says the close halts on any other linked issue.
