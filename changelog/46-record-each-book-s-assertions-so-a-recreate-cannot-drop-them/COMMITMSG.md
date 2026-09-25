close the assertions.json branch: summary, close review, condensed changelog

add pr-summary-2026-09-25.md, the PR body
add pr-review-2026-09-25-close.md, the close-gate review (APPROVE)
condense CHANGELOG.md from 347 lines to 153, every timestamp kept
fix NOTES.md's count of backfilled measurements, 23 rather than 20
narrow the backfill's fact-label example to a live system behind sign-in, so it no longer contradicts the open-web rule
have the bare-value sweep grep the value in words and in figures
decode a figure's entities one at a time, folding a decoded line break to a space so line numbers hold
assert the fixture's mode check follows a write that happened, taking it to 32 assertions
correct the PR summary's list of what fails and what passes with REVIEW lines
