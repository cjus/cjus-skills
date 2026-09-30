# guard-default-branch.sh under-matches a truncated payload when jq is absent

Start date: 2026-09-30 10:51:36 MDT

Ticket: #1 (status:todo -> status:in-progress)

## Overview

`plugins/pr/hooks/guard-default-branch.sh` has two ways to read a `PreToolUse` payload. With
`jq`, it parses the payload and emits a sentinel last, so the sentinel's presence proves the
parse finished. A payload that fails to parse goes to `gate()` and is denied. Without `jq`, the
degraded branch runs `GIT_VERB` against the raw payload text. It documents its contract as
"Over-matches, never under-matches", but it has no equivalent of the sentinel. Suppose the
payload is cut off inside the `command` value, before the git verb. Then nothing in what remains
matches, the branch exits 0, and a commit or push on the default branch runs unguarded.

The objective is to make the no-jq branch detect a payload that did not arrive whole, and to
send it to the same `gate()` deny the jq path uses for an unparseable payload. Every degraded
path then fails toward the operator. The branch also adds a case to
`plugins/pr/hooks/test-guard-default-branch.sh` that fails without the fix and passes with it,
and updates the suite's documented case count to match.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#1: guard-default-branch.sh under-matches a truncated payload when jq is absent**

Labels at start: `bug`, `status:todo`, `priority:medium`.

> Found during the review of #3, where it was marked DROP as pre-existing and out of scope.
> Filed because it is a correctness gap in a fail-closed guard, which the scope contract
> escalates regardless of likelihood.
>
> ### Symptom
>
> With `jq` absent **and** a `PreToolUse` payload truncated mid-`command`, the degraded
> raw-match branch of `plugins/pr/hooks/guard-default-branch.sh` finds no git verb in the
> truncated string and exits 0. A commit or push on the default branch then runs unguarded,
> silently.
>
> ### Why it matters more than its likelihood suggests
>
> That branch documents its own contract as **"Over-matches, never under-matches."** An
> under-match is therefore not a tolerated edge case but a contradiction of the property the
> branch exists to provide. Every other degraded path in this hook fails toward the operator.
>
> The guard's header is explicit that nearly every defence in it exists because the obvious
> spelling was measured to fail open, and that reading the hook is not evidence. Two review
> rounds on #3 each found one further fail-open in the new activation logic, so the base rate
> for "this path is fine" in this file is poor.
>
> ### Preconditions
>
> Both must hold simultaneously, which is why this is medium rather than high:
>
> 1. `jq` is not on `PATH`, so the hook takes the raw-regex branch.
> 2. The payload is truncated inside the `command` value, so `GIT_VERB` does not match what
>    survives.
>
> ### Occasion
>
> Next time the no-`jq` branch is touched, or any work on payload parsing in that hook.
>
> ### Suggested direction
>
> The no-`jq` branch already matches `ALLOW_TOKEN_RAW` anchored to the `"command"` key. A
> truncated payload could be detected the same way the jq path detects one -- the sentinel
> there proves the expression ran to completion -- and treated as unparseable, which routes it
> to the existing `gate()` deny rather than to a silent exit 0.
>
> Whatever the fix, it needs a case in `hooks/test-guard-default-branch.sh` that fails without
> it. The suite is at 54 cases and its convention is that every defence is pinned by a probe.

**Corrections from the issue's comments:**

- **The "#3" in the body predates the repository rebuild.** In this repo, #3 is an unrelated
  issue about council state, so it is not a reference to follow.
- **The suite has 73 cases, not 54.** The count is self-describing: `passed N, failed N,
  skipped N  (73 cases)`. Only the two linked-worktree cases can skip. `plugins/pr/hooks/README.md`
  pins the 73 and says that any other total means the line is stale.
- **Triage on 2026-09-24 confirmed the issue is still valid.** The no-jq branch still has no
  truncation check: it gates or exits 0 on `GIT_VERB` alone.

## Plan

- [x] Phase 1: Reproduce. Run the hook with `jq` off `PATH` on a default-branch fixture. First
      send a whole `git commit` payload and see it gated. Then send the same payload truncated
      inside `command`, before the verb, and see the hook exit 0 with no output. Record both
      runs in `CHANGELOG.md`.
