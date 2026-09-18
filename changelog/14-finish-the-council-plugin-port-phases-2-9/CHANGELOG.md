# Finish the council plugin port: phases 2-9

Start date: 2026-09-18 09:03:01 MDT

Successor to #9. That branch landed the mechanical layer only — `env.mjs`, `council-lib.sh`,
`roster-rows.mjs`, `council-state.sh` and two test suites — and closed on merge of PR #13.
The plugin ships no skills and is held out of `.claude-plugin/marketplace.json`, so it is
inert. This branch lands the skills, the reference docs and the README, taking the plugin
from inert to installable.

The retirement of the cjus-dev copy is **not** part of this branch. Phase 9 splits at the
repo boundary — only its `detect.sh` half lands here, and the deletions in cjus-dev become
their own ticket there, blocked on this PR. See `PLAN.md § Decision — phase 9 splits at the
repo boundary`.

## Changes

### 2026-09-18 — design questions settled ahead of the phases

All five open questions settled before any phase started, each recorded in `PLAN.md` with a
`## Decision` section. Summary:

- **An absent roster projects the four Claude defaults**, rather than `0 seated / NONE`. The
  script's own `roster:` line already claimed a Claude-only council; the seating line
  contradicted it.
- **`/council:status` probes by default.** `--no-probe` collapses `down` into `unknown`, and
  `unknown` still seats the member, so the flag reports a seat that may not exist.
- **`env.mjs:rosterPath` gets deleted rather than reconciled** with `council_roster_path`. The
  two config-dir halves already agree; the only divergence was `COUNCIL_ROSTER`, and the JS
  side has no callers.
- **Model alias availability is a limitation, not a question.** Downgraded to the phase 7
  README task. It opened a new live question: phase 5 ships the `COLLAPSED` class with nothing
  observing actual per-member models, so the class can never fire.
- **Phase 9 splits at the repo boundary.** Only the `detect.sh` half lands here; the cjus-dev
  half becomes its own ticket there, blocked on this PR.

### 2026-09-18 — phase 1: the three skills, `reference/`, the marketplace entry

- **`skills/ask/SKILL.md`** — ported from cjus-dev's `council/SKILL.md`. Renamed to
  `/council:ask`, every `${CLAUDE_SKILL_DIR}` path moved onto `${CLAUDE_PLUGIN_ROOT}`, and
  `allowed-tools` narrowed from bare `Bash` to `Agent, Read, Grep, Glob` plus eight scoped
  `Bash(...)` entries. Roster resolution now names the `XDG_CONFIG_HOME` level the shipped
  `council_roster_path` already honors.
- **`skills/setup/SKILL.md`** — ported from `council-setup/SKILL.md`. This carries phase 2's
  path move: the sibling-relative `${CLAUDE_SKILL_DIR}/../council/detect.sh` is now
  `${CLAUDE_PLUGIN_ROOT}/scripts/detect.sh`.
- **`skills/status/SKILL.md`** — new, and the only skill without a cjus-dev original. A
  read-only wrapper over `council-state.sh --text`, per Decision 3 on #9 and the probe
  decision above. `allowed-tools` is `Bash(sh:*), Read` and nothing else.
- **`reference/roster.example.json`** — ported and de-privatized. `providers.md`,
  `trust-boundary.md` and `roster.md` are deliberately left to phase 6, which is the phase
  that splits them out of `SKILL.md`.
- **The marketplace entry** for `council` is now in `.claude-plugin/marketplace.json`. It was
  held back on #9 until a skill existed; three now do.

### 2026-09-18 — phase 2: private material stripped, paths moved

- **`scripts/openrouter.mjs`** — ported, closing the last of #9's three blockers. The
  host-repo `await import(<repoRoot>/scripts/dotenv.mjs)` and its `repoRoot()` walk are gone;
  it calls `env.mjs:resolveCouncilKey` instead. Its no-key message now names all three levels
  of the chain rather than one `.env`, because naming one is how a key lands in the file the
  tool does not read.
- **Repo-private material removed** from every ported file. The `ASSERTIONS.md → A-060`
  attribution, the `sb's PRODUCTION key` wording, the hash-verified same-secret note and the
  `cjus.dev` settings claim are all gone; the generic halves of those warnings are kept.
  `roster.example.json`'s dated ZDR measurement became the *method* for measuring, with a note
  that any such measurement goes stale.
- **`skills/setup` step 5 reads the actual settings file** instead of asserting what
  `.claude/settings.json` already grants. It also now states that `${CLAUDE_PLUGIN_ROOT}` does
  not expand inside `settings.json`, so the rule must carry a resolved absolute path — a
  silent no-match otherwise.

### Verification

- `claude plugin validate --strict plugins/council` — passes.
- `claude plugin validate --strict .` (marketplace) — passes.
- `./test-env.sh ./env.mjs` — 46 passed, 0 failed.
- `./test-council-state.sh ./council-state.sh` — 81 passed, 0 failed.
- `openrouter.mjs` exit codes checked by hand: `5` on missing `M`/`P`, `3` with no key
  resolvable, and the error names all three chain levels. The suite for these is phase 8.
- `council-state.sh --text` runs clean and reports real seating.

### Known interim state

`scripts/detect.sh` is **phase 3** and does not exist yet, so the `!`-prefixed detection block
in `skills/ask` and `skills/setup` falls through to its `|| echo "detection unavailable"`
branch. Verified to degrade cleanly rather than error. Both skills already instruct the model
to proceed Claude-only and say so when that line appears.
