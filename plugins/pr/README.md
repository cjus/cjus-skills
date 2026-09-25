# pr

Twenty-two Claude Code skills that carry a branch from a GitHub issue to a merged PR, and keep the issue queue honest while they do it.

The workflow is issue-backed all the way down: the issue number **is** the ticket number, the branch name carries it, and the branch's folder on disk is named after it. That single identifier is what lets a skill pick up a branch it has never seen and work out where things stand — which is the point, because the agent that finishes a branch is rarely the one that started it.

**No skill here trusts conversation memory.** Every one of them re-derives state from git, GitHub and the branch's own files, and reports what it found rather than what it was told.

---

## Contents

- [Install](#install)
- [Quick start](#quick-start)
- [The shape of a branch](#the-shape-of-a-branch)
- [Configuration](#configuration)
- [The lifecycle spine](#the-lifecycle-spine) — `init` `ticket` `start` `pre-test` `close` `cleanup` `abort`
- [Working on a branch](#working-on-a-branch) — `cp` `status` `resume` `plan-check` `sync` `summary` `commitmsg` `condense` `precompact` `sanity` `continuity-add` `continuity-prune`
- [The queue](#the-queue) — `next` `reviews` `triage`
- [The plan folder](#the-plan-folder)
- [The three hooks](#the-three-hooks)
- [How detection works](#how-detection-works)
- [What ships here](#what-ships-here)
- [License](#license)

---

## Install

```bash
claude plugin marketplace add cjus/cjus-skills
claude plugin install pr@cjus-skills
```

Restart Claude Code, then run `/pr:init` once in each repo that should use the workflow.

**Plugin skills are namespaced by their plugin**, so every command is `/pr:<name>` — `/pr:close`, `/pr:next`. A bare `/close` does not resolve. This page writes the prefix out in every command you would type, and in prose too, dropping it only where several skills are listed together by bare name.

What it needs: `git`, the `gh` CLI authenticated against your repo, and Node for the lifecycle script. `jq` is used where it is available and routed around where it is not. Nothing is installed when the plugin is installed — a Claude Code manifest has no dependency-resolution step — so every binary here is one you already have.

**The three hooks install with the plugin**, declared in `hooks/hooks.json`. There is no `.claude/settings.json` fragment to paste. They stay inert until a repo has a `.claude/pr-config.json`; see [The three hooks](#the-three-hooks).

---

## Quick start

```
/pr:init                                    once per repo
/pr:next                                    what should I work on?
/pr:ticket add retry logic to the uploader  files the issue, reports the branch name
/pr:start feature/123-add-retry-logic       branch, worktree, plan folder
                                            ... do the work ...
/pr:cp                                      commit and push
/pr:pre-test                                draft PR, CI, code review
/pr:close                                   the gates, then the merge-ready PR
                                            ... merge on GitHub ...
/pr:cleanup 123                             worktree gone, branch deleted
```

Only the spine has a fixed order. Everything in [Working on a branch](#working-on-a-branch) is optional and unordered — reach for it when you want it.

**`/pr:close` is mandatory before a merge.** It is the step that links the issue with a reference GitHub actually resolved, writes the handoff record, and leaves the PR with a real body.

---

## The shape of a branch

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

`/pr:next`, `/pr:reviews` and `/pr:triage` sit outside a branch entirely and leave no branch artifact, so they have no position on the spine.

Each step leaves something durable behind, and that artifact — not a memory of having run the command — is what the next skill detects:

| Step | Leaves behind |
|---|---|
| `/pr:init` | `.claude/pr-config.json`, the queue labels |
| `/pr:ticket` | a GitHub issue, labelled `status:todo` |
| `/pr:start` | the plan folder, the branch pushed, the issue at `status:in-progress` |
| `/pr:cp` | commits on the remote |
| `/pr:pre-test` | a PR titled `[#123] …`, so CI has run |
| `/pr:summary` | `pr-summary-<date>.md` in the plan folder |
| `/pr:close` | `COMMITMSG.md`, the continuity entry, a resolved closing reference, a verified `[#123]` title |
| `/pr:cleanup` | worktree removed, branch deleted, `status:in-progress` cleared |

`reference/lifecycle.md` carries the full map, and `scripts/pr-lifecycle-state.mjs` is what computes it:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --text      # human summary
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs"             # JSON
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline   # git + filesystem only
```

---

## Configuration

`/pr:init` writes `.claude/pr-config.json` at the repo root. **A missing config is not an error** — every skill falls back to the defaults below and says so once. What the file buys you is the choices that differ from them, the queue labels, and the hooks.

| Key | Default | What it controls |
|---|---|---|
| `repo` | derived from `origin` | The `owner/name` every `gh` call targets. Set it when the remote is a fork and issues live upstream. |
| `ticketPrefix` | `""` | Empty means the ticket ID **is** the issue number. Set `abc` and it becomes `ABC-123`. |
| `branchPrefix` | `"feature/"` | Prepended to every branch name. `""` disables it. |
| `worktrees.enabled` | `true` | Whether `/pr:start` creates a linked worktree or switches the current checkout. |
| `worktrees.root` | `"../{repo}-Worktrees"` | Where worktrees go. `{repo}` expands to the repo's directory name. |
| `checks.*` | `null` | Shell commands for `lint`, `typecheck`, `test`, `build`. |
| `docs.changelogRoot` | `"changelog"` | The directory holding one folder per branch. |
| `docs.continuityRoot` | `"continuity"` | The recent-work log. `null` disables continuity entries. |
| `docs.assertionsFile` | `"ASSERTIONS.md"` | The invariants file audited at close. `null` disables the audit. |
| `migrations.dir` | `null` | Hand-applied migrations, for the drift gate at close. |
| `closeGate.requiredArtifacts` | `["pr-summary", "continuity"]` | What must exist and be tracked before the close gate releases. |
| `closeGate.enabled` | `true` | Whether the `Stop` hook blocks a close that has not landed. |
| `mainGuard.enabled` | `true` | Whether default-branch commits and pushes need explicit approval. |

**A `null` check is absent, not failing.** Skills skip it in silence and never report it as a gap. A repo whose test command exists but has no tests is the repo's business; configure it or leave it `null`, but do not configure it and then explain the exit code.

The config is resolved from `git rev-parse --git-common-dir`, never from the working directory, so **one config at the main checkout serves every worktree**. `reference/config.md` documents the full schema, the derivation rules, and the slug rule every skill shares.

---

## The lifecycle spine

Seven skills with a fixed place in the order — though `abort` is the exit rather than a step, which is why the diagram above draws it to the side.

### `/pr:init`

```
/pr:init
/pr:init --force
```

Runs **once per repo**, not once per branch. Detects the GitHub repo, the package manager and the check commands, asks about the choices it cannot detect, writes `.claude/pr-config.json`, and creates eleven labels: the two `status:*` and three `priority:*` labels the queue runs on, plus the six type labels `/pr:ticket` picks from — `bug`, `feature`, `refactor`, `docs`, `infra` and `research`.

It also reads the repo's squash-merge title setting and, only with a yes, changes it to `PR_TITLE`, so a single-commit PR cannot land with its commit subject in place of the `[#123]` title.

It is also what arms the hooks. Until this file exists, all three are inert.

### `/pr:ticket`

```
/pr:ticket the uploader retries forever on a 413
```

Turns a freeform description into a GitHub issue labelled `status:todo` and `priority:high`, then reports the branch name that issue yields — so the next command is a copy-paste away. `/pr:close` also calls it when triaging deferred work into a follow-up.

### `/pr:start`

```
/pr:start feature/123-add-retry-logic
```

Creates the branch — in a linked worktree when `worktrees.enabled` is true — carries over what a fresh checkout does not bring (untracked local config and the like), installs dependencies, initializes the plan folder, reads the recent continuity entries, then enriches `PLAN.md` from the issue body and moves the issue to `status:in-progress`.

**The objective it writes into `PLAN.md` is frozen for the life of the branch.** Later work refreshes status only; newly discovered work goes under `## Deferred` rather than quietly becoming scope. `reference/scope-contract.md` has the reasoning: a PR is done when it delivers the objective established here without regressing anything, not when the code it touched becomes defect-free.

### `/pr:pre-test`

```
/pr:pre-test
```

Decides whether the branch is ready for hands-on testing. Refreshes `PLAN.md`, opens a **draft** PR so CI starts running, runs the configured checks, and dispatches the `code-reviewer` agent over the whole PR diff.

The draft matters. A draft PR carrying a placeholder body is the state this skill exists to create, so the body checks skip drafts entirely — flagging one would fire a gap on correct behavior every run.

The draft is titled `[#123] <plan title>`. A PR's number never matches its ticket's, since GitHub numbers both from one sequence, and a squash merge appends only the PR number. The prefix is what puts the ticket into the commit that lands, as `[#123] <title> (#141)`. `reference/ticketing.md` lists which number each surface shows.

### `/pr:close`

```
/pr:close
```

The mandatory gate before a merge, and the largest skill here. In order: `/pr:summary`, a merge-conflict check placed before the expensive work, a migration-drift check, the configured checks plus CI, a review gate, `/pr:condense`, the issue link and the title prefix, `/pr:commitmsg`, the continuity entry and assertion audit, deferred-work triage, then commit and push until the tree is clean.

Three of those deserve calling out:

- **The issue link resolves by exact number and is then verified.** A `Closes #123` that reads correctly but did not register is the exact failure this workflow exists to prevent, so the skill asks GitHub what it actually resolved rather than trusting the string it just wrote. It halts on failure, on every path.
- **The title carries the ticket ID, and is verified alongside the link.** An existing PR missing the `[#123]` prefix gets it, keeping the rest of its title, and a wrong ticket ID in that position is replaced.
- **Deferred-work triage happens here, once.** `PLAN.md § Deferred` is a triage inbox, not a backlog. Most entries exit as DROP; the rest become follow-up issues through `/pr:ticket`.

It arms the close sentinel before committing, which is what lets the `Stop` hook refuse to end the turn while the close is half-landed.

### `/pr:cleanup`

```
/pr:cleanup 123
```

Tears down a merged branch's workspace by ticket number. Verifies the close ran and the PR **actually merged**, confirms the issue closed, removes the worktree, deletes the branch, and pulls the merge.

Destructive, so it is one of three skills marked `disable-model-invocation` — it runs only when you type it.

### `/pr:abort`

```
/pr:abort 123 the upstream API shipped this natively
```

The other ending. Closes the issue as *not planned*, closes any open PR, removes the worktree, and deletes the branch locally and on the remote. Permanent, and likewise explicit-invocation only.

---

## Working on a branch

Twelve skills with no fixed order and no obligation. None of them is a step you owe the workflow; each is there for a moment you recognize.

### `/pr:cp`

```
/pr:cp
/pr:cp tighten the retry backoff
```

Stage everything, commit with a concise message, push. The one you will type most.

### `/pr:status`

```
/pr:status
```

A 20-second read: what this branch does, what it now prevents, and where it sits in the lifecycle. **It writes nothing.**

### `/pr:resume`

```
/pr:resume
```

For coming back after a break. Deliberately **not** a recap of the conversation — it rebuilds the picture from git, GitHub and the branch's documents, which is frequently not where the last message said things stood. Leads with the open questions and blockers, and says explicitly which ones only you can answer.

### `/pr:plan-check`

```
/pr:plan-check
```

Asks whether `PLAN.md` is still true, refreshes its status checkboxes, and states the concrete next steps.

### `/pr:sync`

```
/pr:sync
/pr:sync 123
```

The default branch moved — does it affect me? Assesses what the new commits mean for **every** live worktree, then merges them into the current one. **Stays silent when nothing intersects**, which is most of the time and is the reason it is worth running.

### `/pr:summary`

```
/pr:summary
```

Writes `pr-summary-<date>.md` into the plan folder: code examples, plan alignment, testing notes, impact. This document becomes the PR body at close.

### `/pr:commitmsg`

```
/pr:commitmsg
```

Writes `COMMITMSG.md` covering **only the uncommitted changes** — not the branch, not the diff against main.

### `/pr:condense`

```
/pr:condense
```

Refreshes `PLAN.md` status and shrinks a `CHANGELOG.md` that has grown unwieldy, preserving timestamps. `/pr:close` runs it as a step.

### `/pr:precompact`

```
/pr:precompact
```

Run it right before a context compaction. Brings `PLAN.md` fully current and adds explicit resume steps **written for an agent with none of the current context** — which is the audience that will read them.

### `/pr:sanity`

```
/pr:sanity
```

Re-audits the factual claims in your immediately previous response against `reference/evidence-discipline.md`, classifying each as verified, inferred or unsupported, and issuing corrections for anything that does not hold.

**It is not a correction quota.** A clean re-audit reports nothing, in one clause — manufacturing a hedge to prove the check ran is how you train a reader to skip the corrections that matter. It re-runs a tool call only to settle a claim it actually flagged, never speculatively.

### `/pr:continuity-add`

```
/pr:continuity-add
```

Writes one continuity entry as a new file under the repo-root continuity folder, sourced from the plan folder, the commits and the PR. **Additive only** — it touches no existing entry. `/pr:close` invokes it.

### `/pr:continuity-prune`

```
/pr:continuity-prune 2026-01-01
```

Deletes continuity entry files older than a cutoff, after showing the list and asking. The third destructive skill, and likewise explicit-invocation only.

---

## The queue

Three skills that sit outside any branch.

### `/pr:next`

```
/pr:next
```

What should I work on? Cross-references recent PR activity and local worktrees against the open `status:todo` queue, high priority first, then medium. Each candidate comes with its derived branch name, ready to hand to `/pr:start`.

### `/pr:reviews`

```
/pr:reviews
```

What did we just do, and what is next? Summarizes recently completed work from the continuity entries, the assertions file and merged PRs, then cross-references the open queue.

### `/pr:triage`

```
/pr:triage
/pr:triage --apply
```

Reviews every open issue against the state of the default branch: closes the ones the work has already retired, stamps the ones that still hold with a last-reviewed record, and consolidates issues that have converged on one piece of work.

**Reports only by default.** It writes nothing until you pass `--apply`.

---

## The plan folder

Every branch gets one directory at the repo root, named for the branch minus its prefix:

```
changelog/123-add-retry-logic/
  PLAN.md                    created by /pr:start, scope-frozen
  CHANGELOG.md               appended to as work proceeds
  pr-summary-2026-09-14.md   written by /pr:summary
  COMMITMSG.md               written by /pr:close
```

**Merged branches' folders stay in the repo as history.** Nothing deletes one without explicit direction.

The distinction that trips people up: those four files are **per branch**. The continuity folder and the assertions file are **repo-global** and shared across every branch, so they live at the repo root and are never duplicated into a branch folder.

| Document | Audience | Question it answers |
|---|---|---|
| `PLAN.md` | the agent on this branch | what am I doing, and what is left? |
| `CHANGELOG.md` | the same | what has this branch changed so far? |
| `pr-summary-<date>.md` | the PR reviewer | what does this PR do, and why? |
| `<continuityRoot>/<date>-<slug>.md` | a returning agent | what just happened in this project? |
| `<assertionsFile>` | an agent validating a change | what invariants must hold? |

**Nothing in the continuity folder is shared between entries** — no index, no combined file, no stored counts. Ordering comes free from the ISO date prefix. That is load-bearing rather than tidiness: the layout it replaced was one shared log prepended to at a fixed offset, and concurrent closes collided in it, desyncing the entry count, duplicating IDs, and leaving the merge ref uncomputable — which suppressed CI runs outright, because no run is created for a PR whose merge commit cannot be produced. Adding any shared file back reintroduces all three. `reference/handoff-docs.md` carries the detail.

---

## The three hooks

Declared in `hooks/hooks.json` and installed with the plugin. **A hook is inert in a repo with no `.claude/pr-config.json`** — a user-scope plugin's hooks fire in every repo you open, and without that rule, installing this plugin would gate default-branch commits everywhere on the machine. The config file is the marker that a repo opted in.

The asymmetry with the skills is deliberate: a skill is **invoked**, so it may sensibly run on defaults when the config is absent. A hook is **ambient**, so it may not.

| Hook | Event | What it does |
|---|---|---|
| `on-session-start.sh` | `SessionStart` | Loads the branch's summaries into context — or `PLAN.md` and `CHANGELOG.md` when none exists yet, since a summary supersedes the plan as the branch's most condensed account. A session after a compaction does not resume blind. Silent on the default branch. |
| `guard-default-branch.sh` | `PreToolUse` (`Bash`) | Requires explicit approval for a commit or push on the default branch, including refspecs that target it from elsewhere. |
| `verify-close-landed.sh` | `Stop` | Refuses to end a turn while a `/pr:close` is in flight and its artifacts have not landed. |

Turn individual ones off with `mainGuard.enabled` and `closeGate.enabled`. To disable all three, disable the plugin.

Two things the guard **cannot** do, both worth knowing before relying on it:

- **It evaluates before the command runs**, so a compound `git checkout -b x && git push` is judged against the branch as it stands beforehand — still the default branch. Run them as separate tool calls.
- **It sees Bash tool calls only.** A script that commits internally passes unguarded. It covers the agent typing git; it is not a repo-wide write barrier.

The close gate is scoped by a sentinel at `$(git rev-parse --git-dir)/pr-close-active` — per-worktree, and outside the work tree so it can never dirty the status it guards. `/pr:close` arms it; the hook disarms itself once the checks pass. Blocking is bounded to once per turn, so it can never wedge a session.

`hooks/README.md` documents all three in full, including the bypasses the guard closes and why two of them read as correct.

---

## How detection works

Three rules shared by every skill, and the reason the reports are worth reading.

**Ask the system, not the text.** Assert on the platform's own resolution, never on a string that looks right. A PR body containing `Closes #123` is not evidence that GitHub linked the issue; the resolved reference is.

**Detect missing outcomes, never missing invocations.** Whether anyone typed `/pr:pre-test` is unobservable. Whether CI has ever run on this branch is a fact. Outcomes are also what actually matters — a PR you opened by hand satisfies the outcome exactly as well as one a skill opened, and a check insisting on the skill would flag it as a gap.

**A value that could not be determined never produces a gap.** If `gh` is unreachable, a missing issue and an unreadable issue look identical from here, so the state is reported as unresolved and nothing is said. Treating an absence as proof is the trap; a gate that false-positives trains you to click through it. Silence is the default, and a gap has to earn its line.

The gaps that can fire, each with a remedy: `no-config`, `no-ticket`, `no-plan`, `ticket-not-in-progress`, `unpushed`, `no-ci`, `ci-failing`, `ci-no-verdict`, `pr-body-empty`, `pr-body-placeholder`, `pr-missing-closes`, `close-incomplete`, `not-cleaned-up`. `reference/lifecycle.md` has the table.

---

## What ships here

```
plugins/pr/
  .claude-plugin/plugin.json
  README.md
  agents/code-reviewer.md              the review agent /pr:pre-test and /pr:close dispatch
  hooks/hooks.json                     all three hooks, installed with the plugin
  hooks/on-session-start.sh            SessionStart: rehydrate branch context
  hooks/guard-default-branch.sh        PreToolUse: gate default-branch writes
  hooks/verify-close-landed.sh         Stop: refuse a half-landed close
  hooks/test-guard-default-branch.sh   the guard's probe suite: refspecs, modes, worktrees
  hooks/README.md                      all three in full, and the bypasses closed
  reference/assertion-audit.md         when the audit runs, and what it reports
  reference/config.md                  the full schema, derivations, the slug rule
  reference/evidence-discipline.md     classifying a claim before asserting it
  reference/git-conventions.md         branch, commit and PR shapes
  reference/handoff-docs.md            the six document kinds and their audiences
  reference/lifecycle.md               the map every skill shares
  reference/pr-config.schema.json      JSON Schema for .claude/pr-config.json
  reference/scope-contract.md          what "done" means, and what Deferred is for
  reference/ticketing.md               issues as tickets, labels, the queue
  scripts/pr-lifecycle-state.mjs       the lifecycle authority, --text or bare for JSON
  scripts/test-acceptance.sh           the whole substrate through a throwaway repo
  skills/                              22 skills, one SKILL.md each
    abort/  cleanup/  close/  commitmsg/  condense/  continuity-add/
    continuity-prune/  cp/  init/  next/  plan-check/  pre-test/
    precompact/  resume/  reviews/  sanity/  start/  status/
    summary/  sync/  ticket/  triage/
```

The `reference/` documents are what keep these skills repo-agnostic. The ticketing, evidence, scope and lifecycle rules every skill cites are owned by the plugin, so nothing here depends on the host repo having a `CLAUDE.md` of its own.

**Reading the guard is not evidence.** Nearly every defence in `guard-default-branch.sh` exists because the obvious spelling was measured to fail *open*, and two of the bypasses it closes read as correct. Run the probe suite after any edit to it, and `scripts/test-acceptance.sh` — pointed at an **installed** copy rather than a source tree, since that is what catches packaging defects — after any change to the substrate.

---

## License

MIT. See the [repository root](https://github.com/cjus/cjus-skills).
