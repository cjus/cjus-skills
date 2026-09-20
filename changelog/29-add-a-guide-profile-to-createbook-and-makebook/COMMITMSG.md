add a guide profile to createbook and a reading edition to makebook

The whole branch lands in one commit; nothing was committed before this.

Rule set and checker:
- add `chapter-prose.md § The guide profile`, a delta against the narration
  rules: openings that stand alone, headings that carry the point, four
  labelled callouts, numbered procedures, optional exit-on-weakness, an
  optional wrong model, provenance carried by the mark, and appendices
- teach `check-book.sh` the profile, read from `book.json` and never inferred:
  H3 allowed under `guide` and H4 never, the four callouts with a ceiling of
  four, the `-appendix-N-` file kind with `[A<N>-<n>]` tags exempt from the
  shape and required-section rules, and the profile first on the summary line
- flag a `sources` key that looks like a repo path reaching a chapter's page
- name the unread profile when `book.json` exists and jq does not, so a guide
  book failing under the narration rules says why

Binder:
- add the reading edition, by `--reading-edition` or `"edition": "reading"`:
  paragraph tags off the page and the header's `Draws on` and `Fills in` rows
  moved to chapter endnotes, with the markdown never touched
- render the four callouts as boxed asides in the PDF and the EPUB
- add lesson-script slide rows under a declared `slide_figures` folder: compact
  art at 62% measure, no figure number, off the Figures page, still measured
  against the legibility floor at the width it prints at
- fix the glossary's code spans, letter grouping and sort order, in both the
  PDF and EPUB builders, which had three symptoms of one cause
- label and number appendices as appendices rather than as chapters

Skills and docs:
- settle the profile at step 1, record it in the outline, show it at the gate,
  and name it in every chapter agent's prompt
- count every word on the page in the read-time estimate, not the prose alone
- let a `sources` entry carry a reader-facing `display` name beside its path,
  and teach `check-provenance.sh` that form, which its parser would otherwise
  have read as two missing paths
- have `updatebook` read the profile and hold an edit to the named rule set
- record in `NOTES.md` what was measured, what is asserted, and the five
  decisions the ticket left open

Fixtures:
- `jq-unrunnable/` pins the jq guard, asserting both that a broken jq stops the
  run and that a working one reads every declaration
- `guide/` and `guide-under-narration/` are the same chapters under each rule
  set, so a checker that stopped enforcing either is visible

bookcraft 1.2.0 -> 1.3.0. No breaking change: absent keys mean the previous
behaviour throughout, and the default-edition text of the existing fixtures
binds byte-identical to the previous builder.

Closes #29.
