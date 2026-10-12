# Keep figures and slides through an updatebook chapter rewrite

Start date: 2026-10-12 09:50:36 MDT

An `/updatebook` chapter rewrite drafts the chapter again from `/createbook`'s step 5 prompt
and replaces the file whole. The prompt has no line for figures or slides, so the rewritten
chapter binds without the ones the old chapter placed, and nothing warns. This branch makes a
rewrite keep them, or drop one only with a recorded reason, and brings #87's slide exemption
into line with it.

## Changes

### 2026-10-12 10:00:30 MDT: the open questions are settled

The operator ruled on both: the chapter agent re-places the figures and slides, through a step 5
item only a rewrite fills, and a kept figure is re-checked against the paragraph it now follows.

### 2026-10-12 10:03:33 MDT: a chapter rewrite keeps its figures and slides

- **`createbook § 5`.** Item 15 hands the chapter agent what the old chapter placed. The agent
  places each where the new prose needs it, writes a slide's explanation as it drafts, and names
  one it leaves out in its findings file.
- **`updatebook § Rewriting one chapter`.** Lists the figures and slides before drafting, reads
  the findings file, re-checks each kept figure, and diffs what the chapter places before and
  after. § 6's report names each one kept, corrected or dropped.
- **The slide exemption is retired**, since its reason was the drop. § Adding prose and the
  levels table say a rewrite keeps the chapter's figures and slides.
- **Elsewhere.** The README, a dated `NOTES.md` section, and bookcraft 1.13.0 to 1.14.0.

18 of 18 fixtures, 231 citations.

### 2026-10-12 10:17:03 MDT: the pre-test review's in-scope findings, applied

The review asked for changes; CI had passed all five jobs on PR #95.
- Step 9 now matches an inline SVG `<title>` with an `id`, the house template's form.
- Step 9 runs `git show` from the chapter's folder, so an absolute path no longer empties the
  old side.
- Item 15 names inline SVG as the one exception to `chapter-prose.md § Never`.
- The rewrite list's own step references read "§ 2" and "§ 5".

A script ran step 9 as the skill prints it and caught every drop, by relative or absolute path.
Five suggestions were left. 18 of 18 fixtures, 232 citations.

### 2026-10-12 10:36:46 MDT: the close review's suggestions, applied

The close review approved, and CI passed all five jobs on the pre-test fixes. Item 15 now tells
the agent, as "Say that", to open each image and keep an inline SVG's block. Step 9 says a drop
with no reason is put back, or dropped then with its reason. The PR summary's CI line and "§ 6"
references are corrected. 18 of 18 fixtures, 232 citations.
