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

## This file's existence is what activates the hooks

The two `enabled` flags above turn individual hooks **off** in a repo that already opted in.
What turns them **on at all** is this file being present.

The plugin declares its three hooks in `hooks/hooks.json`, so they install with the plugin and
need no `.claude/settings.json` edit. A plugin enabled at user scope reaches every repo on the
machine, which for an ambient hook is too wide: without a rule, installing this plugin would
gate default-branch commits in every repo you open. **So a hook is inert wherever
`.claude/pr-config.json` does not exist**, and writing it is the act that opts a repo in.

The asymmetry with the skills is deliberate. A skill is **invoked**, so it may sensibly fall
back to the defaults in this table when the file is absent. A hook is **ambient**, so it may
not.

Three consequences worth knowing:

- **The marker is the file, not the directory.** A repo with a `.claude/` holding only
  `settings.json` is still unconfigured as far as the hooks are concerned.
- **It is resolved at the main checkout's root**, through `git rev-parse --git-common-dir`. A
  linked worktree has no `.claude/` of its own, so a worktree reads its main checkout's config
  and the guard stays armed where this workflow actually runs.
- **Deleting this file disables all three hooks**, which is a blunter instrument than the two
  `enabled` flags and takes the rest of the workflow's configuration with it.

## Deriving `repo` from the remote

Both remote forms must parse, and the `.git` suffix is optional in both:

```bash
git remote get-url origin \
  | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##'
```

**If `origin` is absent or the result does not look like `owner/name`, stop and ask.** Guessing here targets `gh` at the wrong repo, and the failure is silent: `gh issue view 1` succeeds against whatever repo it resolved.

## Deriving the ticket ID, the branch slug and the PR title

With `ticketPrefix` empty, issue `123` titled "Fix the blank render" yields:

- Ticket ID `123`
- Branch `feature/123-fix-the-blank-render`
- Branch slug `123-fix-the-blank-render`
- Changelog folder `changelog/123-fix-the-blank-render/`
- Title tag `#123`
- PR title `[#123] Fix the blank render`

With `ticketPrefix` set to `abc`:

- Ticket ID `ABC-123`
- Branch `feature/abc-123-fix-the-blank-render`
- Title tag `ABC-123`
- PR title `[ABC-123] Fix the blank render`

**The slug is the title lowercased, non-alphanumerics collapsed to single hyphens, then trimmed.** Every skill that derives a slug uses that one rule, so two skills asked about the same issue produce the same branch name.

**The PR title is the title tag in square brackets, one space, then the title.** The title tag is the ticket ID, with a `#` in front when the ID is a bare issue number. That `#` makes the tag read as a GitHub reference. A prefixed ID gets no `#`, because `#ABC-123` is not a GitHub reference. `/pr:pre-test` builds the title from PLAN.md's H1, and `/pr:close` builds it from the issue title. `/pr:start` wrote the first from the second, so they normally agree.

- **A title counts as prefixed only when it starts with exactly `[<title tag>] `**, meaning `[#123] ` or `[ABC-123] `. A matching tag later in the title does not count. GitHub appends the PR number to the end of a squash subject, so only the start of the title keeps the ticket at a fixed position.
- **A leading token is ticket-shaped** when it is `[#<digits>]`, or `[<PREFIX>-<digits>]` in any case with a prefix configured, whether or not it matches this ticket. `[#<digits>]` counts even in a prefixed repo, so a repo that adopts a prefix later can still correct its open PRs. Any other leading tag, such as `[WIP]`, belongs to the operator. `/pr:close § Step 4b` replaces a ticket-shaped token and keeps the operator's tags.
- **A branch that carries no ticket gets no prefix.** It has no ID to put there, and inventing one is worse than leaving the title unprefixed.

The prefix exists because a PR's number never matches its ticket's. `ticketing.md § PR numbers are not ticket numbers` explains why, and how the prefix reaches the commit that lands on the default branch.

**Recovering the issue number from a branch name** is the reverse, and it is what most skills actually need:

```
^(?:<branchPrefix>)?(?:<ticketPrefix>-)?(\d+)-
```

Both optional groups are built from config rather than hardcoded. A branch that does not match carries no ticket, which is a reportable state and not an error: a branch made by hand is still a branch.

## Resolving a ticket number to its branch

`/pr:cleanup`, `/pr:abort` and `/pr:sync` take a ticket number and have to find the branch that carries it. All three use this one rule:

```bash
git for-each-ref --format='%(refname:lstrip=2)%09%(worktreepath)' refs/heads \
  | grep -iE '^(<branchPrefix>)?([^/[:space:]]+/)*(<ticketPrefix>-)?<ticket>-'
```

Drop the `(<branchPrefix>)?` and `(<ticketPrefix>-)?` groups when those settings are empty, and escape any regex metacharacters in them. `lstrip=2` rather than `short`, which prints `heads/…` when a tag shares the branch's name and so yields the wrong slug.

**Match the branch name, never the worktree path.** The pattern requires the ticket to open a segment of the branch name, or to follow `branchPrefix` directly, and to end at its hyphen. So ticket `6` finds `feature/6-…`, a nested `feature/<owner>/6-…`, `feature-6-…` where `branchPrefix` is `feature-`, and, with `ticketPrefix` set to `abc`, `feature/abc-6-…`; and not `feature/16-…`, `feature/66-…`, `feature/6x-…` or `feature/14-phases-6-9`. A path cannot be anchored that way: `6-` is a substring of `…/feature/16-…`, and a worktree root's own name can carry digits.

**Each row is a branch and the worktree it is checked out in.** The second field is empty when the branch is checked out nowhere, and is the main checkout (the first `worktree` entry of `git worktree list --porcelain`) when the branch is checked out there, as it usually is when worktrees are off. The rows cover every local branch that carries the ticket, not only those with a worktree, so each skill says which rows it can act on.

The rule is looser than the recovery regex above in one respect: it accepts segments before the ticket, such as an owner. So a nested `feature/<owner>/6-…` is found by its number, although recovering a number from that name finds none.

**When nothing matches, look for a word in front of the number** before reporting the miss:

```bash
git for-each-ref --format='%(refname:lstrip=2)' refs/heads \
  | grep -iE '(^|/)[[:alpha:]]+-<ticket>-'
```

A hit is usually a branch that puts a tracker key before the number, such as `<user>/abc-836-…`, in a repo whose `ticketPrefix` is not that key, often because the repo never ran `/pr:init`. Name the branch, say that setting `ticketPrefix` to the key through `/pr:init` resolves it, and **do not act on it.** The rule is strict on purpose: accepting any leading word would let a hand-made `feature/fix-6-…` answer for ticket 6.

## The `checks` contract

A `null` check is **absent**, not failing. Skills distinguish three outcomes and never conflate the first two:

| State | Meaning | How a skill reports it |
|---|---|---|
| `null` | The repo has no such check | Silence. Never a gap. |
| Configured, exit 0 | Passed | One clause in the report |
| Configured, non-zero | Failed | A gap, with the command and its output |

A repo whose test command exists but has no tests is the repo's business, not this plugin's. Configure it or leave it `null`; do not configure it and then explain the exit code in prose.
