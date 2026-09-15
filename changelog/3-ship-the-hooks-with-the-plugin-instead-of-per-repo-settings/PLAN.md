# Ship the hooks with the plugin instead of per-repo settings

Start date: 2026-09-14 19:18:58 MDT

## Overview

The plugin ships three hooks, and `hooks/README.md` tells the operator to wire them into a
repo's `.claude/settings.json` using `"${CLAUDE_PLUGIN_ROOT}"/hooks/<name>.sh`. That variable
is not exported to a hook belonging to no plugin, so the procedure produces hooks that never
run and fail silently — fail-open in the one file designed to fail closed.

Declare the hooks in `hooks/hooks.json`, the scope where `${CLAUDE_PLUGIN_ROOT}` resolves,
and gate activation on `.claude/pr-config.json` existing, so the plugin being enabled at user
scope does not gate default-branch commits in every repo on the machine.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**[#3 Ship the hooks with the plugin instead of per-repo settings](https://github.com/cjus/cjus-skills/issues/3)** — `bug`, `priority:high`

The plugin ships three hooks and `hooks/README.md` tells the operator to wire them into a repo's `.claude/settings.json` using `"${CLAUDE_PLUGIN_ROOT}"/hooks/<name>.sh`. **That procedure produces a hook that never runs, and it fails silently.**

### Evidence

Measured 2026-09-14 against Claude Code 2.1.272, three headless runs using `--settings` to supply a project-scoped `PreToolUse` hook, each pointing at a probe script that records its argument and environment:

| Hook command contains | Hook fired | Probe recorded |
|---|---|---|
| `'${CLAUDE_PROJECT_DIR}'` (control) | yes | `env_CLAUDE_PROJECT_DIR=[/path/to/repo]`, `env_CLAUDE_PLUGIN_ROOT=[UNSET]` |
| `'${CLAUDE_PLUGIN_ROOT}'` | no | nothing written |
| `"${CLAUDE_PLUGIN_ROOT}/hooks/guard-default-branch.sh"` | no | nothing written |

The control establishes that hooks from that settings file are honored and that `CLAUDE_PROJECT_DIR` is exported. The two plugin-root variants were dropped with no warning and no error: the `Bash` tool call proceeded normally as though no hook were configured.

`CLAUDE_PLUGIN_ROOT` is not exported to a hook that belongs to no plugin, which follows from its definition as the plugin's own installation directory.

**This is fail-open in the one file designed to fail closed.** A repo that follows the README gets a `guard-default-branch.sh` that announces nothing and gates nothing.

### Acceptance

Installing the plugin into a repo that has `.claude/pr-config.json` gives working hooks with no `.claude/settings.json` edit. Installing it into a repo that has no such file changes nothing about that repo's commit behavior. Both states verified by probe, not by inspection.

### Occasion

Blocks switching `behirut-ai2` off its local `pr-*` skills, which is waiting on this.

## Plan

- [x] Phase 1: Add `hooks/hooks.json` declaring all three hooks, which is the documented scope where `${CLAUDE_PLUGIN_ROOT}` does resolve. Verify by probe rather than by reading the docs, since the docs were the source of the wrong answer here.
  **Done 2026-09-14.** `hooks/hooks.json` declares `SessionStart` → `on-session-start.sh`, `PreToolUse`/`Bash` → `guard-default-branch.sh`, `Stop` → `verify-close-landed.sh`, each invoked **directly** rather than through `bash`, preserving the fail-closed executable-bit property argued in `hooks/README.md`. Measured against Claude Code 2.1.272 with a probe plugin of the same shape, installed for real into an isolated `CLAUDE_CONFIG_DIR`:

  | Event | Hook fired | `CLAUDE_PLUGIN_ROOT` |
  |---|---|---|
  | `SessionStart` | yes | resolved to the plugin dir, `plugin_root_exists=yes` |
  | `PreToolUse` (`Bash`) | yes | resolved, same |
  | `Stop` | yes | resolved, same |

  The exact inverse of the ticket's settings.json measurement, and `argv0` in every record is the script path itself, confirming direct invocation. **A `--settings` file declaring `extraKnownMarketplaces` + `enabledPlugins` fired nothing**: a known marketplace is not an installed plugin, so that is not a valid probe route for hooks.
- [x] Phase 2: Decide and implement the activation rule. `guard-default-branch.sh` sets `GUARD_ENABLED="true"` before it reads config, so a plugin-declared hook would gate default-branch commits in **every** repo, the plugin being enabled at user scope. Proposal: a hook is active only where `.claude/pr-config.json` exists, making the config file the marker that a repo opts into this workflow. Skills keep their current behavior of running on defaults when it is absent; the asymmetry is deliberate, because a skill is invoked and a hook is ambient.
  **Done 2026-09-14.** Implemented as `pr_repo_configured()` called at the top of `gate()` in `guard-default-branch.sh`, rather than at each call site. `gate()` is the single chokepoint every block passes through, so the parsed path, the degraded no-jq and no-grep paths that run *before* the config read, the undeterminable-branch path and any path added later all honour it for free. The check needs neither `jq` nor `grep`, which is what lets it cover the paths that exist because one of those is missing, and it resolves the config through `git rev-parse --git-common-dir` so a linked worktree reads its main checkout's config. Acceptance measured live against the real plugin, installed from a copy of this source tree:

  | Repo | `.claude/pr-config.json` | `git commit -am` on `main` | Commits |
  |---|---|---|---|
  | configured | yes | **blocked**, guard message shown | 1 → 1 |
  | unconfigured | no | succeeded, exit 0 | 1 → 2 |

  Neither repo had any `.claude/settings.json` hook wiring. The unconfigured repo *did* have a `.claude/` directory, from the install itself, and stayed inactive: the marker is the config file, not the directory.
- [x] Phase 3: `verify-close-landed.sh` needs no gate of its own, being sentinel-scoped already, but confirm that by probe in a repo with no config.
  **Confirmed 2026-09-14, no change needed.** Probed in an unconfigured repo on the default branch with a dirty tree, the state that would otherwise block: exit 0, no output, no `decision:block`. `verify-close-landed.sh:153` returns before any config read unless the sentinel file exists, and only `/pr:close` arms it.
- [x] Phase 4: ~~`on-session-start.sh` already exits when the branch has no changelog folder. Confirm it stays silent in an unconfigured repo.~~
  **The premise was wrong, and the probe caught it. A gate was needed.** The changelog-folder test is not a stand-in for an activation rule: `changelog/` is an ordinary directory name, so an unconfigured repo that merely *has* one, on any branch matching the default `feature/` prefix, had the full PR context injected into every session. Measured before the fix: 176 bytes of `=== CURRENT PR CONTEXT ===` emitted from a repo with no `pr-config.json`. Fixed by making the config read an early `exit 0` when the file is absent, which also removed a nested conditional. Re-measured after: silent when unconfigured, emits when opted in, silent again when the config is removed.
- [x] Phase 5: Rewrite `hooks/README.md`: the hooks arrive with the plugin, and the settings fragments come out.
  **Done 2026-09-14.** Both JSON fragments removed, with a short note on why the old procedure produced hooks that never fired, so the retired spelling is not reintroduced by someone reading around for it. Gained an `Activation` section and a section for `on-session-start.sh`, which shipped undocumented: the file said "Two hooks" while three shipped. **The root `README.md` carried the same retired procedure and was corrected too** — it told operators `/pr:init` would show them a settings fragment, and quoted a stale 39-case suite.
- [x] Phase 6: Update `/pr:init` step 6, which currently offers those fragments, and its step 7 report line for hooks.
  **Done 2026-09-14.** Step 6 is no longer "offer the hooks" but "tell the operator the hooks just went live", because writing the config in step 4 is now the act that activates them. It names the two per-repo off switches, and instructs against writing a settings fragment. Step 7's report line became `Hooks: active with the plugin - session context, main guard <on | off>, close gate <on | off>`, since installed-vs-offered is no longer the distinction that exists.
- [x] Phase 7: Update `reference/config.md` to document the activation rule next to `mainGuard.enabled` and `closeGate.enabled`.
  **Done 2026-09-14.** Added `## This file's existence is what activates the hooks` directly below the schema table, drawing the distinction the two flags do not: they turn one hook off in a repo that opted in, while the file's presence is what opts it in at all. Names the three consequences: the marker is the file rather than the `.claude/` directory, it resolves at the main checkout's root, and deleting it disables all three hooks.
- [x] Phase 8: Extend `hooks/test-guard-default-branch.sh` with the no-config case, and `scripts/test-acceptance.sh` with a plugin-declared-hooks path.
  **Done 2026-09-14.** `scripts/test-acceptance.sh` went from 28 cases to 39. A new phase 0 asserts the packaging: `hooks.json` present, all three events declared, the guard matched to `Bash`, commands resolving through `${CLAUDE_PLUGIN_ROOT}`, every declared command naming a file that exists **and is executable**, and `hooks/README.md` carrying no settings fragment to drift back into. Phase 1, the repo with no config, gained three inertness cases including the `changelog/`-folder shape that was the Phase 4 defect. **Mutation-tested, since a check that cannot fail is worthless**: removing the guard's executable bit, deleting `hooks.json`, dropping the `Bash` matcher, undeclaring `Stop`, re-adding a README fragment, and removing either activation gate each turn the suite red.
  On the guard suite: `test-guard-default-branch.sh` went from 39 cases to **54**, all passing under every invocation style tested — relative, absolute, from `$HOME`, and from an unconfigured temp directory. Its fixtures opt in through an `optin()` helper, since the suite's throwaway repos were unconfigured and 21 cases correctly stopped gating the moment Phase 2 landed. Added the inert section (commit, push, `--mirror`, `bypassPermissions`, an unknown mode, detached HEAD and an unborn branch all pass untouched), two linked-worktree cases proving the config is found at the main checkout's root rather than by a cwd-relative test, and — across two review rounds — the cases covering payloads whose `cwd` is absent or empty, which must resolve through `CLAUDE_PROJECT_DIR` rather than the hook's working directory.
- [x] Phase 9: Bump the plugin version.
  **Done 2026-09-14.** `0.1.0` → `0.2.0`. Minor rather than patch: the installation procedure changes, since a repo that previously pasted settings fragments should delete them, and the hooks' activation condition is new.

## Open Questions

- ~~Does `hooks/hooks.json` in a user-scope-enabled plugin apply to every repo the user opens, or only where the plugin is enabled per-project?~~ **Resolved 2026-09-14 by probe: every repo.** A user-scope-enabled probe plugin fired its `SessionStart` hook in a throwaway repo with no `.claude/` directory at all, no `pr-config.json`, no project settings and no prior install there, with `cwd` recorded as that repo. Phase 2's activation rule is therefore **necessary, not defensive**, exactly as the plan assumed.
- ~~Where does the config-presence check live — inline in each hook script, or in a shared helper the three scripts source?~~ **Resolved 2026-09-14: inline, and in only two of the three scripts.** `verify-close-landed.sh` needs no check at all (Phase 3), so the shared helper would have had exactly two callers while adding a file each hook must resolve by absolute path, and an ambiguous verdict when a packaging defect makes it unresolvable. Both call sites also want different things: the guard needs a boolean at its `gate()` chokepoint, `on-session-start.sh` needs the config path it was already computing. Each script had already resolved that path independently, so the gate cost two lines in one and a restructure of an existing block in the other. Prior narrowing, kept because it rules the option out on its merits: a third option, gating inline in the `hooks.json` command the way `understand-anything` does with `[ -f .understand-anything/config.json ]`, is **ruled out here**. That spelling resolves the config by a cwd-relative path, and this plugin's config lives at the **main checkout's** root, which is not `$PWD` inside a linked worktree — the very environment this branch is being developed in. `on-session-start.sh` already resolves it via `git rev-parse --git-common-dir`, so the check has to run somewhere that can do the same.

## Deferred

Triaged at `/pr:close`. Not scope for this branch.

- **A repo that followed the old README has dead hook entries in its `.claude/settings.json`.** They are harmless, since they never fired — that is the bug — but they are cruft that now reads as though it were wiring the hooks up, and a reader could "fix" the paths and reintroduce confusion. Nothing in this branch removes them. Candidate: a note in `/pr:init` that detects `${CLAUDE_PLUGIN_ROOT}` hook commands in a repo's settings and offers to strip them.
- **`test-acceptance.sh` phase 0 reads `hooks/README.md` for a `"hooks"` string** to catch a settings fragment drifting back in. That is a coarse proxy: a fragment written with different spacing, or prose that merely quotes the word, would fool it in either direction. It is deliberate for now, being cheap and catching the realistic regression, but a stricter check would parse fenced JSON blocks.

