# Reduce root README to a plugin catalog with links

Start date: 2026-09-20 09:59:48 MDT

Reduce the root `README.md` to a catalog of available plugins — name, what it does, and a
link to the plugin folder's own `README.md` — relocating plugin-specific detail into those
plugin READMEs.

## Changes

### 2026-09-20 — Root README reduced to a catalog, 167 lines to 57

**Decisions, both made by the operator.** The catalog names only the plugin, not its skills —
the four per-plugin skill tables are gone, since each plugin's README already documents its own
skills. The root `## Layout` section was removed outright rather than trimmed. The governing
constraint was that the root be easy to browse and concise by nature.

**`## Plugins` is now a four-row table** — plugin name linking to `plugins/<name>/README.md`, and
one or two lines on what it does. Its wording was checked against `.claude-plugin/marketplace.json`
so the two descriptions do not drift.

**Three details were root-only and would have been lost. They were relocated first:**

- The eleven-label breakdown and the six type-label names (`bug`, `feature`, `refactor`, `docs`,
  `infra`, `research`) → `plugins/pr/README.md` under `/pr:init`. They existed in
  `plugins/pr/reference/ticketing.md` but not in the plugin README, which is where the acceptance
  criterion points.
- The rationale that `reference/` documents keep skills repo-agnostic, so nothing depends on the
  host repo having a `CLAUDE.md` → `plugins/pr/README.md` and `plugins/council/README.md`, under
  each one's `## What ships here`. Neither README stated it.
- The `${CLAUDE_PLUGIN_ROOT}` explanation → kept at the root, in `## Install`. It is a
  marketplace-level fact about how every plugin resolves its own files, not a per-plugin one, and
  no plugin README explains it even though bookcraft and pr both use the variable in commands.

**Everything else was already covered downstream** and was verified before removal, not assumed:
the `pr` Configuration and Hooks subsections (`## Configuration` and `## The three hooks`,
including the inert-without-config rule and the `mainGuard.enabled` / `closeGate.enabled`
toggles), the lifecycle diagram, council's "nothing to configure to start" and "seating is a
join" paragraphs, bookcraft's "only `/makebook` needs third-party packages", and the per-plugin
file trees, which all four READMEs carry as `## What ships here`.

**Verified:** all five relative links in the root README resolve; no file in the repo links to the
removed `#layout` or `#plugins` anchors.

**Review, same day.** Verdict APPROVE, no blocking or important issues; the reviewer re-checked
all 18 removed items against `git show origin/main:README.md` independently. Two non-blocking
accuracy nits in the new prose were fixed rather than deferred: the catalog's closing line had
promised cost and configuration coverage that `explain` and `bookcraft` do not have, and the
`explain` row said "under 250 words" where the skill's bar is "at most 250".

**Default branch moved mid-branch.** `main` gained five commits, one editing
`plugins/bookcraft/README.md`, which the Phase 1 audit depended on. Every bookcraft anchor was
re-verified against `origin/main` and all survive; the merge is clean.
