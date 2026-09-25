# Carry the ticket number into PR titles and squash commits

Start date: 2026-09-25 08:04:45 MDT

A PR's number never matches its ticket, and a squash merge lands on `main` carrying only the PR
number. This branch puts the ticket ID in the PR title so both numbers reach the merge commit's
subject, and makes the plugin say which number is which.

## Changes

### 2026-09-25: `[#N]` title prefix, squash-title check, both numbers labelled

- **Operator decisions.** The prefix is `[#32] <title>`, or `[ABC-32] <title>` with
  `ticketPrefix` set. `/pr:close` owns the title check. The lifecycle script raises no title gap.
- **The rule lives in `reference/config.md`**, next to the slug rule. A title counts as prefixed
  only when it starts with exactly `[<id>] `, and a branch with no ticket gets no prefix.
- **`/pr:pre-test`** opens the draft PR with the prefix. It still leaves an existing PR alone.
- **`/pr:close` step 4b** creates the PR prefixed. On an existing PR it prepends the prefix,
  keeping the operator's wording, or replaces a stale ticket-shaped leading token. The title
  goes through the same verification query as the closing reference. That query gets a third
  element, `.title | startswith("[$ID] ")`, and 8b re-runs it. Exercised with `jq` on eight
  titles: only an exact leading `[<id>] ` verifies.
- **`/pr:init` step 6** reads `squash_merge_commit_title` and asks before `PATCH`ing it to
  `PR_TITLE`. It sends the current message back unchanged: GitHub's REST docs say the title is
  required whenever the message is sent. Hooks and Report are renumbered 7 and 8. Nothing
  outside init cited those numbers.
- **The lifecycle `pr` line** now reads `PR #57 → closes #42`, or `PR #57 → no closing ref to #42`
  when GitHub has not resolved the link. "closes" comes only from `closingIssuesReferences`.
- **`reference/ticketing.md § PR numbers are not ticket numbers`** gives, for each surface,
  which number it shows, why a single-commit PR bypasses the title under `COMMIT_OR_PR_TITLE`,
  and the rule that a report writes `PR #41` and never a bare `#41`.
- **Acceptance phase 8** puts a stub `gh` first on `PATH` to exercise the `pr` line. Against this
  branch: 41 passed, 0 failed. Against `main`'s script: both new checks fail, and it prints
  `pr       #57 OPEN`.
- pr plugin version `0.2.5` → `0.2.6`.

### 2026-09-25: this repo squashes to the PR title

- **Operator decision.** `cjus/cjus-skills` `squash_merge_commit_title` was changed from
  `COMMIT_OR_PR_TITLE` to `PR_TITLE`, using the `PATCH` from `/pr:init` step 6 with the message
  sent back as `COMMIT_MESSAGES`. Read back: `PR_TITLE`, `COMMIT_MESSAGES`. Merge commits and
  rebase merges are still allowed. This is the first live run of that call. It changes a
  GitHub setting, not a file, so the diff does not show it.
- **Operator decision.** This branch's PR is titled `[#44] …` by hand, because the installed 0.2.5
  plugin will not add the prefix.

### 2026-09-25: review fixes (`pr-review-2026-09-25.md`, APPROVE)

- **Operator decisions on the review's questions.** A leading `[#N]` is ticket-shaped even in a
  prefixed repo, and a malformed same-ID tag such as `[#44]Carry` is normalized.
- **One name for the bracketed part.** `config.md` defines the *title tag*: `#123`, or `ABC-123`
  with a prefix. It also defines a ticket-shaped leading token in one place. The ticket ID stays
  `123`, so the rule no longer reads as `[123] `. `close` and `pre-test` now use the new term.
- **Step 4b is one jq transform, not a three-row table.** It strips every leading ticket-shaped
  token, including a trailing space or colon, then prepends `[$ID] `. Tested on 13 titles: each
  output is idempotent, and `[WIP]` and `[XYZ-9]` stay.
- **Verification is a fixed point.** The title passes only if 4b's transform would leave it
  unchanged. `[#44] [#44]Carry`, which the old `startswith` check passed, now fails. The 4b and
  verify snippets were extracted from `SKILL.md` and run read-only against PR #45, with the edit
  swapped for an echo. The transform left the title unchanged, and verify returned
  `[202,false,true]`. The `false` is expected: a draft has no closing reference yet.
- **The lifecycle `pr` line keys its warning on `hasCloses`**, so a PR that closes another issue
  reads `closes #99, no closing ref to #42`. A third stub case covers it. 42 passed, 0 failed.
- **`/pr:init` step 6** reads `$CURRENT_MESSAGE` on its own and guards it before the `PATCH`.
  The reason given for sending it is corrected. The 4b report row gains a `deferred to 8b` form.

