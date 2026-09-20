# Add an `## In short` overview section to every createbook chapter

Closes #26.

## Overview

Every `/createbook` chapter gains a short section directly under the four-row header table,
written for a reader who has not read the chapter or who read the ones before it a month ago.
It holds two things in order: a **carried-in line** naming the concepts the chapter reintroduces
from earlier ones, and then **the walk** through what the chapter argues, in the order it argues
it. The section is opt-in through `"overview": true` in `book.json`, absent by default, so every
book written before this passes untouched.

The failure it fixes was counted rather than assumed. Seventeen of the eighteen chapters in the
reference teaching guide open on a definite noun phrase handed forward by the chapter before: `The
diagram`, `The marks`, `The join`, `The scan`. Chapter 10 is the only opener that does not. Read
in order that works. Read by jumping to one chapter, which is how a guide is actually used, the
article points at a referent the reader never had, and the opening paragraph is the worst place
in a chapter to lose someone.

A second, unrelated defect surfaced while verifying this branch and is fixed in its own commit:
`check-book.sh` had been silently running in its weakest mode on this machine for every book.

## Key changes

| File | Change |
|---|---|
| `reference/chapter-prose.md` | New `### In short` spec covering both halves. `§ Headings` corrected, `§ Before sending` grew a fifth bullet. |
| `SKILL.md` | Chapter file format example, step 4 `book.json`, step 5 prompt, new step 6 pass, step 7 checker description. |
| `scripts/check-book.sh` | Eight changes for the section, plus the jq guard. |
| `fixtures/overview/` | New two-chapter control fixture with its own `book.json` and glossary. |
| `NOTES.md` | Provenance entry recording the three decisions and the one accepted limitation. |
| `.claude-plugin/plugin.json` | 1.0.2 to 1.1.0, an additive format change. |

## Code examples

**The section, as a chapter carries it** (`SKILL.md § Chapter file format`):

```markdown
## In short

Carried in: **image** (ch. 1), the packaged filesystem a container starts from. **Dockerfile**
(ch. 2), the recipe whose lines are run in order to build one.

An image is built in pieces, one per line of the recipe, and every piece is kept...
```

**Finding the section's end, which is the whole difficulty** (`scripts/check-book.sh`). The
chapter's opening paragraph carries no heading of its own, so the next H2 is the part heading
*below* it and stopping there would swallow it:

```bash
ovw_end=$(printf '%s\n' "$body" | awk -v start="$ovw_start" '
  NR <= start { next }
  /^[[:space:]]*## / { print NR; found = 1; exit }
  /^\[[0-9]+-[0-9]+\] / { print NR; found = 1; exit }
  /^[[:space:]]*<!--/ { if (pstart) { print pstart; found = 1; exit } next }
  /^[[:space:]]*$/ { pstart = 0; next }
  { if (!pstart) pstart = NR; next }
  END { if (!found) print 0 }
')
```

**The jq guard** (`scripts/check-book.sh`). Every jq call in the script is `2>/dev/null`, so a
jq that cannot execute yields an empty string for each declaration:

```bash
if command -v jq >/dev/null 2>&1 && ! printf '{}' | jq -e . >/dev/null 2>&1; then
  echo "error: jq is on PATH at $(command -v jq) but will not run." >&2
  exit 2
fi
```

## Plan alignment

All seven phases and all thirteen ticket action items are complete. `PLAN.md § Open Questions`
is empty.

Three questions were open when work began and each was resolved by operator decision, recorded
with its rejected alternative in `PLAN.md § Settled rules` and `§ Resolved Questions`:

- **The carried-in line requires the literal `Carried in: ` prefix.** Inferring the line from its
  first `**term** (ch. N)` was rejected because both failure modes read as passes.
- **The cap of three is checked.** The line is found by a fixed prefix and a count has nothing to
  compare, so the objection that keeps the walk's rule out of the checker does not reach it.
- **The walk's no-glossed-term rule is written and reviewed, not checked.** It would need
  `OUTLINE.md`, which the checker does not read, and the comparison does not survive scripting.

**Deviations from the plan, both additive and both necessary:**

1. **`§ Before sending` gained a fifth bullet**, which no action item named. The decision to leave
   the walk's rule out of the checker only holds if some pass actually reviews it; without a
   checklist entry the rule would have been unenforced in practice rather than by design.
2. **`SKILL.md` step 5 now tells the chapter agent *not* to write the section**, and a new step 6
   pass writes it instead. The carried-in line takes its words from the glossary, which does not
   exist while chapters are being drafted, so an agent writing it there would invent exactly the
   definitions the section exists to avoid inventing.

## Testing

No automated suite exists for this skill; verification is the fixture plus mutation testing.
`fixtures/overview/` is a passing two-chapter control: chapter 1 carries the section with no
carried-in line, chapter 2 carries two terms in.

Run it:

```bash
plugins/bookcraft/skills/createbook/scripts/check-book.sh \
  plugins/bookcraft/skills/createbook/fixtures/overview
```

Each rule was verified by mutating a copy of the fixture and confirming the checker catches it:

