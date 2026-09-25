# PR review: Pass the PR to gh pr view --repo in resume and close (Phase 6 close gate)

Close-gate review, 2026-09-25, against `main` (`75f1a0b`). The branch is one commit ahead
(`2215027`), zero behind, and pushed. Phase 6 exists only in the working tree. PR #38 is open,
no longer a draft, and CI is green. Ticket #30.

**What this review covers.** This review covers the delta since `pr-review-2026-09-25-rerun.md`
(APPROVE). That means the Phase 6 edits to `close/SKILL.md` (`:72`, `:145-150`, `:212-218`) and
`pre-test/SKILL.md` (`:73-76`), plus the rewritten `pr-summary-2026-09-25.md`. It also covers the
`PLAN.md` and `CHANGELOG.md` updates and `COMMITMSG.md`, since close step 7 commits all of them.
The committed diff (`2215027`) has not changed since the approved re-run, so I did not re-audit
it.

**Settled, and not raised again:** the dated line numbers in `CHANGELOG.md`'s Phase 1 entry,
the review files' placeholder `org/repo` URL, citing gh's own source as a dependency, and every
other item the three earlier reviews dropped.

## Summary

Phase 6 passes `"$BRANCH"` to both `gh pr checks` calls. It removes pre-test's blanket
`2>/dev/null || echo` so gh's own messages show through, and close step 1d now stops on any
error other than "no PR" or "no runs". It also guards close step 4's link edit so a failed or
empty body read can never wipe the description. The shell is correct, every claim in the
rewritten summary checks out against the diff, the log and live runs, and both audits are
clean. One close-time item needs attention: the body on PR #38 predates Phase 6, and step 4 as
written will not replace it.

## What is working well

- **The guard chain is correct shell, in every shell a model might use.** I ran `:212-215`
  verbatim under bash, zsh and sh with a stand-in `gh`. A failed read (stderr, exit 1) and an
  empty read both short-circuit with exit 1 and never call the edit. A good read passes a body
  containing `$HOME`, backticks and double quotes through literally, then one blank line and the
  closing line. The status of `BODY=$(…)` is the substitution's own status, which is why the
  `&&` chain works.
- **Pre-test got the real fix, not just the argument.** Adding `"$BRANCH"` alone would have left
  `2>/dev/null || echo "no PR / no runs yet"` merging three different outcomes into one: no PR,
  no runs, and CI could not be read. Letting gh's message through, and then naming the two
  benign ones, keeps those outcomes apart.
- **Close 1d's new rule follows the plugin's evidence discipline.** "Any other error is not
  'no runs'" treats an absent signal as unknown rather than as a pass. That is the principle
  step 1b's exit-code table already applies to `git merge-tree`.
- **The step 1b note is now scoped so that it holds.** "That takes `--repo`" resolves the
  09-24 review's suggestion that the "every" claim was contradicted at `:396`. That line has no
  `--repo`, so it now falls outside the rule rather than breaking it.
- **The summary is precise.** All five of its line references are correct, its diff figures
  match, and it records what was not verified instead of implying it was.

## Verification

Run 2026-09-25 on gh 2.92.0.

