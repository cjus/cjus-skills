close the branch: apply the review findings and land the artifacts

Two real fixes from the close-gate review, which returned APPROVE, plus the
closing artifacts.

**`NONE` claimed a roster declared no members when it had declared members and
lost every one of them.** Phase 5's pin check made that reachable: a roster with
one Claude member pinned to `opus-4.5` seats nobody, and the report listed the
unseated member and then said "the roster declares no members" two lines below it.
That is the same self-contradiction phase 4 removed from the absent-roster case,
reintroduced somewhere new. The two readings now print differently, the header
records that NONE has two routes, and `skills/ask` checks `.notSeated[]` before
saying which one it is -- because the advice is opposite: an empty `.notSeated[]`
is a decision to respect, a non-empty one is a typo or a missing key to fix.
`test-council-state.sh` gains the regression case whose absence let it through,
plus one asserting a genuinely empty roster still says so.

**`openrouter.mjs` still exited 1 on the most ordinary failure it has.** The
reviewer flagged a network failure rejecting unhandled; a timeout and a 200 whose
body is not JSON did the same. All three contradicted the exit-code contract this
branch had just documented and tested in that file. They exit 4 now -- no usable
answer, which is where they leave the caller -- and name the cause, including
undici's `cause.cause.code` so ECONNREFUSED reaches the message. Four cases cover
them.

Three smaller findings were stale text this branch wrote: test-detect.sh's header
still said the probe cases belonged to a later phase, reference/providers.md
pointed at "the availability block above" that the phase 6 split left in another
file, and the root README's Layout block was misaligned by one column.

Artifacts: pr-summary-2026-09-19.md and pr-review-2026-09-19.md are new. PLAN.md's
Status section was condensed from a per-phase diary to a single current statement,
since CHANGELOG.md holds the narrative, and CHANGELOG.md itself was condensed with
all eight dated headings preserved and none merged. PLAN 328 lines to 232,
CHANGELOG 413 to 192.

PLAN also gains the deferred-work triage table: six items, one ticketed onto #15,
two already tracked there, two dropped, and one -- the openrouter exit-1 paths --
fixed here rather than deferred.

No continuity entry and no assertion audit: both are null in this repo's
pr-config.json.

Suites: 46, 40, 104, 46 -- 236 cases, all passing. `claude plugin validate
--strict` passes for the plugin and the marketplace.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