| Mutation | Expected | Result |
|---|---|---|
| Declared, section removed | fail | caught |
| Part heading above the section | fail | caught |
| Header table not immediately before | fail | caught |
| Four carried-in terms | fail | caught |
| Carried term absent from the glossary | fail | caught |
| Carried term pointing at this chapter | fail | caught |
| Carried-in line with no bolded term | fail | caught |
| Not declared, no section | pass | passes |
| Three parts, five H2s | pass | passes |
| `overview` without a glossary | pass | passes |

Regression: `fixtures/fence` and `fixtures/provenance` behave exactly as before, exit 0 and exit
1 respectively, the latter by design.

The jq guard was verified in all three configurations: jq working (exit 0, full checks), jq
present but broken (exit 2, names the path), jq absent (exit 0, documented fallback and note).

**Two bugs were found by the fixture, both silent, both fixed:**

1. The carried-in line is a paragraph rather than a physical line. Reading only its first line
   passed a four-term line whose first two happened to wrap, and collected half the terms for
   the glossary cross-check.
2. `declared_ovw` was unbound under `set -u` on the no-jq path. It surfaced only because the
   documented fallback was exercised rather than assumed.

## Impact assessment

11 files, 847 insertions, 16 deletions. No dependencies added. bookcraft 1.0.2 to 1.1.0.

**No breaking change.** `"overview"` is absent by default and every rule is gated on it, so a
book written before this is checked exactly as it was. Both pre-existing fixtures confirm it.

**One behaviour change that is not backward compatible, and is intended:** `check-book.sh` now
exits 2 when jq is on PATH but will not run, where it previously degraded silently. Any
environment with a broken jq will start failing loudly. That is the point; the alternative is a
book checked in the weakest mode while `book.json` declares otherwise.

**Accepted limitation, documented in `NOTES.md` and announced at runtime.** The section has no
end marker, so the sweeps end it at the first paragraph tag, failing that at the first paragraph
a provenance mark names, failing that at the next part heading, and failing all three at the end
of the file. A book declaring `provenance` and not `tags` lands on the third and leaves one
paragraph per chapter whose mark nothing checked; a missing mark there is self-concealing, being
the very thing the sweep would have used to find the boundary. A book offering none of the first
three lands on the last and counts its whole chapter as overview. Either way the run prints a
note naming the chapter count and what it cost. Declaring `tags` ends the section exactly, and
every book this skill writes declares them.

## Review

Two review rounds ran on this branch. Round one returned `REQUEST_CHANGES` with three real
defects; round two returned `APPROVE` and found two regressions the fixes had introduced. All
five are fixed and covered, and the adversarial battery is 17 cases plus both `jq` paths:

1. **Blocking.** The glossary cross-check aborted the whole run on a book where no chapter
   carried a term in. bash 3.2 treats `"${arr[@]}"` on an empty array as unbound under `set -u`,
   so the script stopped before its summary line: not a wrong answer but no answer. Every
   single-chapter book has that shape. Fixed with the `${arr[@]+"${arr[@]}"}` idiom the script
   already used elsewhere, and `fixtures/overview-nothing-carried/` now holds the shape.
2. **Important.** The rules were gated on the heading being present rather than on the
   declaration, so a pre-existing book using `## In short` as an ordinary part heading failed the
   position rule, contradicting the opt-in promise. Now gated on `overview`.
3. **Important.** Where nothing marked the section's end, the range ran to end of file and
   swallowed the whole chapter, and the disclosure note could not fire because it only covered
   the part-heading case. **The disclosure is fixed; the extent itself is unchanged and is the
   accepted remedy**, so a chapter with no tag, no mark and no following part heading still
   reports almost no prose, and now says so.

A second round found two regressions introduced by those fixes, both since corrected:

4. **A declared book could not pass without `jq`.** Gating recognition on the declaration meant
   an unreadable `book.json` turned the section into ordinary prose, so `fixtures/overview/` went
   from clean to 11 tag-numbering failures on a machine with no `jq`, contradicting the fallback
   `SKILL.md` promises. Recognition is now structural, first H2 with the header table
   immediately before it, and only the checks need the declaration.
5. **A missing space silently disabled two checks.** With the prefix matched only in its exact
   form, `Carried in:` read as a chapter carrying nothing in, so a five-term line naming a term
   the book never defined and pointing at a chapter that does not exist passed clean. The prefix
   is now matched loosely to find the line and exactly to validate it.

Full reviews are at `pr-review-2026-09-20.md` and `pr-review-2026-09-20-round2.md`.

## Deferred work

`PLAN.md` has no `## Deferred` section and nothing was parked during this branch.

One item is worth the operator's attention but is not this branch's work: **every book checked on
this machine before today was validated in the weakest mode**, because of the jq defect. If any
were signed off as satisfying `provenance` or `suggested_reading`, those declarations were never
enforced. Re-running `check-book.sh` on them once jq is repaired would establish whether that
matters. The repair itself needs sudo and is outside the repo.

## Assertions

`assertionsFile` is `null` in `.claude/pr-config.json`, so the repo configures no assertions file
and no audit applies.
