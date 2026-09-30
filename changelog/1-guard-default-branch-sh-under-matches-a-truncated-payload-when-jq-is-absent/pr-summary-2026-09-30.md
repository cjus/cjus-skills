# guard-default-branch.sh under-matches a truncated payload when jq is absent

## Overview

When `jq` is missing, `plugins/pr/hooks/guard-default-branch.sh` falls back to matching the raw
`PreToolUse` payload. That fallback's own contract is "over-matches, never under-matches", and
it broke that contract on a payload that did not arrive whole. If the payload was cut inside the
`command` value, before the git verb, `GIT_VERB` found nothing, the hook exited 0, and a commit or
push on the default branch ran unguarded. An empty payload took the same exit. The jq path
already denies both, because its sentinel proves the parse finished.

This PR gives the no-jq path the same guarantee. Before it reads anything else from the raw
payload, the path now checks that the payload arrived whole. A payload that fails the check goes
to the existing `gate()` with the mode unrecovered, so it is denied in every permission mode,
just as the jq path's unparseable-payload gate denies. A whole payload gets exactly the decision
it got before. The probe suite gains the first cases that cover the no-jq path at all: 18 of
them, taking it from 73 cases to 91.

## Key changes

- **`plugins/pr/hooks/guard-default-branch.sh`.** The no-jq branch now starts with a two-part
  completeness check, placed before the approval token and before mode recovery. Its comment
  explains:
  - what the check proves
  - why each half is needed
  - the class of cuts it cannot see, and why those are harmless
  - the schema assumption the closing-quote half relies on
  - why it runs first

  The header's decision table has a new row for it.
- **`plugins/pr/hooks/test-guard-default-branch.sh`.** Three new sections run the hook with jq
  hidden, through a folder of links to only `cat`, `git`, `grep` and `dirname`. The first case
  checks that jq really is hidden. The sections cover:
  - Whole payloads keep their behaviour: 4 cases.
  - Whole non-git payloads must not gate: 5 cases, since this path runs on every Bash call.
  - Truncated payloads fail closed: 8 cases. Six of them fail against the unfixed hook.
- **`plugins/pr/hooks/README.md`.**
  - The case count goes from 73 to 91, and the coverage list now includes the no-jq path.
  - A note explains why dropping a directory from `PATH` does not hide jq on macOS.
  - The mass-failure paragraph was rewritten with the two shapes, measured again after this change.
- **`plugins/pr/.claude-plugin/plugin.json`.** `pr` goes from 0.2.9 to 0.2.10.

## Code examples

The check, at the head of the no-jq branch in `plugins/pr/hooks/guard-default-branch.sh`:

```bash
PAYLOAD_CMD_RAW='"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"'
PAYLOAD_END_RAW='[}][[:space:]]*$'
if ! [[ $INPUT =~ $PAYLOAD_CMD_RAW && $INPUT =~ $PAYLOAD_END_RAW ]]; then
  gate "jq not found, and the PreToolUse payload did not arrive whole, so the default-branch commit guard cannot read the command."
fi
```

The check has two halves:

- **The closing quote.** The first half reads the `command` value as JSON escapes: a `\` always
  pairs with the character after it. So it matches only when the value closes on a genuine,
  unescaped quote.
- **The trailing brace.** The second half requires the object to end in `}`.

Each half misses a cut the other catches. A cut after the command but before the object ends
passes the closing-quote half. A cut just after a `}` inside the command passes the
trailing-brace half.

A truncation probe, from `plugins/pr/hooks/test-guard-default-branch.sh`. It is cut from a whole
payload in mode `default`, so a check that recovered the mode from the fragment would answer
`ask`:

```bash
P=$(rawp default 'echo "a" && f() { :; }; git commit -m x')
nj "cut just after a } inside the command"  deny "${P%%; git commit*}"
```

The fragment ends in `}`, so only the closing-quote half catches it. The leading `echo "a"` is
there so that a check letting any `"` close the value, including an escaped one, also fails
this case.

## Plan alignment

Every phase went as planned:

| Phase | Outcome |
|---|---|
| 1. Reproduce | Done. With jq hidden, a whole commit got `ask`. The same payload cut before the verb exited 0 with no output. Empty stdin did the same, which the ticket did not name. |
| 2. Probes first | Done. Against the unfixed hook: `passed 85, failed 6 (91 cases)`, and the six failures were exactly the truncation cases. |
| 3. Fix | Done. The check runs before the token and the mode recovery, and whole-payload behaviour is unchanged. |
| 4. Prove the fix closes the hole | Done, and wider than planned. Seven mutants were each caught by the case written for it, as tabled below. |
| 5. Docs | Done. Hook comment block, header decision table, README count and explanation. |

The plan's four open questions all got answers:

- **What counts as whole:** both halves together.
- **Deny a cut payload with no git verb in it:** yes. That payload is exactly the ticket's hole.
- **Does the approval token count on a cut payload:** no, because the check runs first.
- **How to hide jq:** the links-only `PATH`. Dropping a directory is not enough, because
  macOS ships `/usr/bin/jq`.

