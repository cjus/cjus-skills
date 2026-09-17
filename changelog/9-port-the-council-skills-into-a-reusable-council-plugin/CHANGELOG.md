# Port the council skills into a reusable council plugin

Start date: 2026-09-16 16:40:16 MDT

Package the `council` and `council-setup` skills, currently project-scoped in `cjus-dev`
at `.claude/skills/`, as a third plugin in this marketplace alongside `bookcraft` and
`pr`.

## Changes

### 2026-09-16 — Phase 1 (partial): plugin root, `scripts/env.mjs`, 43-case probe suite

Created `plugins/council/` with a manifest at **version 0.1.0** — the conventional start for a
new plugin, and the answer to the plan's open question on versioning. `bookcraft` is at 1.0.2
and `pr` at 0.2.0; neither implies anything for a third. One-value edit if it should differ.

**The `.env` reader landed first because both blocker #1 and Decision 2 resolve to it.** The
self-contained parser that replaces the host-repo `dotenv.mjs` import is the same file that
implements the three-level precedence chain, so they were never two pieces of work.

- **Deliberately not a dotenv clone.** The host repo's parser is a version-pinned port of Next's
  grammar because it must predict what `next build` inlines. Council resolves one opaque token,
  so there is no `${VAR}` interpolation, no multi-line values, no `KEY: value` form. Each
  omission is one fewer thing that can go subtly wrong with a secret inside it.
- **One divergence from dotenv is deliberate.** dotenv ends an unquoted value at the first
  unescaped `#`, so `K=ab#cd` parses as `ab`. Applied to a credential that silently *truncates*
  it, and a truncated key fails as an HTTP 401 — exit 4, "the provider rejected us" — pointing
  nowhere near the file that caused it. Here `#` only opens a comment when whitespace precedes
  it. Both behaviours are pinned by a test.
- **Empty is absent at every level.** A present-but-empty value falls through the chain instead
  of reaching the provider, for the same reason: an empty key returns 401 and reports a
  configuration mistake as a provider failure.
- **A failing level is not an absent one.** `ENOENT` means that level is simply not in use;
  `EISDIR`/`EACCES` mean a configured level is broken. The latter warns and falls through, so
  one bad level cannot take the chain down while looking like "no key".
- **No flag prints the value**, and none should be added. `--probe` reports presence and
  provenance only; the key is returned to importing code and never crosses a process boundary.
  Two tests assert a planted `sk-SECRET` appears in no output stream.
- Exit 0 present / 3 absent, mirroring `openrouter.mjs`'s "3 = no key, do not seat this member",
  so `detect.sh` can branch on status rather than parse text.

**Two findings from checking the plan against the machine, both of which change later phases.**

- **Decision 2's backward-compatibility premise is false.** The plan states cjus-dev "has the key
  in its `.env` and is served at step 2". It does not: `COUNCIL_OPENROUTER_API_KEY` is absent from
  cjus-dev's `.env`, absent from the environment, and there is no `~/.config/council/.env`.
  Only the unprefixed `OPENROUTER_API_KEY` is exported, which council deliberately refuses to
  read. Meanwhile the roster has `external.openrouter.enabled: true` — consent granted. So
  OpenRouter members are **consented but unseatable**, and every council on this machine has been
  running Claude-only and correctly reporting `HOMOGENEOUS`. Decision 2 is therefore not a
  convenience; step 3 of the chain is the slot that has been missing. Phase 9's verification step
  ("confirm the key still resolves via step 2") is written against the false premise and needs
  rewriting to create the user-level file first.
- **`detect.sh` and the parser already disagree on `export`.** detect.sh's grep is anchored
  `^[[:space:]]*COUNCIL_...` and does not admit an `export ` prefix; the parser does, as dotenv
  does. Verified concretely: on `export COUNCIL_OPENROUTER_API_KEY=sk-test`, detect.sh reports
  "absent -- do NOT seat OpenRouter members" while the parser returns the key. That is the exact
  drift class the suite exists for — the context block says one thing while the member spends.
  The row is marked `DIVERGES` in the table and is a Phase 2 porting item.

**The suite is a table, not a pile of assertions, because the rule will have two implementations.**
`detect.sh` must stay POSIX `sh` and Node-free, so it cannot call into `env.mjs`; it will
re-implement the chain. Two implementations of one rule drift invisibly, so the presence cases
are written as an oracle both must answer to on `(present?, source)`, and detect.sh gets replayed
against it in Phase 2. 43 cases pass: precedence, absent-vs-empty, recognised and deliberately
unrecognised line forms, `XDG_CONFIG_HOME`, failing levels, the mode-600 warning, value fidelity,
exit status, and non-leakage.

Three initial failures were the harness's own bugs, recorded so the distinction stays visible:
`probe()` discarded stderr at the source, so an outer `2>&1` could not recover the warnings three
cases assert on; and the value-fidelity cases passed `env.mjs` as the first trailing argument to
`node -e`, which lands at `process.argv[1]` and tripped the module's own is-this-main guard — the
CLI ran, printed "absent", and every parser case read as a failure. The module path now travels
in the environment instead.

