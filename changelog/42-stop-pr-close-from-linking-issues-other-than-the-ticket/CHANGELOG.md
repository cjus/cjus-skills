# Stop /pr:close from linking issues other than the ticket

Start date: 2026-09-25 16:11:44 MDT

`/pr:close` verifies that the PR closes the ticket but not that it closes nothing else, and its
two-edit body write can leave the PR closing nothing. This branch tightens the verify, puts the
closing-keyword rule where the summary is written, and writes the body in one edit.

## Changes

### 2026-09-25: Operator decisions

- **The closing-keyword rule is moved into `/pr:summary`, not mirrored.** Close step 4 keeps a
  pointer to it.
- **This branch's PR is titled `[#42] …` by hand**, because the installed 0.2.5 plugin predates the
  prefix. #44 did the same.

### 2026-09-25: Phase 1, the verify stops on any issue other than the ticket

- **The verify query gains a fourth element,** the references other than the ticket, and it must
  be `[]`. The stop names each one, and step 8b inherits the check.
- **References are keyed on `owner/name` as well as number**, a field read off PRs #38 and #45.
  So `other/repo#42` shows as a stray, not as the ticket. The kept-description pre-check uses the
  same keying.
- **A stray straight after an edit is re-read**, like a `false`.
- **The remedy follows the body's author.** When the skill wrote the body, fix the summary and
  re-run. When the operator wrote it, report the stray to them.
- The jq was tested on six fixtures, and live on PR #45: `[9599,true,true,[]]`. The README's
  link bullet was updated.

### 2026-09-25: Phase 2, the closing-keyword rule moves to `/pr:summary`

- **`summary/SKILL.md` step 3 states the rule.** It lists all nine keywords and both reference
  shapes, says the rule covers prose, and has examples use a `#N` placeholder.
- Close step 4 points to it. The README's `/pr:summary` entry was updated.

### 2026-09-25: Phase 3, the summary and the link go to the PR in one edit

- **Create and replace build the whole body once**, marker then summary then the closing line,
  and send it in one `gh` call. There is no longer an intermediate body for the PR #38 race.
- **The build is chained with `&&`**, because marker plus closing line alone would pass the
  verify. Against a stub `gh`, a missing, directory or mode-000 summary stops before `gh` runs.
- The kept path (pre-check, then one append) is unchanged. Step 8b's deferred create carries the
  closing line in the body it creates.

### 2026-09-25: Phase 4, version bump and tests

- `plugin.json` 0.2.7 → 0.2.8.
- Acceptance suite 42/0. It does not cover skills, so it guards only against regressions. The
  guard suite passed 73/0.
- A lifecycle-script gap for strays went under `PLAN.md § Deferred`.

### 2026-09-25: `/pr:pre-test`, draft PR #49, review APPROVE, four review items applied

- **PR #49 opened as a draft with the `[#42]` title.** `pr-review-2026-09-25.md` returned APPROVE.
- **Applied from the review:**
  - A stray can be a Development-sidebar link, which no body edit removes. The operator removes
    it, and the close is not re-run.
  - The keyword rule covers the colon form.
  - A stray naming this repository under another name means `$REPO` is stale.
  - The stop on an intended second closing issue is deliberate, as the ticket asks. That issue is
    closed by hand after the merge.
- **For this branch's close:** the installed 0.2.5 plugin runs it, so the summary's closing-line
  examples use `#N` by hand, and 8b is the backstop for the old two-edit race.

### 2026-09-25: `/pr:close` review gate APPROVE

- `pr-review-2026-09-25-close.md` returned APPROVE.
- Its one important item was a summary sentence that overstated the pre-test review's jq runs:
  four new payloads, not ten, and the ticket-only cases pass. The sentence was corrected before
  step 4 wrote the body.
