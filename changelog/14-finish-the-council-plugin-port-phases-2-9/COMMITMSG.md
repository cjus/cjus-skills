record the follow-up tickets and fix the PR's closing reference

The first close left its deferred triage unresolved, so three artifacts claimed
work was untracked when it now is. This pass files that away and corrects two
things the second close-gate review caught.

The summary and PLAN now cite the tickets: #22 carries phases 3-9 plus the live
COLLAPSED question and the M=/P= interface decision, #15 gained the two
output-contract items this branch found, and cjus/cjus-dev#89 holds the phase 9
retirement. PLAN's Deferred section gained a triage table showing all six items
and why three dropped.

**The PR's closing reference was resting on a sentence.** The summary read "this
PR closes #14" as ordinary prose, and GitHub was resolving that as the closing
keyword -- so the link that retires the ticket depended on nobody rewording a
line of narrative. Both occurrences are reworded, and the reference is now an
explicit trailer on the PR body, which is the only thing that should carry that
meaning. Verified: with the prose reworded and before the trailer landed,
closingIssuesReferences went empty, which is what proves the prose was load
bearing rather than incidental.

The impact figures were also inverted. The split is five plan-folder documents
against six shipped files, not the reverse; the summary now gives the shipped
figures on their own, since those do not drift when this commit lands and the
combined total does.

Two smaller corrections: PLAN's status still said both skills proceed Claude-only
when detection is unavailable, which stopped being true when `ask` was changed to
keep seating OpenRouter, and it still described the cjus-dev ticket as unfiled.

No continuity entry and no assertion audit: both are null in this repo's
pr-config.json.
