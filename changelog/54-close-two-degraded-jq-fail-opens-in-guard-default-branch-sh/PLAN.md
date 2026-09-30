# Close two degraded-jq fail-opens in guard-default-branch.sh

Start date: 2026-09-30 13:16:16 MDT

Ticket: #54 (status:todo -> status:in-progress)

## Overview

`plugins/pr/hooks/guard-default-branch.sh` has two degraded paths when `jq` misbehaves. Each one
lets a default-branch commit or push run without a prompt and without output:

1. **No jq, whole payload.** The no-jq branch runs `GIT_VERB` against the raw JSON payload, so
   the verb's boundaries are JSON syntax rather than the command's own characters. If the
   command ends in its verb, the character after the verb is the string's closing `"`, which
   `GIT_VERB`'s trailing group rejects. If the verb starts a later line, the text before `git`
   is the escape `\n`, and `GIT_VERB`'s leading group rejects its `n`. Either way, the hook
   exits 0. The jq path answers `ask` for the same commands.
2. **jq on `PATH` but unable to run.** `HAVE_JQ` is set by `command -v jq` alone, so a jq that
   exits 126 (for example a stray x86 binary on Apple Silicon) takes the jq branch. The parse
   fails and `gate()` runs, but `gate()` builds its output with `jq -nc`, which fails too. The
   hook prints nothing and exits 0, so every default-branch commit or push passes.

The objective has three parts:

- Make the no-jq branch gate a whole payload wherever the jq path would, at least as far as
  JSON encoding at the verb's boundaries is concerned. That covers the closing quote after the
  verb and escape sequences on either side of it.
- Make sure a jq that is present but cannot run never leaves the hook silent.
- Pin each fix with probes in `plugins/pr/hooks/test-guard-default-branch.sh` that fail without
  it.

The branch keeps the no-jq branch's documented contract, "Over-matches, never under-matches",
and every behaviour the suite already pins.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#54: Close two degraded-jq fail-opens in guard-default-branch.sh**

Labels at start: `bug`, `status:todo`, `priority:high`.

> Escalated from the review of #1 (PR #53), under the scope contract's rule that a pre-existing
> security defect is filed immediately. Both holes give the same results on `main` and on #1's
> branch. Both are much more likely to occur than the truncation #1 fixed.
>
> - [ ] **No jq, whole payload: a command that ends in its verb, or has it at the start of a
>   later line, runs unguarded.** The raw-payload branch matches `GIT_VERB` against the raw
>   JSON.
>   - When the command ends in its verb, the next character is the JSON string's closing
>     quote, which `GIT_VERB`'s trailing group does not accept. This covers `git push`,
>     `git commit` and `cd /x && git push`.
>   - When the verb starts a later line, the raw text before `git` is `\n`. Its `n` fails
>     `GIT_VERB`'s leading non-alphanumeric group. This covers `git add -A`⏎`git commit -m x`
>     and `ls`⏎`git push origin main`.
>   - All of these pass on the default branch. With jq, the hook answers `ask` for them.
> - [ ] **jq present but unable to run: every default-branch commit or push runs unguarded.**
>   An example is a stray x86 jq on Apple Silicon, which `plugins/pr/hooks/README.md` already
>   names as a known case.
>   - The parse fails, so `gate()` runs. But `gate()`'s own `jq -nc` fails too, so the hook
>     prints nothing and exits 0.
>   - `git commit -m x` passes along with everything else.
>
> Each fix needs probes in `plugins/pr/hooks/test-guard-default-branch.sh` that fail without
> it.
> - For the first item, the no-jq harness that #1 added (`nj`/`rawp`, with a links-only
>   `PATH`) already exists.
> - For the second, a broken-jq harness can put a stub `jq` that exits 126 first on `PATH`.

No comments on the issue at start.

## Plan

- [x] Phase 1: Reproduce both holes against `main` @ `a26f79c` in opted-in throwaway repos.
      - For item 1, use a links-only `PATH` with no jq. Try `git push`, `git commit`,
        `cd /x && git push`, `git add -A`⏎`git commit -m x` and `ls`⏎`git push origin main`.
        Compare each with the jq path's `ask`.
      - Also try a verb followed by an escaped newline or tab, such as `git push`⏎`echo done`.
        It has the same cause, since the character after `push` is the escape's `\`.
      - For item 2, put a stub `jq` that exits 126 first on `PATH` and send `git commit -m x`.
      - Record every run in `CHANGELOG.md`.
- [x] Phase 2: Write the probes first.
      - Add `nj` cases for each shape from item 1, including one under `bypassPermissions` so
        that `deny` is pinned as well as `ask`.
      - Add a broken-jq harness, a stub `jq` exiting 126 first on the hook's `PATH`, with
        cases for a default-branch commit and for a non-git command.
      - Confirm every new case fails against the current hook.
