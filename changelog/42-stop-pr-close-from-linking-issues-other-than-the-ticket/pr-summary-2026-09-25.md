# Stop /pr:close from linking issues other than the ticket

## Overview

`/pr:close` step 4 checked that the PR closes the ticket, but never that it closes nothing else.
A summary that quoted a closing line with another issue's number would close that issue on merge
while the verify passed. The way step 4 wrote the body could also leave the PR closing nothing:
it replaced the body with the summary, then appended the closing line in a second edit a few
seconds later. On PR #38 GitHub resolved those two edits out of order, and
`closingIssuesReferences` read `[]` for over a minute after the push.

This PR makes three changes. The verify, and step 8b's backstop, now stop when the PR would close
any issue other than the ticket, and they name each one. The rule against closing keywords in the
summary moves into `/pr:summary`, which writes that text. And the create and replace paths write
the summary and the closing line as one body, in a single edit.

## Key changes

- **`plugins/pr/skills/close/SKILL.md`**
  - **Step 4 verify:** the query gains a fourth element, the closing references other than the
    ticket, which must be `[]`. References are keyed on `owner/name` as well as number, so a
    same-numbered issue in another repository is a stray, not the ticket. The kept-description
    pre-check uses the same keying.
  - **Stray remedy:** it depends on where the link comes from. In a body the skill wrote, fix the
    summary and re-run. In an operator's description, report the stray and leave it to them. For
    a Development-sidebar link, have the operator remove it there, and do not re-run. The stop is
    deliberate even for a second issue the operator meant to close.
  - **Single-write body:** create and replace build the marker, the summary and the closing line
    once, chained with `&&`, and send them with one `gh pr create` or one `gh pr edit`. The
    kept-description path keeps its pre-check and single append.
  - **Re-reads:** a stray straight after an edit is re-read like a `false`, up to three reads.
  - **Step 8b** creates a deferred PR with the closing line already in its body, and fails on a
    stray.
  - **Report rows** 4 and 8b say "and no other issue".
- **`plugins/pr/skills/summary/SKILL.md`:** step 3 states the closing-keyword rule. It lists all
  nine keywords in any case, with or without a colon, and both reference shapes. It says the rule
  covers prose as well as quoted syntax, and that examples use a `#N` placeholder. Close step 4
  now points here instead of carrying its own copy.
- **`plugins/pr/README.md`:** the `/pr:close` link bullet mentions the stray stop. The
  `/pr:summary` entry says the document carries no closing keyword with an issue number.
- **`plugins/pr/.claude-plugin/plugin.json`:** 0.2.7 → 0.2.8, so installed copies refresh.

## Code examples

**The verify, `plugins/pr/skills/close/SKILL.md` "Verify on every path":**

```bash
gh pr view "$BRANCH" --repo "$REPO" --json body,closingIssuesReferences,title \
  | jq -c --argjson n "$N" --arg id "$ID" --arg p "$PREFIX" --arg repo "$REPO" '
      ("^(\\[(#[0-9]+" + (if $p == "" then "" else "|" + $p + "-[0-9]+" end) + ")\\][ :]*)+") as $re
      | [.closingIssuesReferences[]
         | ("\(.repository.owner.login)/\(.repository.name)" | ascii_downcase) as $r
         | if $r == ($repo | ascii_downcase) then "#\(.number)" else "\($r)#\(.number)" end] as $refs
      | [(.body | length),
         ($refs | index("#\($n)") != null),
         (.title == "[\($id)] " + (.title | sub($re; ""; "i"))),
         ($refs - ["#\($n)"])]'
```

Before, the second element was `[.closingIssuesReferences[].number] | index($n) != null`, and
nothing looked at the other numbers.

**The body write, step 4.** Before, there were two edits:

```bash
[ -s "$SUMMARY" ] && { printf '%s\n\n' '<!-- pr:close:summary -->'; cat "$SUMMARY"; } \
  | gh pr edit "$BRANCH" --repo "$REPO" --body-file -
BODY=$(gh pr view "$BRANCH" --repo "$REPO" --json body --jq .body) && [ -n "$BODY" ] \
  && gh pr edit "$BRANCH" --repo "$REPO" --body "$BODY ... <closing line>"
```

