---
name: precompact
description: Bring PLAN.md fully current before a context compaction, including explicit resume steps written for an agent with none of the current context. Use when the user says "/pr:precompact" or right before a compaction.
allowed-tools: Bash(node:*), Bash(git:*), Read, Edit, Write
---

# /pr:precompact

**This runs in preparation for context compaction.** Afterward most of the working session is gone, and the next agent, likely you with a fresh context window, will rely almost entirely on `PLAN.md` to resume.

Treat this as a handoff to somebody who has none of the context you have right now. Where the SessionStart hook is installed, it rehydrates the successor from the branch folder, so what you write here is exactly what it will see.

## Steps

1. **Check the branch.**

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --text
   ```

   **On the default branch** there is no active work stream to preserve. Say so briefly and stop. Do not create or edit any `PLAN.md`.

   **No plan folder** for this branch, because it was created without `/pr:start`? Ask the operator rather than guessing which folder to write.

2. **Snapshot the real state**, so the update reflects ground truth rather than conversation memory:

   ```bash
   git status
   git log "$DEFAULT_BRANCH"..HEAD --oneline
   git diff "$DEFAULT_BRANCH"...HEAD --stat
   ```

3. **Bring `PLAN.md` up to date** against that snapshot:

   - Mark completed items done, and correct stale "what is left" claims.
   - **Capture decisions and discoveries that exist only in conversation context** and would otherwise be lost. This is the highest-value part of the step.
   - Note uncommitted work in progress and where it stands.

4. **Write an explicit `## Resume after compaction` section** at the end, replacing any prior one. It must let a context-free agent pick up cleanly:

   - **Current state.** One or two lines: what is done, what is in flight.
   - **Next steps.** Concrete and ordered, naming file paths, commands and symbols. Not vague intentions.
   - **Watch-outs.** Gotchas, failing checks, blocked items, and edits not yet committed.
   - **Verification.** How to confirm the work so far is correct.

   **Hook caveat:** where the folder already holds a `pr-summary-*.md`, the SessionStart hook loads that **instead of** `PLAN.md`. In that case append a one-line pointer to the newest summary, such as "See `PLAN.md` § Resume after compaction for current state", so the successor still lands on the resume steps.

5. **Report** that the plan is current and the resume section is written, and state the top next step in one line.

**Do not commit.** This is compaction prep, and the operator may want to keep working. Commit only if asked.
