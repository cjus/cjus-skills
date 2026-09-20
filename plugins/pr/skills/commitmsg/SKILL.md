---
name: commitmsg
description: Write COMMITMSG.md in the branch's plan folder, covering only the uncommitted changes. Use when the user says "/pr:commitmsg", asks for a commit message, or when /pr:close needs the message its commit will use.
allowed-tools: Bash(node:*), Bash(git:*), Bash(date:*), Write, Read, Edit
---

# /pr:commitmsg

Write the commit message `/pr:close` will commit with.

## Steps

1. **Resolve the plan folder.**

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline --text
   ```

   The folder is `<changelogRoot>/<branch-slug>/` at the repo root.

2. **See what is uncommitted**, staged and unstaged both:

   ```bash
   git status
   git diff --stat
   git diff
   git diff --cached
   ```

3. **Write `COMMITMSG.md`** into the plan folder:

   ```
   {short imperative summary, under 80 characters}

   {one line per item in the uncommitted changes}
   ```

   The summary follows `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`: imperative mood, lowercase, no trailing period. "add websocket retry logic", not "Added WebSocket retry logic."

## The one rule that makes this useful

**Describe only what is NOT yet committed.** Do not include items from earlier commits on this branch. The file exists so `/pr:close` can commit the closing artifacts with an accurate message, and a summary that restates the whole branch makes that commit read as though it did everything.

**No machine-authorship markers, and no secret values.**
