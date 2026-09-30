# Close two degraded-jq fail-opens in guard-default-branch.sh

Start date: 2026-09-30 13:16:16 MDT

The default-branch guard has two degraded-jq paths that fail open silently. Without jq, the
raw-payload match misses a verb whose boundary is JSON syntax. That happens when the verb is the
last word of the command, before the closing quote, or starts a later line, after an escaped
newline. When jq is on `PATH` but cannot run, the parse fails and `gate()` is called, but
`gate()`'s own `jq -nc` fails as well, so the hook prints nothing. This branch closes both holes
and adds probes that fail without each fix.

## Changes

### 2026-09-30 13:55:26 MDT: Phase 1, both holes reproduced against `main` @ `a26f79c`

The hook was run directly against an opted-in throwaway repo on `main`. Each command went
through three paths:

- the jq path
- a no-jq `PATH`: a folder of links to only `cat`, `git`, `grep` and `dirname`, as in the suite
- a broken-jq `PATH`: a stub `jq` that exits 126, first on the normal `PATH`

| Command | jq | no jq | broken jq |
|---|---|---|---|
| `git push` | ask | nothing, exit 0 | nothing, exit 0 |
| `git commit` | ask | nothing | nothing |
| `cd /x && git push` | ask | nothing | nothing |
| `git add -A`⏎`git commit -m x` | ask | nothing | nothing |
| `ls`⏎`git push origin main` | ask | nothing | nothing |
| `git push`⏎`echo done` | ask | nothing | nothing |
| `git push`⇥`echo done` | ask | nothing | nothing |
| `git commit` followed by a CR | ask | nothing | nothing |
| `git commit -m x` | ask | ask | nothing |

Under `bypassPermissions`, every `ask` above became `deny` and every "nothing" stayed nothing.
With a broken jq, `ls -la` also printed nothing. It passes, as it should, but only because
`gate()` fails silently.

**Chosen for item 1: widen the regex, not decode.** A decode in bash builtins has to use
`${s//pattern/replacement}`, and on bash 3.2 that grows roughly with the cube of the length. One
`\n` replacement took 1.1s on 10KB, 8.3s on 20KB and 66s on 40KB. A 1MB run was killed after
100s. The no-jq path runs on every Bash call, so decoding is not an option.

The raw-only variant `GIT_VERB_RAW` adds one escape class, `\\([bfnrt]|u[0-9a-fA-F]{4})`, which
is any JSON escape except `\"`, `\\` and `\/`. It is accepted:

- before `git`
- at every whitespace run
- after the verb, where the unescaped closing `"` is also accepted

The token classes stay as they are in `GIT_VERB`, and so `GIT_VERB_RAW` matches everything
`GIT_VERB` matches.

**Evidence.**

- **Differential test.** Commands were generated around the shape
  `<lead>git<sep>[<opt><sep>[<arg><sep>]]<verb><trail>`, with random boundary characters. Each
  command was encoded with `JSON.stringify`, and again with every non-ASCII character
  `\u`-escaped. The decoded command matched against `GIT_VERB` stood in for the jq path.
  - 160,000 checks: 2 encoders × 2 seeds × `C` and UTF-8 × 20,000 commands.
  - Today's raw match missed 95–98% of the decoded matches: 1,329–1,491 of 1,367–1,531 per run.
  - `GIT_VERB_RAW` missed none. It over-matched 400–842 per run, and every over-match is a gate
    the jq path would not make, which is the safe direction.
- **Cost.** Six 1MB payload shapes built to stress the regex engine. The worst took 0.32s
  against 0.07s for `GIT_VERB`, under both `C` and UTF-8.

**Chosen for item 2 (the operator chose "ask").** A jq that cannot run takes the no-jq path.
When the parse fails, `jq -n true` is run once: if that succeeds, the payload is at fault and
is denied as before; if it fails, the no-jq path takes over, with its completeness check, token
and mode recovery. The happy path costs nothing extra. As a separate safeguard, `gate()` falls
back to `printf` when `jq -nc` produces nothing, so no route through it can end silently.

### 2026-09-30 14:07:29 MDT: Phases 2–6, probes, both fixes, mutation proof, docs

**Probes.** 22 cases were added, taking the suite from 91 to 113. `nj` now wraps a general
`pj` helper that takes the hook's `PATH`.

