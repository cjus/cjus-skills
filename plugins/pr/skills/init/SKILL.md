---
name: init
description: Set a repo up for the pr plugin. Detects the GitHub repo, the package manager and the check commands, asks about the choices it cannot detect, writes .claude/pr-config.json, and creates the status and priority labels the queue runs on. Use when the user says "/pr:init", when a skill reports a no-config gap, or when setting up a repo to use this workflow for the first time.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(node:*), Bash(ls:*), Bash(cat:*), Read, Write, AskUserQuestion
argument-hint: "[--force]"
---

# /pr:init

Prepare the current repo for this plugin. Runs **once per repo**, not once per branch.

It writes `.claude/pr-config.json` and creates the labels the queue depends on. Everything else in the plugin runs on defaults until it does, so `/pr:init` is a convenience for recording what differs, plus the one step that touches GitHub's label set.

| Invocation | Effect |
|---|---|
| `/pr:init` | Refuses if `.claude/pr-config.json` already exists, reporting what it holds. |
| `/pr:init --force` | Re-runs detection and rewrites the file, after showing the diff and confirming. |

Any other argument is an error: say so and stop.

## Step 1. Resolve the repo root and refuse to guess

```bash
GIT_COMMON=$(git rev-parse --git-common-dir)
case "$GIT_COMMON" in /*) ABS="$GIT_COMMON" ;; *) ABS="$(cd "$GIT_COMMON" && pwd)" ;; esac
REPO_ROOT=$(dirname "$ABS")
```

**Refuse and stop** when any of these hold, rather than writing a config that names the wrong thing:

- The command fails, meaning this is not a git repo.
- `git remote get-url origin` is absent, or does not parse to `owner/name` by the rule in `${CLAUDE_PLUGIN_ROOT}/reference/config.md`.
- `.claude/pr-config.json` exists and `--force` was not passed.

An unresolvable repo is the one failure worth blocking on: every `gh` call in the plugin targets it, and a wrong value succeeds silently against somebody else's repo.

## Step 2. Detect what can be detected

Run these together and report what each returned:

```bash
git remote get-url origin
git symbolic-ref --quiet refs/remotes/origin/HEAD
ls "$REPO_ROOT"
gh repo view --json nameWithOwner,defaultBranchRef
```

Derive:

- **`repo`**, by the parsing rule in `reference/config.md`. Cross-check it against `gh repo view --json nameWithOwner`. **On a mismatch, stop and ask** rather than picking one: the remote and the authenticated view disagreeing means the checkout points somewhere the operator may not intend.
- **The default branch**, from `refs/remotes/origin/HEAD` or `defaultBranchRef`. This is detected at run time by every skill and is deliberately **not** written into the config, so a repo that renames its default branch needs no config edit.
- **The check commands**, from the lockfile and manifest present at the repo root:

| Marker | Package manager | Check commands to propose |
|---|---|---|
| `pnpm-lock.yaml` | pnpm | `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build` |
| `yarn.lock` | yarn | `yarn lint`, `yarn typecheck`, `yarn test`, `yarn build` |
| `package-lock.json` | npm | `npm run lint`, and so on |
| `Cargo.toml` | cargo | `cargo clippy`, `cargo test`, `cargo build` |
| `go.mod` | go | `go vet ./...`, `go test ./...`, `go build ./...` |
| `pyproject.toml` | python | leave `null` and ask; the tooling varies too much to guess |

**Propose only the scripts that exist.** For a Node repo, read `package.json → scripts` and offer only the keys actually defined. A configured command that fails because the script is missing is worse than a `null`, because `null` is silent and a broken command becomes a gap on every run.

## Step 3. Ask about what cannot be detected

Use `AskUserQuestion`. Keep it to the choices that change behavior, and carry the detected value as the recommended option:

1. **Ticket prefix.** Default none, so a branch reads `feature/123-slug` and the ticket ID is the bare issue number. Offer a prefix for repos that want `ABC-123`.
2. **Worktrees.** Default on. Say plainly that the alternative switches the current checkout to a new branch instead.
3. **Check commands.** Present what was detected for confirmation, and let the operator correct or clear any of them.
4. **Close-gate artifacts.** Default `pr-summary` and `continuity`. Offer dropping `continuity` for a repo that does not want that convention.

