# Add a guide profile to createbook and makebook

Start date: 2026-09-20 09:21:08 MDT

Add a `guide` profile to `createbook` (a second rule set beside the narration rules, with callouts, numbered procedures, appendices and looser opening and heading rules), a `reading` edition to `makebook` (tags stripped, header rows moved to endnotes, glossary code spans, compact slide rows, boxed callouts), a read-time estimate that counts every word, reader-facing source display names, and a fix for `check-book.sh` silently passing when `jq` is present but unrunnable. Closes #29.

## Changes

### 2026-09-20 09:21:08 MDT — branch opened

Plan written from #29. Objective fixed: a `guide` profile in `createbook`, a `reading` edition in
`makebook`, a full-word read-time estimate, reader-facing source display names, and the
`check-book.sh` jq bug.

### 2026-09-20, working session

**Synced `main` first.** Fast-forward `2949445` -> `3de2915`, eight commits, no conflicts, bringing
in #23 (PR #33) and #34 (PR #35). `/pr:plan-check` then found Phase 0 four-fifths already shipped by
`ed4653e` in #26, which predates this branch: the plan's measurement had been taken against the code
before that commit. Plan status corrected rather than re-scoped.

**Phase 0** closed with `fixtures/jq-unrunnable/`, a two-half runner. Verified to have teeth: a copy
of the checker with the guard deleted exits 0 with `inferred`, failing all four negative assertions.

**Phase 1** added `chapter-prose.md § The guide profile` as a delta against the narration rules, and
taught `check-book.sh` the profile, the H3 rule, the four labelled callouts, the appendix file kind
and `[A<N>-<n>]` tags. Two fixtures, `guide/` and `guide-under-narration/`, are the same chapters
under each rule set.

**Phase 2** added the reading edition, boxed callouts, lesson-script slide rows and the glossary
code-span fix to `build-book.py`. The glossary fix had to land twice: the EPUB has its own builder
carrying the same three symptoms.

**Phases 3 and 4** made the read-time estimate count every word on the page and added the object
form of a `sources` entry. That form broke `check-provenance.sh`, which iterated a dict over its
keys and would have reported two fabricated missing paths per display-named source; fixed in the
same pass.

**One self-inflicted regression, caught before commit.** Reading the profile inside the jq block
left `declared_profile` unset on the no-jq path, and `set -u` killed the documented fallback. Both
new variables are now initialised with the other declarations.

**Five open questions settled without the operator**, each recorded with its reasoning in
`NOTES.md § Five decisions the ticket left open`.

### 2026-09-20 — close, review round one

`REQUEST_CHANGES`. One blocking defect and two important ones, all mine, all fixed:

- **Blocking:** `emit_slide` nested its legibility measurement under `if is_svg:`, which is always
  false for a slide, so the slide legibility report could never flag anything. Proved by measuring
  one piece of art both ways — flagged at 2.4pt as a figure, silent as a slide. The same shape of
  failure this branch's Phase 0 exists to fix.
- Appendix carried-in terms were graded against a chapter number an appendix does not have.
- The step-4 `book.json` template defaulted every new book to a guide in the reading edition.

Three non-blocking suggestions taken as well: appendix figure numbering (`A1.1`), a dead awk
counter, and a fenced-block exemption in the repo-path check.

### 2026-09-20 — close, review round two

`APPROVE`, findings verified by re-running each original reproducer. One residual report-only nit
(an appendix slide numbered `3.s1`) fixed to `A1.s1` in the same pass.

### 2026-09-20 — close, deferred triage

Four review-deferred items triaged: two fixed in the branch (an over-broad `HEADER_NOTE_RE` that
relocated an author's table row in the reading edition, reproduced first; and `group_for` labelling
an appendix with a chapter part), two dropped. Nothing ticketed.
