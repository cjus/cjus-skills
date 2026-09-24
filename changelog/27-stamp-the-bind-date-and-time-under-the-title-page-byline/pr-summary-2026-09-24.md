# Stamp the bind date and time under the title page byline

## Overview

A bound book used to carry nothing that said when it was bound. Two PDFs or two EPUBs made
from the same folder looked the same to a reader, down to the EPUB's identifier, which is
derived from the folder and the title on purpose so a re-send replaces the book on a device.
This branch prints the time of binding on the title page, directly under the author name, in
both outputs `/makebook` produces:

```
A bound cover's title block, top to bottom:
  Guide Fixture
  Two chapters and an appendix under the guide profile
  <byline>
  Created: 2026-09-24 07:21:28 MDT
  ───────────────────────────────
  <description>
```

The stamp is read once per run. The PDF cover on every settling pass, the EPUB's cover page and
the EPUB's generated cover art all print the same value, so the PDF and the EPUB from one
binding can be matched to each other and told apart from any other binding.

## Key changes

| File | Change |
|---|---|
| `plugins/bookcraft/skills/makebook/scripts/build-book.py` | New `bind_stamp()`. `main` reads it once before the settling loop and passes it as a required `stamp` argument through `assemble`, `build_cover`, `build_epub`, `epub_cover_body` and `render_cover_png`. PDF cover CSS gives `.cover .stamp` the byline's type. EPUB CSS gives `.stamp` the byline's spacing and sets both flush left. |
| `plugins/bookcraft/skills/makebook/SKILL.md` | A paragraph on the creation stamp under the PDF page table. The PDF and EPUB cover rows name it, and the `cover_image` note says supplied art does not carry it. |
| `plugins/bookcraft/.claude-plugin/plugin.json` | Housekeeping: version 1.5.0 → 1.6.0, so installed copies are offered the update. A minor bump, as for earlier behavior changes. |
| `changelog/27-…/PLAN.md`, `CHANGELOG.md` | The operator's answers to the six open questions, phase status, measurements, and deferred items. |

## Code examples

The stamp itself, in `plugins/bookcraft/skills/makebook/scripts/build-book.py`:

```python
def bind_stamp() -> str:
    ...
    return f"Created: {datetime.now().astimezone():%Y-%m-%d %H:%M:%S %Z}"
```

Read once in `main`, before the settling loop, and never by a cover:

```python
    # Read here, once, before the first render. Every settling pass and the
    # EPUB after them print this same value, so one binding carries one stamp.
    stamp = bind_stamp()
```

Placed under the byline on the PDF cover, unconditionally, so a book with no `byline` still
gets it in the byline's place (`build_cover`):

```python
    if cfg.get("byline"):
        bits.append(f'<div class="byline">{html_mod.escape(cfg["byline"])}</div>')
    bits.append(f'<div class="stamp">{html_mod.escape(stamp)}</div>')
    bits.append('<div class="head-rule"></div>')
```

`epub_cover_body` does the same with a `<p class="stamp">`. The generated EPUB cover art is a
screenshot of `build_cover`, so it carries the stamp without any code of its own.

## Plan alignment

All five phases were completed as planned.

1. **Capture once per run.** `stamp` is a required argument with no default at every level,
   matching how `assemble` already requires `css`. A cover that read the clock itself would
   print a different time on each settling pass and another in the EPUB.
2. **PDF cover.** `.cover .byline, .cover .stamp` share the byline's 10pt system sans. The
   byline's 0.28in gap before the rule moved to the stamp, and the byline keeps 0.06in.
3. **EPUB cover page.** `.byline, .stamp` share spacing and set `text-indent: 0`.
4. **SKILL.md.** Documented.
5. **Bind and inspect.** See Testing.

The operator answered the plan's six open questions before implementation:

- **Format:** local time with the zone abbreviation. Seconds are included so two rebinds in
  one minute still differ.
- **Label:** `Created: `.
- **No byline:** the stamp prints anyway, in the byline's place.
- **Type:** the byline's size and face.
- **Override:** no reproducibility override.
- **Cover art:** a declared `cover_image` is left untouched.

