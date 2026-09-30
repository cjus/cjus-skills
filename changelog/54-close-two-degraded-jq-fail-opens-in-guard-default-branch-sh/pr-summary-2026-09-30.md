# Close two degraded-jq fail-opens in guard-default-branch.sh

## Overview

`plugins/pr/hooks/guard-default-branch.sh` asks or denies before a commit or push on the
default branch. It has two degraded paths for when `jq` misbehaves, and each one let a
default-branch commit or push run with no prompt and no output:

1. **No jq, whole payload.** The no-jq branch matched `GIT_VERB` against the raw JSON payload,
   so the characters either side of the verb were JSON's, not the command's. A command ending
   in its verb (`git push`, `cd /x && git push`) had the string's closing `"` after it. A verb
   starting a later line had the escape `\n` before it. `git`⇥`push` had `\t` in the middle.
   `GIT_VERB` accepts none of these, so all of them passed while the jq path asked.
2. **jq on `PATH` but unable to run**, such as a stray x86 build on Apple Silicon, which exits
   126. The payload parse failed and `gate()` ran, but `gate()` built its output with the same
   jq, so the hook printed nothing and exited 0. **Every** default-branch commit and push
   passed.

Both paths now reach a decision. Without jq, the no-jq branch matches `GIT_VERB_RAW`, a variant
of `GIT_VERB` widened for the raw payload. A jq that cannot run is detected after a failed parse
and handled exactly as a missing one, which was the operator's choice. It asks in a prompting
mode and denies otherwise. `gate()` itself can no longer end without printing a decision,
whatever its jq does.

## Key changes

- **`plugins/pr/hooks/guard-default-branch.sh`**
  - **`GIT_VERB_RAW`** in the no-jq branch. It adds one escape class, any JSON escape except
    `\"`, `\\` and `\/`, before `git`, in every whitespace run and after the verb. It also
    accepts the unescaped closing `"` after the verb. Every group is `GIT_VERB`'s with
    alternatives added and none removed.
  - **Parse-failure route.** `jq -n true` now tells a malformed payload (still denied) from a
    jq that cannot run (sent to the no-jq branch). The branch is now `if [[ "$HAVE_JQ" == 0 ]]`
    rather than `else`, so both cases reach it.
  - **`gate()`.** It captures `jq -nc` and falls back to `printf` whenever that output is empty.
    The reason and the deny instruction are each checked against a safe shape, `JSON_SAFE`,
    and each is swapped for a fixed literal if it fails. The check is phrased so that a regex
    that fails to evaluate still swaps.
  - **Header decision table.** It gains the jq-cannot-run row. The comments on each changed
    block explain the design and give the evidence.
- **`plugins/pr/hooks/test-guard-default-branch.sh`** goes from 91 cases to 115.
  - `nj` wraps a general `pj` helper that takes the hook's `PATH`.
  - 10 new no-jq cases, for the verb beside JSON syntax.
  - A broken-jq harness, a stub `jq` that exits 126, with 8 cases.
  - A harness whose jq fails only on `jq -nc`, with 5 cases, one of which checks that a swapped reason keeps the approval-token instruction.
  - One malformed payload that looks whole to the no-jq branch.
- **`plugins/pr/hooks/README.md`**
  - The case count and the coverage list.
  - The mass-failure shapes, measured again. A broken jq and a missing jq now give the same
    shape, so the text explains the shape by where the suite ran.
- **`plugins/pr/.claude-plugin/plugin.json`**: `pr` goes from 0.2.10 to 0.2.11.

## Code examples

**The no-jq match**, `plugins/pr/hooks/guard-default-branch.sh`, at the end of the no-jq branch.
Before:

```bash
[[ $INPUT =~ $GIT_VERB ]] &&
  gate "jq not found, so the default-branch commit guard cannot read the command."
```

After:

```bash
RAW_ESC='\\([bfnrt]|u[0-9a-fA-F]{4})'
GIT_VERB_RAW='(^|[^[:alnum:]_./-]|'"$RAW_ESC"')git([[:space:]]|'"$RAW_ESC"')+(-[^[:space:]]+([[:space:]]|'"$RAW_ESC"')+([^-[:space:]][^[:space:]]*([[:space:]]|'"$RAW_ESC"')+)?)*(commit|push)([[:space:]]|;|&|\||$|"|'"$RAW_ESC"')'
[[ $INPUT =~ $GIT_VERB_RAW ]] &&
  gate "jq is missing or cannot run, so the default-branch commit guard cannot read the command."
```

**The parse-failure route**, `plugins/pr/hooks/guard-default-branch.sh`, in the jq branch:

```bash
if [[ "$JQ_RC" != 0 || "$PAYLOAD" != *"--PR-GUARD-END--" ]]; then
  jq -n true >/dev/null 2>&1 &&
    gate "The PreToolUse payload could not be parsed, so the default-branch commit guard cannot read the command."
  HAVE_JQ=0
else
  CWD=${PAYLOAD%%$'\n'*}
  # ...MODE and CMD as before
fi
fi

if [[ "$HAVE_JQ" == 0 ]]; then
  # the no-jq branch: completeness check, approval token, mode recovery, GIT_VERB_RAW
```

**`gate()`'s output**, `plugins/pr/hooks/guard-default-branch.sh`:

```bash
local out=""
[[ "$HAVE_JQ" == 1 ]] &&
  out=$(jq -nc --arg d "$decision" --arg r "${reason}${stop}" '...' 2>/dev/null)
if [[ -n "$out" ]]; then
  printf '%s\n' "$out"
else
  [[ $reason =~ $JSON_SAFE ]] ||
    reason="The default-branch commit guard needs operator approval for this commit or push. jq failed while building the full reason."
  [[ $stop =~ $JSON_SAFE ]] ||
    stop=" STOP and ask the operator in conversation."
  printf '{"hookSpecificOutput":{...,"permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "${reason}${stop}"
fi
```

## Plan alignment

| Phase | Outcome |
|---|---|
| 1. Reproduce | Done against `main` @ `a26f79c`, adding `git push`⏎`echo done`, `git push`⇥`echo done` and a trailing CR to the ticket's shapes. All nine commands, in both modes, gave nothing on the no-jq and broken-jq paths while the jq path asked or denied. The one exception is `git commit -m x`, which only the broken-jq path let through. |
| 2. Probes first | Done. Against the unfixed hook, 98 passed and 15 failed, and the 15 are exactly the gating cases. **Deviation:** the plan said every new case should fail. The other 7 pass either way. Two check the harness or guard against regression, and the other five guard against over-reach, which mutants pin instead. |
| 3. Fix item 1 | Done by **widening the regex rather than decoding the command**. Decoding with bash builtins means `${s//…/…}`, which grows roughly with the cube of the length under bash 3.2: 1.1s for 10KB, 66s for 40KB. That rules it out on a path that runs for every Bash call. The completeness check, the token, mode recovery and the ask/deny split are unchanged. |
| 4. Fix item 2 | Done: reclassify after a failed parse with `jq -n true`, plus the `gate()` fallback. The operator chose "ask", as with a missing jq. |
| 5. Mutation proof | Done. All 14 mutants are caught by their own cases: 7 on the regex, 3 on the reclassification, 4 on the fallback, including the joint swap as it stood before the review. |
| 6. Docs | Done: the hook's comments and decision table, and the README's count and shapes. |

All three open questions in `PLAN.md` are resolved there, with the evidence.

## Testing

**Automated**

- **Suite.** 115 of 115 on macOS (bash 3.2.57, jq 1.8.2) and in `ubuntu:24.04` (bash 5.2.21,
  jq 1.7):
  ```bash
  plugins/pr/hooks/test-guard-default-branch.sh plugins/pr/hooks/guard-default-branch.sh
  ```
- **Acceptance.** `plugins/pr/scripts/test-acceptance.sh` passes 42 of 42 against a copy of
  `plugins/pr`.