- [x] Phase 2: Add the probe(s) to `test-guard-default-branch.sh` first. Run the hook with a
      `PATH` that has `bash`, `git` and `grep` but no `jq`, and check that a payload truncated
      mid-`command` gets `deny`. Confirm the new case fails against the current hook.
- [x] Phase 3: Fix the no-jq branch in `guard-default-branch.sh`. Before the `GIT_VERB` test,
      check that the payload arrived whole. When it did not, call `gate()` with a
      "could not be parsed" reason and do not recover the mode, so the result is `deny`, as on
      the jq path. The existing no-jq behaviour for a whole payload must not change: the
      approval token, mode recovery and the `ask`/`deny` split all stay as they are.
- [x] Phase 4: Show that the fix is what closes the hole. Remove the new check and confirm the
      probe fails again, then restore it. Run the full suite and report the new case count.
- [x] Phase 5: Update the documentation that describes this path: the no-jq comment block and
      the header's decision table in the hook, and the case count (73) with its explanation in
      `plugins/pr/hooks/README.md`.

## Open Questions

- **What counts as "arrived whole" without jq?** Candidates: the `"command"` value has an
  unescaped closing quote, the payload ends in `}` after trailing whitespace, or both. Checking
  only the closing quote misses a payload cut after `command` but before the object closes.
  Checking only the trailing `}` misses a cut exactly after a nested `}`. A payload cut
  before the `"command"` key even appears must be caught too.
  **Resolved 2026-09-30:** both. Each half is pinned by a case only it catches. The one cut
  both pass comes after the command has closed, so GIT_VERB still reads all of it.
- **Should a truncated payload be denied even when it contains no git verb?** The jq path
  denies an unparseable payload whatever it holds, and matching that is the consistent choice.
  But this path runs on every Bash call, so a false positive in the completeness check would
  block commands that have nothing to do with git. The check has to be tight enough that a
  whole payload never trips it.
  **Resolved 2026-09-30:** yes. The ticket's hole is exactly a cut payload with no verb left.
  Five whole non-git payloads pass: escaped quotes with a trailing backslash, newlines,
  non-ASCII and pretty-printed JSON, plus a plain `ls -la`.
- **Does the approval token still count on a truncated payload?** `ALLOW_TOKEN_RAW` is
  anchored to the start of `command`, so a payload cut after the token but before the git verb
  could still carry it. The jq path gives no approval to an unparseable payload. The likely
  answer is to check completeness before the token.
  **Resolved 2026-09-30:** no. The check runs before the token, which is pinned by
  "cut after the approval token" and by a mutant that moves the token check first.
- **How does the suite simulate jq's absence?** The suite builds its payloads with `jq`, so
  it needs `jq` itself. The hook alone has to run with a `PATH` that leaves `jq` out. No case
  covers the no-jq branch today, so this may be the first, and the shim must not break the
  suite's other cases.
  **Resolved 2026-09-30:** a temp folder of links to `cat`, `git`, `grep` and `dirname` only.
  Dropping a directory is not enough, because macOS ships `/usr/bin/jq`. The first no-jq case
  checks that jq is hidden. The 73 existing cases are unchanged.

## Deferred

- **The hook's header says the plugin "ships NO test suite for it"**
  (`guard-default-branch.sh`, header, "ON EVIDENCE" paragraph). That is stale:
  `test-guard-default-branch.sh` exists and runs 73 cases. It is outside this objective unless
  Phase 5 is already editing that paragraph.
- **Invalid UTF-8 defeats every bash regex in the no-jq branch under a UTF-8 locale.** Measured
  on bash 3.2.57: `=~` matches nothing in such a payload, not even a trailing `}`. Before this
  branch, `git commit -m x` in such a payload exited 0; under `LC_ALL=C` it was gated. The new
  completeness check now denies it, but with a "did not arrive whole" reason that misnames the
  cause, and no probe pins it, because a probe would need a UTF-8 locale installed. Claude Code
  sends valid UTF-8, so this is not live.
- **The suite has no fast exit when its own jq is missing or broken.** It reports a mass
  failure instead (33/58 or 6/85), and the missing-jq shape depends on the directory it is run
  from, because the `t()` cases do not pin `CLAUDE_PROJECT_DIR`. The README now documents both
  shapes. A precheck like `printf '{}' | jq -e .` would replace them with one clear error.
