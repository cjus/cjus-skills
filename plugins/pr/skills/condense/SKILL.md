---
name: condense
description: Refresh PLAN.md status and shrink an oversized CHANGELOG.md for the current branch, preserving timestamps. Use when the user says "/pr:condense", when the branch's changelog has grown unwieldy, or as a step of /pr:close.
allowed-tools: Bash(node:*), Bash(git:*), Bash(date:*), Write, Read, Edit
---

# /pr:condense

## Steps

1. **Resolve the plan folder.**

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline --text
   ```

   `PLAN.md` and `CHANGELOG.md` live in `<changelogRoot>/<branch-slug>/`.

2. **Bring `PLAN.md` up to date with the branch's real state.**

   > **Status only, never scope.** The objective was fixed at `/pr:start` and is immutable for the life of the branch. Newly discovered work goes under `## Deferred`.
   >
   > **Park it and keep moving. Do not ask about ticketing here.** `## Deferred` is a triage inbox, not a backlog; triage runs once, inside `/pr:close`, where DROP is the default. See `${CLAUDE_PLUGIN_ROOT}/reference/scope-contract.md`.

3. **Shrink `CHANGELOG.md`** by summarizing its content.

   **Retain every timestamp.** They are the only record of when the work actually happened, and a condensed log that drops them cannot be reconciled against `git log` afterward. Summarize what happened under each timestamp; never merge two timestamps into one.
