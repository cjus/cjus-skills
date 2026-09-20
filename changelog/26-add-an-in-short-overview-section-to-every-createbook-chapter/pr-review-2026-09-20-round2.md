# PR review, round 2: add an `## In short` overview section to every createbook chapter

Reviewed: `feature/26-add-an-in-short-overview-section-to-every-createbook-chapter`, 3 commits
ahead of `main` (`847be04`, `ed4653e`, `f580832`). Round 1 (`pr-review-2026-09-20.md`) returned
REQUEST_CHANGES on one Critical and two Important findings. **This is a delta review**: it
verifies those three fixes and reviews what `f580832` itself changed. The rest of the PR was
reviewed in round 1 and is not re-audited. No PR exists yet (`gh` reports none), so the base is
`main` directly.

All runs below are `PATH=/usr/bin:$PATH ./scripts/check-book.sh ...` on `/bin/bash` 3.2.57, the
bash `#!/usr/bin/env bash` actually resolves to on this machine.

## Summary

`f580832` fixes all three round-1 findings. I reproduced each defect against the pre-fix script
(`ed4653e`) and confirmed each is gone at HEAD. The four fixture folders behave exactly as
stated. Two new things came in with the fixes, both confined to the new format and neither a
regression against `main`: a book declaring `overview` cannot pass on a machine without `jq`, and
the now-stricter `Carried in: ` prefix turns a one-character typo into a silent skip of two
checks rather than a failure.

## Verification of the three round-1 fixes

### 1. Critical — empty `carried_records` aborts the run. **CONFIRMED FIXED.**

`check-book.sh:842` now reads `for rec in ${carried_records[@]+"${carried_records[@]}"}; do`,
the idiom already used at `:923`.

Reproduced both sides against the new fixture:

```
$ ed4653e's check-book.sh fixtures/overview-nothing-carried
check-prefix.sh: line 849: carried_records[@]: unbound variable
rc=1

$ HEAD's check-book.sh fixtures/overview-nothing-carried
chapters: 1  content-checked: 1  tagged: 1/1 (required)  prose: 190  structure: 112
  overview: 46 (required)  provenance: required  suggested reading: required  glossary: 1 terms
OK    structure is sound; read the seams for continuity
rc=0
```

`fixtures/overview-nothing-carried/` is the right fixture for the right reason: one chapter,
`overview` **and** `glossary` both declared (so the cross-check block is entered), and a section
whose first paragraph deliberately does not open with the prefix (so the array stays empty). That
is the exact combination the older fixture could not reach.

I also swept the file for the same bug class. Every remaining `[@]` expansion is either guarded
by the same idiom (`:923`) or provably non-empty at the point of use (`chapters`, which exits 2
at `:197` when empty). No second instance.

Worth noting as a positive: the guarded expansion is unquoted on the outside, which would word-split
a record. It does not, because the alternative value is quoted inside, and the fixture proves it —
`fixtures/overview/` carries the two-word term `carried-in line` through that loop and resolves
it as one key.

### 2. Important — rules gated on heading presence rather than on the declaration. **CONFIRMED FIXED.**

`check-book.sh:312` now requires `[ "$ovw_mode" = required ]` before `ovw_present` is set, so the
position rule, the header-table rule, the cap, the cross-check and the `h2` subtraction at `:693`
all move together with the declaration.

Reproduced with `fixtures/fence/` (no `overview` key) with one part heading renamed to
`## In short`:

| | verdict | prose |
|---|---|---|
| `main` | OK | 567 |
| `ed4653e` | FAIL x2 (position, part count) | 564 |
| HEAD | OK | 567 |

HEAD is now byte-identical to `main` on that book except for the new `overview: 0 (off)` field on
the summary line, and the prose figure is back to `main`'s because the section is no longer
carved out of it. The opt-in promise in `PLAN.md` § Overview holds, and `SKILL.md:258` now states
the rule explicitly ("**The declaration is what makes the heading a section**"), so the docs and
the code agree. Old-format books also behave identically to `main` under the no-`jq` fallback.

