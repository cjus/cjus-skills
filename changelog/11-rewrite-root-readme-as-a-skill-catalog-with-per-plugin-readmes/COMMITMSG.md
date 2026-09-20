close the branch: apply the review-gate findings and land the artifacts

- correct three claims in plugins/pr/README.md that the close review
  caught: on-session-start.sh loads all summaries instead of the plan
  rather than "the plan folder and newest summary", /pr:start's step
  order had two pairs transposed, and the stated prefix convention was
  not the one the page follows
- add pr-summary-2026-09-20.md, which becomes the PR body
- add pr-review-2026-09-20.md, the close review gate's full report
- record today's entry in CHANGELOG.md, both timestamps preserved
- log the review's two pre-existing root README findings under
  PLAN.md § Deferred
