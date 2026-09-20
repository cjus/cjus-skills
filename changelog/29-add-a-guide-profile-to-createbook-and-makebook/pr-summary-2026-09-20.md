# Add a guide profile to createbook and makebook

Closes #29.

## Overview

The bookcraft prose rules were derived from a corpus of audio narration, and a listener cannot look back. Applied to a preparation guide — a book opened at one chapter the week it is needed — they produce linked essays with a lookup layer bolted on: well written and hard to use. This branch adds a second rule set rather than loosening the first, so every book written before it passes untouched.

Five pieces ship together: a `guide` profile in `/createbook` selected by `"profile": "guide"` in `book.json`; a reading edition in `/makebook` that binds the same folder with the workshop marks taken down; a read-time estimate that counts every word on the page instead of the prose alone; reader-facing display names for sources; and the fixture that pins down the `check-book.sh` jq guard.

bookcraft goes `1.2.0` → `1.3.0`. Nothing in the default path changes: the default-edition text of the existing fixtures binds byte-identical to the committed builder.

## Key changes

| File | What changed |
|---|---|
| `skills/createbook/reference/chapter-prose.md` | New `§ The guide profile`: a delta against the narration rules covering opening, headings, callouts, procedures, section ends, the wrong model, provenance in prose, appendices, and a suggested teaching-chapter shape |
| `skills/createbook/scripts/check-book.sh` | Reads `profile` from `book.json`; H3 allowed under `guide` and H4 never; four labelled callouts with a ceiling of four; the `-appendix-N-` file kind with `[A<N>-<n>]` tags, exempt from the shape and required-section rules; flags a repo-path source key reaching the page; reports the profile first on the summary line |
| `skills/createbook/scripts/check-provenance.sh` | Accepts the object form of a `sources` entry, with a guard for one carrying no `path` |
| `skills/makebook/scripts/build-book.py` | Reading edition (tag stripping, header rows to endnotes); callouts as boxed asides in both formats; lesson-script slide rows; glossary code spans and sorting, in both glossary builders; appendix labelling |
| `skills/createbook/SKILL.md` | The profile at steps 1, 2, 3, 4 and 5; `§ The read-time estimate`; source display names |
| `skills/makebook/SKILL.md` | `§ The reading edition`, `§ Callouts`, `§ Lesson-script slides`, `§ Appendices`; two new flags |
| `skills/updatebook/SKILL.md` | Reads `profile` at step 0 and holds an edit to the named rule set |
| `skills/createbook/NOTES.md` | What was measured (one book) versus what is asserted; the five decisions the ticket left open; the read-time arithmetic; why the glossary fix landed twice |
| `fixtures/guide/`, `fixtures/guide-under-narration/`, `fixtures/jq-unrunnable/` | Three new fixtures, 549 lines |

## Code examples

**The profile is read, never inferred** (`skills/createbook/scripts/check-book.sh`):

```bash
case "$declared_profile" in
  ""|narration) profile=narration ;;
  guide) profile=guide ;;
  *)
    echo "error: book.json \"profile\" must be \"guide\" or absent, not: $declared_profile" >&2
    exit 2
    ;;
esac
```

Inferring the rule set from a chapter that happens to carry an H3 would turn a failure into a silent reclassification — the same shape as the jq bug this plugin was already bitten by.

**The reading edition changes nothing on disk** (`skills/makebook/scripts/build-book.py`):

```python
harvest_md = body_md
notes: list[tuple[str, str]] = []
if reading:
    body_md = PARA_TAG_RE.sub("", body_md)
    notes = [(m.group(1), m.group("body").strip())
             for m in HEADER_NOTE_RE.finditer(body_md)]
    body_md = HEADER_NOTE_RE.sub("", body_md)
body_html = boxify_callouts(md.render(body_md))
if notes:
    body_html += build_endnotes(md, notes)
```

The change happens between reading the file and rendering it. `plain` is still built from `harvest_md`, so the index is identical across editions — both carry the same words on the page, the rows having moved rather than gone.

**The glossary defect was three symptoms of one cause** (`skills/makebook/scripts/build-book.py`):

```python
# before: sorted by raw text, so `PRAGMA foreign_keys` filed under the backtick
entries.sort(key=lambda e: e[0].lower())
letter = term[0].upper() if term[0].isalpha() else "#"
f'<span class="gloss-term">{html_mod.escape(term)}</span>'

# after
entries.sort(key=lambda e: gloss_sort_key(e[0]))
key = gloss_sort_key(term)
letter = key[0].upper() if key and key[0].isalpha() else "#"
f'<span class="gloss-term">{inline_code_html(term)}</span>'
```

Wrong sort, wrong letter group and literal backticks all came from never taking the markdown off the term.

## Plan alignment