| Check | Result |
|---|---|
| The banned-term audit from CLAUDE.md, case-insensitive, pattern read programmatically from that file | Positive control: 8 hits in `CLAUDE.md`, which is gitignored. **Zero** in each of the 11 files the close commits: the 4 plugin files, `PLAN.md`, `CHANGELOG.md`, `COMMITMSG.md`, the three earlier reviews and the summary. Also zero in `git grep` of `main` and `HEAD`, in the committed diff, in the working-tree diff, in the message of `2215027`, and in #38's title and body. I audited this file after writing it, and it is also zero. |
| Closing keyword followed by a literal number, over the same 11 files and #38's body | Every hit targets #30: `COMMITMSG.md:1` (the subject), `PLAN.md:97`, `pr-review-2026-09-24.md:55`, `pr-summary-2026-09-25.md:138` (inside inline code), and #38's body at line 135. There is one exception. `pr-review-2026-09-25.md:70` and `:189`, and `pr-review-2026-09-25-rerun.md:56`, quote the past-tense "resolve" keyword followed by #38. That is file text, which GitHub does not act on, and the re-run review already settled it. **No closing keyword in a PR body or commit message targets anything but #30.** |
| Attribution sweep | Clean. The only vendor-name hit is `plugin.json`'s pre-existing `$schema` URL, which is not attribution. `2215027` is authored as the repo owner. |
| `org/repo`-shaped and cross-repo URL sweep | Only the settled placeholder in two review files, plus `plugin.json`'s links to this repo. |
| `git diff main --numstat -- plugins/`, working tree included | 1/1, 11/6, 3/1, 5/1, so **4 files, +20 −9**. That matches the summary's `:161`. |
| Line references | `close:69`, `:145`, `:212`, `:227` and `:242`, and `pre-test:73`, each sit on the cited command. |
| Close `:145` as written, on this branch | `fixtures (macos-latest)=pass  fixtures (ubuntu-latest)=pass`, exit 0 |
| Pre-test `:73` as written | The JSON for both jobs, `bucket: pass`, exit 0 |
| Same call, on a branch with no PR | `no pull requests found for branch "…"`, exit 1 |
| Same call, on PR #8's head branch (before CI existed) | `no checks reported on the '…' branch`, exit 1 |
| Same call, with no argument | `argument required when using the --repo flag`, exit 1 |
| `gh pr checks --json` exit status on fail or pending | Not run live, since no PR here has a failing check. In gh 2.92.0's implementation, JSON output is written and returned **before** the fail and pending exit codes are applied, so `--json` exits 0 in both cases. That is consistent with the summary's "neither skill depends on it". |
| Any `gh pr` subcommand other than `list` and `create` called with `--repo` and no argument, anywhere under `plugins/` | None |
| `$BRANCH` established in pre-test before step 5 | Yes. Step 1 says the state check "yields the branch", and step 3 already passes `"$BRANCH"` at `:36` and `:47` on `main`. |
| Version | `0.2.5` exists only in `2215027`. `main` is `0.2.4`, there is no tag, and the marketplace entry has no version field. Phase 6 lands in the same merge as the bump, so **no second bump is needed**. |
| `plugins/pr/scripts/test-acceptance.sh "$PWD/plugins/pr"` | passed 39, failed 0 |
| `git diff --check` (working tree and `main...HEAD`), trailing whitespace, final newlines | Clean |

### The four probes you asked about

- **`$BRANCH` in pre-test.** It is established before step 5, as shown above. Step 5 adds no
  new dependency, since step 3 already relied on it.
- **The `BODY=… && [ -n "$BODY" ] && gh pr edit …` chain.** The shell is correct, and it does
  what the note says (see the first bullet under What is working well). Trailing newlines in the
  body are stripped by `$(…)`, exactly as the old nested form did, and the literal blank line
  puts the closing line in its own paragraph.
- **"Any other error → stop" in close 1d.** This is consistent with the step. Its other bullets
  already stop on `fail` and on a suspected flake, and only proceed on `pending` or a confirmed
  absence of runs. Step 1b has no matching "other error" rule, but it does not need one: it has
  a local fallback that produces the same verdict, and CI has no local equivalent. The one gap is
  cosmetic. The halt list at `:37` does not name this new stop (see Suggestions).
- **Version bump.** Not needed (see the table).

## Issues found

### Critical

None.

### Important

**PR #38's body is the pre-Phase-6 summary, and step 4 as written will leave it there**

Location: PR #38's body, and `plugins/pr/skills/close/SKILL.md:201` and `:227-231`

**What I see:** #38's body (6,482 chars) is the summary from the approved re-run, plus the
closing line for #30. It still says "3 plugin files changed, +12 −6", and it lists the
`gh pr checks` calls and the link edit's failed read under "Deferred work", both of which Phase 6
has since fixed. `closingIssuesReferences` already includes #30. On this re-run, step 4 finds an
open PR with a real description. The table says to keep a real description. The pre-append check
at `:227` returns `true`, so the body is not touched. Step 8b then checks only for a non-zero
length and `true`, both of which the stale body satisfies.

**The risk:** the merged PR would describe a different change from the one it contains: three
files instead of four, no mention of pre-test, and two fixes listed as deferred. The repo's
squash setting builds the commit message from commit messages, so git history is unaffected. The
PR page is still the record that reviewers and later readers go to.

**Suggested fix:** at this close's step 4, treat the body as stale. Replace it with the new
summary, then run the guarded link edit so the closing line is appended once more:

