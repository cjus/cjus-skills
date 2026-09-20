# Reduce the root README to a plugin catalog

Closes #34.

## Overview

The root `README.md` had grown into a second copy of the plugin documentation. It carried a
`### <plugin>` section for each of the four plugins, each with a skills table, plus a `## Layout`
section whose tree annotated every plugin's internal file structure. All four plugins already have
their own README, so most of that detail existed twice and could drift.

This reduces the root to a catalog: a four-row table naming each plugin, a line or two on what it
does, and a link to `plugins/<name>/README.md`. The `## Layout` section is removed. `## Install`,
`## Releasing` and `## License` stay, since they are genuinely repo-level. The file goes from 167
lines to 57.

The operator set two decisions before implementation: the catalog names only the plugin, not its
skills, and `## Layout` goes entirely rather than being trimmed. The governing constraint was that
the root be easy to read and browse, and concise by nature.

## Key changes

| File | Change |
|---|---|
| `README.md` | `## Plugins` becomes a four-row catalog table; `## Layout` removed; one sentence added to `## Install`; the intro's plugin roll-call dropped as redundant with the table below it. |
| `plugins/pr/README.md` | Receives two root-only details: the eleven-label breakdown with the six type-label names, and the rationale that `reference/` docs keep the skills repo-agnostic. |
| `plugins/council/README.md` | Receives the same repo-agnostic rationale for its three reference documents. |

## Code examples

**The catalog that replaces 80 lines of per-plugin sections** (`README.md`):

```markdown
| Plugin | What it does |
|---|---|
| [**bookcraft**](plugins/bookcraft/README.md) | Writes a book, binds it into a PDF and a matching EPUB, revises it in place, and checks that its claims are ones its cited sources actually support. |
| [**council**](plugins/council/README.md) | Puts one question to several independent members and reconciles their answers without manufacturing consensus. |
| [**explain**](plugins/explain/README.md) | Explains a topic for a mid-level engineer — as prose under 250 words, or as a diagrammed page when the answer's shape is the point. |
| [**pr**](plugins/pr/README.md) | A GitHub-issue-backed PR lifecycle. The issue number is the ticket number, two labels carry state, and the merge closes the ticket. |
```

**Detail relocated rather than dropped** (`plugins/pr/README.md`, under `/pr:init`):

```diff
-and creates the `status:` and `priority:` labels the queue runs on, plus the type labels `/pr:ticket` picks from.
+and creates eleven labels: the two `status:*` and three `priority:*` labels the queue runs on, plus the six type labels `/pr:ticket` picks from — `bug`, `feature`, `refactor`, `docs`, `infra` and `research`.
```

The six names lived in `plugins/pr/reference/ticketing.md`, but not in the plugin README, which is
where acceptance criterion 2 points. The count was verified against `skills/init/SKILL.md`: two
`status:*` plus three `priority:*` plus six type labels is eleven, so the root's claim was accurate.

## Plan alignment

All four phases and all three acceptance criteria are complete.

- **Phase 1 (audit)** — each root plugin section was diffed against its plugin README before
  anything was deleted. Three details turned out to be root-only.
- **Phase 2 (relocate)** — those three were moved first. The `pr` Configuration and Hooks
  subsections, which `PLAN.md` flagged as most at risk, turned out to be *already* covered by
  `plugins/pr/README.md` `## Configuration` and `## The three hooks`, including the
  inert-without-config rule and both `.enabled` toggles, so they needed no move.
- **Phase 3 (rewrite)** — `## Plugins` became the table above; `## Layout` was removed.
- **Phase 4 (verify)** — links and coverage checked, below.

**Deviation, stated plainly.** `PLAN.md` Phase 2 anticipated moving the `pr` Configuration and
Hooks subsections down into the plugin README. That move was not needed: the plugin README already
carried both in more depth. The three details that *did* need relocating were different ones the
audit surfaced, and are listed above. The phase's intent — no detail lost — was met; its predicted
mechanism was not what the work required.

**One judgment call.** The catalog is a table rather than four `### <plugin>` subsections. A table
is more browsable for four entries and matches the operator's brief, but it means the root no
longer has a per-plugin anchor. Nothing in the repo links that way, so nothing broke.

**The `${CLAUDE_PLUGIN_ROOT}` sentence stayed at the root** rather than moving into a plugin
README. It is a marketplace-level fact about how every plugin resolves its own files, and no
plugin README explains it even though `bookcraft` and `pr` both use the variable in commands.
Putting it in one plugin's README would have been the wrong home; putting it in all four would
have duplicated it.

## Testing

This is a documentation change with no executable surface, so verification is by inspection:

1. **Every relative link resolves.** All five in the root README were extracted and stat'd:
   `LICENSE` and the four `plugins/<name>/README.md` targets. All present.
2. **Nothing links to the removed sections.** The repo was grepped for `README.md#layout` and
   `README.md#plugins` anchors and for `../../README.md` references. No hits outside `changelog/`.
3. **No detail was dropped.** Each claim removed from the root was located downstream before
   removal, not assumed: the `pr` Configuration and Hooks subsections, the lifecycle diagram
   (`plugins/pr/README.md`), council's "nothing to configure to start" and "seating is a join"
   paragraphs, bookcraft's "only `/makebook` needs third-party packages", and the per-plugin file
   trees, which all four READMEs carry as `## What ships here`.
4. **Re-verified against the moved default branch.** `main` gained five commits during this work,
   one of which edited `plugins/bookcraft/README.md`. Every bookcraft anchor the audit relied on
   was re-checked against `origin/main` and all survive.
5. **No description drift.** The catalog wording was checked against
   `.claude-plugin/marketplace.json`, which carries its own one-line description per plugin.

No automated tests were added or modified; the repo has no configured check commands.

## Impact assessment

- **5 files changed, 116 insertions, 120 deletions.** Two of those files (`PLAN.md`,
  `CHANGELOG.md`) are branch documents, not shipped content.
- **`README.md`: 167 → 57 lines.**
- **No dependencies affected. No breaking change.** No skill, script, hook or manifest was touched,
  so no plugin behavior changes and no version needs bumping.
- **Reader-facing effect:** someone landing on the repo now sees what the four plugins are in one
  screen, and goes to a plugin's README for anything more. The per-plugin detail has exactly one
  home instead of two, which removes the drift that motivated the ticket.

## Deferred work

`PLAN.md` has no `## Deferred` section, and this branch deferred, descoped and punted nothing. Both
of the plan's Open Questions were answered by the operator before implementation and are recorded
as resolved in `PLAN.md`.

**Assertions:** not configured for this repo (`docs.assertionsFile` is `null`), so no audit
statement applies.
