# Port qe and qve into a standalone explain plugin

Start date: 2026-09-16 18:12:36 MDT

Ticket: https://github.com/cjus/cjus-skills/issues/12

## Overview

Package the `qe` (quick explain) and `qve` (quick visual explain) skills as a third
plugin in this marketplace, alongside `bookcraft` and `pr`, so they install from the
plugin instead of living per-machine and per-repo.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

Package the `qe` (quick explain) and `qve` (quick visual explain) skills as a third plugin in this marketplace, alongside `bookcraft` and `pr`, so they install from the plugin instead of living per-machine and per-repo.

**Where they live today.** The two are not in the same place, and neither of them is a pair in `cjus-dev`:

- `qe` — `~/.claude/skills/qe/SKILL.md`, a **user-level** skill. It is not in `cjus-dev` or any other repo; it is installed on this machine only.
- `qve` — `~/dev/cjus-dev/.claude/skills/qve/`, a **project** skill in the `cjus-dev` repo, with `references/page-template.html`.

That split is the reason for the port: `qe` works everywhere but only on machines it has been copied to, and `qve` works only inside `cjus-dev`.

**Goal: the plugin becomes the only home.** Once the plugin is deployed and verified, both originals are deprecated — the global `~/.claude/skills/qe/` and the project-level `cjus-dev` `qve`. Two live copies of a skill drift, and a user-level `qe` shadowing a plugin `qe` is a confusing failure to diagnose.

## Plan

- [x] Phase 1: Create `plugins/explain/` with `.claude-plugin/plugin.json`, a `README.md`, and both skills under `skills/` — invoked as `/explain:qe` and `/explain:qve`. Nothing the plugin writes at runtime may live under `${CLAUDE_PLUGIN_ROOT}`. (D-5)
- [x] Phase 2: Carry `qve`'s `references/page-template.html` into the plugin at `plugins/explain/skills/qve/references/page-template.html`, byte-for-byte, and cite it from `qve`'s SKILL.md as `${CLAUDE_PLUGIN_ROOT}/skills/qve/references/page-template.html`. (D-2, D-3)
- [x] Phase 3: Fix every cross-skill reference, in both directions and both forms, since after the port the two skills ship together. **File paths:** replace `qve`'s absolute `~/.claude/skills/qe/SKILL.md` (source `SKILL.md:23`) with `${CLAUDE_PLUGIN_ROOT}/skills/qe/SKILL.md`. **Command strings:** namespace the bare `/qe` and `/qve` invocations in both SKILL.md files, including their frontmatter `description` examples — a bare `/qve` does not resolve for a plugin-installed user, so `qe`'s offer to run one is dead as written. (D-3)
- [x] Phase 4: Reword `qve`'s cross-skill references so none names a skill a plugin installer may lack — leave `dataviz` as-is, make `diagram-dot` conditional, and replace the `make-pdf` pointer with the two venv commands it stood in for. Do not vendor their tooling. (D-4) **The review found two more** the first pass missed: `/debrief` (user-level-only, and the last bare slash-command form in either file) is now conditional, and the honesty rule `qve` delegated to the host repo's `CLAUDE.md` is now stated in the skill itself.
- [x] Phase 5: Register the plugin in `.claude-plugin/marketplace.json`, inserted alphabetically. **The review found** the root `README.md` did not know a third plugin existed; its § Plugins and § Layout sections now carry `explain`.
- [x] Phase 6: Keep `qve`'s scratch output directory at `$HOME/.claude/qve` and carry its prune step across unchanged — the path is already outside the plugin root, which is what a plugin-installed skill requires. (D-5)
- [ ] Phase 7 (post-merge): Verify the plugin-installed `qe` and `qve` both work, from a repo other than this one. **Static half done pre-merge** — `claude plugin validate` passes on the plugin manifest, on `.claude-plugin/marketplace.json`, and on the `plugins/explain/skills` components. **Live half runs after the merge** (D-6): `claude plugin marketplace update cjus-skills` then `claude plugin install explain@cjus-skills`, restart, and confirm `/explain:qe` and `/explain:qve` both resolve and run. Confirm `/explain:qe` reaches the plugin rather than the user-level `~/.claude/skills/qe/` — the namespaced form should be unambiguous, but the Goal paragraph's shadowing concern is what Phase 8 retires.
- [ ] Phase 8 (post-merge): Deprecate `~/.claude/skills/qe/` — remove it, so the plugin copy is not shadowed by a user-level skill of the same name.
- [ ] Phase 9 (post-merge): Deprecate `cjus-dev`'s `.claude/skills/qve/` — remove it, and enable this plugin in `cjus-dev` so `/qve` keeps working there.

## Decisions

Decisions of record, so they are not re-litigated mid-build. Each cites the merged
precedent it follows.

