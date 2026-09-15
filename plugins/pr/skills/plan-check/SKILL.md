---
name: plan-check
description: Check whether the branch's PLAN.md still matches reality, refresh its status, and state the concrete next steps. Use when the user says "/pr:plan-check", asks whether the plan is current, or wants to know what is left on the branch.
allowed-tools: Bash(node:*), Bash(git:*), Bash(date:*), Write, Read, Edit
---

# /pr:plan-check

## Steps

1. **Resolve the plan folder and the branch's real state.**

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --text
   ```

2. **Review `PLAN.md`** against that state. Look specifically for stale claims about what was done, what is left, and what comes next, and correct them.

   > **Update status, never scope.** The objective fixed at `/pr:start` is immutable for the life of the branch. Refresh what is done, what is left, and the next steps. **Do not add newly discovered work as a new plan checkbox**: that silently raises the acceptance bar, and it is a leading cause of branches that never converge.
   >
   > Newly found work goes under `## Deferred` unless the operator explicitly agrees to expand the objective. **Park it and keep moving. Do not ask about ticketing here**; triage runs once, inside `/pr:close`. See `${CLAUDE_PLUGIN_ROOT}/reference/scope-contract.md`.

3. **State the concrete next steps** from the now-current plan. Name files, commands and symbols, not intentions.

   **If nothing in scope remains open, the next step is `/pr:close`, and the operator runs it.** Say so in those words: it is required before the branch can merge. **Open `## Deferred` items do not hold this back**, since they are triaged inside the close.

## Lifecycle position

`/pr:plan-check` runs inside the work band, whenever `PLAN.md` may have drifted from what the branch actually is. Fold the state check into the report per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.
