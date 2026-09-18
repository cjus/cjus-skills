close phases 1 and 2: apply the close-gate review and land the artifacts

Three fixes from the close-gate review, all in prose this branch authored.

`ask`'s detection block echoed "detection unavailable - assume Claude-only" while
the bullet three lines below had just been rewritten to say the opposite, so the
skill contradicted itself on the one path that is live for the whole of phases
1-2. It now matches `setup`'s plain "detection unavailable".

`Bash(git:*)` is restored, reverting the narrowing to `Bash(git diff:*)` made
earlier today on the pre-test review's advice. The skill instructs
`git -c core.fsmonitor= -c core.hooksPath=/dev/null diff ...`, whose text begins
`git -c` rather than `git diff`, so a prefix rule past the subcommand cannot match
it. The two reviews disagreed; the command text settles it. The `-c` flags are a
hardening measure, so the grant widens rather than the command changing.

`status` no longer tells the model to name which key level is missing. The script
reports only that the key is absent, never which of the three levels it looked in,
so naming one would be a claim its output does not support.

Closing artifacts: the PR summary, the close-gate review, and this message. The
CHANGELOG gained the close-gate entry, had two lines corrected that the fixes made
stale, and was reordered so its verification block describes the final state. PLAN
records that the branch closes with phases 3-9 outstanding and that a successor
ticket is the follow-up this close must not drop.

No continuity entry and no assertion audit: both are null in this repo's
pr-config.json.
