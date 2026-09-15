# Configuration

Every skill in this plugin reads `.claude/pr-config.json` at the root of the repo it is invoked in. `/pr:init` writes that file. A skill that needs a value the file does not carry falls back to the default in the table below, and a skill that needs a value with no sensible default says so and stops rather than guessing.

## Resolving the file

The config lives at the **repo root**, not in the worktree the session happens to sit in, so resolve it from git rather than from the working directory:

```bash
GIT_COMMON=$(git rev-parse --git-common-dir)
case "$GIT_COMMON" in /*) ABS="$GIT_COMMON" ;; *) ABS="$(cd "$GIT_COMMON" && pwd)" ;; esac
REPO_ROOT=$(dirname "$ABS")
CONFIG="$REPO_ROOT/.claude/pr-config.json"
```

`--git-common-dir` returns the **main** checkout's `.git` from inside a linked worktree, which is what makes one config serve every worktree of a repo. It returns a relative `.git` from the main checkout itself, hence the absolute-path branch.

**A missing config file is not an error.** Every skill runs on defaults when it is absent; `/pr:init` exists to record the choices that differ from them, and to create the labels. A skill reports `no pr-config.json, running on defaults` once and continues.

## Schema

```json
{
  "$schema": "https://raw.githubusercontent.com/cjus/cjus-skills/main/plugins/pr/reference/pr-config.schema.json",
  "repo": "owner/name",
  "ticketPrefix": "",
  "branchPrefix": "feature/",
  "worktrees": {
    "enabled": true,
    "root": "../{repo}-Worktrees"
  },
  "checks": {
    "lint": null,
    "typecheck": null,
    "test": null,
    "build": null
  },
  "docs": {
    "changelogRoot": "changelog",
    "continuityRoot": "continuity",
    "assertionsFile": "ASSERTIONS.md"
  },
  "migrations": {
    "dir": null,
    "versionPattern": "^([0-9]+)_"
  },
  "closeGate": {
    "enabled": true,
    "requiredArtifacts": ["pr-summary", "continuity"]
  },
  "mainGuard": {
    "enabled": true,
    "approvalToken": "PR_ALLOW_MAIN"
  }
}
```

| Key | Default | What it controls |
|---|---|---|
| `repo` | derived from `git remote get-url origin` | The `owner/name` every `gh` call targets. Derivation covers both HTTPS and SSH remote forms. Set it explicitly when the remote is a fork and issues live upstream. |
| `ticketPrefix` | `""` | The ticket ID's leading token. Empty means the ticket ID **is** the issue number, and a branch reads `feature/123-slug`. Set it to `abc` and the ID becomes `ABC-123` with a branch of `feature/abc-123-slug`. |
| `branchPrefix` | `"feature/"` | Prepended to every branch name. Set `""` to disable. |
| `worktrees.enabled` | `true` | Whether `/pr:start` creates a linked worktree or switches the current checkout to a new branch. |
| `worktrees.root` | `"../{repo}-Worktrees"` | Where worktrees are created. `{repo}` expands to the repo's directory name. Relative paths resolve against the main checkout, not the cwd. |
| `checks.*` | `null` | Shell commands for lint, typecheck, test, and build. `null` means the repo has no such check and every skill skips it silently rather than reporting a gap. |
| `docs.changelogRoot` | `"changelog"` | The directory holding one folder per branch. |
| `docs.continuityRoot` | `"continuity"` | The directory holding the recent-work log. Set `null` to disable continuity entries entirely. |
| `docs.assertionsFile` | `"ASSERTIONS.md"` | The invariants file audited at close. Set `null` to disable the audit. |
| `migrations.dir` | `null` | Directory holding hand-applied migrations. `null` means the repo has none and `/pr:close`'s drift gate reports `n/a`. |
| `migrations.versionPattern` | `^([0-9]+)_` | Regex whose first capture group is a migration file's version, used to detect two branches claiming the same one. |
| `closeGate.enabled` | `true` | Whether the `Stop` hook blocks a close that has not landed. |
| `closeGate.requiredArtifacts` | `["pr-summary", "continuity"]` | Which artifacts must exist and be tracked before the gate releases. Valid entries: `pr-summary`, `continuity`, `commitmsg`. Removing `continuity` here is how a repo opts out of that convention without losing the rest of the gate. |
| `mainGuard.enabled` | `true` | Whether the `PreToolUse` hook gates commits and pushes on the default branch. |
| `mainGuard.approvalToken` | `"PR_ALLOW_MAIN"` | The environment variable that records operator approval for a default-branch write. |

## Deriving `repo` from the remote

Both remote forms must parse, and the `.git` suffix is optional in both:

```bash
git remote get-url origin \
  | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##'
```

**If `origin` is absent or the result does not look like `owner/name`, stop and ask.** Guessing here targets `gh` at the wrong repo, and the failure is silent: `gh issue view 1` succeeds against whatever repo it resolved.

## Deriving the ticket ID and the branch slug

With `ticketPrefix` empty, issue `123` titled "Fix the blank render" yields:

- Ticket ID `123`
- Branch `feature/123-fix-the-blank-render`
- Branch slug `123-fix-the-blank-render`
- Changelog folder `changelog/123-fix-the-blank-render/`

With `ticketPrefix` set to `abc`:

- Ticket ID `ABC-123`
- Branch `feature/abc-123-fix-the-blank-render`

**The slug is the title lowercased, non-alphanumerics collapsed to single hyphens, then trimmed.** Every skill that derives a slug uses that one rule, so two skills asked about the same issue produce the same branch name.

**Recovering the issue number from a branch name** is the reverse, and it is what most skills actually need:

```
^(?:<branchPrefix>)?(?:<ticketPrefix>-)?(\d+)-
```

Both optional groups are built from config rather than hardcoded. A branch that does not match carries no ticket, which is a reportable state and not an error: a branch made by hand is still a branch.

## The `checks` contract

A `null` check is **absent**, not failing. Skills distinguish three outcomes and never conflate the first two:

| State | Meaning | How a skill reports it |
|---|---|---|
| `null` | The repo has no such check | Silence. Never a gap. |
| Configured, exit 0 | Passed | One clause in the report |
| Configured, non-zero | Failed | A gap, with the command and its output |

A repo whose test command exists but has no tests is the repo's business, not this plugin's. Configure it or leave it `null`; do not configure it and then explain the exit code in prose.
