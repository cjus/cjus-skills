# Code review for the close gate, 2026-09-21

Reviewed: the delta since `pr-review-2026-09-21.md`, which covered 6b497e6 and is settled. That
means 0648cc2 (the four fixes plus housekeeping) and the uncommitted `pr-summary-2026-09-21.md`.
The whole PR was not re-audited. Nothing recorded as accepted-not-fixed in the earlier review is
re-raised here.

Every claim below was reproduced against the real scripts, including reverting each fix in a
scratch copy to confirm the old behaviour, rather than read off the diff.

## Summary

The four fixes are correct. Each one was checked against the behaviour it replaces, and none of
them breaks a neighbouring path. What is not correct is the *evidence* shipped alongside two of
them: one new regression assertion cannot fail, one fix has no assertion at all, and the
pr-summary's "Edge cases covered" list claims five cases that nothing asserts.

## What is working well

**All four fixes verified sound.**

- **`CITE_SECTION` terminators.** Reverting to `[^,;)]+` in a scratch copy reproduces exactly the
  failure the new fixture assertion forbids (`carries no heading matching`, one hit). The
  assertion genuinely pins the fix.
- **`_lower_lead` breaks no locator kind.** Checked each: a section citation starts with `§`, so
  `^[A-Za-z]+` never matches and it is returned untouched; `ITEM` is `^Q\d` with `re.I`, so the
  folded `q12` still matches and the failure message still prints `Q{n}`; `STEP` carries `re.I`;
  `PAGES`/`SLIDES` are the kinds the fold exists to reach. Applied only inside `check_ledger`, so
  the step 7 mark path is byte-for-byte unchanged — the blast radius is exactly the new mode.
- **`isdecimal`.** Confirmed directly: with a real U+00B2 the old `isdigit()` path exits 1 with
  `ValueError: invalid literal for int()`, the new one exits 2 with the named refusal. The fix
  itself is right; only its test is not (below).
- **Anchored `APPENDIX_FILE` is exactly right, and matches the authority.** Ran `chapter_id`
  against eleven filenames beside `check-book.sh:291`'s own pattern. They agree on every one:

  | filename | `chapter_id` | `check-book.sh:291` |
  |---|---|---|
  | `claimfix-appendix-1-the-labels.md` | `('appendix', 1)` | appendix |
  | `my-great-book-appendix-2-the-table.md` | `('appendix', 2)` | appendix |
  | `guide-07-the-appendix-2-problem.md` | `('chapter', 7)` | not an appendix |
  | `guide-12-plain.md` | `('chapter', 12)` | not an appendix |
  | `Guide-Appendix-1-Caps.md` | `('chapter', 1)` | not an appendix |
  | `appendix-1-no-book-slug.md` | `('chapter', 1)` | not an appendix |
  | `guide2-appendix-1-x.md` | `('chapter', 2)` | not an appendix |
  | `no-digits-here.md` | `(None, None)` | not an appendix |

  The anchor is what does the work: `(?:-[a-z]+)*` cannot cross a digit run, so in a real chapter
  filename the `-NN-` blocks any later `-appendix-N-` from ever being reached. Dropping `re.I` is
  right too: `check-book.sh` rejects a non-lowercase filename outright, so a book that reaches
  here with one is already failing the structural check.

**The dash terminators do not produce the mirror-image false failure.** This was the obvious risk
and it does not land. Built a source heading `## The Grain — And Why It Matters` and a ledger
citing it in full: the run exits 0. Two things save it — `heading_hit` accepts a citation that is
a *prefix* of the real heading, and `norm()` folds em and en dashes to `-` anyway.

**The two tightened assertions are genuinely tighter.**
`grep -q "NOT USED.*names kind None and number None"` is line-scoped against `NOT USED  <name>:
<why>`, so it now asserts both the file and the reason, where `NOT USED.*appendix` matched the
filename. `cannot read 'B2'` pins the named refusal, which "no such folder" does not produce.