**One deviation, stated:** the EPUB cover's byline is now flush left. On main it picked up
`p`'s 1.2em indent whenever a subtitle preceded it (measured at 19.2px in Chromium). Left alone,
that would have indented the stamp under an unindented byline in some configurations and not
others. The fix changes the look of the byline on existing EPUB covers.

## Testing

**Manual binds.** The `guide` fixture was copied out of the tree and bound at 11.8, 14 and
17pt, plus a copy with `byline` removed from `book.json`. For each:

- `pdftotext` of page 1 and `EPUB/cover.xhtml` carried the same `Created:` value.
- Page 2 of the PDF began with the Contents probe, so the cover fit on one page, and the build
  printed no cover warning.
- The PDF page 1 and the generated `cover.png` were inspected as images. The stamp sits under
  the byline in the byline's type.
- The EPUB cover page was rendered in Chromium. Byline and stamp are both `text-indent: 0` and
  the same computed size.

**Cover cost, measured against main's `build-book.py`** by where the description's first word
lands in the PDF text layer:

| Cover | main | branch | cost |
|---|---|---|---|
| With byline | 244.45pt | 265.45pt | 21pt |
| No byline | 208.45pt | 244.45pt | 36pt |

The cost is identical at 11.8, 14 and 17pt, because none of the cover's type scales. A cover
that sat within that distance of spilling on main now spills onto page 2, and the existing
`ZQCOVERENDQZ` warning reports it.

**Automated.** `plugins/bookcraft/scripts/test-fixtures.sh` passed 11 of 11. CI (`fixtures`)
passed on macOS and Ubuntu. Neither binds a book, so neither exercises this change (see
Deferred work).

**Review.** The pre-test review approved with no blocking findings. It independently confirmed:

- the stamp has a single call site;
- every changed signature's callers map correctly;
- nothing that reads the text layer back (`locate`, the index matcher, the settling test) is
  affected;
- `build_css()` output differs from main only in the added rules, at all three sizes.

Its one factual correction, that the cover cost was 21pt only with a byline, is reflected
above.

**Edge cases considered.**

- A book with no byline.
- A time zone with no abbreviation. `%Z` prints the UTC offset, for example `+04`.
- A declared `cover_image`. Untouched by design and not bound here, because no fixture declares
  one.
- An EPUB with neither subtitle nor byline. The description's first paragraph now indents as it
  already did in every other configuration.

**To verify by hand:**

- Bind a book twice and confirm the two stamps differ.
- Bind a book with no byline and a long description, and watch for the cover warning.
- Bind with a `cover_image` and confirm the art has no stamp while the cover page does.
- Open the EPUB in Books or on a Kindle.

## Impact assessment

- **Plugin files:** three changed, counting `plugin.json`: 54 lines added and 17 removed.
- **Version:** bookcraft moves from 1.5.0 to 1.6.0.
- **Dependencies:** none added. `datetime` is standard library.
- **Signatures:** `assemble`, `build_cover`, `build_epub`, `epub_cover_body` and
  `render_cover_png` each gained a required `stamp` parameter. Nothing outside `build-book.py`
  calls them.
- **Visible changes:**
  - Every PDF cover and EPUB cover page gains one line.
  - Generated EPUB cover art gains it too.
  - The EPUB byline is no longer indented.
- **Breaking:** none in interface. A book whose cover was within 21pt (36pt with no byline) of
  running onto page 2 will now do so, and the build says so.

## Deferred work

- **No automated check binds a book.** The fixture runner and the CI workflow never invoke
  `build-book.py`, so a regression there would ship with CI green, and this branch's evidence
  is the manual binds above. Filed as #32. The `build-book.py` fixes already queued in #19 and
  #20 are the occasion to pick it up.
- **Fixture bylines name a model.** The pre-test review asked whether this conflicts with the
  repo's no-attribution rule. It is by design: #10 made `/createbook` write the name of the
  model that wrote the chapters as the byline, and the fixtures follow that rule.
