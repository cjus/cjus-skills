close #30: pass the branch to gh pr checks, make close step 4 safe to re-run

pass "$BRANCH" to gh pr checks in close step 1d and pre-test step 5
drop pre-test's 2>/dev/null fallback that reported a false "no runs"
name gh's no-PR and no-runs messages in both, and stop close 1d on any other error
read the PR body first in close step 4 and edit only on a successful, non-empty read
mark every body close writes with a pr:close:summary marker, and replace a marked body on re-run
guard the create and replace pipes with a non-empty summary check
append the link without the pre-append check after a create or replace in the same run
keep literal closing keywords with an issue number out of the summary
re-read a false closingIssuesReferences, up to three reads in all, before stopping
widen close step 1b's note to cover gh pr checks and calls that take --repo
add pr-summary-2026-09-25.md, the PR body for #38
add the pre-test review and five close reviews
record the operator's two scope changes and phases 6 and 7 in PLAN.md
record phase 4, the close runs and phases 6 and 7 in CHANGELOG.md, keeping every timestamp
add COMMITMSG.md