- **Item 1.** 10 `nj` cases. Eight must gate: `git push` and `git commit` as the whole command,
  `cd /x && git push`, both later-line shapes, the verb before `\n`, `git`⇥`push`, and `git push`
  under `bypassPermissions`, which must deny. Two must pass: `echo "git push"` and
  `printf 'git push\n'`, which pin that only an unescaped quote ends the verb and that `\\n` is
  not a newline.
- **Item 2.** A broken-jq harness, a stub `jq` that exits 126, with 8 cases: a check that the
  stub cannot run, commit ask and deny, a command ending in its verb, the approval token, a
  non-git command, an empty payload, and an unconfigured repo. A second stub fails only on
  `jq -nc`, so it parses and then fails in `gate()`. Its 3 cases are commit ask and deny, and a
  `-C` path holding a `"`.
- **Malformed payload.** One case with a trailing comma, which is invalid JSON that still looks
  whole to the no-jq check. With a jq that runs, it must still be denied.

Against the unfixed hook: 98 passed and 15 failed, and the 15 are exactly the gating cases.
The other 7 new cases pass either way. Two are checks on the harness or against regression:
the stub cannot run, and an unconfigured repo is left alone. The other five guard against a
fix that reaches too far, and the mutants below turn each of them red.

**Fixes.**

- **Item 1.** The no-jq branch matches `GIT_VERB_RAW`, as chosen in Phase 1.
- **Item 2.** On a failed parse, `jq -n true` decides: jq runs, so `gate()` denies as before;
  jq cannot run, so `HAVE_JQ=0` and the no-jq branch runs. The branch changed from `else` to
  `if [[ "$HAVE_JQ" == 0 ]]`.
- **`gate()`.** It now captures `jq -nc` and falls back to `printf` when that output is empty.
  A reason that holds `"`, `\` or a control character is replaced by a fixed one, since
  `printf` cannot escape it.

**Evidence.**

- **Suite.** 113 of 113 on macOS with bash 3.2.57 and jq 1.8.2. Also 113 of 113 in
  `ubuntu:24.04` with bash 5.2.21 and jq 1.7, where the differential test (4 × 20,000 checks)
  found no under-match either.
- **Real broken jq.** The stale x86_64 jq on this machine, symlinked first on `PATH`, fails
  with `Bad CPU type in executable`, exit 126. On `main`, the hook printed nothing for
  `git commit -m x`, `git push` or `ls -la`. On the branch it gives ask, deny under
  `bypassPermissions`, ask, and nothing for `ls -la`.
- **Phase 1 repro, repeated.** All 18 shapes now give the same decision on all three paths.
- **Mutants.** All 12 were caught, each by its own cases:

| Mutant | Cases turned red |
|---|---|
| no-jq branch uses `GIT_VERB` | 9: every item-1 gating case, plus the broken-jq "ending in its verb" case |
| no closing `"` after the verb | 6: the cases whose command ends in its verb |
| no escape before `git` | 2: both later-line cases |
| no escape in whitespace runs | 1: `git`⇥`push` |
| no escape after the verb | 1: the verb before `\n` |
| `\"` also ends the verb | 1: `echo "git push"` |
| `RAW_ESC` loosened to `\\.` | 2: both precision cases |
| every failed parse denies | 4: broken-jq ask, token and non-git cases |
| every failed parse goes to the no-jq branch | 1: the trailing-comma payload |
| `HAVE_JQ` not cleared | 4: the broken-jq gating cases |
| `gate()` has no fallback once jq ran | 3: every jq-fails-in-`gate()` case |
| no swap for an unsafe reason | 1: the quoted `-C` path, which printed invalid JSON |

- **Acceptance.** 42 of 42, against a copy of `plugins/pr`.

**Docs.**

- **Hook.** The decision table gained the jq-cannot-run row. The parse-failure comment explains
  the `jq -n true` question and why not every failed parse is handed over. The no-jq branch
  comment explains `GIT_VERB_RAW`, what it over-matches, why decoding was rejected, and the
  evidence. The `gate()` comment explains the fallback and the swap.
- **README.** The case count went from 91 to 113, and the coverage list names the new sections.
  The mass-failure shapes were measured again. `main`'s 33/58 and 6/85 were reproduced first,
  confirming the method. The new shapes are 35/78 outside a configured repo and 8/105 inside
  one. A broken jq and a missing jq now give the same shape, because the hook treats them the
  same way, so the text explains the shape by where the suite ran, not by what is wrong with
  jq.
- **Version.** `pr` goes from 0.2.10 to 0.2.11.
