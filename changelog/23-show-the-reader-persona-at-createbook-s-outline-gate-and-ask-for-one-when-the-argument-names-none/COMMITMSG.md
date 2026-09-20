close the branch: resolve both deferred items, and fix six accuracy findings

At close-time triage the operator directed both surviving deferred items to be
resolved here rather than filed as a follow-up.

OUTLINE.md now records where the reader came from, not just who they are.
Section 3 has to state the provenance and can run in a later session than
section 2, so an outline holding the persona but not its origin left the gate
reconstructing from memory the one thing it exists to check. Section 3 now
reads it off the outline's top line.

Section 5's chapter prompt names the persona/posture collision at the point an
agent meets it. Item 1 tells the agent to follow chapter-prose.md, whose
section The reader is the reading posture; item 2 then hands it "the reader"
meaning the domain persona. Item 2 now says outright that the persona does not
modify the posture, and passes provenance where the persona was inferred.

Nothing parses OUTLINE.md's top line, so neither change reaches check-book.sh
or book.json.

The close review also widened the provenance marker to the part-given case: an
argument naming a reader but not what they know fires no ask, while the
knowledge assumptions stay the model's to guess, and reporting that as "from
the argument" hides the inferred half.

Accuracy fixes across the branch documents: "The third case" was a positional
reference NOTES.md counts to differently, now "An inferred persona"; NOTES.md's
decision record still described a two-way marker after the shipped line became
three-way; CHANGELOG.md's Phase 1 entry did the same, and its "one line above"
claim about the posture cite was a paragraph, not a line; both the changelog
and the summary credited PR #28 with preventing drift in
plugins/bookcraft/README.md, a file that PR never touched.

CHANGELOG.md condensed to four timestamped rounds, all retained. PLAN.md status
refreshed, and its Deferred section now records both items resolved rather than
parked.

Adds pr-summary-2026-09-20.md, which is the PR body, and
pr-review-2026-09-20-close.md.
