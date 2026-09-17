# Port the council skills into a reusable council plugin

Start date: 2026-09-16 16:40:16 MDT

Package the `council` and `council-setup` skills, currently project-scoped in `cjus-dev`
at `.claude/skills/`, as a third plugin in this marketplace alongside `bookcraft` and
`pr`.

## Changes

The full narrative, with the code examples and the plan-alignment table, lives in
`pr-summary-2026-09-16.md`; the review findings live in `pr-review-2026-09-16.md`. All four
timestamps below are preserved, each condensed to its decisions and their evidence.

### 2026-09-16 — Phase 1 (partial): plugin root, `scripts/env.mjs`, 43-case probe suite

Created `plugins/council/` with a manifest at **0.1.0**, answering the plan's open question on
versioning. `bookcraft` at 1.0.2 and `pr` at 0.2.0 imply nothing for a third.

The `.env` reader landed first because blocker #1 and Decision 2 resolve to the same file.
Deliberately **not** a dotenv clone: no interpolation, no multi-line values, no `KEY: value`.
One divergence is intentional — dotenv ends an unquoted value at the first unescaped `#`,
which silently **truncates** a credential into a 401 that points nowhere near the file; here a
`#` opens a comment only when whitespace precedes it. Empty is absent at every level, for the
same reason. A level that is *failing* (`EISDIR`/`EACCES`) warns and falls through rather than
reading as absent. No flag prints the value.

Two findings from checking the plan against the machine, both of which changed later phases:
**Decision 2's backward-compatibility premise is false** — `COUNCIL_OPENROUTER_API_KEY` is
absent from cjus-dev's `.env`, from the environment and from `~/.config/council/.env`, while
the roster has `openrouter.enabled: true`, so those members are consented but unseatable and
every council here has run Claude-only. And **`detect.sh` and the parser already disagreed on
`export`**, verified concretely.

The suite is a table rather than a pile of assertions, because the rule will have two
implementations and `detect.sh` cannot call into Node.

### 2026-09-16 — Decision 3 resolved: `council-state.sh`, in sh with jq

**Open question 1 answered: `sh`, not `.mjs`.** Node stays required only when an OpenRouter
member is seated, so a status read never demands a Node install from a Claude-only council.
jq is a real parser; the pure-sh alternative is regex-scraping nested JSON, and `detect.sh:36`
already scrapes one field that way — past where the technique holds.

`council-lib.sh` exists so the chain is implemented **twice, not four times**. Nothing on the
sh side emits the key. Presence is computed in `awk`, not `grep`, because **last assignment
wins**: a file with `K=sk-live` followed by `K=` has no key, and a grep stopping at the first
hit reports the opposite. The `export` divergence is closed.

`council-state.sh` refuses to guess: a missing roster is legitimate, a malformed or unreadable
one exits 2 and prints nothing, because "failed to parse" and "no external members" otherwise
give the same answer. Run live it reproduced by machine what had been found by hand — four
consented OpenRouter members, none seated.

**The oracle caught a bug both implementations shared**: `K=  # note` resolved to the literal
key `# note` on both sides, because the whitespace marking the comment is consumed as the gap
after `=`. Only the expected-value column caught it. Three further failures were the harness's
own and are recorded as such.

### 2026-09-16 — Correction: jq cannot be a hard dependency

**Nothing installs anything when a plugin is installed.** Verified against `claude plugin
validate --strict`: `requires` and `postInstall` are unknown fields ignored at load time.

That made the previous entry's "jq is the lighter ask" wrong in the way that matters —
requiring jq put a hard dependency on **the exact path choosing sh over Node existed to
protect**. The roster is now read through jq **or** Node, whichever is present; only the
absence of both is fatal. Both backends emit one normalized TSV and nothing downstream knows
the roster was ever JSON.

Backend parity is held to the same oracle rule, and immediately found a divergence: a roster
whose entire content is `null` was *accepted* by jq, since `null | .foo` is null and every
`// default` absorbed it, while Node refused on type.

Two defects fixed in passing, both in the new code: a sourced POSIX `sh` file cannot discover
its own path, and `if ! cmd; then case "$?"` can never see a non-zero code because POSIX
defines `!` as *replacing* the status with its negation.

### 2026-09-16 — Review pass: one blocker fixed, four invariant breaks closed

`/pr:pre-test` opened draft PR #13. **The repo has no CI** — no `.github/workflows/`, no runs
ever — so the suites are this branch's only automated evidence.

**Blocker: the jq backend reported confident seating for a roster that failed to parse.** Given
a file with no JSON value, jq runs the filter zero times and **exits 0**, so the type guard
inside the filter never fired; two concatenated documents were merged into one council. Fixed
by reading under `jq -s`, making a `length != 1` check reachable.

**The parity suite could not have caught it**, and that is the lesson: both sides must be
*asked* the question before they can disagree, so a no-op success is invisible to a diff-based
test. When two implementations are bound by a fixture table, the table's coverage **is** the
invariant.

Four further defects, each contradicting an invariant the code itself states: the key leaked
into an `sh -x` trace; `--json` emitted unescaped roster strings; a skipped Ollama probe
counted as confirmed `CROSS-VENDOR` diversity; and Ollama basic-auth userinfo reached `curl`'s
argv. Also closed: the sh side folded "unreadable `.env`" into "absent" while `env.mjs` warns.

The close-gate review then returned **APPROVE**, verifying all six fixes hold rather than
assuming, and raised three non-blocking issues now parked under `PLAN.md § Deferred`.