After, there is one:

```bash
[ -s "$SUMMARY" ] \
  && BODY=$(printf '%s\n\n' '<!-- pr:close:summary -->' && cat "$SUMMARY" && printf '\n\nCloses #%s' "$N") \
  && printf '%s\n' "$BODY" | gh pr edit "$BRANCH" --repo "$REPO" --body-file -
```

## Plan alignment

- **Phase 1, the verify and 8b fail on strays:** done as planned. It also keys on repository,
  because `closingIssuesReferences` carries it and a number-only match let `other/repo#N` pass as
  the ticket.
- **Phase 2, move the rule into `/pr:summary`:** done. The operator chose to move the rule rather
  than mirror it, so close step 4 keeps only a pointer.
- **Phase 3, one body edit on create and replace:** done, and the verify's existing re-reads are
  unchanged.
- **Phase 4, version bump and acceptance suite:** done.
- **After `/pr:pre-test`:** the review's one important finding (sidebar links) and its two
  suggestions (the colon form, a stale `$REPO`) were applied. So was a sentence answering its
  question about an intended second closing issue: the stop is deliberate, as the ticket asks.
- **Title:** this PR was titled with `[#42]` by hand, because the installed 0.2.5 plugin predates
  the prefix.

## Testing

**Automated:**

- `plugins/pr/scripts/test-acceptance.sh plugins/pr`: 42 passed, 0 failed. The suite does not
  cover skills, so this shows only that nothing regressed.
- `plugins/pr/hooks/test-guard-default-branch.sh`: 73 passed. The hook is untouched.

**Verify jq:**

- Run on six sample payloads: no references, the ticket only, the ticket plus a stray, a
  cross-repository `#42`, a mixed-case `owner/name`, and a stray only. Each gave the expected
  tuple.
- Against merged PR #45 it returned `[9599,true,true,[]]`.
- The pre-test review re-ran it on 10 payloads, four of them new: empty `gh` output,
  `closingIssuesReferences: null`, a reference with `repository: null`, and `body: null`. Each of
  the four stops the close, and the two ticket-only cases still pass.

**Single-write body:**

- Run against a fake `gh` on `PATH`.
- A good summary produces one call, with the marker on line 1 and `Closes #N` last. The number is
  a placeholder here.
- A missing summary, a directory and a mode-000 file each exit 1 before `gh` is called. The
  reviewer repeated this under bash and zsh, and added the empty-summary case.

**By hand:** run the verify block against a PR with `N` set to its ticket.

- A PR with no closing line gives `false` and `[]`.
- Link another issue in the PR's Development sidebar, and it appears as a stray.
- Remove the link, and the result returns to `[]`.

## Impact assessment

- **Plugin files:** 4 changed, +50 / −32. That is `close/SKILL.md` +45 / −29, `summary/SKILL.md`
  +2, the README +2 / −2 and `plugin.json` +1 / −1. The branch folder adds `PLAN.md`,
  `CHANGELOG.md`, the pre-test review and this summary.
- **Dependencies:** none.
- **Behavior change:** a close that used to pass while the PR also linked another issue now stops
  and names that issue. That covers a Development-sidebar link or an operator's description that
  closes a second ticket. The operator removes the link, or closes the other issue by hand after
  the merge.
- **Breaking changes:** none. The body shape is unchanged: marker first, summary, then the one
  closing line.

## Deferred work

- A lifecycle-script gap for stray closing references. `pr-lifecycle-state.mjs` could flag an
  open PR whose `closingIssuesReferences` holds an issue other than the ticket. It is out of scope
  here, since the objective is close's verify. #44 made the same call for its title check and left
  it to `/pr:close`.
- The pre-test review also noted a pre-existing claim, in three places, that GitHub ignores a
  closing keyword inside a sentence that negates it. That is unverified, and the new stray check
  stops any link it would cause. The review marked it DROP.

## Assertion audit

Assertions are disabled in this repository (`docs.assertionsFile` is `null`).