I re-ran the round-1 adversarial battery against `fixtures/overview/` to make sure the gate did
not quietly disarm anything. All five rules still fire:

- four bolded terms -> `the carried-in line names 4 terms and the ceiling is 3`
- a term absent from the glossary -> `... names "ghostterm", which glossary.md does not define`
- a term glossed in this same chapter -> `... taught in chapter 2, which is not earlier than chapter 2`
- heading removed under `overview: true` -> `book.json declares overview but the chapter has no "## In short" section`
- an H2 inserted above it -> the position failure and the header-table failure

### 3. Important — nothing marks the section's end, so the range runs to EOF. **CONFIRMED FIXED, as disclosure.**

`check-book.sh:330-334` makes "nothing found" the terminal rung of the ladder and increments
`ovw_fallback` for it, and `:909` drops the `prov_mode = required` condition so the note fires in
both cases. Reproduced with a chapter carrying `## In short`, no tags, no marks and no part
headings, in a book declaring `overview: true`:

```
note: 1 chapter(s) carry no paragraph tag and no provenance mark to
      end "## In short", so it was ended at the next part heading, or at the
      end of the file where there was none. ... the figures above understate
      the prose and a chapter's opening paragraph went unswept.
```

The pre-fix script printed no note at all on the same book.

**One point of precision for the record, because the commit message says "Both corrected".** The
*extent* is unchanged: that probe still reports `prose: 0` and `longest 0`, with all 137 words
scored as overview. What changed is that the run now says so. That is exactly the remedy round 1
asked for ("Treat 'found nothing' as the fourth rung of the fallback ladder and disclose it"), and
it is the right trade — a disclosed wrong figure is a usable figure, a silent one is not, which is
the script's own doctrine at `:918`. I am confirming the fix, not reopening it. Just do not let a
later reader take the commit message to mean the number was corrected.

### 4. The trailing space on `ovw_carried_prefix`. **CONFIRMED, and it did not break anything.**

`check-book.sh:96` is now `"Carried in: "`. Every writer of that literal in the repo already has
the space: `reference/chapter-prose.md:89,97,102`, `SKILL.md:61,333`, `NOTES.md:381`, and
`fixtures/overview/overview-fixture-02...md:12`. Both overview fixtures still pass, and the
paragraph-join at `:639-643` interacts with it benignly — a line reading exactly `Carried in:`
with its terms wrapped to the next physical line still matches, because the join appends the
separating space.

### The four fixture folders

```
fence                      rc=0   overview: 0 (off)
overview                   rc=0   overview: 128 (required), glossary: 3 terms
overview-nothing-carried   rc=0   overview: 46 (required),  glossary: 1 terms
provenance                 rc=1   2 x "body has 1 part headings"
```

