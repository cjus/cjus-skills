---
name: ticket
description: Create a GitHub issue from a freeform description, labelled status:todo with priority:high, and report the branch name it yields. Use when the user says "/pr:ticket <description>", asks to file or open a ticket, or when /pr:close triages deferred work into a follow-up issue.
allowed-tools: Bash(node:*), Bash(gh:*), Bash(git:*), Read
argument-hint: <description of what to do>
---

# /pr:ticket

Create a ticket, which in this workflow is a **GitHub issue** on the repo `.claude/pr-config.json` names, from `$ARGUMENTS`.

There is no external tracker. The issue **number** is the ticket number, and the branch derives from it. See `${CLAUDE_PLUGIN_ROOT}/reference/ticketing.md` for the label scheme and `${CLAUDE_PLUGIN_ROOT}/reference/config.md` for how the repo, the prefixes and the slug resolve.

If `$ARGUMENTS` is empty, ask what the ticket should cover and stop.

## What to produce

- **Title.** A concise, imperative summary, roughly ten words or fewer. "the decision log sometimes renders blank on mobile" becomes "Fix blank decision log render on mobile".
- **Body.** A short markdown description capturing the intent. Include any concrete detail the user gave, such as repro steps, acceptance criteria, or the affected area, as bullets. **Do not invent details that were not provided**, and do not pad the body to look thorough.
- **Type label**, optional. Pick one of `bug`, `feature`, `refactor`, `docs`, `infra`, `research` only if the description clearly maps to it. **Omit it entirely if nothing clearly fits.** Never guess.

> **Grouped follow-ups create ONE issue, not one per item.** When `$ARGUMENTS` describes several related items, which is what `/pr:close`'s deferred triage hands over, that grouping is deliberate. File it as a **single** issue whose body is a `- [ ]` checklist, titled for the shared surface area. Never fan a grouped request out into multiple `gh issue create` calls. Split only if the user explicitly asks for separate issues.

## Fixed values

- **Assignee:** `@me`.
- **Status:** `status:todo`. New issues enter the queue `/pr:next` draws from; the label advances only when `/pr:start` begins the work.
- **Priority:** `priority:high`, **always**. Every ticket is filed high. Never downgrade it, never set another value, and never add a note in the body suggesting a different priority even when the work seems lower-urgency. If the user explicitly asks for a different priority, honor that. `reference/ticketing.md` explains why the default carries no ranking information and is still correct.

## Step 1. Resolve the repo and confirm the labels exist

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline --text
```

Take `repo` from that output. If it is unresolved, stop and say so: filing into the wrong repo succeeds silently.

The two labels this skill applies must exist, because `gh issue create` **fails** on an unknown label rather than creating it:

```bash
gh label list --repo "$REPO" --limit 60 --json name --jq '.[].name' | grep -E '^(status:todo|priority:high)$'
```

Both present? Continue. Either missing? Run `/pr:init` first, or create just those two and say you did.

## Step 2. Create the issue

```bash
gh issue create \
  --repo "$REPO" \
  --title "<title>" \
  --body "<body markdown>" \
  --label "status:todo" \
  --label "priority:high" \
  --assignee "@me"
```

Add `--label "<type>"` only when a type label clearly fits.

**Pass a long or backtick-bearing body with `--body-file`**, writing it with the Write tool first. A body on the command line is the shell's to interpret before `gh` sees it, and a backtick or a `$` in a repro step is exactly what a bug report contains.

## Step 3. Derive the branch name

`gh issue create` prints the new issue's URL, whose trailing path segment is the number. Derive the rest by the rule in `reference/config.md`:

1. **Ticket ID** is the number, or `<PREFIX>-<number>` when `ticketPrefix` is set.
2. **Branch** is `<branchPrefix><ticketPrefix-><number>-<slug>`, where the slug is the title lowercased with non-alphanumerics collapsed to single hyphens, then trimmed.

With the defaults, issue 412 titled "Fix blank decision log render on mobile" yields `feature/412-fix-blank-decision-log-render-on-mobile`.

## Step 4. Report the branch name and nothing else

```
feature/412-fix-blank-decision-log-render-on-mobile
```

**That is the entire report.** Do not also recite the title, labels, assignee, issue URL, or a summary of the body. It is all one click away, and the branch name is the one thing `/pr:start` consumes. This is the standing exception to the rule that a ticket is always cited with its full URL: that rule covers **existing** tickets being discussed, and a ticket you just created is not one. See `reference/ticketing.md § Reporting a ticket`.

## Lifecycle position

`/pr:ticket` opens the cycle. `/pr:start` follows and consumes the branch name this skill reports. `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md` has the full map.

Fold the state check into this skill's report per the contract in that file:

- Report each `gaps` entry with its remedy, most consequential first.
- **An empty `gaps` list is one clause, never a section.**
- Name `next` as the recommended next command unless this skill's own steps reached a different one, in which case give yours and say why.
- **Never run `next` yourself.** It is a recommendation, and `/pr:close` in particular is always the operator's to invoke.
