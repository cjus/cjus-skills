# Finish the council plugin port: phases 1 and 2

## Overview

`plugins/council/` was inert. Its predecessor (#9, merged as PR #13) landed only the
mechanical layer — `env.mjs`, `council-lib.sh`, `roster-rows.mjs`, `council-state.sh` and two
test suites — so the plugin shipped no skills, was deliberately absent from
`.claude-plugin/marketplace.json`, and nothing called any of it.

This PR delivers **phases 1 and 2 of nine**. The plugin now ships three skills, carries a
marketplace entry, and has no remaining tie to the repo it was ported from. All five of the
ticket's open design questions were settled before either phase started, each recorded in
`PLAN.md` with its reasoning and what it touches.

Phases 3-9 are deliberately out of scope here. They continue on
[#22](https://github.com/cjus/cjus-skills/issues/22), filed at this close, because #14 is
retired on merge.

## Key changes

| File | What it is |
|---|---|
| `plugins/council/skills/ask/SKILL.md` | Ported from cjus-dev's `council/SKILL.md`. The council itself: three reconciliation modes, the honesty contract, the trust boundary. |
| `plugins/council/skills/setup/SKILL.md` | Ported from `council-setup/SKILL.md`. Writes the roster consent record. |
| `plugins/council/skills/status/SKILL.md` | **New**, no original. A read-only wrapper over `council-state.sh`. |
| `plugins/council/scripts/openrouter.mjs` | Ported, rewritten onto `env.mjs`. Closes the last of #9's three blockers. |
| `plugins/council/reference/roster.example.json` | Ported and de-privatized. |
| `.claude-plugin/marketplace.json` | The `council` entry, held back on #9 until a skill existed. |

## Code examples

**The blocker fix.** `openrouter.mjs` previously reached sideways into its host repo for a
`.env` parser, guessing the repo root by walking three levels up from the skill directory:

```js
// before — plugins/council/scripts/openrouter.mjs (cjus-dev original)
function repoRoot() {
  const fromScript = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
  if (existsSync(join(fromScript, "scripts", "dotenv.mjs"))) return fromScript;
  return process.cwd();
}
const { readDotenv } = await import(join(root, "scripts", "dotenv.mjs"));
```

Under any plugin layout that path is wrong, and the `process.cwd()` fallback lands in a
project with no such file. The import was top-level with no `try`/`catch`, so the member died
with `ERR_MODULE_NOT_FOUND` and exit `1` — a code the caller has no meaning for, leaving it
unable to distinguish "no key" (exit `3`, report it in the footer) from "this script is
broken".

```js
// after — plugins/council/scripts/openrouter.mjs:27
import { KEY_NAME, resolveCouncilKey, userEnvPath, displayPath } from "./env.mjs";
const { value: key } = resolveCouncilKey();
```

**The no-key message names the whole chain**, rather than one `.env`:

```js
// plugins/council/scripts/openrouter.mjs:44
console.error(
  `${KEY_NAME} did not resolve. Checked, in order: the environment, ` +
    `${displayPath(`${process.cwd()}/.env`)}, and ${displayPath(userEnvPath())}. ` +
    "Do not seat this member; report it in the council footer. " + ...
```

Naming one level is how a key lands in the file the tool does not read — the failure this
branch's review then found in the prose, and fixed.

**`/council:status` is a wrapper, not a reimplementation** (`skills/status/SKILL.md:16`):

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/council-state.sh" --text
```

Its `allowed-tools` is `Bash(sh:*), Read` and nothing else. `curl`, `jq` and the
`roster-rows.mjs` fallback all run *inside* that script rather than as separate tool calls, so
one grant covers them.

## Plan alignment

**Completed as planned.**

- Phase 1 — three skill directories, `reference/`, the marketplace entry.
- Phase 2 — repo-private material stripped, `council-setup` moved off its sibling-relative
  path onto `${CLAUDE_PLUGIN_ROOT}`.

**Deviations, each recorded in `PLAN.md`.**

- **`/council:status` shipped in phase 1, not phase 4.** Phase 4 listed it, but it needed
  nothing phase 4 adds and the skill directories existed as of phase 1. Phase 4 now owes only
  the `skills/ask` half plus the `rosterPath` deletion.
- **`reference/` carries only `roster.example.json`.** Its three `.md` files belong to phase 6,
  which is the phase that splits them out of `SKILL.md`. Creating them empty here would have
  claimed phase 6 work.
- **`openrouter.mjs` was ported as part of phase 2.** The ticket's phase-2 text names only the
  private-material strip and the path move, but #9's third blocker is this file, and the skill
  references it — leaving it absent would have shipped a dangling path.
- **Phase 9 split at the repo boundary** before it ran. Its cjus-dev half cannot live in a
  branch of this repo, so it became its own ticket there:
  **[cjus/cjus-dev#89](https://github.com/cjus/cjus-dev/issues/89)**, filed 2026-09-18 and
  blocked on this PR.

**Five design questions settled before any phase started**, each with a `## Decision` section
in `PLAN.md`: an absent roster projects the four Claude defaults; `/council:status` probes by
default; `env.mjs:rosterPath` gets deleted rather than reconciled; model-alias availability is
a limitation rather than a question; phase 9 splits at the repo boundary. One new question was
opened and is live — what mechanism makes `COLLAPSED` observable, which phase 5 must answer
before it ships the class.

## Testing

**Automated.** No tests were added; phase 8 owns the new suites (`detect.sh` probes and
`openrouter.mjs` exit codes). The two existing suites still pass unchanged:

```bash
cd plugins/council/scripts
./test-env.sh ./env.mjs                       # 46 passed, 0 failed
./test-council-state.sh ./council-state.sh    # 81 passed, 0 failed
claude plugin validate --strict plugins/council   # passes
claude plugin validate --strict .                 # passes
```

**By hand.** `openrouter.mjs`'s exit codes were exercised directly, since phase 8's suite does
not exist yet:

```bash
node plugins/council/scripts/openrouter.mjs                    # exit 5, usage
env -u COUNCIL_OPENROUTER_API_KEY M=x/y P=p.txt node …         # exit 3, names all three levels
XDG_CONFIG_HOME=/tmp/x env -u … M=x/y P=p.txt node …           # exit 3, names $XDG/council/.env
```

That third case is what caught the review's XDG finding: the runtime resolves
`$XDG_CONFIG_HOME/council` first, while the docs named only `~/.config/council/.env`.

**Edge cases considered.** `detect.sh` is phase 3 and absent, so the `!`-prefixed detection
block in `ask` and `setup` was run with the file missing *and* with `CLAUDE_PLUGIN_ROOT`
unset: both print `detection unavailable` and exit `0`, with no stderr leak. `council-state.sh
--text` was run against the real roster and reports seating correctly.

**What a manual test should look at.** `/council:status` against your own roster is the
cheapest check — it writes nothing. Note that with `XDG_CONFIG_HOME` set, the key belongs in
`$XDG_CONFIG_HOME/council/.env`.

## Impact assessment

- **6 shipped files, 680 insertions, 0 deletions.** Every one is new except
  `.claude-plugin/marketplace.json`, which gains a six-line entry. The other five files in the
  diff are this branch's own plan-folder documents — PLAN, CHANGELOG, COMMITMSG, this summary
  and the review — which add roughly a thousand further lines but ship nothing.
- **No dependencies affected.** The plugin has no install step; `openrouter.mjs` uses only
  Node builtins and the sibling `env.mjs`.
- **No breaking change** to anything shipped. The four pre-existing scripts are untouched.
- **One behavioral change visible to users:** `council` now appears in the marketplace, so it
  can be installed. Before this PR it could not.
- **The cjus-dev copy is untouched** and still authoritative there. Retiring it is the split-out
  ticket's job, so the two copies coexist until then.

## Deferred work

Parked under `## Deferred` in `PLAN.md`, all found during this branch and none fixed here.
**All four were triaged at close**: three ticketed, one dropped.

- **The unconfirmed-diversity annotation is attached to the class, not the cause.**
  `council-state.sh` appends the "unconfirmed" suffix only to `CROSS-VENDOR`, so an
  Ollama-only roster classed `HOMOGENEOUS (local)` carries no annotation when the probe was
  skipped, though it is equally unconfirmed. `skills/status` documents the gap rather than
  asserting past it. **Ticketed onto
  [#15](https://github.com/cjus/cjus-skills/issues/15)**, whose existing five defects are the
  same output contract.
- **`M=`/`P=` env prefixes defeat an `allowed-tools` prefix rule.** `skills/ask` instructs
  `M=… P=… node "${CLAUDE_PLUGIN_ROOT}/scripts/openrouter.mjs"`. Claude Code strips a leading
  assignment only for known-safe variables, so `Bash(node:*)` does not match and every
  OpenRouter member prompts. A narrower rule cannot help, because `${CLAUDE_PLUGIN_ROOT}` does
  not expand in a permission pattern. **Needs an operator decision:** giving the script a
  `--model`/`--prompt-file` interface would fix it at no cost to secrecy, but it changes a
  shipped interface that phase 8 is meant to test. **Carried on
  [#22](https://github.com/cjus/cjus-skills/issues/22)** as an item needing an operator
  decision.
- **Two pre-existing scripts document the key chain without `$XDG_CONFIG_HOME`.**
  `council-lib.sh:131` and `env.mjs:38`. The same wording was corrected in this branch's own
  files; these two are outside the diff and were left alone rather than widening it.
  **Ticketed onto [#15](https://github.com/cjus/cjus-skills/issues/15).**
- **`Bash(jq:*)` is declared but never instructed in `skills/setup`.** Plausibly intended for
  parsing the OpenRouter catalogue the skill fetches with `curl`. Either instruct it or drop
  the grant. **Dropped at triage** — no user-visible symptom and no occasion that would cause
  it to be picked up, which is the bar a ticket has to clear.

**Phases 3-9 continue on [#22](https://github.com/cjus/cjus-skills/issues/22)**, filed
2026-09-18. This PR completes #14 having delivered two of its nine phases — the same shape as its
predecessor, where #9 shipped the mechanical layer alone, closed on PR #13, and #14 was filed
as its successor.

**Assertion audit:** `docs.assertionsFile` is `null` in this repo's `pr-config.json`, so the
audit is disabled rather than skipped. No invariants file exists to update.
