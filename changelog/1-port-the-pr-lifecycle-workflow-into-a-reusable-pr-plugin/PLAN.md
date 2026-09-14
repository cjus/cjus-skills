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

- [ ] `/pr:init` writes `.claude/pr-config.json` and bootstraps the labels (labels already bootstrapped by hand on this repo, see `CHANGELOG.md`)
- [ ] `/pr:ticket`
- [ ] `/pr:start`
- [ ] `/pr:pre-test`
- [ ] `/pr:close`
- [ ] `/pr:cleanup`
- [ ] Work-band skills: `/pr:cp`, `/pr:status`, `/pr:resume`, `/pr:sync`, `/pr:plan-check`, `/pr:precompact`, `/pr:condense`, `/pr:summary`, `/pr:commitmsg`, `/pr:abort`
- [ ] Queue skills: `/pr:next`, `/pr:reviews`, `/pr:triage`
- [ ] `/pr:sanity`
- [ ] Handoff-document skills (additive + destructive)
- [ ] Code-reviewer agent + review rubric
- [ ] Lifecycle state script, prefix-configurable
- [ ] Lifecycle map document
- [ ] `Stop` hook (close-landed guarantee)
- [ ] Main-branch guard hook, approval token renamed
- [ ] De-identification pass across the ported material
- [ ] Rationale rewrite for the incident-derived gates (mechanism, not the private repo's measurements)
- [ ] Packaging: `plugin.json`, marketplace entry, README section, `claude plugin validate --strict`
- [ ] Acceptance: install into an unrelated repo and complete one real ticket end to end; grep the published plugin for source-repo identifiers and get nothing

Full detail, including the acceptance criteria and the de-identification checklist, lives in the issue body rather than duplicated here.

## Open Questions

- None yet — see the issue for the eight decisions already settled with the operator.
