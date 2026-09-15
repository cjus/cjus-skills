# Hooks

Three hooks, declared in `hooks.json` and installed **with the plugin**. There is no
`.claude/settings.json` fragment to paste and nothing for `/pr:init` to write.

Earlier versions of this file told you to wire them up per repo with
`"${CLAUDE_PLUGIN_ROOT}"/hooks/<name>.sh`. **That procedure produced hooks that never ran, and
it failed silently.** `CLAUDE_PLUGIN_ROOT` is the plugin's own installation directory and is
not exported to a hook belonging to no plugin, so the harness dropped those commands with no
warning: fail-open in the one file designed to fail closed. `hooks.json` is the scope where
the variable does resolve, measured by probe on all three events.

The scripts are invoked **directly**, not through `bash`. The harness runs a hook as a
command, so a file without its executable bit is a guard that silently never fires. A `bash`
wrapper masks exactly that, and once did: this plugin shipped a non-executable guard while
every test still passed.

## Activation

**A hook is inert in a repo that has no `.claude/pr-config.json`.**

The plugin is normally enabled at user scope, and a user-scope plugin's hooks fire in every
repo you open — measured, not assumed. Without an activation rule, installing this plugin
would gate default-branch commits in every repo on the machine. The config file is the marker
that a repo opted into this workflow, so `/pr:init` writing it is what turns the hooks on.

The asymmetry with the skills is deliberate: a skill is **invoked**, so it may sensibly run on
defaults when the config is absent. A hook is **ambient**, so it may not.

The config is read from the **main checkout's** root via `git rev-parse --git-common-dir`,
never by a path relative to the hook's working directory. A linked worktree has no `.claude/`
of its own, so a relative test would read every worktree as unconfigured and disarm the guard
exactly where this workflow does its work.

## `on-session-start.sh` (SessionStart)

Loads the current branch's PR context — its plan folder, the newest summary — into the
session. Stdout goes straight into the model's context. Sources are startup, resume, clear and
compact, so after a compaction this rehydrates the branch state and the successor does not
resume blind.

There is no project-pointer file: the branch **is** the pointer, so a worktree can never
rehydrate another branch's context. It stays silent on the default branch, and when the branch
has no folder under `<changelogRoot>/`.

**The folder test is not an activation rule and must not be mistaken for one.** `changelog/`
is an ordinary directory name; before the config gate existed, any unconfigured repo that
merely had one, on a branch matching the default `feature/` prefix, had this context injected
into every session.

## `guard-default-branch.sh` (PreToolUse, matcher `Bash`)

Requires operator approval for a commit or push on the repo's default branch, including a push
whose refspec targets it from any branch, and the whole-repo forms that name no ref while
writing every branch.

**The verdict depends on the session's permission mode, because `"ask"` does not work in all
of them.** In prompting modes the hook returns `ask`, which overrides an allow rule and
prompts. Under `bypassPermissions`, and any other non-prompting mode, an `ask` is silently a
no-op, so the hook returns `deny` instead, which **is** honored there.

**The approval token is a speed bump, not a security boundary.** Under `bypassPermissions` the
agent could set it itself. Its job is to make approval explicit and auditable in the
transcript, and the workflow's rule is that it may only be added **after** the operator
approves in conversation. Rename it with `mainGuard.approvalToken`; the default is
`PR_ALLOW_MAIN`.

Activation is checked inside `gate()`, the single chokepoint every block passes through, so
the degraded paths that run before the config read honour it too. The check needs neither `jq`
nor `grep`, which is what lets it cover the paths that exist because one of those is missing.

Two things it cannot do, both worth knowing before relying on it:

- **It evaluates before the command runs**, so a compound `git checkout -b x && git push` is
  judged against the branch as it stands beforehand, which is still the default branch. Run
  the checkout and the push as separate tool calls.
- **It sees Bash tool calls only.** A script that commits internally passes unguarded. The
  guard covers the agent typing git; it is not a repo-wide write barrier.

## `verify-close-landed.sh` (Stop)

Refuses to end a turn while a `/pr:close` is in flight and its artifacts have not landed: a
dirty tree (untracked files included), an unpushed tip, or a required artifact missing or
untracked.

**It is scoped by a sentinel, and that is not optional.** The `Stop` payload carries no field
naming the active skill, so without scoping the hook would demand a clean tree on every stop
during ordinary development. `/pr:close` arms it at step 7 and clears a stale one at step 0;
the hook disarms itself once the checks pass.

That sentinel is also why this hook needs no activation check of its own: it returns before any
config read unless `/pr:close` armed it, which only happens in a repo already running this
workflow. Verified by probe in an unconfigured repo, on the default branch, with a dirty tree.

The sentinel lives at `$(git rev-parse --git-dir)/pr-close-active`, which is per-worktree and
**outside** the work tree, so it can never dirty the status it guards. Drive it through
`--arm` and `--disarm` rather than spelling the path, so the skill and the hook cannot drift
apart.

Which artifacts it requires comes from `closeGate.requiredArtifacts`. Setting
`closeGate.enabled` to `false` makes it clear any sentinel and exit, so turning it off cannot
strand one.

**Blocking is bounded:** at most once per turn, so it can never wedge a session. The block path
deliberately leaves the sentinel armed, so a close abandoned after step 7 costs one extra turn
on every later turn in that worktree until `--disarm` runs. Every block message names it.

## Turning one off

`mainGuard.enabled` and `closeGate.enabled` in `.claude/pr-config.json` disable the guard and
the close gate for a repo that has otherwise opted in. See `reference/config.md`. To disable
all three at once, the plugin itself is what you disable.

## Testing

Nearly every defence in `guard-default-branch.sh` exists because the obvious spelling was
measured to fail **open**, and two of the bypasses it closes read as correct. **Reading the
hook is not evidence.** Run the probe suite after any edit:

```bash
"${CLAUDE_PLUGIN_ROOT}"/hooks/test-guard-default-branch.sh \
  "${CLAUDE_PLUGIN_ROOT}"/hooks/guard-default-branch.sh
```

48 cases covering the refspec forms, chained and multi-line commands, commit messages that must
not forge or trip the guard, redirection through `-C` and `--git-dir`, undeterminable branches,
malformed payloads, the branch names that must **not** gate, the unconfigured repo that must be
left untouched, and the linked worktree whose config lives at its main checkout's root.
Requires `jq` and `git`, and writes only to throwaway repos under the system temp directory.

**It invokes the hook directly rather than through `bash`, deliberately**, for the reason given
at the top of this file: invoking through `bash` hides a missing executable bit.

### Testing all three together

`${CLAUDE_PLUGIN_ROOT}/scripts/test-acceptance.sh` drives the whole plugin's mechanical
substrate through the lifecycle in throwaway repos, including all three hooks under a
non-default configuration. **Point it at an installed copy rather than a source tree**, since
that is what catches packaging defects.