**Differential test of `GIT_VERB_RAW` against the jq path**, run in a scratch harness and not
committed:

- **Mine.** 40,000 generated commands, each encoded with `JSON.stringify` and again with every
  non-ASCII character `\u`-escaped, under `C` and UTF-8: 160,000 checks, no under-match. A
  further 80,000 checks on Linux found none either. Today's raw match missed 95–98% of the
  decoded matches.
- **The reviewer's.** 180,000 checks, stricter than mine: the jq side ran `grep -E` line by line
  and the token check, over all of ASCII plus Unicode spaces and surrogates. It found no
  under-match, and the same test caught 53 under-matches in `main`'s regex.

**A real broken jq.** This machine has a stale x86_64 jq that fails with `Bad CPU type in
executable`, exit 126. With it symlinked first on `PATH`:

- On `main`, the hook printed nothing for `git commit -m x`, `git push` and `ls -la`.
- On this branch it gives ask, deny under `bypassPermissions`, ask, and no output for `ls -la`.

**Cost.** The no-jq branch runs on every Bash call without jq. On 1MB payloads built to stress
the regex engine it took about 0.4s at worst, against 0.07s for the old regex.

**By hand**

- **No jq.** Run the hook with a `PATH` holding only links to `cat`, `git`, `grep` and
  `dirname`. The suite's `NOJQ` folder is built that way, because macOS ships `/usr/bin/jq`.
  Send it a default-branch payload whose command is `git push` or `cd /x && git push`. It asks.
- **Broken jq.** Put a directory first on `PATH` holding a `jq` that cannot run. `ls -la`
  passes silently, `git commit -m x` asks, and under `bypassPermissions` it denies.

**Edge cases.** Each of these is pinned by a case:

- `echo "git push"` and `printf 'git push\n'` still pass without jq. An escaped quote does not
  end the verb, and `\\n` is not a newline.
- A trailing-comma payload is still denied when jq runs, rather than handed to the no-jq branch.
- An empty payload with a broken jq is denied.
- An unconfigured repo is left alone.
- A reason or a token name holding a `"` still yields valid JSON with a decision when jq fails
  inside `gate()`. A reason holding one still keeps the approval-token instruction.

**Unchanged.** The jq path's stdout is byte-identical to `main`'s for commit, `-C` with a quote,
push, `ls` and three malformed payloads, in both modes.

## Impact assessment

- **Size.** The code and doc changes are 222 lines added and 57 removed, across the hook, the
  suite, the README and `plugin.json`. The rest of the diff is this branch's plan folder: plan,
  changelog, this summary, and the reviews.
- **Dependencies.** None added. The no-jq branch still needs only bash builtins, so it survives
  jq and grep both being absent.
- **Behaviour.**
  - Without jq, or with a jq that cannot run, more commands now gate, and that is the intended
    direction. The widened regex also over-matches in ways the jq path would not: a literal
    backslash-n before `git`, and a `\b` or a non-whitespace `\u` escape counting as whitespace.
    That branch already gates every commit and push regardless of branch.
  - With a working jq, nothing changes.
- **No breaking change.**

## Deferred work

- **Pre-existing issues found in review, filed separately and not addressed here:**
  - `GIT_VERB`'s trailing group rejects `)`, `>` and a backtick, so `(cd /x && git push)`,
    `echo $(git push)` and `git push>/dev/null` pass on the default branch on every path, jq
    included. Filed as #58.
  - Without jq, the approval token is honoured across a `\n` inside an assignment's value.
    Filed as #59.

  Both behave identically on `main`, and each was filed as its own issue under the scope
  contract's rule for pre-existing security defects.
- **Nothing checks that `GIT_VERB_RAW` stays in step with `GIT_VERB`.** The item-1 probes catch
  a drift that loses one of their shapes, but not a new shape added to `GIT_VERB` alone. A
  section running one command list through both paths and comparing decisions would catch it.
- **The hook header's "ON EVIDENCE" paragraph still says the plugin "ships NO test suite".** It
  is stale, as #1 also noted, and this branch did not edit that paragraph.
