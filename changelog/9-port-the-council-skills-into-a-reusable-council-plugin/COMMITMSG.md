add the closing artifacts for the mechanical layer

Adds pr-summary-2026-09-16.md, the document that became PR #13's body: what
this partial delivery covers, where it deviates from the plan as written, how
to verify it by hand, and the deferred work.

Adds pr-review-2026-09-16.md from the close-gate review, which returned
APPROVE after verifying the six earlier fixes hold rather than assuming them,
and raised three non-blocking issues.

Condenses CHANGELOG.md from 232 lines to 100, keeping all four timestamps and
their headings distinct, with the narrative now carried by the summary.

Refreshes PLAN.md status: records the review verdict, and parks the three new
findings under Deferred -- an empty TSV field collapsing because tab is IFS
whitespace and shifting the whole seating row, three --json fields
interpolated without the escaping their siblings get, and the two roster
backends disagreeing at the refusal boundary on ill-typed fields.
