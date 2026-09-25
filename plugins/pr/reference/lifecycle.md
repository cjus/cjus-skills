# The PR lifecycle

The map every skill in this plugin shares. It answers two questions: what comes next, and what should already have happened but did not.

`${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs` is the authority on both. This file explains what it computes and why; the script is what a skill actually runs.

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --text      # human summary
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs"             # JSON
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline   # git + filesystem only, no gh
```

## The order

```
/pr:init → /pr:ticket → /pr:start → [ work ] → /pr:pre-test → /pr:close → (merge) → /pr:cleanup
                                        │
                                        ├── /pr:cp          commit and push
                                        ├── /pr:sync        the default branch moved, does it affect me
                                        ├── /pr:status      quick rundown
                                        ├── /pr:resume      returning after a break
                                        ├── /pr:plan-check  is PLAN.md still true
                                        ├── /pr:abort       abandon this branch deliberately
                                        └── /pr:precompact, /pr:condense, /pr:summary, /pr:commitmsg
```

`/pr:init` runs once per repo, not once per branch.

`/pr:next`, `/pr:reviews` and `/pr:triage` sit outside a branch. The first two pick what to work on next. `/pr:triage` reviews the issue queue rather than a PR: it retires issues the work has overtaken and stamps the rest. None of the three leaves a branch artifact, so none has a position on the spine.

Skills in the work band are unordered among themselves and none is required. Only the steps on the spine have a fixed place, and **`/pr:close` is mandatory before a merge**.

## What each step leaves behind

Detection keys on these, because they are on disk or on GitHub where any skill can read them.

| Step | Durable artifact | Absence means |
|---|---|---|
| `/pr:init` | `.claude/pr-config.json`, the labels | skills run on defaults, and the queue labels may not exist |
| `/pr:ticket` | a GitHub issue, labelled `status:todo` | the branch has no ticket to close |
| `/pr:start` | the branch's plan folder, branch pushed, issue relabelled `status:in-progress` | the branch was made by hand and downstream skills have no plan to read |
| `/pr:cp` | commits pushed to the remote | CI has not seen the work |
| `/pr:pre-test` | a PR exists, so CI has run | nothing has been checked beyond the local machine |
| `/pr:summary` | `pr-summary-<date>.md` in the plan folder | the PR has no body to publish |
| `/pr:close` | `COMMITMSG.md`, the continuity entry, a resolved closing reference on the PR | the merge will not close the issue, and the handoff record is missing |
| `/pr:cleanup` | worktree removed, branch deleted, `status:in-progress` cleared | a merged branch is still occupying a worktree |

## Two rules the detection obeys

**Ask the system, not the text.** Assert on the platform's own resolution rather than on a string that looks like it. See `evidence-discipline.md § Ask the system, not the text`, which carries the `Closes #N` case in full.

**Detect missing outcomes, never missing invocations.** Whether anyone typed `/pr:pre-test` is unobservable. Whether CI has ever run on this branch is a fact. Outcomes are also what actually matters: a PR the operator opened by hand satisfies the outcome exactly as well as one a skill opened, and a check insisting on the skill would flag it as a gap.

**A value that could not be determined never produces a gap.** If `gh` is unreachable or unauthenticated, a missing issue and an unreadable issue look identical from here, so the script reports the value as unresolved and says nothing. Treating an absence as proof is the trap in `evidence-discipline.md`, and a gate that false-positives trains the operator to click through it. Silence is the default; a gap has to earn its line.

## The gaps it reports

| `id` | Fires when | Remedy |
|---|---|---|
| `no-config` | `.claude/pr-config.json` is absent | `/pr:init` |
| `no-ticket` | the branch name does not match the configured ticket pattern | `/pr:ticket` |
| `no-plan` | the branch's plan folder or its `PLAN.md` is missing | `/pr:start` |
| `ticket-not-in-progress` | the issue is still `status:todo` while the branch has commits | relabel it |
| `unpushed` | local commits are ahead of the upstream branch | `/pr:cp` |
| `no-ci` | the branch has commits but no PR, or a PR with no check run reported | `/pr:pre-test` |
| `ci-failing` | a check run came back in the fail bucket | fix the check |
| `ci-no-verdict` | the run was cancelled or wholly skipped, so it decided nothing | push again, or re-run the workflow |
| `pr-body-empty` | a **ready** PR has a zero-length body | `/pr:close` |
| `pr-body-placeholder` | a **ready** PR's body still *starts with* the draft-placeholder marker | `/pr:close` |
| `pr-missing-closes` | a **ready** PR has a real body with no resolved closing reference | `/pr:close` |
| `close-incomplete` | `COMMITMSG.md` exists but a required close artifact does not | `/pr:close` |
| `not-cleaned-up` | the PR is merged and this worktree still exists | `/pr:cleanup` |

**The three body checks skip a draft, deliberately.** A draft carrying the placeholder is the state `/pr:pre-test` exists to create, and it holds for the whole development band, so flagging it would fire a gap on correct behavior every run. `/pr:close` marks a draft ready and replaces the body when it does, so a **ready** PR with a stub body is a real defect while a draft one is the system working.

The script also reports `steps`: one row per lifecycle step with a tri-state `done` and the evidence behind it. A null means the inputs needed to decide were unavailable, never that the step is outstanding.

## How a skill uses this

Every skill with a position on the map carries a **Lifecycle position** section that runs the script and folds the result into its own report. The contract:

- Report each entry in `gaps` with its remedy, most consequential first.
- An empty `gaps` list is **one clause**, never a section and never a table. Being mid-cycle is the normal state, and a check that narrates it at length trains the reader to skip the one time it matters.
- Name `next` as the recommended next command, unless the skill's own steps reached a different one, in which case say which and why.
- **A skill never runs `next` itself.** It is a recommendation. `/pr:close` in particular is the operator's to invoke, **unless the operator has granted standing permission to run it**, in the project's instructions or in memory. Even then it runs as its own step, once the current skill's report is done, never from inside another skill. A standing grant covers only the commands it names. It never covers a merge, or anything else that writes to the default branch, because those stay the operator's every time.