**All five phases completed as planned.** Every checkbox in `PLAN.md` is now `[x]`.

**Phase 0 was four-fifths already shipped**, by `ed4653e` in #26 — this branch's base. The plan's measurement was taken against the code before that commit and read as current. Four of its five items were already done, more strongly than asked: the run `exit 2`s rather than printing a corrected note. Only the fixture was genuinely open, and it is now `fixtures/jq-unrunnable/`.

### Deviations

**One acceptance line was restated rather than met.** "The reference book's summary line reads `required` / `on` / `on` on this machine" was wrong twice: the checker's vocabulary is `required`, not `on`, and on this machine the line is unreachable at all, because `/usr/local/bin/jq` is still the x86_64 binary and `check-book.sh` now exits 2 before any summary. The fixture asserts the guard instead, which is the behaviour the phase actually bought.

**`check-provenance.sh` had to change and the ticket did not say so.** Allowing the object form of a `sources` entry broke its parser: `[val] if isinstance(val, str) else val` iterates a dict over its **keys**, so `{"path": ..., "display": ...}` would have resolved `path` and `display` as two relative paths and reported each as a declared source that does not exist. Two fabricated failures per display-named source, and the real file never opened.

**A regression introduced and fixed inside the branch.** Reading the profile inside the jq block left `declared_profile` unset on the no-jq path, and `set -u` turned the documented no-jq fallback into a dead run (`unbound variable`, before any chapter was read). Both new variables are now initialised with the other declarations. The degraded-run note was extended at the same time: a guide book checked without jq falls back to the narration rules and fails on every construct the profile exists to allow, and nothing previously said why.

**Five defects the review gate found, all fixed in the branch.** The first is the one worth reading:

- **Blocking: the slide legibility check was dead.** `emit_slide` nested its measurement under `if is_svg:`, but every slide arrives through `from_img`, which passes `is_svg=False` because the markup is an `<img>` tag while handing over the referenced `.svg` file's text as `source`. Neither branch fired, so `rec` carried no `min_pt` and the `slides:` report could never flag anything. Proved by measuring one piece of art both ways: **flagged at 2.4pt as a figure, silently passed as a slide.** That is the "checker exiting 0 is not a checker that ran" failure — shipped in the same branch that fixed one. The measurement now branches on what was read, never on how it was authored, exactly as `emit` does; the illegible slide is now flagged at 1.5pt and the legitimate one still passes.
- **An appendix's carried-in terms were graded against a chapter number they do not have.** An appendix binds after every chapter, so it has no position in the chapter sequence; stamping the record with its appendix number failed a correct book with "taught in chapter 2, which is not earlier than chapter 1". Appendices now stamp `A` and skip the ordering check, keeping the defined-and-has-a-chapter checks.
- **The step-4 `book.json` template handed every new book `"profile": "guide"`, `"edition": "reading"` and `"slide_figures"`.** That inverts Phase 2's "existing edition stays the default". The template is now the ordinary book's whole file, with the three opt-in keys in a table below it saying when to add each and what leaving it out means.
- **A figure inside an appendix numbered `3.1`** under a page headed "Appendix 1", sending a reader to a chapter the book does not have. Now `A1.1`.
- **Two smaller items:** a dead `ok` counter in the callout awk, and the repo-path source-key check not exempting fenced blocks, so a chapter showing a reader what a mark looks like would have been flagged for quoting it.

**The glossary fix had to land twice.** The EPUB has its own glossary builder carrying the same three symptoms. Both now share `gloss_sort_key` and `inline_code_html`.

**Five open questions were settled without the operator**, each recorded with its reasoning in `NOTES.md § Five decisions the ticket left open`:

- Appendix filenames are `<book-slug>-appendix-<N>-<slug>.md`, tagged `[A<N>-<n>]`. Sorting decided the filename (`a` sorts after every digit, so a plain filename sort is still the reading order); tagging decided itself, since an appendix holds exactly the material a chapter cites.
- The reading edition takes both a flag and a `book.json` key, flag winning — the order `check-book.sh` already uses for the tag decision.
- A declared-but-unreadable `book.json` stays a note rather than a failure, because the no-jq fallback is a documented, supported configuration and the dangerous case now stops the run outright.
- `slide_figures` names a folder, and the compact row applies in both editions: a divider slide orphaning half a page is a defect in any edition.
- Source display names use the object form, since one entry per source cannot drift out of sync with itself. The bare string form stays valid.

## Testing

No CI exists in this repo and no test runner ships with it; fixtures are run by hand, as `plugins/bookcraft/README.md § Fixtures` documents. Every command below was run on this branch.

