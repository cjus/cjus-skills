# Keep figures and slides through an updatebook chapter rewrite

Start date: 2026-10-12 09:50:36 MDT

An `/updatebook` chapter rewrite drafts the chapter again from `/createbook`'s step 5 prompt
and replaces the file whole. The prompt has no line for figures or slides, so the rewritten
chapter binds without the ones the old chapter placed, and nothing warns. This branch makes a
rewrite keep them, or drop one only with a recorded reason, and brings #87's slide exemption
into line with it.

## Changes

### 2026-10-12 10:00:30 MDT: the open questions are settled

The operator ruled on both:
- The chapter agent re-places the figures and slides, handed the old chapter's list through a
  step 5 item only a rewrite fills.
- A figure the rewrite keeps is re-checked against the paragraph it now follows, rather than
  kept with its file and `diagrams/README.md` row unchanged.

### 2026-10-12 10:03:33 MDT: a chapter rewrite keeps its figures and slides

- **`createbook § 5`.** Item 15, filled only by an `/updatebook` rewrite, hands the chapter
  agent what the old chapter placed. The agent places each where the new prose needs it, writes
  a slide's explanation as it drafts, and names one it leaves out in its findings file.
- **`updatebook § Rewriting one chapter`.** Lists the figures and slides before drafting, reads
  the findings file, re-checks each kept figure against its new paragraph, and diffs what the
  chapter places before and after. Step 6's report names each one kept, corrected or dropped.
- **The slide exemption is retired.** Its reason was the drop. § Adding prose and the levels
  table now say a rewrite keeps the chapter's figures and slides.
- **Elsewhere.** The README's rewrite paragraph, a dated `NOTES.md` section, and bookcraft
  goes from 1.13.0 to 1.14.0.

18 of 18 fixtures, 231 citations.
