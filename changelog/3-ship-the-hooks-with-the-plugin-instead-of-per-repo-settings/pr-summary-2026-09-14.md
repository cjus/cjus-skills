# Ship the hooks with the plugin instead of per-repo settings

Closes the gap between what `hooks/README.md` told operators to do and what Claude Code
actually honours.

## Overview

The plugin ships three hooks. Until now `hooks/README.md` told the operator to wire each one
into a repo's `.claude/settings.json` with `"${CLAUDE_PLUGIN_ROOT}"/hooks/<name>.sh`. **That
procedure produced hooks that never ran, and it failed silently.** `CLAUDE_PLUGIN_ROOT` is the
plugin's own installation directory and is not exported to a hook belonging to no plugin, so
the harness dropped those commands with no warning and no error. A repo that followed the
README got a `guard-default-branch.sh` that announced nothing and gated nothing — fail-open in
the one file designed to fail closed.

This PR declares all three hooks in `plugins/pr/hooks/hooks.json`, the scope where the variable
does resolve, so they install with the plugin and need no settings edit. Because a plugin
enabled at user scope reaches **every repo on the machine**, it also adds an activation rule:
a hook is inert wherever `.claude/pr-config.json` is absent, which makes writing that file the
act that opts a repo in.

Every behavioural claim here was established by probe against Claude Code 2.1.272, not by
reading the documentation — the documentation is what produced the original wrong answer.

## Key changes

| File | Change |
|---|---|
| `plugins/pr/hooks/hooks.json` | **New.** Declares `SessionStart`, `PreToolUse`/`Bash` and `Stop`, each invoking its script directly rather than through `bash` |
| `plugins/pr/hooks/guard-default-branch.sh` | Adds `pr_repo_configured()`, called at the top of `gate()`; clears `CWD` explicitly |
| `plugins/pr/hooks/on-session-start.sh` | Config read became an early exit, so an unconfigured repo gets nothing |
| `plugins/pr/hooks/test-guard-default-branch.sh` | 39 → 52 cases; fixtures opt in, new inert/worktree/cwd sections |
| `plugins/pr/scripts/test-acceptance.sh` | 28 → 39 cases; new phase 0 asserts the packaging |
| `plugins/pr/hooks/README.md` | Both settings fragments removed; gains `Activation` and the previously undocumented third hook |
| `plugins/pr/skills/init/SKILL.md` | Step 6 no longer offers a fragment; step 7's report line rewritten |
| `plugins/pr/reference/config.md` | Documents that this file's presence is the activation rule |
| `README.md` | Carried the same retired procedure; corrected |
| `plugins/pr/.claude-plugin/plugin.json` | `0.1.0` → `0.2.0` |

## Code examples

**The declaration that makes the variable resolve.** `plugins/pr/hooks/hooks.json`:

```json
"PreToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/guard-default-branch.sh\"" }
    ]
  }
]
```

Invoked directly, with no `bash` wrapper. The harness runs a hook as a command, so a file
without its executable bit is a guard that silently never fires; a `bash` wrapper masks exactly
that, and once did.

**The activation rule, at the one chokepoint every block passes through.**
`plugins/pr/hooks/guard-default-branch.sh`:

```bash
pr_repo_configured() {
  local dir="${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}" common
  common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
  [[ -n "$common" ]] || return 1
  [[ "$common" == /* ]] || common="${dir}/${common}"
  [[ -f "$(dirname "$common")/.claude/pr-config.json" ]]
}

gate() {
  pr_repo_configured || exit 0
  ...
```

Checked inside `gate()` rather than at each call site, so the parsed path, the degraded no-jq
and no-grep paths that run *before* the config read, the undeterminable-branch path and any
path added later all honour it. It needs neither `jq` nor `grep`, which is what lets it cover
the paths that exist because one of those is missing.

**Before and after in `on-session-start.sh`** — the config read became the gate:

```bash
# before: absent config fell through to defaults, and the hook kept going
if [[ -f "$CONFIG" ]] && command -v jq >/dev/null 2>&1; then ...

# after
[[ -f "$CONFIG" ]] || exit 0
if command -v jq >/dev/null 2>&1; then ...
```

## Plan alignment

All nine phases completed. Two departed from the plan as written, both reported rather than
quietly absorbed:

- **Phase 4 was specified as a confirmation and turned out to be a fix.** The plan assumed
  `on-session-start.sh` was already silent in an unconfigured repo because it exits when the
  branch has no changelog folder. It is not: `changelog/` is an ordinary directory name, so any
  unconfigured repo that merely had one, on a branch matching the default `feature/` prefix,
  had 176 bytes of PR context injected into every session. Confirming by probe rather than by
  inspection is what caught it.
