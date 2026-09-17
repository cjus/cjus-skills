# Port the council skills into a reusable council plugin

## Overview

This PR lands the **mechanical substrate** of the council port: the scripts that resolve a
key, read a roster, and compute seating, together with the two test suites that hold them
honest. It does not yet land the skills themselves.

The `council` skill fans one question out to N independent members and reconciles their
answers. Its value depends entirely on those members being genuinely independent, so the
parts that decide *who actually answers* are the parts that had to be correct before
anything else was worth writing. That is what is here.

**This is a partial delivery against a nine-phase plan, and none of the nine checkboxes is
complete.** The plugin ships no skills, is deliberately absent from
`.claude-plugin/marketplace.json`, and is therefore inert: installing this changes nothing
for any user. See *Plan alignment* for exactly what is and is not done.

## Key changes

| File | What it is |
|---|---|
| `plugins/council/.claude-plugin/plugin.json` | Manifest, version 0.1.0. Passes `claude plugin validate --strict`. |
| `plugins/council/scripts/env.mjs` | Self-contained `.env` reader and the three-level key precedence chain. Replaces a cross-repo `dotenv.mjs` import. |
| `plugins/council/scripts/council-lib.sh` | Sourceable POSIX `sh` library: the same chain for Node-free callers, binary lookup, endpoint normalization, and the dual-backend roster reader. |
| `plugins/council/scripts/roster-rows.mjs` | Node roster backend, emitting output byte-identical to the embedded jq program. |
| `plugins/council/scripts/council-state.sh` | The seating join: roster consent crossed with local availability, yielding a projected correlation class. |
| `plugins/council/scripts/test-env.sh` | 46 cases over the key chain. |
| `plugins/council/scripts/test-council-state.sh` | 81 cases over the join, the oracle table, and backend parity. |

### What blocker #1 actually was

`openrouter.mjs` loaded its `.env` parser from a path computed at runtime, three levels up
from the skill directory. Under any plugin layout that path is wrong, the `process.cwd()`
fallback lands in a project with no such file, and the `await import` was top level with no
`try`/`catch` — so the member died with `ERR_MODULE_NOT_FOUND` and exit code 1, which the
caller has no meaning for. It could not distinguish "this member has no key" (exit 3, report
it in the footer) from "this script is broken".

## Code examples

**The `#` rule, `env.mjs`.** dotenv ends an unquoted value at the first unescaped `#`, so
`K=ab#cd` parses as `ab`. Applied to a credential that silently truncates it, and a truncated
key fails as an HTTP 401 — pointing nowhere near the file that caused it.

```js
// An unquoted value that BEGINS with `#` is a comment, not a value...
if (rest[0] === "#") return "";
const comment = rest.search(/[ \t]#/);
return (comment === -1 ? rest : rest.slice(0, comment)).trimEnd();
```

**Presence is not a line match, `council-lib.sh`.** The last assignment wins, so a file with
`K=sk-live` followed by `K=` has no key — a `grep` stopping at the first hit reports the
opposite. Hence `awk`, not `grep`.

```awk
END { if (found) { t = val; gsub(/[ \t]/, "", t); if (t != "") print "present" } }
```

**The refusal path, `council-state.sh`.** A missing roster is legitimate and means a
Claude-only council. A malformed one is not, because "failed to parse" and "no external
members" otherwise print the same answer:

```sh
council_roster_rows "$ROSTER" > "$ROWS" 2>"$ERRF"
RC=$?                     # captured BEFORE anything else runs; `if !` would zero it
if [ "$RC" -ne 0 ]; then
  case "$RC" in
    3) die "$(head -1 "$ERRF"). Install either and re-run; refusing to guess at seating." ;;
    *) die "$ROSTER_DISPLAY: $(head -1 "$ERRF"). Refusing to report seating..." ;;
  esac
