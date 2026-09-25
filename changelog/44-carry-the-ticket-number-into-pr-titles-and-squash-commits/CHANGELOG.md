# Carry the ticket number into PR titles and squash commits

Start date: 2026-09-25 08:04:45 MDT

A PR's number never matches its ticket, and a squash merge lands on `main` carrying only the PR
number. This branch puts the ticket ID in the PR title so both numbers reach the merge commit's
subject, and makes the plugin say which number is which.

## Changes

### 2026-09-25: `[#N]` title prefix, squash-title check, both numbers labelled

- **Operator decisions:** the prefix is `[#32] <title>`, or `[ABC-32] <title>` with a prefix, and
  `/pr:close` owns the title check, so the lifecycle script raises no title gap.
- **What landed:**
  - The rule went into `config.md` next to the slug rule.
  - `/pr:pre-test` creates the draft with the prefix.
  - `/pr:close` step 4b corrects an existing title and verifies it in the closing-reference query,
    and 8b re-runs that query.
  - `/pr:init` step 6 asks before `PATCH`ing `squash_merge_commit_title` to `PR_TITLE`.
  - The lifecycle `pr` line names both numbers.
  - `ticketing.md` has a surface-by-surface table.
  - Acceptance phase 8 uses a stub `gh`, and fails as expected against `main`'s script.
  - Version `0.2.6`.

### 2026-09-25: this repo squashes to the PR title

- **Operator decisions:**
  - This repo's squash title setting is now `PR_TITLE`. It changed with `gh api -X PATCH`, read
    back with `COMMIT_MESSAGES` unchanged, and the other merge methods are still allowed. This was
    the first live run of the init step 6 call. It is a GitHub setting, so it is not in the diff.
  - This PR is titled `[#44] …` by hand.

### 2026-09-25: review fixes (`pr-review-2026-09-25.md`, APPROVE)

- **Operator decisions:**
  - A leading `[#N]` counts as ticket-shaped even in a prefixed repo.
  - `[#44]Carry` is normalized to `[#44] Carry`.
- **What changed:**
  - `config.md` names the *title tag* (`#123` or `ABC-123`).
  - Step 4b became one idempotent jq transform, tested on 13 titles.
  - Verification became a fixed point, which rejects `[#44] [#44]Carry`. The snippets were run
    read-only against PR #45.
  - The `pr` line keys its warning on `hasCloses`, with a third stub case. 42 passed, 0 failed.
  - `/pr:init` guards `$CURRENT_MESSAGE`.
  - The 4b row gains a `deferred to 8b` form.
- **The close review** (`pr-review-2026-09-25-close.md`) is APPROVE. It confirms all six fixes
  and adds three suggestions, which were parked under Deferred.
