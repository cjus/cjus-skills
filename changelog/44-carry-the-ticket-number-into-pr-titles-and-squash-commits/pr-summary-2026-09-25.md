# Carry the ticket number into PR titles and squash commits

## Overview

GitHub numbers issues and PRs from one shared sequence, so a PR's number never matches its ticket's. Ticket 32 merged as PR #41, and its squash commit landed on `main` as `Bind a fixture book in CI so makebook changes get a signal (#41)`, with 32 nowhere in it. The branch name carried the ticket, but the ticket was lost at the PR title and again at the squash subject.

This PR makes the pr plugin put the ticket ID at the front of every PR title as a bracketed *title tag*: `[#32] <title>`, or `[ABC-32] <title>` when `ticketPrefix` is set. A squash merge then lands as `[#32] <title> (#41)`, with both numbers in the subject. `/pr:pre-test` sets the tag when it opens the draft. `/pr:close` normalizes it on every run and verifies it in the same query as the closing reference. `/pr:init` checks the repo's squash-title setting, so a single-commit PR cannot land with its commit subject in place of the title. Reports now label both numbers, and `reference/ticketing.md` lists which number each surface shows.

This PR is itself titled `[#44] …`, by hand, because the installed 0.2.5 plugin does not add the tag yet. This repo's `squash_merge_commit_title` was changed from `COMMIT_OR_PR_TITLE` to `PR_TITLE` as part of the work. That is a GitHub setting, so it does not appear in the diff.

## Key changes

- **`plugins/pr/reference/config.md`.** The section is renamed *Deriving the ticket ID, the branch slug and the PR title*. It defines the title tag (`#123`, or `ABC-123`), the title format, what counts as prefixed (starts with exactly `[<title tag>] `), and what a ticket-shaped leading token is. A branch with no ticket gets no tag.
- **`plugins/pr/reference/ticketing.md`.** A new section, *PR numbers are not ticket numbers*, has a table of which number each surface shows: branch, title, PR URL, closing reference, squash subject, lifecycle line. It explains why `COMMIT_OR_PR_TITLE` lets a single-commit PR skip the title, and sets the reporting rule: a PR number is always written `PR #41`.
- **`plugins/pr/skills/pre-test/SKILL.md`.** The draft PR is created as `[<title tag>] <PLAN.md's H1>`. An existing PR is still left alone.
- **`plugins/pr/skills/close/SKILL.md`.**
  - A create now uses `[$ID] <issue title>`.
  - The new step 4b normalizes an existing title with one jq transform.
  - The verification query gains a third element: a fixed-point check on the title. Step 8b re-runs it, and a failure stops the close.
  - The new report row `4b PR title` includes a `deferred to 8b` form. Rows 6b and 8b now label the issue number.
- **`plugins/pr/skills/init/SKILL.md`.** The new step 6 reads `allow_squash_merge`, `squash_merge_commit_title` and `squash_merge_commit_message`. If the title setting is `COMMIT_OR_PR_TITLE`, it asks before `PATCH`ing it to `PR_TITLE`, and it sends the current message value back unchanged. The Hooks and Report steps become 7 and 8, and the report gains a `Squash:` line.
- **`plugins/pr/scripts/pr-lifecycle-state.mjs`.** The text `pr` line names both numbers and their relationship.
- **`plugins/pr/scripts/test-acceptance.sh`.** Phase 8 puts a stub `gh` first on `PATH` and checks three `pr`-line states.
- **`plugins/pr/README.md`.** Updated for the tag in `/pr:pre-test`, `/pr:close` and `/pr:init`, and in the artifact table.
- **`plugins/pr/.claude-plugin/plugin.json`.** `0.2.5` → `0.2.6`, so installed copies refresh.

## Code examples

**The title transform in `/pr:close` step 4b** (`plugins/pr/skills/close/SKILL.md`). It strips every leading ticket-shaped token, including any space or colon after it, then prepends the tag once. The edit is skipped when nothing changed:

```bash
TITLE=$(gh pr view "$BRANCH" --repo "$REPO" --json title --jq .title) && [ -n "$TITLE" ] \
  && NEW_TITLE=$(jq -rn --arg t "$TITLE" --arg id "$ID" --arg p "$PREFIX" '
       ("^(\\[(#[0-9]+" + (if $p == "" then "" else "|" + $p + "-[0-9]+" end) + ")\\][ :]*)+") as $re
       | "[\($id)] " + ($t | sub($re; ""; "i"))') && [ -n "$NEW_TITLE" ] \
  && { [ "$NEW_TITLE" = "$TITLE" ] || gh pr edit "$BRANCH" --repo "$REPO" --title "$NEW_TITLE"; }
```

**The verification is a fixed point** (same file). A title passes only if the transform would leave it unchanged. A plain `startswith("[$ID] ")` would also pass `[#44] [#44]Carry`:

```bash
      | [(.body | length),
         ([.closingIssuesReferences[].number] | index($n) != null),
         (.title == "[\($id)] " + (.title | sub($re; ""; "i")))]'
```

