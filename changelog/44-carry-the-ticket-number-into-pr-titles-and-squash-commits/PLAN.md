# Carry the ticket number into PR titles and squash commits

Start date: 2026-09-25 08:04:45 MDT

Ticket: #44 (status:todo -> status:in-progress)

## Overview

GitHub shares one number sequence between issues and PRs, so a PR's number never matches its
ticket. Ticket #32 merged as PR #41 and landed on `main` as `Bind a fixture book in CI so makebook
changes get a signal (#41)`, with 32 appearing nowhere in the subject. Every numbered branch
already matches its issue; the ticket number is lost at the PR title and the squash commit.

This branch makes the pr plugin carry the ticket ID into the PR title, so a squash merge lands
with both numbers in its subject, `[#32] Bind a fixture book… (#41)`. It has `/pr:init` check the
repo's squash-merge title setting so a single-commit PR cannot bypass the title, labels both
numbers wherever the plugin reports them, and documents which number each surface shows.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#44: Carry the ticket number into PR titles and squash commits**

### Causes

- `/pr:pre-test` titles the draft PR from PLAN.md's H1, and `/pr:close` from the issue title.
  Neither carries the ticket number.
- GitHub appends the PR number to the subject on squash merge.
- Under the repo's `COMMIT_OR_PR_TITLE` squash setting, a single-commit PR uses its commit subject
  instead of the PR title, so fixing the title alone does not cover every merge.
- The squash body is built from the branch's commit messages, so the PR body's closing reference
  does not land in it.

### Acceptance

- A PR opened and closed through the plugin merges with a subject carrying both the ticket ID and
  the PR number, including a single-commit PR.

## Plan

- [x] Phase 1: Prefix PR titles with the ticket ID, e.g. `[#32] Bind a fixture book…`, or
      `[ABC-32] …` with `ticketPrefix` set. `/pr:pre-test` sets it when it opens the draft PR.
- [x] Phase 2: `/pr:close` corrects the title on an existing PR that lacks the prefix, and
      verifies it alongside its closing-reference check, reporting it as a row in its report.
- [x] Phase 3: `/pr:init` checks `squash_merge_commit_title` and recommends `PR_TITLE`, asking
      before changing the repo setting.
- [x] Phase 4: Label both numbers wherever the plugin reports them, e.g. the lifecycle state line
      reading `PR #41 → closes #32`.
- [x] Phase 5: State in `reference/ticketing.md` that PR numbers never match ticket numbers, and
      which one each surface shows. Put the title-prefix rule beside the slug rule in
      `reference/config.md`, so every skill derives it one way.
- [x] Phase 6: Bump the pr plugin's version so installed copies refresh, and run
      `scripts/test-acceptance.sh`.

## Open Questions

- ~~Is `[#32] <title>` the prefix format, or is another shape preferred?~~ **Resolved
  2026-09-25 (operator):** `[#32] <title>`, and `[ABC-32] <title>` with `ticketPrefix` set.
- ~~Should the lifecycle script raise a gap when an open PR's title lacks the prefix, or leave
  that to `/pr:close`'s check?~~ **Resolved 2026-09-25 (operator):** leave it to `/pr:close`. The
  lifecycle script gets no title gap.
- ~~This repo's own `squash_merge_commit_title` is `COMMIT_OR_PR_TITLE`. Change it to `PR_TITLE`
  as part of this branch, or leave that to a `/pr:init` run afterward?~~ **Resolved 2026-09-25
  (operator): changed now.** Changed with `gh api -X PATCH` and read back as `PR_TITLE`, with the
  message still `COMMIT_MESSAGES`.
- ~~This branch's own PR is opened by the installed plugin, which does not yet prefix titles.
  Title it `[#44] …` by hand so it merges in the new shape?~~ **Resolved 2026-09-25 (operator):
  yes.** No PR exists yet. When `/pr:pre-test` opens it, override the installed 0.2.5 skill's
  title with `[#44] Carry the ticket number into PR titles and squash commits`, and check it again
  at `/pr:close`.

## Deferred

**Triaged at `/pr:close` on 2026-09-25.**
- **Filed as issue #47**, "Warn at /pr:close when a squash would drop the title tag": the
  single-commit squash warning, which covers the first two items below, plus the empty-`$ID`
  guard and the leading space or colon case.
- **Dropped:** the `/pr:pre-test` `ticketPrefix` wording, because `/pr:close` corrects the title.

- `/pr:init` refuses on an already-configured repo unless given `--force`, which reruns
  detection and rewrites the config. So a repo that adopted the plugin before 0.2.6 gets the
  new squash-title check only through a full `--force` rerun. This repo was changed by hand
  instead.
- A repo that declines `PR_TITLE` at `/pr:init` still lands a single-commit PR with its commit
  subject. `/pr:close` does not warn about that. It could read the setting and the commit count
  at step 4b.
- Close review suggestions (`pr-review-2026-09-25-close.md`):
  - An empty `$ID` in `/pr:close` step 4b writes a `[] ` title. That run halts, but the next run
    turns it into `[#44] [] …`, which verifies green. A `[ -n "$ID" ]` guard would prevent it.
  - A title that starts with a space or colon needs two passes to settle, which contradicts the
    skill's claim that one pass is idempotent. The next run fixes it.
  - `/pr:pre-test` does not say to read `ticketPrefix`, so a prefixed repo's draft may open as
    `[#32]` until `/pr:close` corrects it.

