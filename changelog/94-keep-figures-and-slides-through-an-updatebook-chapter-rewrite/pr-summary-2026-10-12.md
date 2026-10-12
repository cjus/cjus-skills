# Keep figures and slides through an updatebook chapter rewrite

## Overview

An `/updatebook` chapter rewrite drafted the chapter again from `/createbook`'s step 5 prompt
and replaced the file whole. That prompt carried no figure and no slide, so the rewritten
chapter bound without the ones the old chapter placed, and nothing reported the loss. This was
already true on `main` before #87. #87 then added a slide exemption that kept one rewrite
trigger from firing on slide paragraphs, but it never reached the other trigger, a chapter that
already carries several lettered tags. So a later run could still rewrite a slide-bearing chapter
and drop its slides.

Now a rewrite lists what the old chapter places before drafting and hands the list to the
chapter agent. The agent re-places each figure and slide, or leaves one out with its reason in
its findings file. Each kept figure is re-checked against the paragraph it now follows. A
before-and-after comparison names anything the rewrite dropped, and the report accounts for
every figure and slide. With the drop gone, the slide exemption is retired, and § Adding prose,
§ When to stop editing in place and § Placing slides now agree that a rewrite keeps a chapter's
figures and slides.

## Key changes

- **`plugins/bookcraft/skills/createbook/SKILL.md`.** A new item 15 in step 5's chapter prompt,
  filled only when `/updatebook` rewrites a chapter:
  - It carries each figure and slide as the old chapter wrote it, with what the paragraph beside
    it said, since the agent never sees the old chapter.
  - A figure goes after the paragraph stating what it shows. A slide goes directly before the
    paragraph that explains it, and the agent writes that explanation as it drafts.
  - An inline SVG is named as the one exception to `chapter-prose.md § Never`'s rule against
    inline HTML, so the agent has no rule to cite for dropping one.
  - One the new chapter no longer needs goes in the findings file with its reason.
  - A first draft and a recreate leave the item out, so drafting a new chapter still places none.
- **`plugins/bookcraft/skills/updatebook/SKILL.md`.**
  - § Rewriting one chapter goes from seven steps to ten:
    - 3 lists the figures and slides before drafting.
    - 4 hands that list over as item 15.
    - 5 reads the agent's findings file.
    - 6 re-checks each kept figure and brings its `diagrams/README.md` row into line, recording
      a dropped figure there as passed over.
    - 9 compares what the chapter places before and after.
  - § 6's report gains a bullet listing each figure and slide as kept, corrected or dropped.
  - § Placing slides retires the exemption: paragraphs added for slides count like any others,
    and a chapter needing several at once is rewritten with its slides.
  - § Adding prose and the levels table say a rewrite keeps the chapter's figures and slides.
  - The rewrite list's own step references now read "§ 2" and "§ 5" where they meant the main
    procedure.
- **`plugins/bookcraft/skills/createbook/NOTES.md`.** A dated section records both operator
  rulings, why the chapter agent suits a rewrite when it was turned down for a recreate, and why
  the exemption is retired. A one-line note marks #87's exemption paragraph as retired.
- **`plugins/bookcraft/README.md`.** The rewrite paragraph says a rewritten chapter keeps its
  figures and slides.
- **`plugins/bookcraft/.claude-plugin/plugin.json`.** 1.13.0 to 1.14.0.

## Code examples

The comparison at rewrite step 9 (`plugins/bookcraft/skills/updatebook/SKILL.md`, § Rewriting
one chapter):

```bash
CHAPTER=<the chapter's file>
# each standalone image's path, and each inline SVG's <title>
placed() { grep -oE '^!\[[^]]*\]\([^)]+\)|<title[^>]*>[^<]*</title>' | sed -E 's/^!\[[^]]*\]//; s/^<title[^>]*>/<title>/'; }
diff <(git -C "$(dirname "$CHAPTER")" show "HEAD:./$(basename "$CHAPTER")" | placed | sort) <(placed <"$CHAPTER" | sort)
```

A `<` line is a figure or slide the rewrite dropped, and each needs a reason. The `<title`
pattern takes attributes because the house figure template writes `<title id="xx-t">`. The
`git -C` form works for a relative or an absolute chapter path.

The slide exemption in § Placing slides, before and after:

```markdown
<!-- before -->
- **Paragraphs added for slides do not count toward § Adding prose's several-at-once rule.** The
  chapter's claim has not moved, and the rewrite that rule calls for would drop the slides this
  run placed, because the chapter prompt it drafts from places none (§ Rewriting one chapter).

<!-- after -->
- **Paragraphs added for slides count toward § Adding prose's several-at-once rule like any
  others.** A chapter that needs several explanations at once is due a rewrite, and the rewrite
  takes the slides with it: the chapter agent places each one, the slides already in the chapter
  and the ones this run was placing, and writes each explanation as it drafts.
```