- [x] Phase 3: Fix item 1 in the no-jq branch so that `GIT_VERB` sees the verb's real
      boundaries. The completeness check, the approval token, mode recovery and the
      `ask`/`deny` split must all behave as they do now.
- [x] Phase 4: Fix item 2 so that a jq that cannot run never leaves the hook silent, and so
      that the hook's output is still well-formed JSON with a decision in it.
- [x] Phase 5: Show that each fix is what closes its hole. Remove each fix in turn, confirm its
      probes fail, then restore it. Run the full suite and report the new case count.
- [x] Phase 6: Update the documentation that describes these paths:
      - the no-jq comment block, `gate()`'s comment and the header's decision table in the hook
      - the case count (91 at start) and the expected failure shapes in
        `plugins/pr/hooks/README.md`, including the "jq cannot run" line, whose shape may
        change

## Open Questions

- **How should item 1 be fixed: widen `GIT_VERB`'s boundaries for the raw branch, or decode
  the command first?** Option one is a raw-only variant whose leading group also accepts a JSON
  escape (`\n`, `\t`, `\r`) and whose trailing group also accepts the closing `"` and a
  following escape. Option two extracts the `command` value (the completeness check already
  matches it) and unescapes it in bash before running the same `GIT_VERB` the jq path uses.
  Option two removes the whole class of boundary mismatches. Its risk is an unescape that
  misreads `\\n`, where an escaped backslash comes before an `n`. Either option must
  over-match rather than under-match.
  **Resolved 2026-09-30: widen.** Decoding with bash builtins means `${s//…/…}`, which grows
  roughly with the cube of the length under bash 3.2: 1.1s for 10KB, 66s for 40KB. That rules
  it out on a path that runs for every Bash call. `GIT_VERB_RAW` adds one escape class,
  `\\([bfnrt]|u[0-9a-fA-F]{4})`, before `git`, in whitespace runs and after the verb, and
  accepts the unescaped closing `"` after the verb. The differential test found no under-match
  in 160,000 checks on macOS and 80,000 on Linux. The worst 1MB case took about 0.4s. The `\\n`
  risk became two precision probes.
- **Where should item 2 be caught?**
  - Probe jq at start-up, so that `HAVE_JQ` means "jq runs" rather than "jq is on `PATH`".
    That costs one more process on every Bash call.
  - Reclassify after the parse fails with exit 126 or 127, falling through to the no-jq
    branch. That adds nothing on the happy path.
  - Have `gate()` fall back to `printf` when `jq -nc` fails, so that it can never print
    nothing. That makes `gate()` safe for every caller, but on its own it denies with a "could
    not be parsed" reason that misnames the cause.
  - Some combination of these may be needed. The deciding property is that no route through
    `gate()` exits 0 silently.
  **Resolved 2026-09-30: reclassify, plus the `gate()` fallback.** After a failed parse,
  `jq -n true` is run once, which is more general than checking for exit 126 or 127. If jq
  runs, the payload is denied as before; if not, the no-jq branch runs. Handing every failed
  parse to that branch was rejected, because a trailing-comma payload would then ask, and a
  probe pins it. `gate()` falls back to `printf` whenever `jq -nc` prints nothing, and swaps a
  reason `printf` cannot escape for a fixed one.
- **Should a broken jq ask or deny?** The no-jq branch asks in a prompting mode, because only
  the parser is missing and the payload is trustworthy. A jq that cannot run is the same
  situation, not a malformed payload. Routing it through the parse-failure gate would deny in
  every mode.
  **Resolved 2026-09-30 by the operator: ask**, exactly as when jq is missing. Prompting modes
  ask, `bypassPermissions` denies, non-git commands pass, and a payload that did not arrive
  whole is denied.

**Phase 2's "every new case fails" held for the 15 gating cases only.** The other 7 pass
either way: two check the harness or guard against regression, and mutants turn the other
five red. See `CHANGELOG.md`.

## Deferred

- **Nothing checks that `GIT_VERB_RAW` keeps in step with `GIT_VERB`.** The comment says to keep
  them in step, and the item-1 probes would catch a drift that loses one of their shapes, but
  not a new shape added to `GIT_VERB` alone. A suite section that runs one command list through
  both the jq and no-jq paths and compares the decisions would.
- **The hook header's "ON EVIDENCE" paragraph still says the plugin "ships NO test suite"**,
  which has been stale since the suite existed. #1 deferred it too. This branch edits the
  decision table just above it, not that paragraph.

## Recent Context

`changelog/1-guard-default-branch-sh-under-matches-a-truncated-payload-when-jq-is-absent/`
added the no-jq completeness check and the `nj`/`rawp` harness this branch builds on. Its
`## Deferred` section lists two more hook items: invalid UTF-8 under a UTF-8 locale, and the
suite having no fast exit when its own jq is broken. Neither is in scope here.
