# The scope contract

## The objective is fixed at `/pr:start`

**A PR is done when it delivers the objective established at `/pr:start` without regressing anything.** It is not done when the code it touched becomes defect-free.

That objective, the ticket plus the initial `PLAN.md` scope, is the acceptance bar, and it is **immutable for the life of the branch**. Only the operator changes it, explicitly, by agreeing to a new version of it.

This constrains the `PLAN.md` updates that `/pr:plan-check`, `/pr:pre-test` and `/pr:condense` perform. They refresh **status**: what is done, what is left, what comes next. They do not enlarge **scope**. Work discovered mid-PR does not become a requirement of this PR by virtue of being written into `PLAN.md`.

**Done is a threshold, not a maximum.** The evidence and review rules raise the floor on correctness; none of them licenses expanding a PR past its objective. Ship the working PR and defer the rest.

## Triage: three bins, and DROP is the default

Anything discovered along the way that does not change whether the objective is delivered gets triaged, not fixed.

**FIX NOW** applies only if the item makes the answer "no". Exactly three qualifiers:

1. The PR cannot deliver its objective while the item stands.
2. The PR **regresses** the default branch: something that worked now does not.
3. The PR **introduced** a correctness, security, or data-loss defect.

Nothing else qualifies. Not "important", not "trivial while we are here".

**TICKET** applies when the item is real, does not block, and clears **both** clauses:

1. You can state a user-visible symptom or a concrete future cost in one sentence.
2. You can name the **occasion** that would cause it to be picked up, such as "next time we touch this schema" or "before the next pricing change". The occasion goes in the issue body.

Cannot name an occasion? It would sit open until somebody pruned it. That is a DROP.

**DROP** is the default, and it is where anything arguable goes. Style preferences, speculative hardening, coverage for untouched code, pre-existing minor issues. Note it in the PR summary prose and let it go: no issue, no deferred entry, no re-raise.

**One unconditional exception.** A **pre-existing** security, data-loss, or correctness defect is filed immediately as its own issue, regardless of both clauses. That is an escalation, not a deferral, and it is never dropped.

**The burden of proof sits on TICKET, never on DROP.** "It is real" is not a reason to file. Real-but-never-scheduled is precisely the backlog this rule exists to prevent. Dropped items stay findable in the committed PR summary; they simply stop being scheduled work.

## `## Deferred` is a triage inbox, not a backlog

Park newly found work under a `## Deferred` heading in `PLAN.md` to keep it out of the plan's checklist, then keep moving. Do not stop to ask about ticketing and do not interrupt the turn with an offer.

Triage runs **once**, at `/pr:close`, against the three bins above, and most entries exit as DROP. Nothing reaches GitHub by sitting in that section.

## Grouping the survivors

Items that clear the TICKET bar are **not** one issue each. Assume every survivor belongs in a **single** follow-up issue, with the items as a body checklist, then split only when you can name the reason:

- A different kind of work (bug vs. refactor vs. docs vs. infra)
- Materially different urgency
- Too large to hold in one ticket, roughly more than eight to ten checklist items

Aim for one issue, accept two or three, justify more. Always present the **grouped** proposal for approval, never a raw item-by-item list.

## `PLAN.md` is not a cross-PR backlog

A `PLAN.md` lives in its branch's changelog folder and is per-branch, so work parked there as "next steps" is effectively lost to anyone not reading that one branch's history. Any task that must be addressed in a **separate or future PR** belongs in a GitHub issue, which is the durable, prioritizable record. `PLAN.md` may reference those issues by number, but the issue is the source of truth.

## Corollary for reviews

Work discovered mid-PR is deferred by default. It is pulled into the current PR only when it **breaks the existing work**, meaning the PR cannot deliver its objective or would regress the default branch while the item stands. "Related", "adjacent" and "while we are here" are not that test.