## Plan alignment

**Completed as planned.**
- Before drafting, the rewrite records every figure and slide with the paragraph beside it
  (rewrite step 3).
- Who re-places them was settled by the operator on 2026-10-12: the chapter agent, through item
  15. Drops go to its findings file, which rewrite step 5 now reads.
- How a kept figure is treated was settled by the operator the same day: it is re-checked
  against its new paragraph (rewrite step 6).
- A loss is visible: rewrite step 9 compares what the chapter places before and after, and
  § 6's report names each figure and slide as kept, corrected or dropped. A dropped figure is
  recorded in `diagrams/README.md` as passed over.
- The exemption no longer argues from the drop, and § Adding prose and § When to stop editing in
  place say a rewrite keeps the chapter's figures and slides.
- bookcraft is bumped, and the fixture checks CI runs pass.

**Deviations.**
- **The exemption was retired rather than reworded, as the implementer's call.** The plan
  allowed either. #87 turned down "rewrite such a chapter with its slides handed to the chapter
  agent" only because of the drop, and that is now what a rewrite does. The pre-test review
  found it coherent. One consequence is worth knowing: after a recreate, a run placing slides may
  now rewrite a slide-heavy chapter through the chapter agent, where before it would only add
  lettered paragraphs.
- **Item 15 names an inline SVG as an exception to `chapter-prose.md § Never`.** Not in the
  plan. The pre-test review found the conflict, and without the exception an agent could drop an
  inline figure by citing that rule.

**Descoped.** Nothing.

## Testing

**Automated.**
- `plugins/bookcraft/scripts/test-fixtures.sh --strict` passes 18 of 18.
- `scripts/check-citations.py` resolves 232 citations, up from 227 on `main`.
- CI passed all five jobs on the branch's first commit, and again on the pre-test review's fixes.

No fixture was added. The skill changes are prose, and the one command in them was verified by a
script instead.

**The step 9 comparison, by script.** It runs the two lines exactly as the skill file prints them,
in a throwaway repository:
- An unchanged chapter, by relative and by absolute path: no output.
- A rewrite that keeps the slide and drops a referenced figure, an inline SVG with a plain
  `<title>`, and one with `<title id="...">`: three `<` lines and nothing for the slide. The same
  from the book folder, and by absolute path.
- An image inside a sentence is never listed.

The first version missed the `<title id=...>` form, which the pre-test review caught.

**By hand.** The real test is a rewrite of a chapter that places figures and slides:
- Step 3's list names each figure and slide with its paragraph.
- The agent's draft places each one on the correct side of its paragraph, with a slide's
  explanation written into the prose rather than patched in afterwards.
- Anything left out appears in `outline-findings/<chapter file stem>.md` with a reason.
- Step 9 prints only those, and § 6's report accounts for every one.
- A kept figure whose labels no longer match the new prose is corrected or dropped, and its
  README row is updated.

**Edge cases considered.**
- An image inside a sentence: not a figure, and neither listed nor compared.
- A slide this run was placing when the chapter became a rewrite: it joins the list, and step 9
  shows it as gained.
- A book without tags: the paragraph is named by its opening words.
- A first draft and a recreate: item 15 is left out, and drafting places none, as before.
- An absolute chapter path: handled by `git -C`.

**Not handled, and left as review suggestions.**
- A book outside git, which step 0 allows, has no `HEAD` for step 9.
- A corrected inline figure whose `<title>` changed shows as a drop and a gain.
- An older findings file at the same path would be read as this agent's.

## Impact assessment

- **Size.** The plugin changes are 64 insertions and 11 deletions across five files. The rest of
  the diff is this branch's plan folder.
- **Dependencies.** None changed.
- **Breaking changes.** None to any interface or file format.
  - `/createbook` drafts exactly as before, since item 15 applies only to an `/updatebook`
    rewrite.
  - `/updatebook`'s rewrite does more, and a slide-placing run can now become a rewrite.
- **Version.** bookcraft 1.13.0 to 1.14.0.
- **Assertions.** Not configured in this repo.

## Deferred work

One item is parked under `## Deferred` in `PLAN.md`. A figure the rewrite drops is recorded in
`diagrams/README.md` as passed over, but nothing says whether its SVG file leaves `diagrams/`.
Left there, `/updatebook`'s sweep of `.svg` files keeps finding facts no chapter shows. Removed,
a figure another chapter still places would break.
