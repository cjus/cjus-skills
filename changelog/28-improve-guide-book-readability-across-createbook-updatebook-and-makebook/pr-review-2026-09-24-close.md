## PR review: Improve guide-book readability across createbook, updatebook and makebook

PR #33, base `main`, reviewed `main...HEAD` at `56ab774` (5 commits). Close review. Acceptance bar: `PLAN.md` Phases 1 to 6. Phase 7 was split to #34 by the operator and is not expected here.

### Summary

The branch gives the `guide` profile its own rule file (`reference/guide.md`), with `chapter-prose.md` kept as the shared core and the handoff rules moved to `narration.md`. It takes the handoff chain out of the guide path, and makes `## In short` the one summary. `check-book.sh` now fails a guide book on the 90-word paragraph stop and adds six report-only signals. `/updatebook` gains lettered tags (`[5-12a]`) and a three-level edit, rewrite or recreate rule, and all five tag consumers accept the new form. `/makebook` binds a guide book's reading edition by default, swaps display names into the source rows, and re-renders with the page markers hidden.

### What is working well

- **The pre-test and independent-review fixes hold, and the fixtures prove it.** I ran the HEAD versions of `lettered-tags/run.sh` and `display-names/run.sh` against the scripts at `9cad641`, the commit before the fixes. The relettered-run and appendix-slug cases in `lettered-tags` fail there, and so do five cases in `display-names`: the doubled article, the word key, the `Act on this` row, the `This chapter` row, and `source_displays` returning `syllabus`. At HEAD all of them pass. So each fix has a regression test that actually bites.
- **The hidden-marker render is checked rather than assumed** (`build-book.py:3372-3399`). `visibility:hidden` keeps the probe boxes. The two renders are compared page by page after whitespace is collapsed, and the probed PDF is restored with a warning if they differ. I confirmed that `final` feeds only the page count afterwards, so no later verification depends on probes that are now hidden.
- **The tag-sequence check resyncs to what is written** (`check-book.sh` tag loop). One wrong tag is reported once instead of failing every tag after it, and gaps and duplicates are still caught at the point they occur. This is a real usability gain over the positional check on `main`.
- **Leading zeros keep resolving.** `tag_key` normalises both halves, and I checked that `[01-02]`, `[01-2a]` and `[A01-1a]` all resolve against the lettered fixture. So keeping the tag halves as strings did not regress citations that `main` resolved through `int()`.
- **Check 4 is conservative in the right direction.** A cut or relettered run counts as a slide, as a changed plain count does. It also ignores lettered tags when counting paragraphs, so adding a lettered paragraph cannot turn a rewording elsewhere into a false slide.
- **The portability claims check out.** `check-book.sh` under `/bin/bash` 3.2.57 with `/usr/bin/awk` gives exactly the seven `REPORT` lines that the manifest row pins. The suite passes 15 of 15 under `--strict`, and `scripts/check-citations.py` resolves all 180 citations.
- **The rule files match the plan.** `guide.md` has worked before-and-after pairs for the orienting opener, the In short rewrite and the verdict-landing close. A guide chapter agent now reads about 8,250 words, down from about 11,700 in the old single file.
- **No forbidden names.** None of the five excluded names appears in HEAD, in the branch diff, or in the uncommitted changelog files.

### Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

🟢 **The header report's display-name skip no longer matches the scoped swap**

📍 Location: `plugins/bookcraft/skills/createbook/scripts/check-book.sh`, the header-row block after the prose repo-path check (`display_keys` skip, around L1500-L1513 of the new file)

**What I see:**
```bash
printf '%s\n' "$display_keys" | grep -qxF -- "$skey" && continue
if printf '%s\n' "$header_rows" | grep -qF -- "$skey"; then
  report "... a repo path with no \"display\" name in book.json, so the bound book prints the path"
```
The comment above it says "/makebook swaps a key for its display name in both places, so a path-like key there is a problem only when it has no display name". That was true when the swap touched every header row. Since `2a69600`, the swap only touches the `Draws on` and `Fills in` rows.

**The risk:**
Suppose a path-like key that has a display name appears in the `Act on this` row. The binder leaves that row alone and the checker skips the key, so the path prints on the reader's page with no signal at all. I reproduced this by writing `` `notes/calendar.md` `` into the `guide-reports` chapter 1 `Act on this` row. Nothing was reported, and only the display-less `notes/policy.md` line fired. `main` behaves the same way, because it reports nothing in the header, so this is not a regression. It is a gap in logic this PR added, and it is unlikely in practice.

**Suggested fix:**
Apply the display-name skip only to keys found in the `Draws on` and `Fills in` rows. Report a path-like key in any other header row whether or not it has a display name. One way is to split `header_rows` into source rows and other rows with the same `**(Draws on|Fills in)**` test the binder uses, then fix the comment. A manifest assertion using the mutation above would pin it.

**Learning note:**
When one tool's check exists because another tool behaves a certain way, narrowing that behaviour has to narrow the check with it. The fix in `2a69600` changed the binder's contract, and the checker's comment still describes the old one.

🟢 **The README overstates where display names are swapped**

📍 Location: `plugins/bookcraft/README.md:216`

**What I see:** "Source keys print as their display names, in the header of either edition and in the reading edition's endnotes, wherever `book.json` gives a source a `display` name."

**The risk:** After `2a69600` the swap applies only to path-like keys, and only in the `Draws on` and `Fills in` rows. `makebook/SKILL.md` says this correctly, but the README does not. An operator who gives `syllabus` a display name and expects it swapped will see it printed as written, which is by design.

**Suggested fix:** "Path-like source keys print as their display names in the header's `Draws on` and `Fills in` rows, and so in the reading edition's endnotes, wherever `book.json` gives the source a `display` name."

**Learning note:** A summary written before a scope fix needs the same fix. The skill file was updated in `2a69600`, and the README line was not.

#### ⏭️ Deferred to follow-up

- **The binder's appendix pattern is still unanchored**, `build-book.py` `APPENDIX_FILE_RE` (unchanged line). A chapter slug holding `-appendix-N-` binds as an appendix, while all three checkers now read it as a chapter. This is pre-existing and not worsened. I can name no occasion that would pick it up, so it is a **DROP**. Theme: appendix filename recognition.

Items already recorded under `PLAN.md § Deferred` and the summary's Deferred work (the CI bind test, merging windows in the phrase report, a code-span key followed by `:` or `#`) are known and not re-raised.

### Questions

- Neither blocks. Should the lettered-tag report also give the number of lettered tags per chapter, so the "several" judgement in `updatebook § When to stop editing in place` has a figure to go on? It already lists them, so the count is only one step away.

### Verdict

VERDICT: APPROVE

Phases 1 to 6 are delivered, the review fixes in `2a69600` hold under their fixtures, and nothing regresses against `main`. The two 🟢 items are optional before merge.
