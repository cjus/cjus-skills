fix documentation drift in the root README and hooks README

Four documentation-accuracy defects deferred from #11, each verified against
source before and after the edit.

The guard probe suite count in plugins/pr/hooks/README.md was 54; the suite
reports 73 passed, 0 failed. A first run showed 31/42 because the jq first on
PATH is an x86-only binary that aborts on Apple Silicon; /usr/bin/jq passes
everything. The count is 73 under either run.

The root catalog named 13 of the 15 non-spine pr skills. Added
/pr:continuity-add and /pr:continuity-prune in their own clause, naming the
repo-root continuity folder they operate on. Verified by diffing the skill
names in the README against plugins/pr/skills/: 22 on disk, 22 named.

## Releasing named bookcraft's paths as the procedure though four plugins now
ship. Generalized to one procedure parameterized by <plugin>, on evidence that
all four have an identical layout. The bare . in the first validate command is
flagged as deliberately not parameterized. claude plugin tag --help confirms
the {name}--v{version} format and the marketplace check; validate --strict
passes on the marketplace and all four plugins.

Two one-liners: the code-reviewer agent is spawned by /pr:close Step 2 and
/pr:pre-test Step 4, not by the close gate, which is the Stop hook and spawns
nothing. /pr:init creates eleven labels, not only the queue's: two status:*,
three priority:*, and six type labels.

The ticket's own citations had rotted -- four of its five anchors. All three
line numbers moved: the catalog to README.md:87, the code-reviewer line to
:137, the /pr:init sentence to :69. One path is wrong too:
plugins/bookcraft/plugin.json does not exist, the manifest is at
plugins/bookcraft/.claude-plugin/plugin.json. Only plugins/pr/hooks/README.md
survived. Edits were anchored on text.

Review caught three defects this branch introduced in its own prose, across
two passes, and self-review caught a fourth: a substitution note that said
"all three commands" when only two take the parameter, a /pr:continuity-prune
one-liner that omitted its confirmation step, a changelog claim that one
anchor had drifted, and the correction to that claim, which said three and was
also wrong. All four are fixed here.

Scope extended once at the close triage, by operator decision, to fix the
deferred items here rather than file them:

The probe suite now describes its own completeness. It could skip its two
linked-worktree cases when git worktree add fails, but printed one skip line
for the two and no skip count, so a degraded run read as a complete one --
the same ambiguity this ticket was filed over, inside the tool meant to
settle it. The totals line is now "passed 71, failed 0, skipped 2 (73 cases)"
with both cases named, and the total is invariant. No assertion changed and
the exit code still keys on failures alone.

Added .claude/settings.json, which git-conventions.md:22 asks for and nothing
in the repo set, so every agent-assisted commit re-litigated attribution by
hand. Verifying the key turned up a gap in the doc itself: its snippet set
only commit and pr, but the schema declares a third key, sessionUrl, a
boolean defaulting to true that emits the Claude-Session trailer the same
sentence bans. A repo following that snippet exactly still leaked the
identifier. The doc now prescribes all three and says why the types differ.

Added scripts/test-acceptance.sh to the root layout tree, corrected a false
claim in the hooks README that a missing jq stops the suite running (it runs
all 73 and prints 31/42, the same shape as a wrong-architecture jq), and
commented the corrected case count onto issue #5 rather than editing its
body.

Closes #27