**The lifecycle `pr` line** (`plugins/pr/scripts/pr-lifecycle-state.mjs`). It was `pr       #45 OPEN (draft), …`. Now it names the relationship, taken only from GitHub's resolved closing references. The missing-link note keys on `hasCloses`, so a PR that links some other issue still says the ticket is not linked:

```js
const prLink = (p) => {
  const closes =
    p.closesIssues?.length > 0 ? ` → closes ${p.closesIssues.map((n) => `#${n}`).join(", ")}` : "";
  const missing =
    p.hasCloses === false ? `${closes ? "," : " →"} no closing ref to #${ticketNumber}` : "";
  return closes + missing;
};
```

## Plan alignment

All six phases landed as planned:

1. **Title prefix.** `/pr:pre-test` sets it on create. The format is the operator's choice: `[#32]`, and `[ABC-32]` with a prefix.
2. **`/pr:close` corrects and verifies the title**, and reports it on its own `4b` row. The operator decided the lifecycle script raises no title gap, so the check lives only in `/pr:close`.
3. **`/pr:init` checks `squash_merge_commit_title`** and asks before changing it.
4. **Both numbers are labelled** on the lifecycle line and in the close report rows.
5. **The rules are documented** in `ticketing.md` and `config.md`.
6. **The version is bumped**, and the acceptance suite runs.

**One deviation from the first commit, made in response to review.** The code review (APPROVE, `pr-review-2026-09-25.md`) found three important edge cases:
- "Ticket ID" was used in two senses.
- A three-row decision table in step 4b could double the tag, and `startswith` passed the result.
- The `pr` line went quiet when a PR linked a different issue.

The second commit resolves all three and the three minor suggestions. It introduces the *title tag* term, replaces the table with the jq transform, makes verification a fixed point, and keys the note on `hasCloses`. The operator decided two questions the review raised: a leading `[#N]` counts as ticket-shaped even in a prefixed repo, and `[#44]Carry` is normalized to `[#44] Carry`.

**Two operator decisions outside the diff.** This repo's squash title setting was changed to `PR_TITLE`, and this PR was titled `[#44] …` by hand.

## Testing

**Automated:** `plugins/pr/scripts/test-acceptance.sh plugins/pr` passes 42 of 42. The new phase 8 covers three `pr`-line states with a stub `gh`: linked, unlinked, and linked to a different issue. As a control, the same phase against `main`'s script fails both of its original checks, because `main` prints `pr       #57 OPEN`. CI `fixtures` passes on macOS and Ubuntu.

**Transform and verification:**
- The step 4b jq transform ran on 13 titles. Each output is idempotent, and `[WIP]` and `[XYZ-9]` survive.
- The fixed-point check accepts `[#44] Carry` and rejects `[#44] [#44]Carry`, `[#44]Carry` and an untagged title.
- Both snippets were extracted verbatim from `close/SKILL.md` and run read-only against this PR, with the edit swapped for an echo. The transform left the title unchanged, and verification returned the expected draft-state result.

**Live checks:**
- This branch's lifecycle script, run against this PR, prints `pr       PR #45 → no closing ref to #44, OPEN (draft), …`.
- The `/pr:init` step 6 `PATCH` ran live against this repo. Read back: `PR_TITLE`, with `COMMIT_MESSAGES` unchanged and the other merge methods still allowed.

**Manual verification:** after this PR merges with a squash, its subject on `main` should read `[#44] Carry the ticket number into PR titles and squash commits (#45)`.

**Edge cases considered:**
- a branch with no ticket
- a prefixed repo with a leftover `[#N]` tag
- a same-ID tag with bad spacing or a colon
- an already-doubled tag
- operator tags such as `[WIP]`
- a PR that links a different issue
- a failed or empty title read, or an empty message read, before an edit
- a token without admin access at `/pr:init`

## Impact assessment

- **Plugin code:** 9 files, 173 insertions and 29 deletions. The branch's plan folder adds three documents.
- **Dependencies:** none added. `/pr:close` already allowed `jq`, and the transform uses only `sub` with flags.
- **Behavior change for users of the plugin:**
  - PR titles gain a leading `[<title tag>] `.
  - `/pr:close` edits the title of an existing PR that lacks the tag, keeping the rest of its words.
  - The text `pr` line changes shape. No skill or hook parses that line.
  - `/pr:init` can change a GitHub repo setting, only with a yes.
- **Nothing breaks.** A PR opened before this version gets the tag at its next `/pr:close`.

## Deferred work

- `/pr:init` refuses on an already-configured repo unless given `--force`, which reruns detection and rewrites the config. So a repo that adopted the plugin before 0.2.6 gets the new squash-title check only through a full `--force` rerun. This repo was changed by hand instead.
- A repo that declines `PR_TITLE` at `/pr:init` still lands a single-commit PR with its commit subject, and `/pr:close` does not warn about it. It could read the setting and the commit count at step 4b.
