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
refresh status only; newly discovered work goes under `## Deferred

Both items triaged here were completed in-branch rather than deferred out:

- ~~Landing the `qve` removal in `cjus-dev`.~~ **Done** — `f7bc581` on that repo's `main`.
- ~~`cjus-dev`'s `CLAUDE.md:416` names `/qve` and `/qe`.~~ **Done** in the same commit, which also adds plugin skills to that file's description of where skills come from, since it previously named only project and user-level sources.

## Open Questions

- ~~Does `model:` in skill frontmatter do anything for a plugin-installed skill?~~ **Resolved by Phase 2: yes, it is honored.** It was the one-line confirmation, not the follow-up-work branch. Caveat: established by static analysis of the `2.1.274` binary; live confirmation rides along with Phase 1's post-restart verification.
- ~~What lands as a commit on this branch?~~ **Resolved:** the record is this branch folder — `PLAN.md` status plus the `CHANGELOG.md` entry per phase. The folder is still untracked, so the first commit is what puts it under version control.
- ~~Phase 1's live half needs a restart from a repo other than `cjus-skills`.~~ **Resolved 2026-09-17.** Verified from `cjus-dev`. Recorded precisely: *resolution* was observed there (both skills present, `qve` and `explain:qve` coexisting as distinct entries), while *execution* of both skills happened in this worktree. The plugin is user-scoped so the path is identical, but the two halves were observed in different sessions and the record says so rather than implying one session did both.
