# Ship the hooks with the plugin instead of per-repo settings

Start date: 2026-09-14 19:18:58 MDT

Move the plugin's three hooks from per-repo `.claude/settings.json` fragments to a
plugin-declared `hooks/hooks.json`, where `${CLAUDE_PLUGIN_ROOT}` actually resolves, and
gate their activation on the presence of `.claude/pr-config.json` so an unconfigured repo
is left untouched.

## Changes

The full narrative, with the measurement tables, lives in `pr-summary-2026-09-14.md`. All five
timestamps below are preserved; each is condensed to the decision and its evidence.

### 2026-09-14 — Phase 1: hooks declared by the plugin

Added `plugins/pr/hooks/hooks.json` declaring `SessionStart` → `on-session-start.sh`,
`PreToolUse`/`Bash` → `guard-default-branch.sh`, `Stop` → `verify-close-landed.sh`, each invoked
**directly** rather than through `bash` so a missing executable bit cannot hide.

Verified by probe against Claude Code 2.1.272, not by reading docs — the docs produced the
original wrong answer. A probe plugin of identical shape, really installed into an isolated
`CLAUDE_CONFIG_DIR`, fired on all three events with `CLAUDE_PLUGIN_ROOT` resolved: the exact
inverse of the ticket's settings.json result.

Two findings kept: **a user-scope plugin's hooks reach every repo** (the probe fired in a repo
with no `.claude/` at all), which makes the Phase 2 gate necessary rather than defensive; and
**`--settings` is not a probe route for plugin hooks**, since a known marketplace is not an
installed plugin and fired nothing.

### 2026-09-14 — Phases 2–4: the activation rule

`.claude/pr-config.json` became the marker that a repo opted in; the hooks are inert without it.

`guard-default-branch.sh` gained `pr_repo_configured()`, called at the top of `gate()` rather
than at each call site, so every blocking path honours it — including the degraded no-`jq` and
no-`grep` paths that run before the config read. The check needs neither tool, which is what
lets it cover them, and resolves via `git rev-parse --git-common-dir` so a linked worktree reads
its main checkout's config.

`verify-close-landed.sh` needed nothing: probed in an unconfigured repo, on the default branch,
with a dirty tree, it exits 0 silently, being sentinel-scoped.

**`on-session-start.sh` needed a gate the plan said it would not.** The changelog-folder test is
not an activation rule: `changelog/` is an ordinary directory name, so an unconfigured repo that
merely had one, on a branch matching the default prefix, had 176 bytes of PR context injected
into every session.

Acceptance measured live against the real plugin, no settings wiring in either repo: configured
→ commit on `main` blocked; unconfigured → succeeded, exit 0. The unconfigured repo had a
`.claude/` directory and stayed inactive, the marker being the file.

Guard suite 39 → 48 cases; the fixtures had to opt in, since 21 cases correctly stopped gating
the moment the rule landed. The check is inline rather than a shared helper: only two of the
three hooks need it, and the two call sites want different things.

### 2026-09-14 — Phases 5–9: the docs, the suites and the version

The retired procedure is gone from every file that carried it — `hooks/README.md` (both
fragments, plus an `Activation` section and the previously undocumented third hook), the root
`README.md`, `/pr:init` step 6 and its step 7 report line, and `reference/config.md`. Each
rewrite keeps a note on *why* the old spelling failed, so it is not reintroduced by someone
reading around for it.

`scripts/test-acceptance.sh` 28 → 39 cases: a phase 0 asserting the packaging (every declared
command names a file that exists *and* is executable) and three inertness cases in phase 1.
Mutation-tested, since a check that cannot fail is worthless.

Version `0.1.0` → `0.2.0`, minor rather than patch: the install procedure changes.

### 2026-09-14 — Review round: a fail-open the activation gate introduced

`pr_repo_configured()` resolved the repo from `${CWD:-$PWD}`, but `$CWD` is read from the
payload and is unassigned on the path taken when that payload fails to parse. That path — whose
contract is to deny, nothing in an unparseable payload being trustworthy — resolved activation
from `$PWD` alone, so a malformed payload arriving while the hook's cwd sat outside the repo let
a default-branch commit through. The repo had already written the answer down at
`verify-close-landed.sh:142`; the new function was the only place that had drifted.

`CWD` is now cleared explicitly, since it is read before assignment and an inherited environment
variable could otherwise steer the verdict. The malformed-payload cases were asserting the
runner's working directory rather than the hook — green from the repo root, `43 passed, 5
failed` elsewhere — and now set `CLAUDE_PROJECT_DIR` explicitly. Guard suite 48 → 52.

### 2026-09-14 — Second review round: the same fail-open, one line further along

The close's review gate returned `REQUEST_CHANGES`. The previous fix was real but incomplete.

**The fallback had to be spelled in two places.** `guard-default-branch.sh:280` assigns
`CWD="$PWD"` *before* the activation check runs, so a payload that parsed while carrying an
**empty** `cwd` shadowed the chain and never reached `CLAUDE_PROJECT_DIR`. Measured: the guard
emitted nothing and allowed the commit. All four resolution sites now agree.

**The suite was green for the wrong reason, twice.** The "cwd outside the repo" case `cd`s
before invoking `$HOOK`, so a relative hook path vanished — under the documented invocation the
suite read `51 passed, 1 failed`, with failure text indistinguishable from the real defect;
earlier runs used absolute paths and masked it. And reverting line 280 left the suite at `52
passed, 0 failed`: nothing pinned the fix. `$HOOK` is now absolutised once, and two cases pin
the parseable-empty-`cwd` path in both directions, so reverting yields `52 passed, 2 failed`.

A third case asserted nothing — the close gate was silent because no sentinel was armed, not
from any config check — and was relabelled to what it measures.

Guard suite 52 → **54**, green under every invocation style tested. Acceptance 39/39. The
third round approved, and corrected a stale case count restated across three docs.
