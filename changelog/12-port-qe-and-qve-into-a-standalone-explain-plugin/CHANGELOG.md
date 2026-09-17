# Port qe and qve into a standalone explain plugin

Start date: 2026-09-16 18:12:36 MDT

Package the `qe` (quick explain) and `qve` (quick visual explain) skills as a third
plugin in this marketplace, alongside `bookcraft` and `pr`, so they install from the
plugin instead of living per-machine (`qe` at user level) and per-repo (`qve` in
`cjus-dev`).

## Changes

- Filed https://github.com/cjus/cjus-skills/issues/12 as the tracking ticket, `status:in-progress` + `priority:high` + `feature`.
- Created branch `feature/12-port-qe-and-qve-into-a-standalone-explain-plugin` from `main` in a worktree.

## 2026-09-16

**Settled the packaging questions from merged evidence before writing any code.** The branch opened with one question — whether to follow the packaging conventions issue #9 settles, or land independently — and it turned out to rest on a false premise.

- **#9 settles no conventions.** The plugin shape is already fixed by `bookcraft` and `pr`, both merged, and `plugins/council/.claude-plugin/plugin.json` on #9's branch matches it field for field. It is a third consumer of an existing convention, not a convention-setter. Divergent packaging was never an option regardless: one repo, one `marketplace.json`, one marketplace.
- **The asset-placement rule is scope-based, not stylistic.** `bookcraft` keeps single-consumer assets under `skills/<name>/` and reserves the plugin root for tooling every skill uses; `pr` puts its `reference/` docs at the root because many skills cite them. Same rule, different inputs. `page-template.html` has one consumer, so it went beside `qve`. Singular versus plural is genuinely unsettled in-repo (`makebook/references/` against `createbook/reference/`), so `qve`'s existing plural stood and the file carried byte-for-byte.
- **Intra-plugin references use the full `${CLAUDE_PLUGIN_ROOT}` path, including self-references.** `bookcraft` cites its own assets that way in two skills and its cross-skill assets identically; `makebook` is the lone outlier, citing bare relative paths that depend on the agent inferring the skill directory. Followed the two, not the outlier.

**Ported both skills verbatim first, then edited.** Each `SKILL.md` was copied and diff-verified identical to its source before any change, so every subsequent edit reads as a diff against the original rather than hiding inside a move.

**The port caught a defect that would have shipped dead.** `qe` ends by offering `/qve <topic>` when a topic's shape wants a diagram. Plugin skills are namespaced, so that bare command resolves to nothing for anyone who installs from the marketplace — the offer was dead as written. Phase 3 was broadened mid-branch from "fix the file path" to "fix every cross-skill reference, in both directions and both forms" to cover it. 12 edits across the two files, including both frontmatter `description` examples and both headings.

- Followed `pr`'s namespacing convention rather than `bookcraft`'s, which is internally inconsistent (`# Make Book` against `# /check-claims`, and an un-namespaced `/updatebook` in a description).
- Every replacement was explicitly anchored rather than globally applied. A global substitution of `/qve` would have corrupted `OUT_DIR="$HOME/.claude/qve"` and the example output path, both of which contain the same string.

**Dependencies reworded, not vendored, because they are three different problems.**

- `dataviz` resolves from the built-in set rather than from this machine or this repo, so it travels with Claude Code and its reference was left untouched.
- `diagram-dot` is a user-level skill on one machine backed by a Homebrew `dot`, and `qve` names it only as an optional offline alternative to the default CDN Mermaid path. Made conditional, with Graphviz named as the actual requirement.
- `make-pdf` was the only one with teeth: a `cjus-dev`-only skill, cited in the verification step, and unreachable from any other repo after the port. Replaced the pointer with the venv commands it stood in for. Playwright stayed unvendored because it is already the *fallback* there, behind Claude-in-Chrome, which is not machine-scoped — vendoring would have backed up a path that survives the port intact. The scripted version is recorded under `## Deferred` in the plan.

**`${CLAUDE_PLUGIN_ROOT}` is version-scoped, which constrains where anything may be written.** `plugins/bookcraft/scripts/install.sh` documents it: Claude Code installs to `.../cache/<marketplace>/<plugin>/<version>`, so the root moves every release and anything beneath it is silently discarded on update. This settled Phase 6 with no edit needed — `qve`'s `$HOME/.claude/qve` was already outside the plugin root, as was its start-of-run prune — and the rationale was written into the skill so the next person does not move the venv under the plugin root.

**Registered alphabetically rather than appended.** `explain` sits between `bookcraft` and `pr` in `marketplace.json`. The plan had predicted that array as the one merge conflict with issue #9. The conflict did not materialise — and not because of the insertion point: council merged as PR #13 mid-branch, landing scripts-only with no `skills/` directory and no marketplace entry at all, so there was no competing hunk. Alphabetical order stands as list hygiene rather than as conflict avoidance. The diff is 6 insertions and 0 deletions, confirming the JSON round-trip reformatted nothing. Description reused verbatim from `plugin.json`, which is the convention both existing entries follow.

**Validated as far as is possible before a merge.**

- `claude plugin validate --strict` passes on the plugin manifest, on `.claude-plugin/marketplace.json`, and on the `plugins/explain/skills` components.
- That is the extent of mechanical checking available. This repo has no CI, no `package.json` and no `Makefile`; the only test scripts belong to the `pr` plugin and do not cover a new one.

**Phases 7-9 merge outstanding, knowingly.** Phase 7 needs the plugin installed the way a user installs it, and the configured `cjus-skills` marketplace resolves from GitHub `main` — so `explain` must merge before it can be installed at all. The pre-merge alternatives were rejected on risk: `~/.claude/settings.json` declares `extraKnownMarketplaces.cjus-skills`, and adding this worktree under that name could have re-pointed the already-installed `bookcraft@cjus-skills` and `pr@cjus-skills` at the branch mid-session. The repo-side port is complete at Phase 6; 7 through 9 are deployment steps — install and verify from a third repo, then retire `~/.claude/skills/qe/` and `cjus-dev`'s `.claude/skills/qve/`.

**Review gate: APPROVE, with three findings fixed before the merge.** The reviewer caught a fourth machine-scoped reference the Phase 4 audit missed — `/debrief` at `qve/SKILL.md:35`, a user-level-only skill and the last bare slash-command form in either file — plus an honesty rule `qve` still delegated to the host repo's `CLAUDE.md`, and a root `README.md` that did not know a third plugin existed. All three are closed. Two items were deferred and triaged at close. Full review in `pr-review-2026-09-16.md`.