**D-1: This branch lands independently of issue #9.** The question of whether to wait on
#9's packaging conventions rested on a false premise — #9 settles no conventions. The
plugin shape (`.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, optional
`reference/`, `scripts/`, `agents/`, `hooks/`) is already fixed by `bookcraft` and `pr`,
both merged on `main`, and `plugins/council/.claude-plugin/plugin.json` on #9's branch
matches it field for field. Divergent packaging was never an option regardless: one repo,
one `.claude-plugin/marketplace.json`, one marketplace. The sole coupling between the two
branches is that both append an object to that file's `plugins` array — a one-hunk
conflict for whichever merges second, not a sequencing constraint.

*Resolved by events, 2026-09-16:* council merged as PR #13 while this branch was in
flight, landing scripts-only — no `skills/` directory and no `marketplace.json` entry.
There was therefore no competing hunk and no conflict. The alphabetical insertion stands
on its own merits as list hygiene, not as conflict avoidance.

**D-2: Plugin assets live beside the skill that owns them.** The repo's rule is
scope-based rather than a plugin-root-versus-per-skill style. `bookcraft` keeps
single-consumer assets under `skills/<name>/` (`skills/makebook/references/figure-template.svg`,
`skills/check-claims/reference/judgement.md`) and reserves the plugin root for tooling
every skill uses (`scripts/install.sh`). `pr` puts its `reference/` docs at the root
because many of its skills cite them. `page-template.html` has exactly one consumer, so
it goes under `skills/qve/`. Singular versus plural is unsettled in-repo
(`makebook/references/` against `createbook/reference/`), so `qve`'s existing plural
stands and the file carries byte-for-byte.

**D-3: Intra-plugin file references use the full `${CLAUDE_PLUGIN_ROOT}` path, including
self-references.** `bookcraft` cites its own assets that way
(`skills/check-claims/SKILL.md:58`, `skills/createbook/SKILL.md:258`) and its cross-skill
assets identically (`skills/check-claims/SKILL.md:40`, `skills/createbook/SKILL.md:378`);
the latter pair is the worked example Phase 3 copies. `skills/makebook/SKILL.md:69` is the
outlier, citing its own assets bare (`references/diagram-style.md`), which depends on the
agent inferring the skill directory as the base. Follow the two explicit skills, not the
outlier.

**D-4: Phase 4 rewords `qve`'s cross-skill references rather than vendoring their
tooling.** The three dependencies are not one problem. `dataviz` is neither user- nor
project-level and resolves from the built-in set, so it travels with Claude Code and its
reference stands. `diagram-dot` is a user-level skill on one machine
(`~/.claude/skills/diagram-dot/`) backed by a Homebrew `dot`, and `qve` names it only as
an optional offline alternative to the default CDN Mermaid path, so a conditional
reference suffices. `make-pdf` is the only one with teeth, being cjus-dev-only and cited
in the verification step — but Playwright is already the *fallback* there, behind
Claude-in-Chrome, which is not machine-scoped. All three sites already degrade honestly
in the source ("degraded, not broken"; "say plainly that rendering was not verified").
Vendoring a Playwright venv would back up a path that still works after the port, so it
is recorded under `## Deferred` instead.

**D-5: Nothing the plugin writes at runtime may live under `${CLAUDE_PLUGIN_ROOT}`.**
`plugins/bookcraft/scripts/install.sh` documents why: Claude Code installs a plugin to a
version-scoped directory (`.../cache/<marketplace>/<plugin>/<version>`), so the root moves
on every release and anything stored beneath it is silently discarded on update —
costing, in bookcraft's case, a fresh ~150 MB install plus a Chromium download. Bookcraft
puts its venv at `${XDG_CACHE_HOME:-$HOME/.cache}/bookcraft/venv` for that reason. This
settles Phase 6 (`qve`'s `$HOME/.claude/qve` is already outside the plugin root and needs
no change) and constrains Phase 1's layout.

**D-6: Phases 7–9 run after the merge, not before it.** Phase 7 needs the plugin installed
the way a user installs it, and the configured `cjus-skills` marketplace resolves from
GitHub `main` — so `explain` has to be merged before it can be installed at all. The
pre-merge alternatives were rejected on risk: `~/.claude/settings.json` declares
`extraKnownMarketplaces.cjus-skills`, and adding this worktree under that same name could
re-point the already-installed `bookcraft@cjus-skills` and `pr@cjus-skills` at the branch
mid-session. What could be checked without touching live config was checked, and passed:
`claude plugin validate` on the plugin manifest, on the marketplace manifest, and on the
`plugins/explain/skills` components. The consequence to accept knowingly is that the
branch merges with Phases 7–9 outstanding; they are deployment steps, not repo work, and
the repo-side port is complete at Phase 6.

## Deferred

Discovered on this branch and out of scope for it. Not work this branch performs.

- **A self-contained Playwright verifier for `qve`.** `plugins/explain/scripts/install.sh`
  plus an `explain-python` wrapper, mirroring `plugins/bookcraft/scripts/install.sh` and
  its `${XDG_CACHE_HOME:-$HOME/.cache}/<plugin>/venv` placement, with `playwright>=1.40`
  as the only requirement. It would let `qve` confirm Mermaid actually rendered without
  Claude-in-Chrome connected. Real value, but it adds a capability rather than porting
  one (see D-4).

## Open Questions

None outstanding. The one question this branch opened is resolved as D-1 above.
