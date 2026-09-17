# Finish the explain plugin rollout

Start date: 2026-09-16 19:50:38 MDT

Ticket: https://github.com/cjus/cjus-skills/issues/17

Run the rollout half of #12 that could not run before that branch merged: install the
`explain` plugin the way a user installs it, verify both skills resolve, then retire the
two originals so each skill has exactly one live copy.

## Changes

### 2026-09-16 — Phase 1 (install) and Phase 2 (model frontmatter)

**The `explain` plugin is installed from the marketplace.** `claude plugin marketplace
update cjus-skills` moved the local marketplace clone from `b0f5320` ("release pr 0.2.1",
which predates #16) to `c724566`, the #16 merge — before the update the cached manifest
listed only `cjus`, `bookcraft` and `pr`, so the update step was load-bearing rather than
ceremonial. `claude plugin install explain@cjus-skills` then installed `explain` at
version `0.1.0`, user scope, with all five files present, and added
`"explain@cjus-skills": true` to `enabledPlugins`. Both skills resolve only after a
restart, so the live half of Phase 1 lands in the next session.

**Phase 1 regained the shadowing check.** #12's review (Question 2) asked whether
`/explain:qe` reaching the plugin rather than the user-level `~/.claude/skills/qe/` gets
verified before the removal, and warned that post-merge is where that detail gets lost.
It had been: this branch's Phase 1 carried only "resolve and run". Restored, because
Phase 3 destroys the evidence the check depends on.

**`model:` in skill frontmatter is honored, including for plugin skills — `qve`'s
`model: opus` stays.** The #12 review's hypothesis was that `--strict` passing meant
unknown keys were tolerated rather than honored. Static analysis of the compiled Claude
Code `2.1.274` binary disproves it on four independent points:

- The plugin command/skill loader reads `w.model`, trims it, treats `"inherit"` as a
  sentinel and resolves anything else through the model-name resolver — the same loader
  that validates `effort` and warns `Plugin command <n> has invalid effort`.
- The frontmatter-to-command mapper emits `model` onto the command object alongside
  `disableModelInvocation`, `userInvocable` and `effort`.
- There is a model-specific runtime guard whose warning text reads `Skill/command model
  "<x>" is not in the availableModels allowlist; keeping the session model`. A fallback
  that names skills and commands only exists because the value is otherwise applied.
- `model` sits in both recognized-key lists — the skill/command list and the plugin list
  — so `--strict` was never treating it as an unknown key.

`opus` resolves as a first-class family alias (`latest_per_family.opus =
"claude-opus-5"`), so the bare form is correct as written.

Two corrections to the review's framing. Its scan covered only plugin skills; four
**user-level** skills in this same setup already declare `model:` (`pr-sanity: opus`,
`diagram-dot`, `diagram-mermaid`, `pr-cp: sonnet`), so the key was never as unattested as
a plugins-only scan suggested. And the finding is static analysis of the shipped binary,
not an observation of `qve` running on Opus — the empirical confirmation rides along with
the post-restart Phase 1 verification.

**Phases 3 and 4 are clean deletes.** Diffing both originals against the plugin copies on
`main`: every difference is an intended de-hosting change — `/qe` to `/explain:qe`,
hardcoded paths to `${CLAUDE_PLUGIN_ROOT}`, host-`CLAUDE.md` references generalized — plus
a Playwright setup block the plugin `qve` gained. Nothing exists only in the originals, so
neither removal loses content.

