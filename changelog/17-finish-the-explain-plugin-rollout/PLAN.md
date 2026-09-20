# Finish the explain plugin rollout

Start date: 2026-09-16 19:50:38 MDT

Ticket: https://github.com/cjus/cjus-skills/issues/17

## Overview

Phases 7-9 of #12 could not run before that branch merged: the plugin has to be installed
the way a user installs it, and the `cjus-skills` marketplace resolves from GitHub `main`.
The repo-side port is complete; this branch is the rollout that finishes it — install and
verify the plugin from a consuming repo, then remove the two originals so no skill has a
second live copy.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

Phases 7-9 of #12 could not run before that branch merged: the plugin has to be installed the way a user installs it, and the `cjus-skills` marketplace resolves from GitHub `main`. The repo-side port is complete; this is the rollout that finishes it.

Until the last two items land, each skill has two live copies, which is the drift the port existed to remove.

- [ ] Verify `/explain:qe` and `/explain:qve` both resolve and run, from a repo other than `cjus-skills`
      `claude plugin marketplace update cjus-skills && claude plugin install explain@cjus-skills`, then restart
- [ ] Confirm `model: opus` in `qve`'s frontmatter is honored in a plugin context
      No other skill in this repo uses it, and the review found none among 138 cached plugin skills — so it may be silently ignored, leaving `qve` on a different model than it was written for
- [ ] Remove `~/.claude/skills/qe/`
      A user-level `qe` shadowing the plugin copy is a confusing failure to diagnose
- [ ] Remove the source repo's `.claude/skills/qve/` and enable the explain plugin in that repo, so `/qve` keeps working there

Context: PR #16, and `changelog/12-port-qe-and-qve-into-a-standalone-explain-plugin/PLAN.md` (D-6 records why these were deferred).

## Plan

- [x] Phase 1 (verified 2026-09-17): Install the plugin as a user does — `claude plugin marketplace update cjus-skills`, then `claude plugin install explain@cjus-skills`, then restart — and verify `/explain:qe` and `/explain:qve` both resolve and run from a repo other than `cjus-skills`. (Observed in two halves: *resolution* from the source repo, *execution* from this worktree. Same user-scoped code path, but two sessions — see Open Questions.) Also confirm `/explain:qe` reaches the plugin rather than the user-level `~/.claude/skills/qe/`, **and `/explain:qve` rather than the source repo's project-level `.claude/skills/qve/`**, recording each pair as distinct entries — #12's review asked for the `qe` half, and the `qve` half is the same situation, since Phase 4 removes that copy exactly as Phase 3 removes the other. Both destroy the evidence, and the restart session is the one cheap chance to collect it. (#12 Phase 7)
- [x] Phase 2: Confirm whether `model: opus` in `qve`'s frontmatter is honored in a plugin context. **Answered: it is honored.** The plugin skill loader parses `model`, the key is in both recognized-key lists, and a skill-specific runtime guard falls back to the session model only when the value is outside the `availableModels` allowlist. `opus` resolves as a family alias. `qve` keeps the line unchanged; no follow-up work. See CHANGELOG.
- [x] Phase 3: Remove `~/.claude/skills/qe/`, retiring the user-level copy that would shadow the plugin's. (#12 Phase 8) **Done.** Not under version control, so a copy was taken before removal; the content is also recoverable from `origin/main`'s plugin copy, which differs by exactly four namespacing hunks.
- [x] Phase 4: Remove the source repo's `.claude/skills/qve/` and enable the `explain` plugin in that repo. **Landed** as `f7bc581` on the source repo `main`, via the quick-commit path its CLAUDE.md sanctions, with the operator approving the main-branch gate. The same commit updates that repo's skills documentation. The enable half is a **verified no-op**: `explain@cjus-skills` is enabled at user scope, the source repo declares no project-level `enabledPlugins`, and `explain:qve` was observed loading there. (#12 Phase 9) **Two corrections to this step's premise, found in review.** The enable half is already satisfied: `explain@cjus-skills` is enabled at *user* scope and the source repo declares no project-level `enabledPlugins`, so there is likely nothing to do there — verify rather than assume. And the step's stated goal, "so `/qve` keeps working there", is not achievable as worded: a plugin skill resolves as `/explain:qve`, so the bare `/qve` goes away by design. The real goal is that the capability keeps working under its namespaced name.

## Deferred

Both items triaged here were completed in-branch rather than deferred out:

- ~~Landing the `qve` removal in the source repo.~~ **Done** — `f7bc581` on that repo's `main`.
- ~~the source repo's `CLAUDE.md:416` names `/qve` and `/qe`.~~ **Done** in the same commit, which also adds plugin skills to that file's account of where skills come from, since it previously named only project and user-level sources.

Two observations are recorded but **not** actionable here — both predate this branch, and it neither worsens them nor is blocked by them:

- `explain@0.1.0`'s `page-template.html` footer still prints the bare `/qve`, which the port missed.
- the source repo documents `CJUS_ALLOW_MAIN=1` for its `main` gate, but its push hook requires `PR_ALLOW_MAIN=1`.

## Open Questions

- ~~Does `model:` in skill frontmatter do anything for a plugin-installed skill?~~ **Resolved by Phase 2: yes, it is honored.** It was the one-line confirmation, not the follow-up-work branch. Caveat: established by static analysis of the `2.1.274` binary; live confirmation rides along with Phase 1's post-restart verification.
- ~~What lands as a commit on this branch?~~ **Resolved:** the record is this branch folder — `PLAN.md` status plus the `CHANGELOG.md` entry per phase. The folder is still untracked, so the first commit is what puts it under version control.
- ~~Phase 1's live half needs a restart from a repo other than `cjus-skills`.~~ **Resolved 2026-09-17.** Verified from the source repo. Recorded precisely: *resolution* was observed there (both skills present, `qve` and `explain:qve` coexisting as distinct entries), while *execution* of both skills happened in this worktree. The plugin is user-scoped so the path is identical, but the two halves were observed in different sessions and the record says so rather than implying one session did both.