```bash
gh pr edit "$BRANCH" --repo "$REPO" --body-file "<changelogRoot>/<slug>/pr-summary-2026-09-25.md"

BODY=$(gh pr view "$BRANCH" --repo "$REPO" --json body --jq .body) && [ -n "$BODY" ] \
  && gh pr edit "$BRANCH" --repo "$REPO" --body "$BODY

Closes #$N"
```

Then confirm the `:242` verify reports a length near 8,700, not 6,482, and `true`. The
installed plugin is still 0.2.3, so run the 0.2.5 forms by hand.

**Learning note:** a check for whether something is already present ("does GitHub already
resolve a link?") makes a step skip safely. It does not tell you whether what is present is
**current**. When an earlier run of the same process wrote the artifact, "already there" can
mean "already stale".

This concerns a close artifact, not the skill text. It does not regress the objective and does
not affect the verdict.

### Suggestions

**Qualify step 4's new stop for the deferred-creation path**

Location: `plugins/pr/skills/close/SKILL.md:218`, against `:235`

**What I see:** "If the read fails or comes back empty, **stop**: at this point the body is
never legitimately empty, because it was just created or replaced from the summary." When
`gh pr create` fails because there are no commits ahead, `:235` says "Do not halt" and defers
creation to 8b. In that case the read fails with "no pull requests found for branch", and the
new note says to stop. The rationale also skips the "open, real description" path, where the
body is kept rather than created or replaced.

**The risk:** low. `main` already has the same tension between `:235` and the verify's "either
failing is a stop" at `:246`, and a model resolves both the same way, with the specific rule
winning. So this PR does not make the path newly reachable. Still, one clause would remove the
ambiguity.

**Suggested fix:** "If a PR exists and the read fails or comes back empty, **stop**. By now its
body is the summary or a real description, so it is never legitimately empty. When creation was
deferred (below), there is no PR yet: skip the edit, and step 8b runs it."

**Name the two new stops in the halt list**

Location: `plugins/pr/skills/close/SKILL.md:37`

The list names "1d a failing check" and "step 4 finding no exact match or a closed or merged
PR". It now omits 1d's "CI could not be read" and step 4's failed body read. Adding both keeps
the list complete, and the list is what the report block relies on.

**Optional: settle the summary's "Not verified" item**

Location: `pr-summary-2026-09-25.md:146-148`, and the matching `CHANGELOG.md` bullet

gh 2.92.0 returns from `--json` output before it applies the fail and pending exit codes, so the
exit status is 0 either way. The text could say so. Its conclusion is already right, so this is
optional.

### Deferred to follow-up

- **Close step 4 does not refresh a PR body that an earlier run of the same close wrote**,
  `close/SKILL.md:198-205` and `:231`. Symptom: re-running a close after a triage stop, as
  happened here, leaves the older summary on the PR while every verify passes. Occasion: the
  next edit to step 4's PR-state table. Theme: close re-run idempotency.

**Considered and dropped:**

- `PLAN.md`'s Phase 3 and 4 entries cite `:224` and `:239`, which are now `:227` and `:242`.
  These are dated entries, like the settled `CHANGELOG.md` line numbers.
- `PLAN.md:57` is an over-long line left by a reflow. Cosmetic.
- The summary's `:18`, "that 'no runs' answer": close never printed that string, and the model
  inferred it. A wording nit.
- In close 1d, "no commit found on the pull request" now reads as a stop. A PR always has a
  commit, so that message really is an error.

## Questions

- **`COMMITMSG.md` predates Phase 6.** Its subject and body cover only the changelog files.
  Step 5 (`/pr:commitmsg`, "covering only the uncommitted changes") has to rewrite it to cover
  the edits to the close and pre-test skills before step 7 commits. Please confirm that happens,
  rather than reusing the file.
- **The installed `/pr:close` is 0.2.3.** As the re-run review noted, pass `"$BRANCH"` by hand
  at steps 1b, 1d, 4 and 8b. At steps 4 and 8b, also use the guarded `BODY=…` form rather than
  0.2.3's nested edit.

## Verdict

VERDICT: APPROVE

Phase 6 delivers the objective as the operator widened it, with correct shell and no
regression. Before step 7, replace #38's stale body at step 4 and make sure step 5 rewrites
`COMMITMSG.md`.
