# Hooks

Two hooks, both optional and neither installed automatically. Each changes how the harness behaves for **every turn** in the repo, so `/pr:init` shows you the settings fragment and lets you decide.

Paths below use `${CLAUDE_PLUGIN_ROOT}`, which Claude Code sets to the installed plugin's directory.

## `verify-close-landed.sh` (Stop)

Refuses to end a turn while a `/pr:close` is in flight and its artifacts have not landed: a dirty tree (untracked files included), an unpushed tip, or a required artifact missing or untracked.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/verify-close-landed.sh"
          }
        ]
      }
    ]
  }
}
```

**It is scoped by a sentinel, and that is not optional.** The `Stop` payload carries no field naming the active skill, so without scoping the hook would demand a clean tree on every stop during ordinary development. `/pr:close` arms it at step 7 and clears a stale one at step 0; the hook disarms itself once the checks pass.

The sentinel lives at `$(git rev-parse --git-dir)/pr-close-active`, which is per-worktree and **outside** the work tree, so it can never dirty the status it guards. Drive it through `--arm` and `--disarm` rather than spelling the path, so the skill and the hook cannot drift apart.

Which artifacts it requires comes from `closeGate.requiredArtifacts`. Setting `closeGate.enabled` to `false` makes it clear any sentinel and exit, so turning it off cannot strand one.

**Blocking is bounded:** at most once per turn, so it can never wedge a session. The block path deliberately leaves the sentinel armed, so a close abandoned after step 7 costs one extra turn on every later turn in that worktree until `--disarm` runs. Every block message names it.

## `guard-default-branch.sh` (PreToolUse, matcher `Bash`)

Requires operator approval for a commit or push on the repo's default branch, including a push whose refspec targets it from any branch, and the whole-repo forms that name no ref while writing every branch.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/guard-default-branch.sh"
          }
        ]
      }
    ]
  }
}
```

**The verdict depends on the session's permission mode, because `"ask"` does not work in all of them.** In prompting modes the hook returns `ask`, which overrides an allow rule and prompts. Under `bypassPermissions`, and any other non-prompting mode, an `ask` is silently a no-op, so the hook returns `deny` instead, which **is** honored there.

**The approval token is a speed bump, not a security boundary.** Under `bypassPermissions` the agent could set it itself. Its job is to make approval explicit and auditable in the transcript, and the workflow's rule is that it may only be added **after** the operator approves in conversation. Rename it with `mainGuard.approvalToken`; the default is `PR_ALLOW_MAIN`.

Two things it cannot do, both worth knowing before relying on it:

- **It evaluates before the command runs**, so a compound `git checkout -b x && git push` is judged against the branch as it stands beforehand, which is still the default branch. Run the checkout and the push as separate tool calls.
- **It sees Bash tool calls only.** A script that commits internally passes unguarded. The guard covers the agent typing git; it is not a repo-wide write barrier.

### Testing it

Nearly every defence in that hook exists because the obvious spelling was measured to fail **open**, and two of the bypasses it closes read as correct. **Reading the hook is not evidence.** Run the probe suite after any edit:

```bash
"${CLAUDE_PLUGIN_ROOT}"/hooks/test-guard-default-branch.sh \
  "${CLAUDE_PLUGIN_ROOT}"/hooks/guard-default-branch.sh
```

39 cases covering the refspec forms, chained and multi-line commands, commit messages that must not forge or trip the guard, redirection through `-C` and `--git-dir`, undeterminable branches, malformed payloads, and the branch names that must **not** gate. Requires `jq` and `git`, and writes only to throwaway repos under the system temp directory.
