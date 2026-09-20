# Port the PR lifecycle workflow into a reusable `pr` plugin

## Overview

Packages a PR lifecycle workflow, developed and run in a private repo, as a self-contained `pr` plugin in this marketplace alongside `bookcraft`. GitHub issues remain the ticket system: the issue number is the ticket number, two labels carry state, and the merge closes the ticket.

The workflow being ported was not repo-agnostic in a superficial way. It carried roughly 200 hardcoded identity references and, more awkwardly, 58 citations of the form `root CLAUDE.md § Ticketing` pointing at conventions that live in one specific repo's handbook. Those citations were load-bearing rather than decorative, so the port is a rebuild of the reference layer rather than a find-and-replace.

## Key changes

**`plugins/pr/reference/` (9 files, 702 lines).** The replacement for those 58 citations. Eight documents carrying the ticketing scheme, git conventions, evidence discipline, the scope contract, the handoff-document conventions, the assertion audit protocol, the lifecycle map, and the configuration contract, plus a JSON schema. Skills cite these through `${CLAUDE_PLUGIN_ROOT}`, so nothing depends on a consumer repo having any particular file.

**`plugins/pr/skills/` (22 skills, 2,865 lines).** The spine (`init`, `ticket`, `start`, `pre-test`, `close`, `cleanup`), the work band (`cp`, `status`, `resume`, `sync`, `plan-check`, `precompact`, `condense`, `summary`, `commitmsg`, `abort`), the queue tools (`next`, `reviews`, `triage`), and the supporting `sanity`, `continuity-add` and `continuity-prune`. `/pr:init` is new; everything else is a port.

**`plugins/pr/scripts/pr-lifecycle-state.mjs` (521 lines).** Computes where a branch sits in the lifecycle, which gaps it has, and which command comes next. Every skill folds its output into their own reports. Made fully config-driven.

**`plugins/pr/hooks/` (5 files, 1,109 lines).** Three hooks, all optional and none installed automatically: a `Stop` hook enforcing that a close actually landed, a `PreToolUse` guard on default-branch writes, and a `SessionStart` context loader. Plus a 39-case probe suite for the guard.

**`plugins/pr/agents/code-reviewer.md` (213 lines).** The review agent `/pr:close`'s gate spawns, with the review rubric folded in so it needs no external skill.

## Code examples

Everything repo-shaped moved behind one config file, read by every skill and both non-trivial hooks:

```json
{
  "repo": "owner/name",
  "ticketPrefix": "",
  "branchPrefix": "feature/",
  "worktrees": { "enabled": true, "root": "../{repo}-Worktrees" },
  "checks": { "lint": null, "typecheck": null, "test": null, "build": null },
  "docs": { "changelogRoot": "changelog", "continuityRoot": "continuity", "assertionsFile": "ASSERTIONS.md" },
  "closeGate": { "enabled": true, "requiredArtifacts": ["pr-summary", "continuity"] },
  "mainGuard": { "enabled": true, "approvalToken": "PR_ALLOW_MAIN" }
}
```

Every key is optional. The defaults give `feature/123-slug` branches with the bare issue number as the ticket ID, so a repo that adopts the plugin and writes no config still gets a working flow.

The ticket pattern is built from config rather than hardcoded, which is what lets one repo use bare numbers and another use `ABC-123`:

```js
const ticketRe = new RegExp(
  `^(?:${cfg.ticketPrefix ? escapeRe(cfg.ticketPrefix) + "-" : ""})(\\d+)-`,
  "i",
);
```

The default branch is deliberately **detected per run rather than stored**, so a repo that renames it strands no configuration:

```js
function detectDefaultBranch() {
  const ref = run("git", ["symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"], { cwd: worktreeRoot });
  if (ref) return ref.replace(/^refs\/remotes\/origin\//, "");
  for (const cand of ["main", "master"]) {
    if (run("git", ["rev-parse", "--verify", "--quiet", `refs/remotes/origin/${cand}`], { cwd: worktreeRoot })) return cand;
  }
  return "main";
}
```

## Plan alignment

Every item in the plan landed. Eight design decisions were settled with the operator before any code was written, and all eight were implemented as agreed: plugin named `pr` with prefix-free skill names, plugin-owned reference docs, full scope including hooks and agent, a configurable-but-default-empty ticket prefix, a `/pr:init` that writes the config and bootstraps labels, worktrees configurable and defaulting on, and a close gate whose required artifacts come from config.

