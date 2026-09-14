---
name: sanity
description: Re-audit the factual claims in your immediately previous response, classifying each as verified, inferred or unsupported, and issue corrections for anything that does not hold. Use when the user says "/pr:sanity" or asks you to double-check what you just asserted.
---

# /pr:sanity

Re-audit your **immediately previous response** against the evidence rules in `${CLAUDE_PLUGIN_ROOT}/reference/evidence-discipline.md`:

> Every factual claim (metrics, counts, historical behavior, "I saw X in the code") must be traceable to a specific source: a file path, a commit, tool output, or a document. Without one, hedge explicitly or retract.
>
> Do not assert or recommend anything you are less than 95% confident in.

## Procedure

1. **Extract the assertions.** List every factual claim and recommendation from your last message: file paths, line numbers, symbol names, behavior descriptions, metrics, counts, "X happens because Y", "this is how it currently works", "this was added in commit Z".

2. **Classify each one** as **verified** (cite the tool result), **inferred** (hedge with exactly one qualifier), or **unsupported** (re-verify now, retract, or rewrite with an explicit "I have not verified this").

3. **Check for the fabrication patterns** in `reference/evidence-discipline.md § Fabrication patterns`, and for absence treated as proof.

4. **Issue corrections in this turn**, in this exact format:

   ```
   Claim: "<exact wording from the previous response>"
   Status: unsupported | over-confident | verified after recheck
   Correction: <retraction, hedge, or citation>
   ```

5. **If everything checks out, say so explicitly and list the sources** backing the load-bearing claims. Silence is not verification.

## What this skill is NOT

- **Not a general code review.** Stay on assertions *you* made in the last response.
- **Not a confidence-boosting exercise.** If you find nothing, double-check that you actually looked.
- **Not a correction quota either.** A clean re-audit reports nothing, in one clause. Do not manufacture a hedge to prove the check ran: that trains the reader to skip the corrections that matter.
- **Do not run tool calls speculatively.** Run them only to verify a specific claim flagged in step 2.
