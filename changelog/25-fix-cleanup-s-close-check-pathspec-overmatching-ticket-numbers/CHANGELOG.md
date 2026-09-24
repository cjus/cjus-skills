# Fix cleanup's close-check pathspec overmatching ticket numbers

Start date: 2026-09-23 16:07:22 MDT

Anchor the ticket number in `/pr:cleanup` step 1's artifact pathspec, so a close check for
ticket 6 can no longer be satisfied by the artifacts of ticket 16 or 26.

## Changes

### Phase 1 — both gaps reproduced, and the issue's fix misses prefixed folders (2026-09-23)

- **The bug shows in this repo.** The old pathspec reported tickets 2 and 4 closed off `12-…`,
  `14-…-phases-2-9`, `22-…` and `14-…`, `34-…`, and neither ticket has a folder. `phases-2-9` is the
  number matching mid-slug, a shape the issue did not list.
- **Finding:** the issue's anchored globs miss every prefixed folder (`changelog/abc-6-…/`).
- **Finding:** step 0's "path containing `6-`" resolves ticket 16's workspace for ticket 6, which
  defeats any step 1 fix.
- **Decision (operator):** step 1 reads the exact slug, and step 0 matches the branch name. This
  departs from the issue's mechanism, not from its objective.
- **Decision:** anchor at a segment start rather than `reference/config.md:131`'s `^`, so nested
  owner-segment layouts (a real incident in the skill) still resolve.

### Phases 2-3 — the edits (2026-09-23)

- **`cleanup/SKILL.md` step 0** runs `git for-each-ref … %(worktreepath)` through an anchored
  `grep -iE`, and sets `WORKTREE_PATH`, `BRANCH` and `SLUG`.
- **Step 1** reads `<changelogRoot>/<slug>/…`. Its note and the incident reference were rewritten.
- **`allowed-tools`** gains `Bash(grep:*)`.
- **Added beyond the phase list:**
  - The main checkout is excluded by path. With worktrees off, the branch rule would otherwise hand
    it to step 5.
  - "No rows" means no branch.

### Phase 4 — the reproduction, before and after (2026-09-23)

- **The scratch repro:** one fresh repo per case, with closed `16-`, `26-` and `14-phases-6-9`
  decoys committed on the default branch.
- **Old rules:** step 1 reported `verified` off decoys, step 0 resolved 16 for 6, and step 0 matched
  `14-phases-6-9`, `66-`, and a worktree root that held digits.
- **New rules, 16 of 16:**
  - flat closed / halted / never-ran each read correctly;
  - nested, `abc-` prefixed and upper-case prefixed branches were found and verified;
  - every decoy returned no rows;
  - with worktrees off, the row carried the main checkout's path.
- **This repo:** ticket 25 resolves only this worktree.
- **`test-acceptance.sh`:** 39 of 39.

### Phase 5 — version (2026-09-23)

`pr` 0.2.3 → 0.2.4.

### Pre-test review — a prefix regression, fixed (2026-09-23)

The review (`pr-review-2026-09-23.md`) returned NEEDS_DISCUSSION. Both code findings were confirmed
in a scratch repo, then fixed in `e0ffa9b`.

- **`(<branchPrefix>)?` now leads the pattern.** Without it, step 0 missed `feature-6-x` under
  `branchPrefix: feature-`, a regression against `main`. Requiring `/`-terminated prefixes was
  rejected: it would narrow a documented setting to cover this branch's own regression.
- **`%(refname:lstrip=2)` replaces `short`.** With `short`, a tag named like the branch printed
  `heads/…`, which gave the wrong slug.
- **Taken:** the multiple-rows rule, and "opened the next gap" in the flat-layout incident.
- **Not taken:** step 3's re-assignment of `BRANCH`. Its worktrees-off consequence was added to
  Deferred.
- **Unverified assumption:** the nested incident repo carried its owner segment in the branch name.
  If it didn't, step 1 asks, defaulting to no.
- **The repro** now reads the format, pattern and pathspecs from `SKILL.md` on each run, and gained
  a `feature-` prefix case and a same-named tag case. 20 of 20. CI green on macOS and Ubuntu.

### Close review (2026-09-24)

`pr-review-2026-09-24-close.md`: APPROVE. It re-verified the pattern under BSD grep and ugrep across
prefix combinations, the `lstrip=2` tag case, and the main-checkout exclusion. Its two wording nits
were applied: the summary says "by path", and `SKILL.md:47` now says the second field is the main
checkout whenever the branch is checked out there.
