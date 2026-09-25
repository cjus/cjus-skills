---
name: init
description: Set a repo up for the pr plugin. Detects the GitHub repo, the package manager and the check commands, asks about the choices it cannot detect, writes .claude/pr-config.json, creates the status and priority labels the queue runs on, and checks that squash merges take the PR title. Use when the user says "/pr:init", when a skill reports a no-config gap, or when setting up a repo to use this workflow for the first time.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(node:*), Bash(ls:*), Bash(cat:*), Read, Write, AskUserQuestion
argument-hint: "[--force]"
---

# /pr:init

Prepare the current repo for this plugin. Runs **once per repo**, not once per branch.

It writes `.claude/pr-config.json` and creates the labels the queue depends on. Everything else in the plugin runs on defaults until it does, so `/pr:init` is a convenience for recording what differs, plus the two steps that touch GitHub: its label set, and, only with a yes, the repo's squash-merge title setting.

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

## Step 6. Check how squash merges are titled

`/pr:pre-test` and `/pr:close` prefix every PR title with its ticket ID, `[#32] <title>`, so a squash merge lands as `[#32] <title> (#41)` with both numbers in its subject. That holds only when GitHub builds the squash subject from the PR title. See `${CLAUDE_PLUGIN_ROOT}/reference/ticketing.md § PR numbers are not ticket numbers`.

```bash
gh api "repos/$REPO" --jq '[.allow_squash_merge, .squash_merge_commit_title, .squash_merge_commit_message] | @tsv'
```

| Result | Action |
|---|---|
| `allow_squash_merge` is `false` | Report `squash merging off` and move on. There is no squash subject to fix. |
| `squash_merge_commit_title` is `PR_TITLE` | Report it as already set. |
| `squash_merge_commit_title` is `COMMIT_OR_PR_TITLE` | Ask, below. |
| A field is empty or the call fails | Report `could not read` and move on. These fields may need admin access to read, and an unread setting is not evidence of either value. |

Under `COMMIT_OR_PR_TITLE`, **a PR with a single commit lands with that commit's subject, not its title**, so the ticket prefix silently fails to reach the default branch on exactly the small PRs that are easiest to merge without looking. Ask with `AskUserQuestion`, carrying `PR_TITLE` as the recommended option, and say plainly that it changes a setting on the GitHub repo, not a file in it. **Never change it without a yes.** It is a repo-wide setting, and it applies to PRs that never went through this plugin.

On a yes, read the current message setting and send it back unchanged with the new title. That pins the pair, so the call changes only the title. GitHub's docs require the title whenever the message is sent, which this call satisfies:

```bash
CURRENT_MESSAGE=$(gh api "repos/$REPO" --jq .squash_merge_commit_message) && [ -n "$CURRENT_MESSAGE" ] \
  && gh api -X PATCH "repos/$REPO" \
       -f squash_merge_commit_title=PR_TITLE \
       -f squash_merge_commit_message="$CURRENT_MESSAGE"
```

**Read the message on its own, and stop if it comes back empty.** An empty string is not one of the message values GitHub accepts (`PR_BODY`, `COMMIT_MESSAGES`, `BLANK`), so the call would fail, and not for the admin reason described below. Do not split the earlier `@tsv` line with `read`: tab counts as whitespace to `IFS`, so an empty middle field shifts the fields after it one place left.

Then re-run the read and report the value it returns rather than the value you sent. A `403` or `404` from the `PATCH` means the token lacks admin on the repo. Report that as `left as COMMIT_OR_PR_TITLE (needs repo admin)`. It does not fail the run, since everything else this skill set up still stands.

## Step 7. Tell the operator the hooks just went live

**The hooks arrive with the plugin and need no `.claude/settings.json` edit.** They are declared in `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`, which is the scope where `${CLAUDE_PLUGIN_ROOT}` resolves. Do not offer a settings fragment, and do not write one: earlier versions of this step did, and the result was hooks that never ran and failed silently.

**Writing the config in step 4 is what switched them on.** A hook is inert in a repo with no `.claude/pr-config.json`, so this repo had none of this behavior a moment ago and has all of it now. That is a real change to every turn in this repo, so say so plainly rather than letting the operator discover it at the first blocked commit.

| Hook | What it does | Cost |
|---|---|---|
| Session context (`SessionStart`) | Loads the branch's plan folder into each session | Some context on every session start, on a branch that has a folder |
| Default-branch guard (`PreToolUse`) | Gates a commit or push on the default branch | One prompt per intentional default-branch commit |
| Close gate (`Stop`) | Refuses to end a turn while a close is in flight and its artifacts are uncommitted | One extra turn if a close is abandoned deliberately, until it is disarmed |

Name the two per-repo off switches, since they are the answer to "I want the rest but not that one":

- `mainGuard.enabled: false` disables the default-branch guard.
- `closeGate.enabled: false` disables the close gate, clearing any armed sentinel rather than stranding it.

There is no switch for the session-context hook; it is silent unless the branch has a plan folder. To turn all three off, the plugin itself is what gets disabled. `${CLAUDE_PLUGIN_ROOT}/hooks/README.md` has the detail.

## Step 8. Report

```
pr plugin ready in <owner/name>

  Config:    .claude/pr-config.json (<n> keys written)
  Default:   <branch> (detected each run, not stored)
  Tickets:   feature/<number>-<slug>, ticket ID is the issue number, PR titles read [#<number>] <title>
  Worktrees: enabled -> <root> | disabled
  Checks:    lint <cmd> | none, test <cmd> | none, ...
  Labels:    <n> present, <n> created this run
  Squash:    PR_TITLE | set to PR_TITLE this run | left as COMMIT_OR_PR_TITLE (declined | needs repo admin) | squash merging off | could not read
  Hooks:     active with the plugin - session context, main guard <on | off>, close gate <on | off>

Next: /pr:ticket <description> to file the first ticket.
```

Report a detected value and a chosen value the same way. Which came from detection and which from a question is not something the reader acts on.

## Common mistakes

- **Writing the config into a worktree.** It belongs at the main checkout's root, which is what `--git-common-dir` resolves. A per-worktree copy means two worktrees of one repo disagree about the ticket prefix.
- **Guessing `repo` from the directory name.** The directory is whatever the clone was named. Parse the remote, and stop if it does not parse.
- **Configuring a check command that does not exist.** A `null` is silent; a broken command is a gap on every run forever.
- **Storing the default branch.** It is detected per run on purpose, so renaming it does not strand the config.