`provenance` fails identically on `main` (verified by running `main`'s checker against it), so it
is pre-existing and stays out of scope, as round 1 recorded.

## What is working well

- **The fixture was written to the defect, not to the feature.** `overview-nothing-carried/`
  reproduces the abort against the pre-fix script and passes against the fixed one, which is the
  difference between a regression test and a folder of markdown. Its chapter is also honest
  teaching about the bug rather than filler.
- **The bug class was swept, not just the instance.** Every array expansion in the file is now
  accounted for.
- **The gating fix moved detection, not just enforcement**, which is what made the whole
  downstream chain — position, header table, cap, cross-check, `h2` subtraction — revert together
  with one condition instead of five.
- **`NOTES.md` records the empty case as something that "had to be found twice"**, and records the
  gating decision with the reason. Both are exactly the entries that stop this being re-litigated.
- **The broadened note names what the fallback cost**, in the run's own output, rather than
  leaving a reader to infer it from a low prose figure.

## Issues found

### Critical

None. Nothing in `f580832` introduces a correctness, security or data-loss defect, and nothing in
it regresses `main`.

### Important

🟡 **A book that declares `overview` cannot pass on a machine without `jq`**

📍 Location: `plugins/bookcraft/skills/createbook/scripts/check-book.sh:116`, `:146`, `:312`

**What I see:**

Declarations are read only inside `if [ -f "$dir/book.json" ] && command -v jq ...`. Without
`jq`, `declared_ovw` is empty, so `ovw_mode=off`, and after the gating fix `ovw_mode=off` now
means the section is not detected at all.

**Reproduced**, `fixtures/overview/` with `jq` off PATH:

```
ed4653e:  OK    structure is sound  (overview: 128 (off))
HEAD:     11 x FAIL, rc=1
          "1 of 5 paragraphs carry no tag (first at paragraph 1) ..."
          "paragraph 2 is tagged [1-1]; the paragraph number must count 1, 2, 3 ..."
```

Old-format books are unaffected: `fixtures/fence/` and the `## In short`-as-a-part variant both
return OK under no-`jq` on `main` and on HEAD alike.

**The risk:**

`SKILL.md:365`, as this PR leaves it, promises "The checker needs only bash, coreutils and awk",
and `SKILL.md:355` promises that a machine without `jq` "also falls back to inference and to that
note". The no-`jq` path is a documented, supported configuration. For `provenance` and
`suggested_reading` that fallback only *relaxes* — and `sugg_present` is still detected from the
heading, so the concept list keeps its exemptions either way. `overview` is now the first
declaration whose absence makes the checker *stricter*, and the failures it emits are false and
misdirecting: eleven messages about paragraph tag numbering on a book whose tags are correct.
Nothing on the summary line says "I could not read book.json", so there is no thread to pull.

This is not a regression against `main` — a main-era book still passes — and it does not block the
objective on a normal machine. It does mean the format this PR ships cannot be validated on a
configuration the skill's own docs call supported.

**Suggested fix:**

Separate "declaration absent" from "declarations unreadable", and let the unreadable case fall
back to presence-based detection with a note:

```bash
book_json_unread=0
if [ -f "$dir/book.json" ] && ! command -v jq >/dev/null 2>&1; then
  book_json_unread=1
fi
...
if { [ "$ovw_mode" = required ] || [ "$book_json_unread" -eq 1 ]; } \
   && printf '%s\n' "$body" | grep -qE "^[[:space:]]*${ovw_heading}[[:space:]]*\$"; then
```

with `ovw_mode` still gating the *missing-section* failure at `:663` and the cross-check at `:838`,
so an unreadable `book.json` never causes a failure, only an exemption. Then add the note the
header comment at `:100` already claims exists:

```bash
if [ "$book_json_unread" -eq 1 ]; then
  echo "note: book.json is present but jq is not, so no declaration in it was read."
  echo "      This run used the weakest mode available for every declared format."
fi
```

That note is worth having on its own merits: it is the one disclosure the "weakest mode" story is
missing, and it would have made these eleven failures self-explaining.

**Learning note:**

When a flag gates *detection* rather than *enforcement* — which round 1 asked for, correctly — the
unreadable-configuration case stops being equivalent to the absent-configuration case. "Absent"
should relax; "unknown" should relax too, but it now travels through the same variable as "absent"
into a code path that tightens. The general principle: a tri-state (declared / not declared /
could not tell) collapsed into a boolean will eventually pick the wrong default on one of the two
folds.

🟡 **`Carried in:` without the space is now silently unchecked rather than checked**

📍 Location: `plugins/bookcraft/skills/createbook/scripts/check-book.sh:96`, `:646`

**What I see:**

`case "$carried_line" in "$ovw_carried_prefix"*)` with the prefix now carrying its trailing space.
A first paragraph that opens `Carried in:**star schema** ...` no longer matches, and by
`chapter-prose.md:102` a non-matching first paragraph *is* a chapter that carries nothing in. So
the line is read as absent and both checks that read it go quiet.

**Reproduced**, `fixtures/overview/` chapter 2, space deleted after the colon and the line grown to
five terms including one absent from the glossary and one pointing at a later chapter:

```
Carried in:**carried-in line** (ch. 1), ... **ghostterm** (ch. 9), y. ...
OK    structure is sound; read the seams for continuity     rc=0
```

The pre-fix script failed that same file on the cap and on the lookup.

**The risk:**

The trailing space was round 1's own 🟢 and it is correct as spec conformance — but the cost of a
one-character typo flipped from "parsed slightly too eagerly" to "two checks silently skipped".
Silence is the worse direction here by the script's own standard at `:918`: *"A checker's silence
about a file it never opened reads exactly like a pass."* The cap is also, per `PLAN.md`
§ The carried-in line's cap, "the failure this section is most prone to", so the check that goes
quiet is the one that matters most.

**Suggested fix:**

Make the near-miss loud. It is distinguishable from genuine absence, so say so rather than
guessing:

```bash
case "$carried_line" in
  "$ovw_carried_prefix"*) ... ;;
  "Carried in"*)
    problem "$base: the carried-in line must open with the literal \"$ovw_carried_prefix\""
    ;;
esac
```

Three lines, and it makes the strict prefix safe to be strict: a paragraph that opens on those two
words and does not match the literal is a typo, never a walk.

**Learning note:**

Tightening a parser moves the failure, it does not remove it. Ask where the near-misses go: if
they land in a branch that means "nothing here", the tightening has converted a loose check into
no check. A parser with a strict accept path usually wants an explicit reject path beside it, so
the middle ground cannot drain into the default.

### Suggestions

🟢 **The commit message says the extent was corrected; it was disclosed**

📍 `f580832`, paragraph 4

"Section extent: ... Both corrected" reads as though the EOF range no longer swallows the chapter.
It still does — correctly, per round 1's accepted remedy — and what changed is that the run now
names the cost. Worth one word of precision if `COMMITMSG.md` or the PR body reuses this text, so
that nobody later reads the `prose: 0` on such a book as a new bug.

## ⏭️ Deferred to follow-up

Carried forward from round 1, which has not yet reached `/pr:close` triage, so these would
otherwise be lost. Both fail the in-scope test: they exist on `main`, and neither is materially
worsened by this PR.

- `fixtures/provenance/` does not pass on `main` either, both chapters failing *"body has 1 part
  headings"*. `plugins/bookcraft/skills/createbook/fixtures/provenance/*.md`. Symptom: anyone
  running that fixture to validate a checker change sees two failures and cannot tell new breakage
  from old. Occasion: next time `check-book.sh`'s heading-shape rule is touched. theme: fixture health.
- No runner and no CI for the fixture folders; all four are invoked by hand and nothing re-runs
  them when `check-book.sh` changes. Repo has no `.github/workflows/`. Symptom: checker
  regressions ship undetected between manual runs. Occasion: next `check-book.sh` change.
  theme: fixture health.

## Questions

1. Is the no-`jq` path something bookcraft still intends to support for a declaring book, or has
   `jq` become a hard requirement in practice? If the latter, the cheaper fix to the first 🟡 is to
   say so at `SKILL.md:365` and make a present-`book.json`-with-absent-`jq` run exit 2 the way the
   broken-`jq` case already does — which is arguably the more honest answer now that a declaration
   changes what gets checked rather than only how strictly.
2. Round 1's second question, about the `jq` guard running before the `[ -f "$dir/book.json" ]`
   test, is unchanged and I still read it as deliberate fail-fast. No action asked.

## Verdict

VERDICT: APPROVE

All three round-1 findings are fixed and verified against the pre-fix script; the two 🟡 items are
new-format gaps rather than regressions against `main`, so they do not block — fix them in this
branch if it is cheap, or ticket them, but the PR delivers its objective either way.
