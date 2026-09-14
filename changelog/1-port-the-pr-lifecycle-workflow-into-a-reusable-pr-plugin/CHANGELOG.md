# Port the PR lifecycle workflow into a reusable pr plugin

Start date: 2026-09-14 12:31:34 MDT

## Changes

- Bootstrapped the label scheme this workflow depends on: `status:todo`, `status:in-progress`, `priority:high`, `priority:medium`, `priority:low`, `feature`, `refactor`, `docs`, `infra`, `research` (`bug` already existed as a GitHub default).
- Filed https://github.com/cjus/cjus-skills/issues/1 as the tracking ticket, `status:todo` + `priority:high` + `feature`.
- Created branch `feature/1-port-the-pr-lifecycle-workflow-into-a-reusable-pr-plugin` from `main` and pushed it.

## 2026-09-14

**Ported the whole plugin.** 22 skills, 8 reference documents, the lifecycle script, 3 hooks, a probe suite, and the review agent.

- **Reference layer replaces the host-repo dependency.** The source skills cited `root CLAUDE.md § X` 58 times. Those became plugin-owned documents under `reference/`, cited through `${CLAUDE_PLUGIN_ROOT}`, so no skill needs the consumer repo to carry any particular file.
- **Everything repo-shaped moved into `.claude/pr-config.json`**: repo, ticket prefix, branch prefix, worktree root and toggle, check commands, doc roots, migration directory, close-gate artifacts, guard token. The default branch is detected per run rather than stored, so renaming it strands nothing.
- **Lifecycle script verified end to end** against this repo before any skill was written: it derived the repo from the remote, detected `main`, parsed the prefix-free ticket number out of the branch, resolved issue #1, and reported the missing config as a gap.
- **Default-branch guard ships a 39-case probe suite**, which the source repo lacked. Every case corresponds to a bypass the hook's own comments name: refspec forms, chained and multi-line commands, commit messages that must not forge or trip it, redirection through `-C` and `--git-dir`, undeterminable branches, malformed payloads, and the branch names that must not gate. All 39 pass.
- **A third hook was added.** `on-session-start.sh` was not in the original scope, but `/pr:precompact` and `/pr:resume` both referenced it, so porting it removed a dangling concept.
- **The Herdr tab-marking steps were dropped**, from both the start and close skills. They were cosmetic and tied to one terminal multiplexer, so they are a tooling preference rather than part of the lifecycle.
- **De-identified.** Zero references to the source repo, its organisation, its product or its stack remain. The incident-derived rationale was rewritten to describe the mechanism rather than the measurement, since the rules stay persuasive only if they stay specific.
- Both manifests pass `claude plugin validate --strict`.

**Acceptance run against an installed copy, which found two real defects.**

- Installed the plugin from a local-path marketplace and ran a new 28-case suite against the **installed** copy rather than the source tree. That distinction is what caught the first defect.
- **The default-branch guard shipped non-executable.** The harness runs a hook as a command, so it would have silently never fired: fail-open, in the one file whose whole design is to fail closed. The 39-case probe suite missed it because it invoked the hook through `bash`, which needs no executable bit. Fixed the mode, and changed the probe suite to invoke directly so all 39 cases now exercise it, plus an explicit up-front assertion. Verified the suite now fails on a deliberately non-executable copy.
- **The lifecycle script called an undeterminable branch `fresh`.** Where `origin/<default>` does not exist (an unfetched remote, a fresh clone, `--offline`), the ahead-count is null, which collapsed into "no commits" and produced a confident, wrong instruction: "No commits yet. Do the work." That violates the script's own rule that an undetermined value never drives a verdict. It now reports phase `unknown` and says the comparison could not be made.
- Shipped the acceptance suite as `scripts/test-acceptance.sh`. It covers config discovery and defaults, repo derivation from an SSH remote, a custom ticket prefix, renamed doc roots, disabled conventions, the worktree-free path, every phase transition, and all three hooks under a non-default configuration including a renamed approval token.
- Three of the initial failures were the test's own bugs rather than the plugin's, and are recorded here so the distinction stays visible: an unreachable remote in the fixture, an assertion that ignored the documented summary-wins-over-plan rule, and a helper that could not express "expect no output".
