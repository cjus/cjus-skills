# Port qe and qve into a standalone explain plugin

Closes #12.

## Overview

`qe` (quick explain) and `qve` (quick visual explain) now ship as a third plugin in this
marketplace, alongside `bookcraft` and `pr`. Before this branch the two lived in different
places and neither was portable: `qe` was a user-level skill at `~/.claude/skills/qe/`,
installed on one machine, and `qve` was a project skill inside the source repo. `qe`
worked everywhere but only where it had been copied; `qve` worked only inside one repo.

Both are now `plugins/explain/skills/`, invoked as `/explain:qe` and `/explain:qve`, and
registered in `.claude-plugin/marketplace.json`. The repo-side port is complete. Retiring
the two originals is deliberately **not** in this PR — see *Plan alignment*.

## Key changes

| Path | What |
| --- | --- |
| `plugins/explain/.claude-plugin/plugin.json` | New manifest, matching the field set `bookcraft` and `pr` use |
| `plugins/explain/README.md` | Install, both skills, a choosing-between-them table, the `/explain:` namespacing rule |
| `plugins/explain/skills/qe/SKILL.md` | Ported from `~/.claude/skills/qe/`; cross-skill references namespaced |
| `plugins/explain/skills/qve/SKILL.md` | Ported from the source repo; references rewritten through `${CLAUDE_PLUGIN_ROOT}`, dependencies reworded |
| `plugins/explain/skills/qve/references/page-template.html` | Carried byte-for-byte, unmodified |
| `.claude-plugin/marketplace.json` | `explain` registered, inserted alphabetically |

Each `SKILL.md` was copied and diff-verified identical to its source **before** any edit, so
every change below reads as a diff against the original rather than hiding inside a move.

## Code examples

**A dead command offer, which the port caught.** `qe` ends by suggesting the visual sibling
when a topic's shape wants a diagram. Plugin skills are namespaced, so the bare form resolves
to nothing for anyone installing from the marketplace:

```diff
- prose is the wrong medium. Answer anyway (don't stall), then offer `/qve <topic>`,
+ prose is the wrong medium. Answer anyway (don't stall), then offer `/explain:qve <topic>`,
```

**A cross-skill file reference that assumed a user-level install** — `plugins/explain/skills/qve/SKILL.md:23`:

```diff
- Inherit `/qe`'s rules (`~/.claude/skills/qe/SKILL.md` — `qe` is installed at user level)
+ Inherit `/explain:qe`'s rules (`${CLAUDE_PLUGIN_ROOT}/skills/qe/SKILL.md` — both skills ship in this plugin)
```

**A dependency on a skill that exists in exactly one repo.** `make-pdf` is source-repo-only and
was cited in `qve`'s render-verification step, so it becomes unreachable the moment the plugin
is installed anywhere else. The pointer is replaced by the commands it stood in for:

```diff
- otherwise drive Playwright headless ... and the `make-pdf` skill documents how to stand
- up its `.venv` if one isn't present yet.
+ Otherwise drive Playwright headless ... Playwright does not ship with this plugin; if it
+ is not already available, one-time setup outside the plugin directory provides it:
+
+ ```bash
+ VENV="${XDG_CACHE_HOME:-$HOME/.cache}/explain/venv"
+ python3 -m venv "$VENV"
+ "$VENV/bin/pip" install playwright
+ ```
```

## Plan alignment

Phases 1 through 6 are complete as planned. Two phases were changed in flight, and both
changes are recorded as decisions in `PLAN.md § Decisions` with the evidence behind them.

- **Phase 3 was broadened**, from "replace `qve`'s file path to `qe`" to "fix every cross-skill
  reference, in both directions and both forms". Carrying the skills verbatim surfaced the dead
  `/qve` offer in `qe`, which the original wording did not cover. 12 edits across the two files.
- **Phases 7 through 9 are deferred to after the merge** (D-6), which is a deviation worth
  stating plainly. Phase 7 verifies the plugin *as installed*, and the configured `cjus-skills`
  marketplace resolves from GitHub `main` — so `explain` has to merge before it can be installed
  the way a user installs it. The pre-merge alternatives were rejected on risk: `~/.claude/settings.json`
  declares `extraKnownMarketplaces.cjus-skills`, and adding this worktree under that same name
  could re-point the already-installed `bookcraft@cjus-skills` and `pr@cjus-skills` at the branch.

**The open question the branch started with is resolved** (D-1). It asked whether to follow the
packaging conventions issue #9 would settle; #9 settles none — the shape was already fixed by
`bookcraft` and `pr`, and council is a third consumer of it.

## Testing

No automated tests were added, because there is nowhere to add them: this repo has no CI, no
`package.json` and no `Makefile`, and the only test scripts belong to the `pr` plugin and do not
cover a new one.

What was verified mechanically:

```
claude plugin validate --strict plugins/explain                      ✔
claude plugin validate --strict .claude-plugin/marketplace.json      ✔
claude plugin validate --strict plugins/explain/skills               ✔
```

The third validates the `SKILL.md` components themselves, not just the manifests.

**To verify by hand, after merge:**

```bash
claude plugin marketplace update cjus-skills
claude plugin install explain@cjus-skills
# restart, then from a repo other than this one:
/explain:qe what is a transactional outbox
/explain:qve raft consensus
```

Confirm `/explain:qe` reaches the plugin rather than the user-level `~/.claude/skills/qe/`.

**Edge cases considered.** Every namespacing replacement was explicitly anchored rather than
globally applied: a global substitution of `/qve` would have corrupted `OUT_DIR="$HOME/.claude/qve"`
and the example output path, both of which contain that string. The `marketplace.json` entry was
inserted alphabetically rather than appended, which keeps the list ordered. The plan had flagged
that array as the likely conflict with issue #9; in the event council merged (PR #13) as a
scripts-only layer carrying no marketplace entry, so no conflict arose.

## Impact assessment

8 files changed, 656 insertions, 0 deletions. Seven files are new; the only edit to an existing
file is a 6-line insertion into `.claude-plugin/marketplace.json`.

**No breaking change.** Nothing existing is modified or removed. The two original skills are
untouched by this PR and keep working exactly as they did — `qe` at user level, `qve` in
the source repo. Retiring them is Phases 8 and 9, post-merge.

**No new dependencies.** Playwright is referenced as optional one-time setup for an optional
verification path, and is not bundled or required.

**Assertions:** not configured for this repo (`docs.assertionsFile` is `null`), so no audit applies.

## Deferred work

One item sits under `PLAN.md § Deferred`:

**A self-contained Playwright verifier for `qve`.** A `plugins/explain/scripts/install.sh` plus an
`explain-python` wrapper, mirroring `plugins/bookcraft/scripts/install.sh` and its
`${XDG_CACHE_HOME:-$HOME/.cache}/<plugin>/venv` placement, with `playwright>=1.40` as the only
requirement. It would let `qve` confirm Mermaid actually rendered without the Claude-in-Chrome
extension connected. It was left out because Playwright is already the *fallback* on that path,
behind Claude-in-Chrome, which is not machine-scoped — so vendoring it would back up a path that
survives the port intact. It adds a capability rather than porting one.
