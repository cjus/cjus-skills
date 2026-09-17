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
which predates #16) to `c724566`, the #16 merge — before the update the cached manifest's
`plugins` array held only `bookcraft` and `pr`, so the update step was load-bearing rather
than ceremonial. The durable evidence for that move is `installed_plugins.json`, which
pins `pr@cjus-skills` at `b0f5320c5d15` and `explain@cjus-skills` at `c72456607f46`; the
marketplace clone itself is shallow and was re-cloned by the update, so its own history no
longer shows the prior commit. `claude plugin install explain@cjus-skills` then installed `explain` at
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
  Precision note, from review: the allowlist is not the *only* gate — a sibling check
  rejects a skill model unsupported in auto mode, with its own warning. `claude-opus-5` on
  first-party passes both, so the conclusion is unchanged, but "only when the value is
  outside the allowlist" would be stronger than the binary supports.
- `model` sits in both recognized-key lists — the skill/command list and the plugin list
  — so `--strict` was never treating it as an unknown key.

`opus` resolves as a first-class family alias (`latest_per_family.opus =
"claude-opus-5"`), so the bare form is correct as written.

Review surfaced two stronger pieces of evidence than the four above, both worth recording.
The Skill tool's own output schema documents the field in prose — "Resolved model the skill
turn runs on when a frontmatter model override took effect; omitted otherwise" — which is
the runtime describing the behavior directly rather than by inference. And the full chain
for plugin *skills* specifically was traced: the plugin skill walker invokes the loader
with an `isSkillMode` flag, the loader returns `model` on the command object, and the Skill
tool applies it. That closes the one gap the four bullets left open, since the first four
establish the loader parses `model` without proving plugin skills reach that loader.

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

### 2026-09-17 — Phases 1, 3 and 4: verified, then the originals removed

**Phase 1 is verified.** Two restarts were needed, and the first one went to the wrong
place, which is worth recording because the wrong place produced a convincing false alarm.

Observed from `cjus-dev`, a repo other than `cjus-skills`: `explain:qe` and `explain:qve`
both resolve, and `qve` and `explain:qve` appear as **distinct entries**, confirming the
namespaced form does not displace a project-level skill of the same bare name. Separately,
in this worktree, both skills were executed end to end. Stated precisely because the two
halves happened in different sessions: resolution was observed in `cjus-dev`, execution
here. The plugin is user-scoped so the code path is the same, but the record should not
imply one session did both.

The shadowing check for `qe` resolved positively rather than by absence. The loaded
`explain:qe` carries the **plugin** copy's description — `"/explain:qe what is a
transactional outbox"` — where the user-level copy read `"/qe what is…"`. Different text,
so the namespaced form demonstrably reached the plugin.

**A false alarm worth not repeating.** Mid-verification it looked as though `explain:qve`
had displaced `qve` while `qe` and `explain:qe` coexisted, which suggested a precedence
rule where a plugin skill hides a *project* skill but not a *user-level* one. It was an
artifact of reading the skill list from this worktree, where `cjus-dev`'s project-level
`qve` correctly does not load at all. No precedence rule exists. The investigation it
prompted did establish one real fact: Claude Code's duplicate-skill guard keys on the
resolved file, not the skill name — it skips only the *same file* reached twice — so two
same-named skills from different sources were never going to collide.

**Phase 2 is now empirical, not just static.** Running `/explain:qve` from a session on
`claude-opus-5[1m]` produced a skill turn reporting `claude-opus-5`. The `model: opus`
frontmatter resolved through the family alias and actually switched the model. The caveat
recorded on 2026-09-16 — that the finding rested on reading the binary rather than
observing behavior — is discharged.

**Phase 3 is done.** `~/.claude/skills/qe/` removed. It was not under version control, so
a copy was taken first; the content is independently recoverable from `origin/main`'s
plugin copy, which differs by exactly four namespacing hunks.

**Phase 4 is half done, and the half that remains is in another repo.**
`cjus-dev/.claude/skills/qve/` is deleted, but `cjus-dev` sits on `main`, where that
repo's own conventions forbid a direct commit. The deletion therefore sits in its working
tree, unlanded, and finishing it needs a branch and a PR *there* — recorded under
`## Deferred` along with the stale `/qve` and `/qe` references at its `CLAUDE.md:416`,
since the two are one piece of work. The enable half of the step is a verified no-op:
`explain@cjus-skills` is enabled at user scope, `cjus-dev` declares no project-level
`enabledPlugins`, and `explain:qve` was observed loading there.

**Two incidentals.** The Playwright venv the `qve` skill documents was created at
`~/.cache/explain/venv`; the cached Chromium builds were 1217-1228 and this Playwright
wanted 1243, so one was downloaded. And the shipped `page-template.html` footer still says
"regenerate with `/qve …`" — a bare name the port missed, cosmetic but live in
`explain@0.1.0`.