Three deviations from a literal port, each a deliberate call:

1. **A third hook was added.** `on-session-start.sh` was not in the agreed scope, but `/pr:precompact` and `/pr:resume` both referenced it, so porting it removed a dangling concept rather than shipping two skills pointing at nothing.
2. **Terminal tab-marking steps were dropped** from `start` and `close`. They were cosmetic and tied to one terminal multiplexer, so they are a personal tooling preference rather than part of the lifecycle.
3. **A `migrations` config key was added** so `/pr:close`'s drift gate generalizes past one specific migrations convention instead of being cut entirely.

## Testing

Two suites ship with the plugin, both runnable by hand.

**`plugins/pr/hooks/test-guard-default-branch.sh`** drives the default-branch guard with 39 crafted payloads against throwaway repos. Every case corresponds to a bypass the hook's own comments name: refspec spellings including the force marker and quoted forms, chained and multi-line commands, commit messages that must neither forge nor trip the guard, redirection through `-C` and `--git-dir`, detached and unborn HEADs, malformed payloads, and the branch names that must **not** gate (`maintenance`, `mainline`, `main-2`, `domain`). All 39 pass.

**`plugins/pr/scripts/test-acceptance.sh`** drives the whole plugin's mechanical substrate through the lifecycle in throwaway repos: config discovery and defaults, repo derivation from an SSH remote, a custom ticket prefix, renamed doc roots, disabled conventions, the worktree-free path, every phase transition, and all three hooks under a non-default configuration including a renamed approval token. 28 cases, all passing.

Beyond the suites: the plugin was installed from a local-path marketplace and both suites were run against the **installed** copy rather than the source tree. Both manifests pass `claude plugin validate --strict`. A leak scan returns nothing for the source repo, its organisation, its product, its stack, or absolute home paths.

### Two defects the acceptance run found

Both were introduced by the port itself and were unreachable in the source repo.

**The default-branch guard shipped non-executable.** It was `644` while the other three hooks were `755`. The harness runs a hook as a command, so it would have silently never fired: fail-open, in the one file whose entire design is to fail closed. The 39-case probe suite missed it because it invoked the hook through `bash`, which needs no executable bit. Fixed the mode, changed the probe to invoke directly so all 39 cases now exercise it, and added an explicit assertion, then verified the suite fails on a deliberately non-executable copy.

**The lifecycle script called an undeterminable branch `fresh`.** Where `origin/<default>` does not exist (an unfetched remote, a fresh clone, `--offline`), the ahead-count is null, which collapsed into "no commits" and produced a confident, wrong instruction: *"No commits yet. Do the work."* That violates the script's own stated rule that an undetermined value never drives a verdict. It now reports phase `unknown` and says the comparison could not be made.

## Impact assessment

- **45 files changed, 5,843 insertions, 0 deletions.** Additive apart from the marketplace entry and the README section.
- **No breaking changes.** `bookcraft` is untouched.
- **No dependencies added.** The script uses only the Node standard library; the hooks use bash, and degrade gracefully when `jq` or `grep` is absent.
- **Nothing is installed automatically.** All three hooks require the operator to paste a settings fragment, because each changes harness behavior for every turn in a repo.

## Deferred

Recorded here rather than ticketed, per the scope contract's default:

- The GitHub-dependent half of the lifecycle (`gh issue create`, the closing-reference assertion, label transitions) is proven against this repo's own issue #1, not re-run in a throwaway GitHub repo. Doing that would mean creating a scratch repo on the account.
- No CI runs either suite or validates the manifests on push. This repo has no workflows at all.
- `/pr:init`'s package-manager detection covers node, cargo and go. Python is deliberately left to ask, because its tooling varies too much to guess.
- The skills are instructions for a model rather than code, so no suite exercises them directly; only their shared machinery is covered.
- No independent review agent ran against this branch. The plugin ships one, but it is not installable until this merges.

## ASSERTION AUDIT

No assertions file in scope for this change. `cjus-skills` declares none, and this branch's `.claude/pr-config.json` sets `docs.assertionsFile` to `null` accordingly. Matched against: the repo root, which holds no `ASSERTIONS.md`.
