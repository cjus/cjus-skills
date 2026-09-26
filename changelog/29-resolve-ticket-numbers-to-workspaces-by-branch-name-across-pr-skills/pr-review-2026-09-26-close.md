## PR review: [#29] Resolve ticket numbers to workspaces by branch name across pr skills

Ticket: `29-resolve-ticket-numbers-to-workspaces-by-branch-name-across-pr-skills` · PR #50 (draft) · base `main` · 2 commits (`41fb996`, `d6a92a4`) · close-gate review

### Summary

The branch moves `/pr:abort` and `/pr:sync` from a worktree-path substring to the anchored branch-name rule, states that rule once in `config.md § Resolving a ticket number to its branch`, and makes `/pr:cleanup` with worktrees off act on the branch step 0 resolved instead of the session's checkout.

This is a re-review at the close gate. The pre-test review (`pr-review-2026-09-26.md`, APPROVE) covered `41fb996` in full. This pass reviews the delta in `d6a92a4`, confirms the four suggestions it applied, checks the uncommitted `pr-summary-2026-09-26.md` that becomes the PR body, and re-reads the full diff for anything the first pass missed. The two `## Deferred` items in `PLAN.md` and the three items the pre-test review deferred are settled and are not re-raised.

### What is working well

- **The delta is tight.** Four changed lines across two skills, each mapping one-to-one onto a pre-test suggestion, plus a CHANGELOG entry recording the decision. Nothing unrelated rode along.
- **The stderr drop is scoped to the half that needs it.** `2>/dev/null` sits on the `ls-files` half only. I confirmed that a bad ref in the `ls-tree` half still prints `fatal: Not a valid object name …`, so quieting the expected warning did not also hide a real lookup failure.
- **The pipeline's exit is mapped onto the table.** Naming "no output, with `grep` exiting 1" as the "No artifacts at all" row closes the gap between what the command prints and the table the model has to read it against.
- **The summary is careful about provenance.** It separates automated checks, checks run by hand, and checks left to the operator, and it gives the one real behaviour change (tracker-key branches with no `ticketPrefix`) its own paragraph with the fix.
- **Scope discipline across the branch.** Both gaps named in the objective are closed. Only the three skills that take a ticket number were touched: `argument-hint` confirms no fourth skill takes one. Work found along the way went to `## Deferred`, not into the diff.

### The four pre-test suggestions

| # | Suggestion | Landed | Where | Notes |
|---|---|---|---|---|
| 1 | Abort says how to set `MAIN_CHECKOUT` | Yes | `abort/SKILL.md:L61` | Placed before the row cases that compare against it. Wording matches cleanup L45 and `config.md`. |
| 2 | Quiet the `ls-files` warning and name the no-output case | Yes | `cleanup/SKILL.md:L82`, `L86` | Verified in a scratch repo, below. |
| 3 | Step 2 says "skip" | Yes, as worded | `cleanup/SKILL.md:L106` | The paragraph now opens with "Skip when `WORKTREE_PATH` is empty". It still sits below the command and below "report it and STOP", whereas steps 5 and 7 put their skip line above the code block. Moving it up one block is optional: a model that runs the command first can only stop falsely, which is the safe direction. Not a finding. |
| 4 | Abort's remote fallback carries rule 1's cardinality | Yes | `abort/SKILL.md:L80` | "One remote row resolves; several list and stop, as in rule 1." |

### Verification I ran

- `plugins/pr/scripts/test-acceptance.sh plugins/pr`: **passed 42, failed 0**.
- `scripts/check-citations.py`: 190 resolve.
- CI on PR #50 at head `d6a92a4`: `fixtures (macos-latest)` and `fixtures (ubuntu-latest)` both SUCCESS.
- `git diff --numstat main...HEAD`: 8 files, +421/−23; the plugin's 5 files, +90/−23. Both match the summary.
- **Cleanup step 1's no-workspace pipeline after the delta**, in a throwaway repo with the branch checked out nowhere and its folder absent on `main`:
  - A committed close lists `COMMITMSG.md` and `pr-summary-*.md`, exit 0, with no warning on stderr.
  - The same `ls-files` without the redirect prints `warning: could not open directory …`. With the changelog root itself absent it prints nothing, so the summary's "when the changelog root exists" qualifier is accurate.
  - No artifacts gives no output and exit 1.
  - A nonexistent `BRANCH` still surfaces `fatal:` from the `ls-tree` half.