**Do not ask about anything already determined.** The repo, the default branch and the package manager were detected in step 2; presenting them as questions spends the operator's attention re-confirming a fact.

## Step 4. Write the config

Write `$REPO_ROOT/.claude/pr-config.json` with the **Write** tool, creating `.claude/` if absent.

**Write only the keys that differ from the defaults**, plus `repo` always. A config that restates every default is a config nobody can skim for what is unusual about this repo, and it silently pins values that would otherwise track the plugin's own defaults as they improve.

```json
{
  "$schema": "https://raw.githubusercontent.com/cjus/cjus-skills/main/plugins/pr/reference/pr-config.schema.json",
  "repo": "owner/name",
  "checks": {
    "lint": "pnpm lint",
    "test": "pnpm test"
  }
}
```

Then verify it parses and that the plugin agrees with what you wrote:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline --text
```

The `no-config` gap must be gone from that output. If it is not, the file is in the wrong place or is malformed, and the run has not succeeded.

## Step 5. Create the labels

Creating an existing label is an error `gh` reports and nothing else, so this is safe to run every time:

```bash
for L in "status:todo:#ededed" "status:in-progress:#0e8a16" \
         "priority:high:#d93f0b" "priority:medium:#fbca04" "priority:low:#c5def5" \
         "bug:#d73a4a" "feature:#a2eeef" "refactor:#c2e0c6" "docs:#0075ca" \
         "infra:#5319e7" "research:#bfd4f2"; do
  name="${L%:*}"; color="${L##*#}"
  gh label create "$name" --color "$color" --repo "$REPO" 2>/dev/null || true
done
```

Then read the set back and report which names now exist, rather than assuming the loop worked:

```bash
gh label list --repo "$REPO" --limit 60 --json name --jq '.[].name'
```

**The status and priority labels are the whole ticket lifecycle**, so a missing one silently drops an issue out of the queue rather than erroring. That is why this step verifies instead of trusting.

## Step 6. Offer the hooks, never install them silently

The plugin ships two hooks, and both change how the harness behaves for every turn in this repo, so neither is installed without the operator saying yes.

| Hook | What it does | Cost of enabling |
|---|---|---|
| Close gate (`Stop`) | Refuses to end a turn while a close is in flight and its artifacts are uncommitted | One extra turn if a close is abandoned deliberately, until it is disarmed |
| Default-branch guard (`PreToolUse`) | Gates a commit or push on the default branch | One prompt per intentional default-branch commit |

Show the exact `.claude/settings.json` fragment each one needs, and let the operator paste it or approve you writing it. `${CLAUDE_PLUGIN_ROOT}/hooks/README.md` carries both fragments.

## Step 7. Report

```
pr plugin ready in <owner/name>

  Config:    .claude/pr-config.json (<n> keys written)
  Default:   <branch> (detected each run, not stored)
  Tickets:   feature/<number>-<slug>, ticket ID is the issue number
  Worktrees: enabled -> <root> | disabled
  Checks:    lint <cmd> | none, test <cmd> | none, ...
  Labels:    <n> present, <n> created this run
  Hooks:     close gate <installed | offered>, main guard <installed | offered>

Next: /pr:ticket <description> to file the first ticket.
```

Report a detected value and a chosen value the same way. Which came from detection and which from a question is not something the reader acts on.

## Common mistakes

- **Writing the config into a worktree.** It belongs at the main checkout's root, which is what `--git-common-dir` resolves. A per-worktree copy means two worktrees of one repo disagree about the ticket prefix.
- **Guessing `repo` from the directory name.** The directory is whatever the clone was named. Parse the remote, and stop if it does not parse.
- **Configuring a check command that does not exist.** A `null` is silent; a broken command is a gap on every run forever.
- **Storing the default branch.** It is detected per run on purpose, so renaming it does not strand the config.