fi
```

## Plan alignment

**No phase is complete.** What landed cuts across five of them:

- **Phase 1 — partial.** Plugin root and manifest exist. The three skill directories,
  `reference/`, and the marketplace entry do not. The marketplace entry is held back
  deliberately so the listing never advertises a plugin with no skills.
- **Phase 2 — one of three blockers.** The `dotenv.mjs` dependency is gone. Repo-private
  material in the four shipped files, and `council-setup`'s relative path, are untouched.
- **Phase 3 — chain done, reporting half not.** Precedence is implemented twice. `detect.sh`
  has not been ported, so nothing yet reports which source won.
- **Phase 4 — script done, callers not.** `council-state.sh` performs the join. `skills/ask`
  does not call it and `/council:status` does not exist.
- **Phase 8 — two of four suites.** `openrouter.mjs` exit codes and `detect.sh` probes remain.

**Phases 5, 6, 7 and 9 are entirely unstarted.**

### Deviations from the plan as written

- **Decision 3 said `council-state.mjs`; this ships `council-state.sh`.** Open question 1
  resolved to `sh` so a Claude-only council never acquires a Node dependency to read its own
  status. The roster is parsed by jq *or* Node, whichever is present, because **nothing is
  installed when a plugin is installed** — verified against `claude plugin validate
  --strict`, where `requires` and `postInstall` are unknown fields ignored at load time.
  Requiring jq alone would have burdened the same path the `sh` choice existed to protect.
- **Decision 2's backward-compatibility premise is false.** The plan states cjus-dev "has the
  key in its `.env` and is served at step 2". It does not:
  `COUNCIL_OPENROUTER_API_KEY` is absent from that `.env`, from the environment, and from
  `~/.config/council/.env`, while the roster has `openrouter.enabled: true`. Those members are
  **consented but unseatable**, and every council on this machine has been running Claude-only
  and correctly reporting `HOMOGENEOUS`. Phase 9's verification step is written against that
  premise and needs re-sequencing to create the user-level file first.

## Testing

**By hand:**

```sh
sh plugins/council/scripts/council-state.sh --text          # seating on this machine
sh plugins/council/scripts/council-state.sh --json | jq .    # same, machine readable
COUNCIL_JSON_BACKEND=node sh plugins/council/scripts/council-state.sh   # force the fallback
node plugins/council/scripts/env.mjs --probe                 # key presence and provenance
```

**Automated** — 127 cases, all passing:

```sh
cd plugins/council/scripts && ./test-env.sh ./env.mjs && ./test-council-state.sh
```

Verified identical output under `sh`, `dash`, `ksh` and `bash`.

**Edge cases covered:** precedence across all three levels; empty, whitespace-only,
commented-out, quoted, `export`-prefixed and CRLF key lines; last-assignment-wins including a
value followed by an empty re-assignment; `XDG_CONFIG_HOME` redirection; a `.env` level that
exists but is unreadable; mode-600 warnings; roster absent, unreadable, malformed,
non-object, empty, whitespace-only and multi-document; members that are `null` or bare
strings; a roster string containing a quote; a non-integer `maxConcurrentExternal`; neither
jq nor Node available; and non-leakage of the key into stdout, stderr, argv and an `sh -x`
trace.

**The oracle discipline is the design point.** Both duplicated pairs — the two key chains and
the two roster backends — are tested against *each other*, with each row also carrying the
expected answer so that agreeing on a wrong answer still fails. That caught two defects a
per-side test would have passed: `K=  # note` resolving to the literal key `# note`, and a
roster of bare `null` accepted by jq while Node refused it.

## Impact assessment

- **9 files, +1982 lines, 0 deletions.** All new; nothing existing was modified.
- **No dependencies added.** Runtime needs are `sh`, `awk`, `sed` and either `jq` or `node`;
  `curl` only for the optional Ollama probe.
- **No breaking change, and no behavioural change for any user.** The plugin has no skills and
  is not in `marketplace.json`, so nothing loads it.
- **Assertion audit: disabled.** `docs.assertionsFile` is `null` in `.claude/pr-config.json`,
  so this repo keeps no assertions file. No audit was performed and none was fabricated.
- **Continuity: disabled.** `docs.continuityRoot` is `null`.
- **CI: none exists.** `.github/workflows/` is absent and the repo has never had a run, so the
  two suites in this PR are its only automated evidence.

## Deferred work

Recorded under `PLAN.md § Deferred`, all raised by the pre-test review:

**Backend and chain parity, lower severity.** jq's `//` and JS's `??` diverge on a
`false`-valued roster field; non-scalar values diverge (`"model": ["opus","sonnet"]` keeps
array text under jq, joins with a comma under Node); the two key chains disagree on exotic
whitespace (a lone vertical tab or NBSP), since JS `trim()` covers all Unicode whitespace
while the `sh` side handles space and tab; `displayPath` uses a bare prefix match on the Node
side and a `/`-boundary match on the `sh` side; and the two backends word their refusal
messages differently for the same failure.

**Robustness.** A tab or newline inside a roster string can inject a synthetic TSV row (both
backends identically, and the roster is self-authored). `council_normalize_endpoint` appends
a port after a path (`myserver/ollama` → `http://myserver/ollama:11434`) and does not bracket
IPv6 — this matters when `detect.sh` lands and shares the helper. A vendor slug containing a
space makes the `wc -w` count over-report and yields `CROSS-VENDOR` for a single vendor.

**Documentation.** `COUNCIL_ROSTER` is a production override undocumented in the library
header.

**Three items need an operator decision rather than triage.** What an absent roster should
project, given that `/council:ask` still seats four Claude members by default while this
script reports `0 seated`; whether `/council:status` will pass `--no-probe`, which would make
the unconfirmed-diversity annotation the normal path; and the precedence between
`COUNCIL_ROSTER` and `XDG_CONFIG_HOME`.