### 2026-09-16 — Decision 3 resolved: `council-state.sh`, in sh with jq

**Open question 1 answered: `sh` + `jq`, not `.mjs`.** Node stays required only when an
OpenRouter member is actually seated, so a status read never demands a Node install from
someone whose council never leaves Claude. jq is the lighter ask and is a real parser — the
pure-sh alternative is regex-scraping nested JSON, which is how you get a confident, wrong
answer about what a council is about to spend. `detect.sh:36` already scrapes one field that
way with `sed`; the seating join needs nested objects and per-provider `enabled` flags, which
is past where that technique holds.

**`council-lib.sh` exists so the chain is implemented twice, not four times.** `openrouter.mjs`
needs the key's *value* and must be Node; `detect.sh` and `council-state.sh` must be Node-free.
That is two implementations of one rule, and two is the maximum tolerable. Nothing in the sh
side ever emits the key — a shell is a bad place to hold a secret, since it leaks through
`set -x`, through the process table, and through any trace pasted into a bug report.

- `council_resolve_key` sets `COUNCIL_KEY_LEVEL` (`env`/`project`/`user`/`none`) alongside the
  display string, so no caller has to string-match prose to learn which level won.
- Presence is computed in `awk`, not `grep`. **Last assignment wins**, so a file with
  `K=sk-live` followed by `K=` has no key — a grep stopping at the first hit reports the
  opposite. Quotes, the comment rule and empty-is-absent all mirror `env.mjs`.
- **The `export` divergence is closed.** The sh side accepts `export K=v` because `env.mjs`
  does; the old `detect.sh` grep did not, which is what made the two disagree.

**`council-state.sh` performs the join and refuses to guess.**

- A missing roster is legitimate and means Claude-only. A **malformed or unreadable** roster
  exits 2 and prints no seating at all, because "failed to parse" and "no external members"
  otherwise produce an identical Claude-only answer — and one of those is a file the user
  believes is in effect. Missing `jq` fails the same way rather than degrading to zero.
- Seating requires consent *and* availability: OpenRouter members consented in the roster but
  with no key resolving are listed under **not seated** with the reason, rather than vanishing.
- Correlation is always labelled **projected**, with `COLLAPSED` named as unpredictable-by-
  construction since it is only observable after the members answer.
- Run live against this machine, it reproduces mechanically what was found by hand earlier on
  this branch: four consented OpenRouter members, none seated, `no key resolves`.

**46 cases in `test-council-state.sh`, and the oracle caught a bug both implementations shared.**
Part 1 replays the `test-env.sh` table against the sh chain, failing a row when the two disagree
**and** when they agree on a wrong answer. That second half earned itself immediately: `K=  # note`
resolved to the literal key `# note` on both sides. The whitespace marking the comment is consumed
as the gap after `=`, so the "whitespace must precede `#`" rule never saw it — and `# note` would
have shipped as a Bearer token and returned 401, pointing nowhere near the file. Both sides now
treat an unquoted value beginning with `#` as empty; quote it if a key really starts with one.
Part 2 covers the join: consent crossed with availability, vendor derivation from the author
prefix, refusal paths, and non-leakage. Both suites green at 46 each.

Three failures were again the harness's own, recorded so the distinction stays visible: BSD
`mktemp` only substitutes trailing `X`s, so a `roster.XXXXXX.json` template silently fell back to
the *real* roster; `env(1)` reads its options before its `NAME=value` operands, so `env K=v -u X`
ran `-u` as the utility; and a `printf` as the last statement of a helper replaced the script's
exit status, turning every refusal into `rc=0`. The first two were masked by `2>/dev/null`, which
the harness no longer does blindly.

### 2026-09-16 — Correction: jq cannot be a hard dependency

**Nothing installs anything when a plugin is installed.** Verified against
`claude plugin validate --strict`: `requires` and `postInstall` are unknown fields that
"Claude Code ignores at load time", and while `dependencies` is schema-valid as an array of
strings, there is no evidence it resolves *system* binaries, and a manifest invoking a package
manager is not a behaviour to assume. Every binary this plugin touches is one the user already
has, or one it must do without.

That makes the previous entry's "jq is the lighter ask" wrong in the way that matters. Requiring
jq put a hard dependency on **the exact path choosing sh over Node existed to protect**: a
Claude-only council needs no key and no Node, and would have been unable to read its own status
because a parser it never asked for was missing.

**The roster is now read through jq OR Node, whichever is present; only the absence of both is
fatal.** Requiring either is strictly weaker than requiring one. Node is already required the
moment an OpenRouter member is seated, so on a machine that can use the plugin's external
members at all, the fallback is free.

- Both backends emit one normalized TSV (`meta` rows plus `member` rows), and nothing downstream
  in `council-state.sh` knows the roster was ever JSON. The `q()` jq calls scattered through the
  seating logic are gone.