**Housekeeping is right.** 1.5.0 is the correct bump for a new mode plus a contract change;
`argument-hint` now reads `N,M,AN`; `tally()` says "appendices"; `id_token()` earns its keep in
the refusal; `PARTIAL n file(s)` is the right wording now that an appendix is one of them.

**Repo conventions clean.** No attribution marker in any commit, in the diff or in the summary.
The cross-project audit pattern returns nothing across the diff and the summary. `check-citations.py`
green (125 resolve). `check-book.sh` passes on the new appendix fixture. Both suites pass, 16 + 16
= 32, matching the claim.

## Issues found

### Critical

None.

### Important

🟡 **The superscript regression assertion cannot fail**

📍 Location: `plugins/bookcraft/skills/check-claims/fixtures/appendix/run.sh:109-114`

**What I see:**

```bash
# isdigit() accepts a superscript that int() then rejects; main no longer wraps
# the parse in a ValueError guard, so this used to traceback and exit 1.
out=$(python3 "$prov" --chapters "²" "$here" 2>&1); rc=$?
```

**The risk:** bash does not interpret `\u` inside double quotes. I extracted that exact line into
a probe script and dumped the argv: the token passed is the six characters `\ u 0 0 b 2`, not
U+00B2. Under the *old* `tok.isdigit()`, `"\\u00b2".isdigit()` is also `False`, so it takes the
same refusal branch. Confirmed by reverting the fix in a scratch copy and running the line from a
file:

```
NEW code, the fixture's literal token: rc=2, error: --chapters cannot read '²'
OLD code, the fixture's literal token: rc=2, error: --chapters cannot read '²'
```

Both assertions pass identically before and after the fix. They pin nothing, and the comment above
them states a rationale the code does not exercise — which is worse than no test, because the next
person reads it as covered.

**Suggested fix:** build the character portably. `$'²'` needs bash 4.2 and this repo runs on
macOS bash 3.2, so use the UTF-8 bytes:

```bash
sup=$(printf '\302\262')   # U+00B2: isdigit() true, int() raises
out=$(python3 "$prov" --chapters "$sup" "$here" 2>&1); rc=$?
```

Verified from a file under bash 3.2: new code rc=2 with the named refusal, old code rc=1 with the
`ValueError` traceback. That is a test that fails when the fix is undone.

**Learning note:** a regression assertion earns its place only by failing against the code it was
written for. Reverting the fix and watching the assertion go red takes a minute, and it is the only
thing that separates a test from a comment.

---

🟡 **The `APPENDIX_FILE` fix ships with no regression assertion**

📍 Location: `plugins/bookcraft/skills/check-claims/fixtures/appendix/` (the whole fixture)

**What I see:** the fixture holds two files, `claimfix-01-the-only-chapter.md` and
`claimfix-appendix-1-the-labels.md`. Nothing in either suite names a chapter whose slug contains
`appendix-N-`. `find plugins -name "*appendix*"` confirms no such fixture file exists anywhere.

**The risk:** the commit message says "Each fix carries a regression assertion" and the pr-summary
lists "a chapter whose slug contains `appendix-N-`" under "Edge cases covered". Neither is true
for this one. It is also the fix most exposed: `^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-` looks
gratuitously elaborate next to `-appendix-(\d+)-`, and the obvious future "simplify" re-opens the
precise collision this branch exists to close — silently, with all 32 assertions still green.

**Suggested fix:** the cheapest path is a unit probe in the shape the ledger fixture already uses
for `_lower_lead`, so no third `.md` file perturbs the emit counts or `check-book.sh`:

```python
for name, want in (("guide-07-the-appendix-2-problem.md", ("chapter", 7)),
                   ("claimfix-appendix-1-the-labels.md",  ("appendix", 1)),
                   ("guide-12-plain.md",                  ("chapter", 12))):
    if m.chapter_id(name) != want:
        bad.append(name)
```

