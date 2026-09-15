# Ship the hooks with the plugin instead of per-repo settings

Start date: 2026-09-14 19:18:58 MDT

Move the plugin's three hooks from per-repo `.claude/settings.json` fragments to a
plugin-declared `hooks/hooks.json`, where `${CLAUDE_PLUGIN_ROOT}` actually resolves, and
gate their activation on the presence of `.claude/pr-config.json` so an unconfigured repo
is left untouched.

## Changes

### 2026-09-14 — Phase 1: hooks declared by the plugin

Added `plugins/pr/hooks/hooks.json` declaring all three hooks at plugin scope: `SessionStart`
→ `on-session-start.sh`, `PreToolUse`/`Bash` → `guard-default-branch.sh`, `Stop` →
`verify-close-landed.sh`.

**Invoked directly, not through `bash`.** `hooks/README.md` argues that running a hook through
`bash` masks a missing executable bit, which is fail-open in the one file that must fail
closed; the declaration keeps that property. All three scripts are `100755` in git.

Verified by probe against Claude Code 2.1.272 rather than by reading the docs, the docs having
been the source of the original wrong answer. A probe plugin of identical shape, really
installed into an isolated `CLAUDE_CONFIG_DIR`, fired on all three events with
`CLAUDE_PLUGIN_ROOT` resolved to its own directory — the exact inverse of the ticket's
settings.json result.

Two findings worth keeping:

- **A user-scope plugin's hooks reach every repo.** The probe fired in a throwaway repo with no
  `.claude/` at all and no prior install. This settles the first open question and makes the
  Phase 2 activation gate necessary rather than merely defensive.
- **`--settings` is not a probe route for plugin hooks.** A settings file declaring
  `extraKnownMarketplaces` plus `enabledPlugins` fired nothing; a known marketplace is not an
  installed plugin. Only a real install exercises hooks.

### 2026-09-14 — Phases 2–4: the activation rule

A hook is ambient where a skill is invoked, so the plugin now treats `.claude/pr-config.json`
at the repo root as the marker that a repo opted into this workflow. Without it the hooks are
inert.

**`guard-default-branch.sh`** gained `pr_repo_configured()`, called at the top of `gate()`
rather than at each call site. Every block passes through `gate()`, so the parsed path, the
degraded no-jq and no-grep paths that run *before* the config read, and the
undeterminable-branch path all honour the rule for free, as will any path added later. The
check uses neither `jq` nor `grep` — that is what lets it cover the paths that exist because
one of those is missing — and resolves through `git rev-parse --git-common-dir` so a linked
worktree reads its main checkout's config.

**`verify-close-landed.sh`** needed nothing. Probed in an unconfigured repo, on the default
branch, with a dirty tree: exit 0, no output. It returns before any config read unless
`/pr:close` armed its sentinel.

**`on-session-start.sh` needed a gate, and the plan said it would not.** The premise was that
its changelog-folder test already covered this. It does not: `changelog/` is an ordinary
directory name, so an unconfigured repo that merely has one, on any branch matching the
default `feature/` prefix, had the whole PR context injected into every session — 176 bytes
of it, measured. The config read became an early exit, which also flattened a nested
conditional.

Acceptance, measured live against the real plugin installed from a copy of this source tree,
with no `.claude/settings.json` hook wiring in either repo:

| Repo | `pr-config.json` | `git commit -am` on `main` | Commits |
|---|---|---|---|
| configured | yes | **blocked**, guard message shown | 1 → 1 |
| unconfigured | no | succeeded, exit 0 | 1 → 2 |

The unconfigured repo did have a `.claude/` directory, created by the install itself, and
stayed inactive. The marker is the file, not the directory.

**Test suite: 39 cases → 48, all passing.** The suite's throwaway repos were unconfigured, so
21 cases correctly stopped gating the moment the rule landed; fixtures now opt in through an
`optin()` helper. Added the inert case (commit, push, `--mirror`, `bypassPermissions`, an
unknown mode, detached HEAD, unborn branch — all pass untouched) and two linked-worktree
cases proving the config is found at the main checkout's root rather than by a cwd-relative
test.

The check is **inline rather than a shared helper**: `verify-close-landed.sh` needs none, so a
helper would have had two callers while adding a file each hook must resolve by absolute path
and an ambiguous verdict when it cannot. Both call sites want different things anyway — a
boolean at the guard's chokepoint, a config path in the session hook.