There are three deviations, all additions rather than changes of scope:

- **Empty stdin is covered.** The ticket named only a cut inside `command`.
- **The phase 5 README work went further than planned.** The mass-failure paragraph's "31/42"
  shape stopped being true once the suite's empty payloads reached a path that denies them, so
  that paragraph was re-measured and rewritten.
- **A review finding led to a wording change.** A new README sentence claimed whole-payload
  parity with the jq path. It was replaced with "the decision it always did", because parity is
  not true and the suite does not claim it.

## Testing

**Automated.** The guard suite gives `passed 91, failed 0, skipped 0  (91 cases)` on macOS with
bash 3.2.57. The reviewer also ran it on Ubuntu 24.04 with bash 5.2 and the glibc regex: 91/91
on the branch, and 85/6 against `main`'s hook. `plugins/pr/scripts/test-acceptance.sh` passes
42 of 42 against the source tree. CI's `fixtures` jobs pass on macOS and Ubuntu. CI does not run
the guard suite.

**Mutation proof.** Each mutant was applied to a copy of the fixed hook, and the full suite was
run against it:

| Mutant | Result | Caught by |
|---|---|---|
| check removed | 85/91 | all 6 truncation cases |
| closing-quote half only | 90/91 | cut after the command, before the end |
| trailing-brace half only | 90/91 | cut just after a `}` inside the command |
| any `"` closes the value | 90/91 | the same `}` case, through its `echo "a"` |
| a `"` closes unless a backslash precedes it | 90/91 | escaped quotes, trailing backslash |
| approval token honoured before the check | 90/91 | cut after the approval token |
| mode recovered before the check | 86/91 | 5 truncation cases answer `ask` |

**Prefix sweeps.** The author ran every strict prefix of four sample payloads under `C` and
`en_US.UTF-8`. The reviewer independently ran every byte prefix of 11 payloads under two locales
on each of macOS and Linux. Neither sweep found a cut inside the command that got past the
check, and no whole payload was rejected.

**By hand.** Build a PATH folder that holds links to only `cat`, `git`, `grep` and `dirname`, and
use a repo that has `.claude/pr-config.json`. Pipe a `PreToolUse` payload for `git commit -m x`
into the hook with `CLAUDE_PROJECT_DIR` pointed at that repo, and it answers `ask`. Cut the same
payload just before `git`, and it now answers `deny`. Before this PR, the cut payload produced
no output at all.

**Edge cases considered:**

- a trailing backslash in the command, which closes on `\\"`
- escaped quotes before the cut
- a `}` inside the command
- multi-line commands, non-ASCII text, and pretty-printed JSON
- a trailing newline after the payload
- a cut after the approval token
- a truncated payload in an unconfigured repo, which stays inert
- cost: about 0.08s for the check on a 1MB command

## Impact assessment

Four files under `plugins/pr` change, with 159 lines added and 16 removed, plus this branch's
plan folder. There are no dependency changes.

- **Behaviour.** The change is limited to the no-jq path. There it now answers `deny` on a
  payload that is empty or cut short, where it used to exit silently. A whole payload is
  unaffected: the reviewer compared `main`'s hook and this branch's hook on whole payloads with
  jq hidden, and every one got the same decision. The jq path is untouched.
- **A side effect, in the safe direction.** Under a UTF-8 locale, a payload containing an
  invalid UTF-8 byte used to let `git commit -m x` through the no-jq path. That happens because
  bash's `=~` then matches nothing in the payload. The new check now denies such a payload.
  Claude Code sends valid UTF-8, so this is edge-case hardening, not a live hole.
- **Breaking changes.** None.

## Deferred work

The review found two pre-existing fail-opens on the degraded-jq paths. Both behave the same on
`main` and on this branch:

- **No jq, whole payload.** A command that ends in its verb, or has the verb at the start of a
  later line, passes unguarded.
- **A jq that cannot run.** The hook passes everything, because `gate()`'s own `jq -nc` fails.

The scope contract says a pre-existing security defect is filed immediately, as an escalation
rather than a deferral, so both went into one issue, #54, as a two-item checklist.

Parked under `## Deferred` in `PLAN.md`, for triage at close:

- **A stale header line.** The hook's "ON EVIDENCE" paragraph still says the plugin ships no
  test suite for the hook, though the suite exists and now runs 91 cases.
- **A misleading reason for invalid UTF-8.** The deny above gives the "did not arrive whole"
  reason, which misnames the cause. No probe pins it, because a probe would need a UTF-8 locale
  to be installed.
- **No fast exit in the suite.** When the suite's own jq is missing or broken, it has no
  early exit and reports a mass failure instead. Where the suite runs from also changes the
  missing-jq shape. The README documents both shapes.

The review also noted that CI does not run the guard suite. It dropped that item, since it had
checked this change on glibc by hand.