- A `git grep` under `plugins/` for the old rule's wording finds none left.
- **Summary hygiene.** No closing keyword followed by an issue reference, checked per line and across line breaks with a regex I first confirmed catches the bare, colon and cross-repo forms. No `org/repo#N` references, no `github.com` URLs, no attribution.
- **Banned-term audit: clean**, over the diff, the two commit messages, the summary and this file.

### PR summary accuracy

I checked every factual claim against the git log and the diff: the four phases, the four Open Question decisions, the four deviations, the applied suggestions, the test and citation numbers, the CI result, the file counts, the manual-verification steps and the deferred list. All of them describe work the two commits actually contain, with one overstatement, 🟢 1 below.

### Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

🟢 **1. The summary says worktrees-on cleanup is unchanged, but two of the changes apply whatever `worktrees.enabled` is**

📍 Location: `changelog/29-resolve-ticket-numbers-to-workspaces-by-branch-name-across-pr-skills/pr-summary-2026-09-26.md:L178`

**What I see:**

```markdown
- **No change** with worktrees on to cleanup's behaviour, or to sync without an argument.
```

The sync half is right. The cleanup half overstates it, because two edits are not conditioned on `worktrees.enabled`:

- Step 8 now pulls only when the main checkout is on the default branch (`cleanup/SKILL.md:L246-L253`). With worktrees on, a main checkout left on some other branch now reports `not pulled (main checkout is on <branch>)`. On `main`, cleanup pulled into it.
- Step 0's "No rows" bullet now runs the no-match check (`cleanup/SKILL.md:L53`). On `main`, worktrees-on cleanup reported "no workspace found for ticket $1".

**The risk:**

Both changes are improvements and both fail safe, so nothing here is wrong in the code. But the PR body is what a later reader uses to decide whether this PR could explain a behaviour they are chasing. Anyone asking "why did cleanup stop pulling?" would read "no change with worktrees on" and rule this PR out.

**Suggested fix:**

```markdown
- **With worktrees on**, cleanup resolves and gates as before. Two changes still reach it: a
  ticket with no matching branch runs the no-match check, and step 8 pulls only when the main
  checkout is on the default branch. Sync without an argument is unchanged.
```

**Learning note:**

Readers use the "no change" lines in an impact section to rule a PR out while hunting a behaviour change. Claim "no change" only for paths that no edited line reaches. Name small changes too, even strict improvements, because a strict improvement is still a change someone may need to find.

#### ⏭️ Deferred to follow-up

These do not affect the verdict. Both predate this PR, and the PR does not make either worse.

- **Abort's remote-only target**, `plugins/pr/skills/abort/SKILL.md:L80`. When only `origin` carries the branch, step 3's `origin/<default>..$BRANCH` and `ls-tree "$BRANCH"` and step 8's local `branch -D` all name a ref that does not exist locally. The inventory errors, and step 8 reports a failed local delete. `main` behaved the same way; this PR only added cardinality handling to that paragraph. theme: abort remote-only target. **DROP:** the outcome is still what the operator confirmed, and step 8 reports each failure.
- **Sync without `$1` leaves the main checkout out of the action half**, `plugins/pr/skills/sync/SKILL.md:L61`. With worktrees off, the main checkout is where the feature branch lives. This PR does not change it, and it is arguable whether "action half" means step 7's merge. theme: worktrees-off sync. **DROP.**

### Questions

None. The delta's intent is recorded in the CHANGELOG entry for the review suggestions.

### Verdict

VERDICT: APPROVE

The branch delivers all four phases of the objective without regressing `main`, and all four pre-test suggestions landed correctly. 🟢 1 is a one-line correction to the summary, best made before `/pr:close` posts it as the PR body. Nothing blocks.