```bash
cd plugins/bookcraft/skills/createbook
./scripts/check-book.sh fixtures/fence                    # 0
./scripts/check-book.sh fixtures/overview                 # 0
./scripts/check-book.sh fixtures/overview-nothing-carried # 0
./scripts/check-book.sh fixtures/jq-unrunnable            # 0
./scripts/check-book.sh fixtures/guide                    # 0
./scripts/check-book.sh fixtures/guide-under-narration    # 1, five failures by design
./scripts/check-provenance.sh fixtures/provenance         # 1, six failures by design
./scripts/check-provenance.sh fixtures/provenance --chapters 1   # 0
./fixtures/jq-unrunnable/run.sh                           # 0, both halves
```

| Check | Result |
|---|---|
| Six binds: `fence`, `overview`, `guide`, each in both editions | exit 0; `epubcheck` reports 0 errors, 0 warnings on all six |
| Default-edition text of `fence` and `overview` vs the committed builder | **byte-identical** |
| Reading edition of `guide` | 0 paragraph tags on the page (default has 10); `Draws on` moves from 21% to 94% through the chapter |
| Slides | `figures: 1`, `slides: 1`; the Figures page lists only `1.1`, the slide absent |
| Glossary | letter groups `A C P`, `#` group gone; `` `profile` `` renders `<code>profile</code>` |
| No-jq fallback | every fixture runs and degrades; the note names the rule set it defaulted to |

**Edge cases exercised deliberately.** Six negative paths were run against temporary copies to confirm the new checks fire rather than merely not-failing: an `A` tag in an ordinary chapter, an unlabelled block quote under `guide`, an H4 under `guide`, an appendix numbered out of order, five callouts against a ceiling of four, and a repo-path source key reaching the prose. Each produced exactly one targeted failure.

**The Phase 0 fixture was verified to have teeth.** A copy of `check-book.sh` with the guard deleted, run against the fixture with a `jq` stub exiting 126, exits 0 printing `OK structure is sound` and the `inferred` note — the original bug — failing all four of the runner's negative assertions.

## Impact assessment

- **10 files modified**, 1,064 insertions, 77 deletions.
- **18 files added** across three fixtures, 549 lines.
- **No dependency changes.** `requirements.txt` untouched; the new code is stdlib and the existing markdown renderer.
- **No breaking change.** `profile` absent means narration, `edition` absent means the default edition, `slide_figures` absent means no slides, and a `sources` value that is a string or a list behaves exactly as before. The byte-identical default-edition bind is the evidence.
- **Version:** bookcraft `1.2.0` → `1.3.0`, a feature release.

**One cross-tool coupling worth a reviewer's attention.** `check-provenance.sh` and `check-book.sh` both read `book.json`'s `sources` map, and this branch changed the shape of a value in it. `check-book.sh` reads only `keys[]`, which is form-agnostic; `check-provenance.sh` reads the values and needed the fix above. Any future change to that map's shape has two consumers, not one.

## Deferred work

`PLAN.md` carries no `## Deferred` section, and nothing was parked during the branch. The two items the plan named as outside its scope remain outside it and are not this branch's to carry:

- **The reference guide rewrite** (in another repo) is the validation run for this profile and was declared not part of this ticket at filing. Nothing here has been tried on a real book beyond the fixtures.
- **A follow-up ticket** holds four other `check-book.sh` items, in a different repo.

**The honest limit on this work**, recorded in `NOTES.md § The guide profile, 2026-09-20`: the entire evidence base is one book, and no rule in the profile has been tried on a reader. The counts in that section say which direction each rule points; none of the magnitudes should be quoted as a property of books in general.

### Deferred-work triage

The review raised four items for deferral. Two were reproduced and fixed in the branch rather than
filed, because each was a few lines and the reproducer was already in hand; two were dropped.

- **Fixed:** `HEADER_NOTE_RE` was matching any table row whose first cell read `**Draws on**`, not
  only the chapter header's. Reproduced: an author's own table about provenance had its row ripped
  out and relocated into the endnotes in the reading edition. The match is now scoped to the region
  above the first H2, which is where the header table lives.
- **Fixed:** `group_for` could label an appendix with a chapter part, since a `sections` range spans
  sequential numbers and an appendix has one. Guarded in both builders.
- **Dropped:** two glossary terms normalising to one sort key. `gloss_sort_key` orders and groups;
  it is not a uniqueness key, and the duplicate check deliberately compares the term as written.
- **Dropped:** `fenced_lines` reading tag-stripped markdown in the reading edition. It would take a
  fenced block containing a line that begins exactly like a paragraph tag, and the stripped form is
  what renders anyway.

Nothing was ticketed. The two items outside this repo — the reference guide rewrite and a follow-up ticket, both in another repo — were out of scope at filing and stay there.

Assertions file: not configured for this repo (`docs.assertionsFile` is `null`), so no assertion audit applies.
