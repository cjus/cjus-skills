# Handoff documents

Six kinds of document, each with a distinct audience and a distinct question. Conflating them is what makes each one worse. The first four are per branch; the last two are repo-global and shared across every branch.

| Where | Audience | Question it answers | Nature |
|---|---|---|---|
| `<changelogRoot>/<branch-slug>/PLAN.md` | The agent working this branch | "What am I doing, and what is left?" | Forward-looking, scope-frozen |
| `<changelogRoot>/<branch-slug>/CHANGELOG.md` | The same | "What has this branch changed so far?" | Version-scoped, narrates the change |
| `<changelogRoot>/<branch-slug>/pr-summary-<date>.md` | The PR reviewer | "What does this PR do and why?" | Version-scoped |
| `<changelogRoot>/<branch-slug>/COMMITMSG.md` | Whoever reads the commit log | "What does this branch's commit say?" | Covers the uncommitted changes only |
| `<continuityRoot>/<date>-<slug>.md` | A returning agent | "What just happened in this project?" | **Temporal, ages out** |
| `<assertionsFile>` | An agent validating a change | "What invariants must hold?" | Atemporal |

Paths come from `docs.*` in `config.md`. Setting `docs.continuityRoot` or `docs.assertionsFile` to `null` disables that convention, and every skill that would write one reports it as disabled rather than as missing.

## The per-branch folder

Every branch gets `<changelogRoot>/<branch-slug>/` at the repo root, where `<branch-slug>` is the branch name minus `branchPrefix`.

```
changelog/123-add-retry-logic/
  PLAN.md                    created by /pr:start, scope-frozen
  CHANGELOG.md               appended to as work proceeds
  pr-summary-2026-09-14.md   written by /pr:summary
  COMMITMSG.md               written by /pr:close
```

**Merged branches' folders stay in the repo as history.** `/pr:close` finalizes the folder; nothing deletes one without explicit direction.

Common mistakes, each of which breaks the skills that read the folder:

- Pluralizing the directory name
- Omitting the per-branch subfolder
- Nesting the whole thing under `.claude/`

## Continuity entries

**One entry per file**, named `<YYYY-MM-DD>-<ticket-slug>.md`, holding a two to five bullet summary with `Date added`, `Covers`, `Source`, `Status`, `Affected` and `Open threads` fields.

Managed by skills rather than hand-authored:

- `/pr:continuity-add` is additive. It writes one new file and touches nothing else. `/pr:close` invokes it.
- `/pr:continuity-prune <date>` is destructive. It deletes whole entry files older than a cutoff, and is always explicit and confirmed.

Editing one entry's fields, such as flipping `Status: active` to `superseded`, is an ordinary edit to that one file.

**Nothing in the continuity folder is shared between entries.** No index, no combined file, no stored counts. Ordering comes free from the ISO date prefix, and header facts are derived on read:

```bash
ls "$CONTINUITY_ROOT"/[0-9]*.md | sort -r
grep -l '^- \*\*Status:\*\* active' "$CONTINUITY_ROOT"/[0-9]*.md | wc -l
```

**This is load-bearing, not tidiness.** The one-file-per-entry layout replaces a single shared log that was prepended to at a fixed offset. Concurrent closes collided in that file, and the collisions did three things at once: they desynced the entry count, they duplicated IDs, and they left the merge ref uncomputable, which suppressed CI runs outright because no run is created for a pull request whose merge commit cannot be produced. Adding any shared file back reintroduces all three.

## Assertions

The assertions file is a local log of verifiable invariants: schema shapes, access policies, build pipeline facts, runtime assumptions. It exists to stop an agent from silently violating a constraint nobody wrote down.

Each entry carries `ID`, `Constraint Type`, `Evidence` (path plus symbol), `Status`, `Impact of Violation`, and `Re-validate` (the triggers that put it back in scope).

**Adding an entry is deliberate and agreed with the operator.** It is never a side effect of an unrelated change, and never a fabricated entry written so an audit has something to report. An entry earns its place by being verifiable and by having a violation that produces an observable failure.

See `assertion-audit.md` for when the audit runs and what it reports.

## Atemporal documents describe the thing as it is

A reference document must read coherently to somebody who does not know what the last commit did. Write "this function uses a hash map for constant-time lookups", not "this replaces the previous approach, which was quadratic".

The version-scoped exceptions, where narrating the change is the entire point, are `CHANGELOG.md`, `pr-summary-<date>.md` and the continuity entries.

**The assertions file is a deliberate partial exception.** An invariant that was read wrongly once will be read wrongly again, so an inline `Amended <date>` note recording why the old reading failed is part of what the entry gives a re-validator. Keep the current state first, with the correction attached to it.