### 2026-09-14 — Phases 5–9: the docs, the suites and the version

**The retired procedure is gone from every file that carried it.** `hooks/README.md` lost both
settings fragments and gained an `Activation` section, plus a section for `on-session-start.sh`,
which had shipped undocumented behind a heading that said "Two hooks". The root `README.md`
carried the same wrong procedure — it promised that `/pr:init` would show a settings fragment
— and was corrected with it. Each rewrite keeps a short note on *why* the old spelling produced
hooks that never fired, so nobody reintroduces it by reading around for it.

**`/pr:init` step 6** is no longer "offer the hooks" but "tell the operator the hooks just went
live", since writing the config in step 4 is now what activates them. It names the two per-repo
off switches and instructs against writing a settings fragment. Step 7's report line changed
accordingly: installed-vs-offered is no longer a distinction that exists.

**`reference/config.md`** gained a section below the schema table drawing the line the two
`enabled` flags do not: they turn one hook off in a repo that opted in, while this file's
presence is what opts the repo in at all.

**`scripts/test-acceptance.sh`: 28 cases → 39.** A new phase 0 asserts the packaging —
`hooks.json` present, all three events declared, the guard matched to `Bash`, commands resolving
through `${CLAUDE_PLUGIN_ROOT}`, every declared command naming a file that exists *and is
executable*, and the README carrying no fragment to drift back into. Phase 1 gained three
inertness cases, including the `changelog/`-folder shape that was the Phase 4 defect.

**The new checks were mutation-tested**, because a check that cannot fail is worthless. Removing
the guard's executable bit, deleting `hooks.json`, dropping the `Bash` matcher, undeclaring
`Stop`, re-adding a README fragment, and removing either activation gate each turn the suite
red.

**Version `0.1.0` → `0.2.0`.** Minor rather than patch: the installation procedure changes, and
a repo that previously pasted the fragments should now delete them.

Final state, both suites run against an installed copy rather than the source tree:
`test-guard-default-branch.sh` 48 passed 0 failed, `test-acceptance.sh` 39 passed 0 failed.

### 2026-09-14 — Review round: a fail-open the activation gate introduced

The code review found that the activation check re-introduced the defect class this ticket
exists to remove, on the one path built to prevent it. Fixed, with tests that pin it.

**`pr_repo_configured()` resolved the repo from `${CWD:-$PWD}`.** On the unparseable-payload
path `$CWD` is not yet assigned — it is read from the payload that just failed to parse — so
that path resolved activation from `$PWD` alone. A malformed payload arriving while the hook's
cwd sat outside the repo therefore exited 0 silently and let a default-branch commit through.
That path's entire contract is to deny, because nothing in an unparseable payload is
trustworthy. **Fail-open in the one file designed to fail closed, which is the sentence this
ticket opens with.**

The fix is `${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}`, and the repo had already written down why:
`verify-close-landed.sh:142` uses exactly that fallback, with a comment noting that
`CLAUDE_PROJECT_DIR` is exported for hook commands and is the session's project dir while
`$PWD` merely happens to be it sometimes. `on-session-start.sh:17` was already correct. The new
function was the only place that had drifted.

**`CWD` is now cleared explicitly at the top.** It is read before it is assigned on every
pre-parse path, so an inherited environment variable of that name could have steered the
verdict from outside the payload. `MODE` was already cleared for the same reason.

**The malformed-payload cases were asserting the runner's working directory, not the hook.**
They pass no `cwd`, so they inherited whatever directory the suite was invoked from: green from
the repo root, and `43 passed, 5 failed` from anywhere else. They now set `CLAUDE_PROJECT_DIR`
explicitly, and gained a mirror block proving the same payloads stay inert in an unconfigured
repo, plus the case that pins the property both halves rest on — a cwd outside the repo must
not disarm the guard.

Also moved the `gate()` docstring back above `gate()`, having been orphaned above the new
function.

**Guard suite 48 → 52 cases, and now cwd-independent:** 52/52 from the hooks directory, from an
unconfigured temp directory and from `$HOME`. Both new fixes mutation-tested — reverting the
fallback to `${CWD:-$PWD}` turns 4 cases red, and dropping the `CWD=""` initialization with
`CWD` set in the environment turns 6 red. Acceptance suite unchanged at 39/39.