**Learning note:** the regex that is hardest to justify on sight is the one that most needs a test
beside it. The test is the justification a later reader will actually trust.

---

🟡 **A dash-truncated section citation now passes silently, with no REVIEW**

📍 Location: `plugins/bookcraft/skills/createbook/scripts/check-provenance.sh:927`

**What I see:** `CITE_SECTION = re.compile(r"§\s*[^,;)|–—]+")`

**The risk:** the terminators are the right call, but they also truncate a citation whose *heading*
carries a dash, and `heading_hit`'s prefix rule then passes the stub. Reproduced against a source
heading `## The Grain — And Why It Matters`:

| ledger cell | before 0648cc2 | after |
|---|---|---|
| `§ The Grain — And Why It Matters` | fail (wrong) | pass (right) |
| `§ The Grain — And Something It Never Says` | fail (right) | **pass** |

The trade is correct — a gate that fails correct ledgers is unusable, and that was a blocking
finding in the first review. What is not correct is that it passes *silently*. This script has a
REVIEW channel for exactly this situation, and the earlier review's own words for the shape are
"exited 0 on a check that had asserted nothing, which is the shape this whole family of scripts
refuses". Here the tail of the citation is unasserted and nothing says so.

**Suggested fix:** when a section citation was cut at a dash, resolve it and then flag the
remainder rather than reporting a clean pass:

```python
for cite in cites:
    verdict, _ = resolve_locator(src, _lower_lead(cite), where)
    if verdict == "ok" and CUT_AT_DASH.search(cite):
        flag(f"{where}: {cite!r} was asserted only as far as the dash; "
             f"what follows it was not checked against {src.name}")
```

A comment at `CITE_SECTION` recording the coverage boundary is the minimum.

**Learning note:** when a fix trades a false alarm for a weaker assertion, the weakening is the
part that needs to be visible. An unasserted claim that looks asserted is the failure mode this
whole script family is built against.

---

🟡 **The pr-summary's "Edge cases covered" list overstates what the suites assert**

📍 Location: `changelog/16-.../pr-summary-2026-09-21.md`, `## Testing`

**What I see:** eight cases listed immediately after "Two fixtures, 32 assertions". Checked each
against the 32 assertion names and the fixture bodies:

| claimed edge case | asserted? |
|---|---|
| a chapter whose slug contains `appendix-N-` | **no** — no such file in any fixture |
| a capitalised locator opening a sentence | yes, the unit probe |
| a section citation followed by prose after an em dash | yes |
| a heading containing a colon | **no** — see below |
| a `--chapters` token `isdigit()` accepts and `int()` rejects | **no** — vacuous, above |
| a findings file whose `number` is a bool | **no** — `file_id` handles it, nothing asserts it |
| an appendix that is partial and carries notes | **no** — no fixture sets `partial_of` |
| a findings file in the superseded shape | yes |

The colon case is the subtle one. The row is
`` | `sources/handbook.md` § Appendix 1: A Colon Belongs To A Heading | No | ... | `` — marked
**Re-openable: No**, so `check_ledger` takes the `unasserted += len(cites); continue` branch and
never resolves the citation at all. Running it confirms: the only output is a REVIEW about the row
naming a path, and the exit is 0 via `OK*`. The paired assertion
`[ "$rc" -eq 0 ]` is satisfied by `OK*` too, so the colon plays no part in either assertion. The
source does not even carry that heading (`sources/handbook.md` has `## What The Grain Is` and
`## When Not To Index`), which is only harmless *because* the row is skipped.

**The risk:** this document becomes the public PR body. Three of the eight claims are unbacked,
one is backed by a test that cannot fail, and one rests on a row that asserts nothing. A reviewer
who trusts the list will not look, which is the whole cost.

**Suggested fix:** either trim the list to the three that hold, or add the assertions and keep it.
If you want the colon case genuinely covered, flip that row to `Re-openable: Yes` and give
`sources/handbook.md` a heading with a colon in it — then the assertion means what it says.