- **Phase 5 extended past `hooks/README.md`.** The root `README.md` carried the same retired
  procedure, telling operators `/pr:init` would show them a settings fragment, and quoted a
  stale case count. Leaving it would have shipped the bug in prose. `on-session-start.sh` was
  also undocumented — the file said "Two hooks" while three shipped.

Both open questions were resolved by measurement rather than left standing:

- **Do a user-scope plugin's hooks apply to every repo?** Yes. A probe plugin fired in a
  throwaway repo with no `.claude/` directory at all and no prior install. This is what makes
  the activation rule necessary rather than defensive.
- **Inline check or shared helper?** Inline, in two of the three scripts.
  `verify-close-landed.sh` needs none, so a helper would have had two callers while adding a
  file each hook must resolve by absolute path and an ambiguous verdict when it cannot.

## Testing

**By hand**, the ticket's own acceptance bar, both halves verified live against the real plugin
installed from a copy of this tree, with no `.claude/settings.json` wiring in either repo:

| Repo | `pr-config.json` | `git commit -am` on `main` | Commits |
|---|---|---|---|
| configured | yes | blocked, guard message shown | 1 → 1 |
| unconfigured | no | succeeded, exit 0 | 1 → 2 |

The unconfigured repo did have a `.claude/` directory, created by the install itself, and
stayed inactive: the marker is the file, not the directory.

**Automated.** `hooks/test-guard-default-branch.sh` 39 → **52 cases**, and now
cwd-independent — 52/52 from the hooks directory, from an unconfigured temp directory and from
`$HOME`. `scripts/test-acceptance.sh` 28 → **39 cases**. Both suites are run against an
installed copy rather than the source tree, since that is what catches packaging defects.

**Every new check was mutation-tested**, because a check that cannot fail is worthless.
Removing the guard's executable bit, deleting `hooks.json`, dropping the `Bash` matcher,
undeclaring `Stop`, re-adding a README fragment, removing either activation gate, reverting the
`CLAUDE_PROJECT_DIR` fallback and dropping the `CWD=""` initialization each turn a suite red.

**Edge cases considered:** linked worktrees, whose config lives at the main checkout's root and
which a cwd-relative test would read as unconfigured; the degraded no-`jq` and no-`grep` paths;
unparseable payloads, where `CWD` is not yet assigned; detached HEAD and unborn branches; and a
`.claude/` directory that exists without `pr-config.json`.

## Review

One blocking finding, fixed in `e2b7116`. `pr_repo_configured()` originally resolved the repo
from `${CWD:-$PWD}`, but `$CWD` is read from the payload and is unassigned on the path taken
when that payload fails to parse. That path — whose entire contract is to deny, because nothing
in an unparseable payload is trustworthy — resolved activation from `$PWD` alone, so a
malformed payload arriving while the hook's cwd sat outside the repo exited 0 and let a
default-branch commit through. **The defect class this ticket exists to remove, on the path
built to prevent it.**

The repo had already written the answer down: `verify-close-landed.sh:142` uses
`${CLAUDE_PROJECT_DIR:-$PWD}` with a comment explaining why, and `on-session-start.sh:17`
matched it. The new function was the only place that had drifted.

The same round found that the five malformed-payload test cases asserted the runner's working
directory rather than the hook — green from the repo root, `43 passed, 5 failed` from anywhere
else. They now set `CLAUDE_PROJECT_DIR` explicitly and gained a mirror block plus a case
pinning that a cwd outside the repo cannot disarm the guard.

## Impact assessment

12 files changed, +651 / −74. No dependencies affected; the hooks use only `git`, `jq`, `grep`
and bash 3.2.

**Breaking change for repos already using this plugin**, in one direction only: a repo that
followed the old README now has dead hook entries in its `.claude/settings.json`. They were
never firing — that is the bug — so removing them changes no behaviour, but they should be
deleted. Conversely, a repo with `.claude/pr-config.json` gains three working hooks it did not
effectively have before, which is the point. A repo with no config is untouched.

**No assertions file is configured for this repo** (`docs.assertionsFile: null`), so no
invariant audit applies.

## Deferred work

Two items, both parked rather than dropped silently:

- **Repos that followed the old README keep dead hook entries in `.claude/settings.json`.**
  Harmless, since they never fired, but they read as though they were wiring the hooks up, and
  someone could "fix" the paths and reintroduce the confusion. Nothing here removes them. A
  candidate fix is a `/pr:init` step that detects `${CLAUDE_PLUGIN_ROOT}` hook commands in a
  repo's settings and offers to strip them.
- **`test-acceptance.sh` phase 0 greps `hooks/README.md` for a `"hooks"` string** to catch a
  settings fragment drifting back in. That is a coarse proxy: a fragment with different
  spacing, or prose merely quoting the word, would fool it either way. Deliberate for now,
  being cheap and catching the realistic regression; a stricter check would parse fenced JSON
  blocks.
