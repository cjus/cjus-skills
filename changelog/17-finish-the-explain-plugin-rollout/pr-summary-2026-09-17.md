# Finish the explain plugin rollout

## Overview

PR #16 ported `qe` and `qve` into a standalone `explain` plugin, but could not finish the
job: phases 7-9 of #12 required the plugin to be installed the way a user installs it, and
the `cjus-skills` marketplace resolves from GitHub `main`. Until that branch merged, the
plugin could not be installed at all. This branch is the rollout that finishes it — install
the plugin from the marketplace, verify both skills resolve and run from a consuming repo,
then remove the two originals so no skill has a second live copy.

Every phase here is a **machine-state change**, not a repo edit: installing a plugin,
observing what a restarted session loads, deleting two directories. What lands in this repo
is the *record* of those changes, which is why the diff is two markdown documents. The
work itself landed on the operator's machine and, for phase 4, in the `cjus-dev` repo as
commit `f7bc581`.

## Key changes

| Path | What changed |
|---|---|
| `changelog/17-finish-the-explain-plugin-rollout/PLAN.md` | Phase status through the rollout, two open questions resolved, the deferred items closed out |
| `changelog/17-finish-the-explain-plugin-rollout/CHANGELOG.md` | The findings: install evidence, the `model:` frontmatter answer, the verification results, and one false alarm recorded deliberately |

No source file in this repo changed. `plugins/explain/` shipped in #16 and is untouched here.

## Plan alignment

All four phases completed.

- **Phase 1 — install and verify.** Done. `claude plugin marketplace update cjus-skills`
  moved the local clone from `b0f5320` to `c724566` (the #16 merge); before it, the cached
  manifest's `plugins` array held only `bookcraft` and `pr`, so the update was load-bearing.
  `claude plugin install explain@cjus-skills` installed `explain@0.1.0` at user scope.
  Verified from `cjus-dev`: both skills resolve, and `qve` and `explain:qve` appear as
  distinct entries. **Recorded precisely:** resolution was observed in `cjus-dev`, while
  execution of both skills happened in this worktree. The plugin is user-scoped so the code
  path is identical, but the two halves were observed in different sessions.
- **Phase 2 — `model: opus`.** Done, and the answer is that it **is** honored, so `qve`
  keeps the line unchanged. First established by static analysis of the compiled
  `2.1.274` binary, then confirmed empirically: running `/explain:qve` from a session on
  `claude-opus-5[1m]` produced a skill turn reporting `claude-opus-5`.
- **Phase 3 — remove `~/.claude/skills/qe/`.** Done. Not under version control, so a copy
  was taken first; the content is also recoverable from `origin/main`'s plugin copy, which
  differs by exactly four namespacing hunks.
- **Phase 4 — remove `cjus-dev`'s `qve`.** Done, landed as `f7bc581` on that repo's `main`
  via the quick-commit path its conventions sanction, with the operator approving the
  main-branch gate. The same commit updates that repo's skills documentation. The "enable
  the plugin there" half was a **verified no-op**: `explain@cjus-skills` is enabled at user
  scope and `cjus-dev` declares no project-level `enabledPlugins`.

**One deviation from the plan as written.** Phase 1's text was amended mid-branch to
restore a shadowing check that #12's review had asked for and this branch's wording had
dropped. Reviewed as a status/how refinement rather than scope change: it adds no
deliverable, since issue #17's first bullet already required verifying resolution, and it
was load-bearing for phase 3, which destroys the evidence the check depends on.

**Phase 4's premise was corrected mid-branch**, also on review. Its stated goal, "so `/qve`
keeps working there", was not achievable: a plugin skill resolves as `/explain:qve`, so the
bare name goes away by design. The real goal is that the capability survives under its
namespaced name, which it does.

## Testing

No automated tests: this repo configures no `checks` and has no CI workflows, and the work
is machine state rather than code. Verification was by direct observation, and it is
reproducible:

1. `claude plugin marketplace update cjus-skills && claude plugin install explain@cjus-skills`, then restart.
2. From a repo other than `cjus-skills`, confirm `/explain:qe` and `/explain:qve` resolve.
3. Confirm the namespaced form reaches the plugin. The decisive evidence was description
   text: the loaded `explain:qe` carried the plugin copy's `"/explain:qe what is a
   transactional outbox"`, where the user-level copy read `"/qe what is…"`.
4. Run `/explain:qve` and observe the reported model. `model: opus` resolves through the
   family alias and switches the turn's model.

**Edge case that produced a false alarm, recorded so it is not re-derived.** Mid-verification
it appeared that `explain:qve` had displaced `qve` while `qe` and `explain:qe` coexisted,
suggesting a precedence rule where a plugin skill hides a *project* skill but not a
*user-level* one. That was an artifact of reading the skill list from this worktree, where
`cjus-dev`'s project-level `qve` correctly does not load at all. **No such rule exists.**
The investigation did establish one real fact: the duplicate-skill guard keys on the
resolved file, not the skill name — it skips only the *same file* reached twice — so
same-named skills from different sources never collide.

## Impact assessment

- 2 files changed, 199 insertions, 0 deletions, all under `changelog/` — measured before this summary, the review and `COMMITMSG.md` were added to the same folder by the close.
- No dependency changes. No source changes in this repo.
- **Breaking change, outside this repo:** the bare `/qe` and `/qve` no longer exist. Both
  are now `/explain:qe` and `/explain:qve`. `cjus-dev`'s documentation is updated in
  `f7bc581`; any other place naming the bare forms is stale.
- Machine state altered: `explain@0.1.0` installed and enabled at user scope;
  `~/.claude/skills/qe/` removed; a Playwright venv created at `~/.cache/explain/venv`.

## Deferred work

Nothing is deferred out of this branch. Both items that were triaged into `## Deferred`
during the work were completed in-branch instead, and both landed in `f7bc581`: committing
the `qve` removal in `cjus-dev`, and the stale `/qve` and `/qe` references at that repo's
`CLAUDE.md:416`.

Two observations recorded that are **not** this branch's to fix, neither rising to a
ticket here:

- `explain@0.1.0`'s `page-template.html` footer still says "regenerate with `/qve …`", a
  bare name the port missed. Cosmetic, but live in the shipped plugin.
- `cjus-dev` documents `CJUS_ALLOW_MAIN=1` as the approval token for its `main` gate and
  its commit hook accepts it, but its **push** hook requires `PR_ALLOW_MAIN=1`. A
  documented, operator-approved push fails on the token its own documentation gives. That
  is a trap in that repo, not this one.

## Assertions

`docs.assertionsFile` is `null` in `.claude/pr-config.json`, so the assertions audit is
**disabled** for this repo. Likewise `docs.continuityRoot`, so no continuity entry is written.
