# Port the PR lifecycle workflow into a reusable pr plugin

Start date: 2026-09-14 12:31:34 MDT

Tracks https://github.com/cjus/cjus-skills/issues/1. The issue body is the plan of record; this file exists so a returning session has local, forward-looking status without re-reading the issue every time. Newly discovered work goes under `## Deferred`, never as new scope: the objective is fixed at branch creation.

## Overview

Package the PR lifecycle workflow, developed in a private repo, as a self-contained `pr` plugin in this marketplace, alongside `bookcraft`. GitHub issues remain the ticket system: the issue number is the ticket number, two labels carry state, and the merge closes the ticket.

## Decisions settled before filing

| Question | Decision |
|---|---|
| Plugin and skill naming | Plugin `pr`; skills drop their prefix, so `/pr:start`, `/pr:close`, `/pr:ticket`. |
| Reference layer | Plugin-owned docs under `reference/`, cited through `${CLAUDE_PLUGIN_ROOT}`. No skill depends on a consumer repo having a `CLAUDE.md`. |
| Scope | Full port: every skill, the lifecycle state script, both hooks, the code-reviewer agent, and the handoff-document conventions. |
| Branch scheme | `feature/{issue}-{slug}` by default, bare issue number as the ticket ID. A repo wanting `ABC-123`-style IDs sets a prefix in config. |
| Configuration | A new `/pr:init` detects what it can, asks about the rest, writes `.claude/pr-config.json`, and creates the `status:*` / `priority:*` labels. |
| Worktrees | Configurable, default on. Every downstream skill needs a working no-worktree path. |
| Close gate | The `Stop` hook keeps blocking an armed close until its required artifacts are committed and pushed; which artifacts are required comes from config. |

## Plan

- [x] Reference layer: ticketing, git conventions, evidence discipline, scope contract, handoff docs, assertion audit, lifecycle, config
- [x] `/pr:init` writes `.claude/pr-config.json` and bootstraps the labels
- [x] `/pr:ticket`, `/pr:start`, `/pr:pre-test`, `/pr:close`, `/pr:cleanup`
- [x] Work-band skills: `/pr:cp`, `/pr:status`, `/pr:resume`, `/pr:sync`, `/pr:plan-check`, `/pr:precompact`, `/pr:condense`, `/pr:summary`, `/pr:commitmsg`, `/pr:abort`
- [x] Queue skills: `/pr:next`, `/pr:reviews`, `/pr:triage`
- [x] `/pr:sanity`
- [x] Handoff-document skills: `/pr:continuity-add`, `/pr:continuity-prune`
- [x] Code-reviewer agent with the review rubric folded in
- [x] Lifecycle state script, config-driven, verified against this repo
- [x] `Stop` hook (close-landed guarantee), config-driven required artifacts
- [x] Default-branch guard hook, approval token configurable, 39-case probe suite passing
- [x] SessionStart hook (third hook, added because two skills referenced it)
- [x] De-identification sweep: zero source-repo identifiers, zero em-dashes
- [x] Rationale rewritten as mechanism rather than the source repo's measurements
- [x] Packaging: `plugin.json`, marketplace entry, README section, both manifests pass `--strict`
- [x] Acceptance: installed from a local marketplace, 28-case suite green against the installed copy
- [x] Two defects found by that acceptance run and fixed (see `CHANGELOG.md`)

## Deferred

- The GitHub-dependent half of the lifecycle (`gh issue create`, the closing-reference assertion, label transitions) is proven only against this repo's own issue #1, not re-run in a throwaway GitHub repo. Doing that would mean creating a scratch repo on the account.
- No CI in this repo runs either test suite or validates the manifests on push.
- `/pr:init`'s detection table covers node, cargo and go. Python is deliberately left to ask.
- The skills themselves are instructions for a model, so no suite exercises them; only their shared machinery is covered.

## Open Questions

- None. The eight decisions settled with the operator are recorded in the table above.
