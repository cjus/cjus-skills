Closes #102.

## What

Three optional `book.json` keys for `/makebook`, each defaulting to today's behaviour exactly.

- **`labels`**: one string per chapter in reading order, appendices not counted. A label replaces the sequential number wherever a chapter's number prints: the contents row, the opening page ("Chapter 6.1"), the PDF outline ("Chapter 6.1: Title"), the EPUB opener, figure numbers (Figure 6.1.2), the EPUB index's links, a glossary entry's `(ch. N)`, and the binder's messages. An empty string prints no number, for an introduction bound as a chapter: no contents number, an opener showing only its part, a bare outline title; its figures fall back to the chapter's place. A list of the wrong length or a non-string entry stops the bind with the reason.
- **`code_wrap`**: wraps a fenced line wider than the measure instead of clipping it, so nothing is lost from the page or the text layer. The long-line warning becomes a count of the lines that wrap.
- **`code_pt`**: fenced code in the PDF at a fixed size (6 to 12.75pt, rounded to the quarter pixel), with the long-line threshold measured at it.

## Why

A book whose chapters carry their own numbering, and cross-reference it in the text, bound with numbers that disagree with the text from its first sub-chapter on. A book that quotes source formatted wider than the measure lost the tail of every long line, and the only remedy was a smaller body for the whole book.

## How

- Labels are applied in the binder (`apply_labels`), not in the book model: `check-references.sh` keys chapters by the model's `unit`, and a label is how a chapter prints, not what it is. Each chapter record gains `fig_unit`, so an empty label can empty `unit` and still number its figures.
- `build_css` takes the three settings as keyword arguments whose defaults are the hand-written values. The contents number column widens to fit the longest label; the Figures page gets its own column (`.toc-num.fig-num`), wide enough for a label plus ".NN", since "1.1.1" ran into its caption in the shared one.

## Testing

- New `makebook/fixtures/labels/`: binds a book with an unnumbered introduction, chapters labelled 1, 1.1 and 2, and an appendix, and checks the contents, the Figures page, every opener, the whole outline tree, both figure numbers, the glossary in both formats, the EPUB openers, the wrapped line's last word in the text layer at `code_pt` 8, and four refusals. Binding the same book with `code_wrap` off loses that word and warns "print cut short", so the check can fail.
- `test-fixtures.sh`: 21 passed, 0 failed, 0 skipped.
- With none of the keys, `build_css()` at 11.8, 14 and 17pt differs from `main`'s by the one `.toc-num.fig-num` rule, whose 1.9em is what the column already inherited.

bookcraft 1.17.0.