- The fallback is Node, not a regex. The `pr` plugin scrapes two flat scalars out of a hook
  payload with `sed` and documents that as degraded; that technique does not reach a nested join
  across two providers' `models[]`, and a seating table confidently wrong about cost is worse
  than one that refuses to print.
- `COUNCIL_JSON_BACKEND` forces a backend, which is how the suite runs every fixture through both.

**Backend parity is held to the same oracle rule as the key chain, and it immediately found a
divergence.** A roster whose entire content is `null` was *accepted* by jq — `null | .foo` is
null, so every `// default` absorbed it and produced a confident Claude-only seating table from a
file containing nothing — while Node refused it on type. An array or a string errors on the first
index, so null was the only value that slipped through. The jq program now carries an explicit
`if type != "object" then error(...)` guard. Ten fixtures × both backends now agree byte-for-byte,
including sparse, empty, `"external": null`, and members that are `null` or bare strings.

Two more defects fixed in passing, both mine and both in the new code: a sourced POSIX `sh` file
cannot discover its own path, so `$(dirname "$0")` in the library resolved against whatever script
sourced it (`COUNCIL_SCRIPT_DIR` now carries it); and `if ! cmd; then case "$?"` can never see a
non-zero code, because POSIX defines `!` as *replacing* the status with its logical negation — the
"neither backend available" branch was unreachable until the status was captured directly.

Suites: 46 for the key chain, 66 for the state join and backends. Both green.

### 2026-09-16 — Review pass: one blocker fixed, four invariant breaks closed

`/pr:pre-test` opened draft PR #13 and ran a review over the diff. **The repo has no CI**
— no `.github/workflows/`, no runs ever — so the two suites are the only automated evidence
this branch has, and opening the PR could not produce a signal.

**Blocker: the jq backend reported confident seating for a roster that failed to parse.**
Given a file with no JSON value in it, jq runs the filter zero times, emits nothing and
**exits 0**, so the `if type != "object"` guard inside the filter never fired. Verified: a
zero-byte roster produced `0 seated / correlation: NONE / rc=0` under jq while Node refused,
and a file holding two concatenated documents was worse — jq ran the filter once per document
and merged the members of both into one council, reporting `2 claude, HOMOGENEOUS`. jq is
tried first, so this was the default path.

This is the exact outcome the design forbids in its own words: *"failed to parse" and "no
external members" must never print the same answer*. The realistic trigger is an interrupted
`/council:setup` write or a stray `>` redirect, and the user gets an authoritative-looking
report that their consented external roster is empty.

Fixed by reading under `jq -s`, so the file arrives as an array and `length != 1` catches
empty, whitespace-only and multi-document in one guard, with the existing type guard still
covering a lone `null`.

**The parity suite could not have caught it, and that is the lesson.** Twenty cases asserted
the backends were byte-identical, but none of the five fixtures was an unparseable file — and
jq's "no input means no work and exit 0" is a no-op success that a diff-based test cannot see,
because both sides have to be *asked* the question before they can disagree. When two
implementations are bound by a fixture table, the table's coverage **is** the invariant.

**Four further defects, each one contradicting an invariant the code itself states:**

- **The key leaked into an xtrace.** `council-lib.sh`'s header promises the value "stays
  inside the Node process that uses it" and names `set -x` as the leak it guards against;
  reading it into a variable and testing it echoed it three times under `sh -x` — which is
  exactly what someone runs when the tool misreports, and exactly what they paste into an
  issue. The option is now saved and cleared around the read, and the variable is cleared
  after. Pinned by a test asserting a planted key appears nowhere in a full trace.
- **`--json` could emit invalid JSON.** Roster strings went between quote characters
  unescaped, so a stance reading `the "paranoid" one` closed the string early. Since Decision
  3 has `skills/ask` consuming this as the source of truth, and a parse failure there would
  likely be handled as "no seating information", the bug landed straight back on
  confidently-wrong seating. Escaped in the emitter; `maxConcurrentExternal` now falls back
  to the default unless it is a plain integer, since it is emitted as a bare JSON number.
- **A skipped Ollama probe was reported as confirmed diversity.** With no `curl`, or under
  `--no-probe`, `REACH=unknown` collapsed into the seated branch and the member counted
  toward `CROSS-VENDOR` — an over-claim in the one direction the honesty contract exists to
  prevent. The member is still seated, since lacking a prober is no reason to unseat it, but
  the uncertainty now survives into both formats (`ollamaProbed: false`, and a text suffix).
- **Ollama basic-auth credentials reached `curl`'s argv**, readable from `ps` by any other
  user for the probe window, although `council_redact` exists precisely because endpoints
  carry userinfo. The URL now goes in on stdin via `-K -`.

Also closed: the sh side folded "unreadable `.env`" into "absent", while `env.mjs` warns and
has a whole test section pinning the distinction. The sh side is the one that prints the
human-facing `key: ... absent` line, so it was giving the less useful of the two answers.

Suites now 46 and 81, both green, and `council-state.sh` produces identical output under
`sh`, `dash`, `ksh` and `bash`. Eight lower-severity findings and three operator decisions
are recorded under `PLAN.md § Deferred`.
