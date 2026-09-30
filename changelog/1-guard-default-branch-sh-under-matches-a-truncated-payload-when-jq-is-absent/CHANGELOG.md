# guard-default-branch.sh under-matches a truncated payload when jq is absent

Start date: 2026-09-30 10:51:36 MDT

When `jq` is absent, the default-branch guard falls back to matching the raw payload. That
fallback promises to over-match and never under-match. A payload cut off inside its `command`
value breaks the promise: no git verb survives the cut, so the hook exits 0 and a commit or push
on the default branch runs unguarded. This branch makes the no-jq path recognise a truncated
payload and deny it, as the jq path already does, and adds a test probe that fails without the fix.

## Changes

### 2026-09-30 10:55:58 MDT — Phase 1: reproduced against `main` @ `3dea6ba`

The hook ran directly, as the harness runs it, against two throwaway repos opted in with
`.claude/pr-config.json`: one on `main` and one on `feature/1-x`. To hide jq, its `PATH` was
a folder of links to only `cat`, `git`, `grep` and `dirname`, under `env -i`. Dropping
`/opt/homebrew/bin` from `PATH` is not enough: macOS also ships `/usr/bin/jq`
(`jq-1.7.1-apple`), so `PATH=/usr/bin:/bin` still takes the jq path. The Phase 2 probe needs
the same links-only folder. The payload uses the harness's key order, with `permission_mode`
ahead of `tool_input`. The truncated payload is the whole one cut just before `git commit`,
so it ends in `"command":"cd /x && `.

| Payload | jq absent | jq present |
|---|---|---|
| whole `git commit`, repo on `main` | `ask`, "jq not found …" | `ask`, "On main …" |
| whole `git commit`, repo on feature branch | `ask`, "jq not found …" | — |
| cut inside `command`, before the verb | **exit 0, no output** | `deny`, "could not be parsed" |
| empty stdin | **exit 0, no output** | `deny`, "could not be parsed" |

The two bold cells are the fail-open. The ticket names only the first. The empty-stdin row is
the same hole at the extreme cut, and it is the case the jq path's sentinel was added to close.
The jq path denies both.

The feature-branch row shows that the no-jq branch gates every commit or push without looking
up the branch. It returns before the branch lookup, which the header's `no jq -> same (fail
toward the operator)` row describes. So the probe needs only an opted-in repo, not one on the
default branch. It does need the opt-in: `gate()` calls `pr_repo_configured` first and exits 0
without it.

### 2026-09-30 11:14:19 MDT — Phases 2–5: probes, the completeness check, mutation proof, docs

**Probes first (Phase 2).** `test-guard-default-branch.sh` has three new sections that run the
hook with jq off its `PATH`. They are the first cases to cover the no-jq branch at all. The
`PATH` is the Phase 1 links-only folder. `CLAUDE_PROJECT_DIR` is set per case, because this
branch never reads the payload's `cwd`, so activation resolves through it. The first case
checks that jq really is hidden. Without that check, every case in the sections could pass by
accident, since the jq path also denies a truncated payload. Against the unfixed hook the run
was `passed 85, failed 6  (91 cases)`, and the 6 failures were exactly the truncation cases.
The 73 existing cases were unchanged.

**The check (Phase 3).** A payload counts as whole when both of these hold:

- a `command` key has a string value that closes on an unescaped quote:
  `"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"`
- the payload ends in `}`, allowing trailing whitespace.

It runs before the approval token and before the mode is recovered from the payload. When it
fails, it calls `gate()` with `MODE` still empty, so the answer is `deny` in every mode, the
same as the jq path's unparseable-payload gate. It uses bash's built-in regex, so it starts no
process. It took 0.08s on a 1MB command under bash 3.2.57.

The plan's open questions were settled like this:

- **What counts as whole:** both halves of the check above. Each alone misses a cut.
- **Deny a cut payload with no git verb in it:** yes. That payload is exactly the ticket's
  hole, and the jq path already denies it.
- **The approval token:** it doesn't count on a cut payload, because the check runs first.
- **Hiding jq:** the links-only folder.

Before writing the check, a prototype tried every strict prefix of four sample payloads under
both the C locale (every byte offset) and UTF-8 (every character offset). The samples covered
a nested `}` inside the command, escaped quotes, a trailing backslash, non-ASCII text and a
multi-line command. No cut inside the command got through. Only two cuts passed the check,
both after the command had closed: one after tool_input's `}`, and one after a `}` inside the
description. No whole payload was rejected, with or without a trailing newline.

**Mutation proof (Phase 4).** Each mutation was applied to a copy of the fixed hook and the
full suite was run against it:

| Mutation | Result | Caught by |
|---|---|---|
| none | 91/91 | — |
| check removed | 85/91 | all 6 truncation cases |
| closing-quote half only | 90/91 | cut after the command, before the end |
| trailing-brace half only | 90/91 | cut just after a `}` inside the command |
| any `"` closes the value (`[^"]*"`) | 90/91 | same `}` case, through its leading `echo "a"` |
| a `"` closes unless a backslash precedes it | 90/91 | escaped quotes, trailing backslash |
| approval token honoured before the check | 90/91 | cut after the approval token |
| mode recovered before the check | 86/91 | 5 truncation cases answer `ask` |

Two probes were reshaped until each of those last three mutants failed:

- The `}` case gained `echo "a"` ahead of the cut. Without it, the any-quote mutant passes.
- The trailing-backslash case moved to a payload where the command is the last string. With
  a `description` after the command, a sloppy check can take its closing quote from that key.

The first try at the heuristic mutant, `"(|...)"`, would not compile on macOS. Every payload
then failed the check, so it measured nothing and was replaced.

The Phase 1 repro against the fixed hook: a whole commit still gets `ask` on both branches.
The truncated payload and the empty payload now get `deny`. `test-acceptance.sh` against the
source tree passed 42 of 42.

**Found in passing:** a payload with an invalid UTF-8 byte used to let a commit through the
no-jq branch. Under a UTF-8 locale, bash's `=~` fails to match anything in such a payload,
even `}` at the end, so GIT_VERB found nothing and `git commit -m x` exited 0. Under `LC_ALL=C`
it was gated. The new check fails closed on it: it answers `deny`, with the "did not arrive
whole" reason. Claude Code sends valid UTF-8, so this is edge-case hardening, not a live hole.
No probe pins it, because a probe would need a UTF-8 locale to be installed. It is listed under
Deferred.

**Docs (Phase 5).**

- **The hook.** The no-jq comment block describes the check, both of its halves, the one cut
  it cannot see, and why it runs first. The header's decision table has a row for it.
- **`plugins/pr/hooks/README.md`.**
  - The case count goes from 73 to 91, and the list of what the suite covers now includes the
    no-jq path.
  - A note explains why dropping a directory from `PATH` doesn't hide jq.
  - The mass-failure paragraph now gives two measured shapes instead of one. The old
    `31/42 (73)` figure was reproduced from `main` first, to check the method. A jq that can't
    run gives 33/58. A missing jq gives 33/58 from outside a configured repo, and 6/85 from
    inside one. The difference comes from the new deny: the suite's empty payloads now reach a
    path that denies them. That path takes activation from the directory the suite runs in.
- **The version.** `pr` goes from 0.2.9 to 0.2.10.
