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

### 2026-09-25: Phase 2, the closing-keyword rule moves to `/pr:summary`

- **`summary/SKILL.md` step 3 states the rule in full.** It lists all nine keywords (any tense,
  any case) and both reference shapes (`#123`, `owner/repo#123`), and it says the rule covers
  ordinary prose, not only quoted syntax. A summary that has to show a closing line uses a `#N`
  placeholder, or names the issue without the keyword.
- **Close step 4 points to it and no longer carries its own copy.** The "do not assume the
  summary supplies the link" paragraph now gives the reason (the summary never carries a
  keyword) instead of the old code-fence explanation.
- README's `/pr:summary` entry says the document carries no closing keyword with an issue number,
  and that the close adds the one closing line.

### 2026-09-25: Phase 3, the summary and the link go to the PR in one edit

- **The create and replace paths build the whole body once**: the marker, then the summary, then
  `Closes #N`. They send it with one `gh pr create` or one `gh pr edit`. The follow-up
  read-and-append edit is gone from both paths, so no intermediate body without the link can
  win the ordering race PR #38 hit.
- **The build is chained with `&&` end to end.** Carrying the link in the same body makes a
  partial build more dangerous than before: marker plus closing line would pass the verify.
  Tested against a stub `gh` on `PATH`. A good summary sends one body in the expected shape. A
  missing summary, a directory and a mode-000 file each stop before `gh` is called.
- **The kept-description path is unchanged**: pre-check, then append. It was already a single
  edit. Its read-and-guard paragraph is now scoped to that path.
- The paragraph that skipped the pre-check "and appended" after a create or replace became two:
  the one-edit rule with the PR #38 incident as its reason, and why a create or replace needs no
  pre-check.
- Step 8b's deferred create puts the closing line in the body it creates, rather than calling
  for a separate append edit.

### 2026-09-25: Phase 4, version bump and tests

- `plugins/pr/.claude-plugin/plugin.json` 0.2.7 → 0.2.8, so installed copies refresh.
- `plugins/pr/scripts/test-acceptance.sh plugins/pr`: 42 passed, 0 failed. The suite does not
  cover skills, so it checks for regressions here rather than testing the change. The skill
  changes were tested with the jq fixtures (Phase 1) and the stub-`gh` body build (Phase 3).
- `plugins/pr/hooks/test-guard-default-branch.sh`: 73 passed. The hook is untouched; the suite
  was run anyway because it is cheap.
- A lifecycle-script gap for stray closing references went under `PLAN.md § Deferred`.

### 2026-09-25: `/pr:pre-test`, draft PR #49, review APPROVE, four review items applied

- **Draft PR #49 was opened with the `[#42]` title set by hand**, as decided.
  `pr-review-2026-09-25.md` returned APPROVE with no blocking findings.
- **Applied 🟡 1: sidebar links.** `closingIssuesReferences` also includes issues linked by hand
  in the PR's Development sidebar, and no body edit removes those. The stray remedy now says to
  report such a link for the operator to remove, and not to re-run.
- **Applied 🟢 1:** the summary rule now covers a keyword with a colon after it.
- **Applied 🟢 2:** a stray that names this repository under another owner or name means `$REPO`
  went stale after a rename or transfer.
- **Review question 1, answered from the ticket:** the stop on an intentionally linked second
  issue is deliberate, and close step 4 now says so. That issue gets closed by hand after the
  merge.
- **Review question 2, for this branch's close:** the installed 0.2.5 plugin runs it, and its
  `/pr:summary` has no closing-keyword rule. Write that summary's closing-line examples with the
  `#N` placeholder by hand. The old two-edit race can still happen one last time, and 8b should
  catch it.