**Learning note:** a coverage claim in a PR body is load-bearing: it is what a reviewer reads
instead of the fixture. It is worth the two minutes of checking each line against an assertion name.

### Suggestions

🟢 **`_lower_lead`'s docstring states a constraint that does not exist.**
`check-provenance.sh:1004` says the fold is partial "so a heading keeps the case `heading_hit` may
compare on". `heading_hit` compares through `norm()`, which ends `.strip().lower()`
(`check-provenance.sh:314`) — no heading comparison anywhere is case-sensitive. A full `.lower()`
would have been equally safe. The conservative fold is fine; the stated reason is not, and the
same claim is carried into the commit message. Suggest: "only the leading run is folded because it
is the only part any anchored pattern reads; nothing downstream needs the rest."

🟢 **A failure message now quotes the folded text rather than the ledger cell.**
`check_ledger` passes `_lower_lead(cite)` into `resolve_locator`, whose `problem()` calls print
`rest`. A ledger that wrote `Slides 4-9` gets a failure quoting `slides 4-9`. `flag()` correctly
keeps the original `cite`; `problem()` does not. Small, but the value of these messages is that
the author can find the string in the file. Passing the original alongside the folded copy is a
one-line change.

🟢 **The summary's demo shows the fix, not the bug.** Under `## Testing`, "To see the bug this
fixes" is followed by a command whose output comment reads "index.json now lists kind chapter
number 1 AND kind appendix 1" — that is the fixed behaviour. Verified: the command runs clean on
HEAD and emits exactly that. Re-title it "To see the fix", or point the command at `main`.

🟢 **The summary's Key changes table omits `updatebook/`.** Two files changed there — `NOTES.md`
drops a line-numbered citation into a superseded outline (explained in the 6b497e6 message) and
`SKILL.md` changes user-facing guidance to `--chapters <..., an appendix as AN>`. The second is a
real behaviour-facing edit and belongs in the table.

## Confirmed sound

Checked and found fine, recorded so nobody re-checks them:

- **The residual `the-appendix-07-title.md` ambiguity is the format's, not this PR's.** A book slug
  ending in the literal word "appendix" reads as an appendix in `chapter_id` *and* in
  `check-book.sh:291` alike. Matching the authority exactly was the goal; it is matched. Not a
  finding.
- `APPENDIX_FILE` uses `\d` where `check-book.sh` uses `[0-9]`, so a Unicode-digit filename would
  differ. `int()` accepts those, so nothing raises, and `check-book.sh` rejects the filename
  anyway. Not worth changing.
- `render-report.py`'s `want` map and all four `sorted(chapters, key=order)` calls key on the pair,
  as the summary says. `file_id` rejects a bool `number` correctly.
- The summary's before/after `render-report.py` snippets are faithful to `main` and to HEAD.
- Counts in the summary check out: 19 files, 1,128 insertions, 73 deletions; 32 assertions;
  `docs.assertionsFile` is `null` in `.claude/pr-config.json`, so no audit statement applies.

## Questions

1. Was the `²` token meant to be a real superscript, or was the intent to test *any*
   unparseable token? If the latter, the comment above it should say so — but then the `isdecimal`
   fix still has no test.
2. On the dash-truncated section citation: is passing silently the intended contract, or would you
   rather it drew a REVIEW? The answer decides whether the third 🟡 is a code change or a comment.

## Verdict

All five phases hold, all four fixes are correct, and nothing in 0648cc2 regresses anything
against `main`. The findings are about evidence and accuracy, not behaviour: two assertions that
do not assert, one assertion-strength boundary worth surfacing, and a public PR body that claims
more coverage than exists. None of them blocks.

VERDICT: APPROVE

Fix the vacuous superscript assertion and trim or back the summary's "Edge cases covered" list
before this body goes public; the other two 🟡 are worth doing in the same pass.
