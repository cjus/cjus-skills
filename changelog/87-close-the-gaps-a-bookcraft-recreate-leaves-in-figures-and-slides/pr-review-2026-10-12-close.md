## PR review: Close the gaps a bookcraft recreate leaves in figures and slides

This is the /pr:close review of PR 93, branch
`feature/87-close-the-gaps-a-bookcraft-recreate-leaves-in-figures-and-slides` against `main`. The
ticket is `87-close-the-gaps-a-bookcraft-recreate-leaves-in-figures-and-slides`. The branch has
three commits: ae109ca, 8039a28 and 7b93723.

This is a re-review. The pre-test review (`pr-review-2026-10-12.md`) approved the first two
commits with six findings. 7b93723 applies them. So this pass covers three things:
- whether each finding landed correctly and completely;
- anything the fixes introduced;
- anything the first pass missed.

It does not re-audit the first two commits from scratch. It re-raises nothing the first pass
settled or dropped, and nothing in the five operator rulings in `PLAN.md § Open Questions`. The
deferred item about chapter rewrites is already parked under `PLAN.md § Deferred`, and is not
repeated here.

### Summary

The branch makes `/makebook`'s figure pass, after a recreate, take its candidates from both of
the old book's records:
- its chapters;
- its `diagrams/README.md`.

The slide folder is left out of both, and the recreate's gate counts the same set. Copied slides
arrive unplaced. The recreate's report lists them, and the operator places them through a new
`updatebook/SKILL.md § Placing slides`. 7b93723 makes six changes there:
- It turns slide placement round, so the slide goes before the paragraph that explains it.
- It exempts slide paragraphs from the several-at-once rewrite.
- It defines the explanation as said to the reader.
- It orders slide placing before repointing.
- It makes the `slides:` count a running total.
- It extends the slide-folder exclusion to the README record.

### The six findings, checked against the tree

| # | Finding | Where it landed | Status |
|---|---|---|---|
| 1 | Slide goes before its explaining paragraph | `updatebook/SKILL.md:277-278`, step 2 row `:90`, report `:282`, `createbook/NOTES.md` § Slides | Applied, and consistent everywhere |
| 2 | Slide paragraphs exempt from several-at-once | `updatebook/SKILL.md:279` | Applied as the operator ruled it. Incomplete against the sibling trigger, see Important 1 |
| 3 | Explanation said to the reader, not a room script | `updatebook/SKILL.md:278` | Applied. The citation resolves to `guide.md:189` |
| 4 | Place slides before repointing | `createbook/SKILL.md:710`, `updatebook/SKILL.md:275` | Applied. Ordering nit, see Suggestion 3 |
| 5 | `slides:` line is a running total | `updatebook/SKILL.md:282` | Applied |
| 6 | Slide folder left out of the README record | `makebook/SKILL.md` (the "Leave out anything under" sentence), `createbook/SKILL.md:701` | Applied in both. The gate cites makebook for the match key |

**Finding 1 needed checking at five sites.** I checked each one:
- **Step 2's table**, where the new row says "The paragraph after it, which prints beside it,
  where it does not explain the slide".
- **Bullet 1**, which says "directly before it", and calls that the reverse of a figure.
- **Bullet 2**, which covers the case where no paragraph explains the slide: "rewrite the one
  after it ... or add the explanation after the slide".
- **The report**, which gives "the tag of the paragraph beside it".
- **`NOTES.md`**, where § Slides records the correction.

All five agree with each other. They also agree with `makebook/SKILL.md § Lesson-script slides`
("its notes running beside it"), and with the guide fixture, where the slide line is followed by
`[1-6] The slide above ...`.

I swept the plugin for stale wording: "paragraph it supports", "tag of the paragraph it follows",
"placed count is what", and "old README as its candidates". The only hits are in dated `NOTES.md`
sections: `:1220` from #80's own section, and `:1285` and `:1310`, which are historical text in
the new section. Those are correct as history.

**Claims in `pr-summary-2026-10-12.md`, checked against the diff:**
- **The size figures are right.** The diff is 10 files, 572 insertions and 10 deletions. The plan
  folder accounts for 466 insertions (72 + 127 + 267). The plugin accounts for 106 insertions and
  10 deletions across seven files.
- **227 citations resolve.** I re-ran `scripts/check-citations.py`: "227 resolve, 10 skipped as
  untracked".
- **The code excerpts match the diff exactly.** I checked the `build-book.py` warning, makebook's
  candidate block and updatebook's placement sentence.
- **The fixture claim holds.** A slide is followed by "The slide above ..."
  (`guide-fixture-01-what-a-profile-selects.md:65-68`).
- **The rulings and deviations listed match `PLAN.md`.**
- **One claim is stale**, about CI. See Suggestion 4.

### What is working well

- **Finding 1's fix turns placement round at every site, not only the one that was flagged.** The
  step 2 row, both bullets, the report line and `NOTES.md` all describe the same geometry, and
  "the reverse of a figure" names the difference so the next editor does not copy the figure rule
  back.
- **The exemption gives its reason in the rule itself.** It says the chapter's claim has not
  moved, and that the rewrite would drop the slides because "the chapter prompt it drafts from
  places none". A future reader can tell from that whether the exemption still applies.
- **Finding 6 went into both records, in both skills**, with the reason given ("slides are copied
  rather than redrawn"). The gate also now cites makebook, so there is one definition of the set
  and one reference to it.
- **`NOTES.md` records the correction openly.** It says what the first text did, why it was
  wrong, and that a figure still follows its paragraph. This is the kind of evidence trail that
  stops the same mistake coming back.
- **The CHANGELOG's per-finding list maps one to one onto the review**, which made this pass
  quick to verify.

### Issues found

#### Critical

None.

#### Important

**1. The slide exemption covers the at-once trigger, but not "already carries several lettered
tags". A later run can still rewrite the chapter and drop its slides.**

Location: `plugins/bookcraft/skills/updatebook/SKILL.md:279`. The rules it does not reach are at
`:197`, `:225` and `:230`.

**What I see:**
The exemption reads: "Paragraphs added for slides do not count toward § Adding prose's
several-at-once rule." That matches the operator's ruling word for word. But `updatebook` has
three triggers that send a chapter to a rewrite, and the exemption names one of them:
- `:197` says "A chapter **collecting several**, or needing several at once, is due a rewrite".
- `:225`, in the Rewrite one chapter row, says "it needs several new paragraphs at once, **or it
  already carries several lettered tags**".
- `:230` says "The lettered-tag report in step 5 is where to watch for one". The exemption itself
  ends by pointing at that report: "`check-book.sh` still reports the lettered tags."

**The risk:**
Take a chapter given three or four slides that no paragraph explained. After the placing run, it
carries three or four lettered paragraphs. Two things then go wrong:
- **The exemption covers that run only.** Step 5 of the same run reports those lettered tags, and
  `:225` and `:230` read them as a chapter due a rewrite. The exemption names only the at-once
  rule, so it does not say the report should be read differently.
- **The exemption is invisible to later runs.** It lives only in § Placing slides, which a later
  run that is not placing slides never reads. That run sees "already carries several lettered
  tags" and rewrites the chapter, replacing the file whole (`:237`) from a prompt that places no
  slide.

The slides then leave the book. Nothing reports it: by ruling, the bind does not warn about
unplaced slides.

The operator's reason for the ruling was that "a rewrite ... would drop the slides the run had
just placed". That reason applies equally to the accumulated-tags trigger, so the fix stops
halfway along its own reasoning.

This is not a regression against `main`, which places no slide at all, so it does not block. But
it is a gap in a rule this PR wrote, it costs two clauses to close, and it sits on the path to
the objective: a recreated book carrying slides binds with them.

**Suggested fix:**
Make the exemption visible where the triggers are, and give later runs a way to recognise a slide
paragraph from the chapter alone. A paragraph lettered directly after a slide line is
recognisable that way.

In § Placing slides, `:279`:

```markdown
- **Paragraphs added for slides count toward neither of § Adding prose's several rules**: not
  the several-at-once rule in this run, and not the several-lettered-tags rule in a later one.
  [rest unchanged]
```

At `:197`, and in the `:225` row:

```markdown
... A chapter collecting several, or needing several at once, is due a rewrite, which is what
renumbers them (§ When to stop editing in place). A lettered paragraph directly after a slide
does not count: it explains the slide, and a rewrite would drop the slide (§ Placing slides).
```

```markdown
| ... or it already carries several lettered tags, not counting one directly after a slide |
```

If the operator would rather not extend the ruling, the other option is to say at `:225` that a
chapter carrying slides is rewritten only with its slide lines carried across by hand. That
reaches into the deferred chapter-rewrite item, though, which is a bigger change.

**Learning note:**
When a rule is exempted, look for its siblings. A threshold usually comes in an "at once" form
and an "accumulated" form, and an exemption that names one leaves the other armed. The exemption
also has to sit where the rule is read, not only where the exempted work happens, or the next
run will not know about it.

#### Suggestions

**2. "Nothing but that report names an unplaced slide" is no longer true once a placing run has
reported.**
Location: `createbook/SKILL.md:710`, against `updatebook/SKILL.md:280` and `:282`.

`updatebook`'s placing run reports "each one left unplaced with the reason", so after it there
are two reports. The sentence means that no check or bind names an unplaced slide. Suggest: "No
check names an unplaced slide: only step 9's report does, and then the placing run's. The bind's
`slides:` line counts only ..." This was in 8039a28, so the first pass missed it. It is not new
in 7b93723.

**3. The repointing instruction comes before the paragraph that says to place slides first.**
Location: `createbook/SKILL.md:704`, against `:710` and the step 9 row at `:694`.

`:704` reads "**Then repoint every outside citation**", immediately after the gate list. Six lines
later, `:710` says to place the slides before repointing. Step 9's report names the figure pass
and `/updatebook`, but not this order. A reader taking `:704` in sequence repoints first, and
pays for each rewritten paragraph twice. That is cost, not loss, because check 4 catches it.
Suggest one clause, at `:704` or in the step 9 row: "once the copied slides are placed (below)".

**4. The summary's CI line is stale.**
Location: `pr-summary-2026-10-12.md`, under Testing.

It says "CI passed all five jobs on the PR before the last commit". `gh pr checks 93` now shows
all five jobs passing on 7b93723, which is the head commit. Suggest: "CI passed all five jobs at
the branch tip." One more point: once `/pr:close` commits the summary and this review, the
"10 files changed, 572 insertions" figures will no longer be the final ones. Either recompute
them at close, or say they cover the branch before the close commit.

#### Deferred to follow-up

No new items. The one deferred item, "a chapter rewrite drops the chapter's figures and slides",
is already parked in `PLAN.md § Deferred`. Fixing it would also make Important 1 moot.

Considered and dropped, with no entry:
- **"Which a chapter does not script" is stated generally, but cites a guide-only, advisory
  section.** `narration.md` says nothing about slides, and the recreated reference book is a
  guide. DROP.
- **A slide placed in two chapters counts twice in `slides:`.** This is left over from finding 5,
  and "the total placed so far" is fair for counting placements. DROP.
- **Bullet 2 could have the close rewritten into a slide explanation** where a slide is placed
  just before the close. This is an edge case, and `guide.md § Close` already guards the close.
  DROP.
- **The first pass's suggested fix included "after the previous unit's provenance mark, with a
  blank line each side", which 7b93723 left out.** The fixture shows the shape, and the checks
  exempt image-only lines. DROP.

### Questions

1. **Important 1.** Does the operator's 2026-10-12 ruling ("exempt") extend to the
   accumulated-tags trigger? Its stated reason covers both. If the answer is yes, this is a
   two-clause edit before merge. If it is no, record the decision under `PLAN.md § Open
   Questions`.
2. **Which provenance mark does a paragraph that explains a slide carry?** The slide folder is
   not a source `book.json` declares, and the fixture marks the slide line `src: fill`. If an
   agent marks the explanation `fill`, the chapter header's Fills-in row moves (step 4). If it
   marks the slide path, `check-provenance.sh` fails on an undeclared source. Either way the
   checks catch it, so this is a question, not a finding. A clause in bullet 2 would settle it.

### Verdict

The objective is delivered:
- Both skills name one figure-candidate set, with the slide folder left out of both records.
- A recreate's procedure says who places the copied slides, where, and how. Its report lists
  them until someone does.

All six pre-test findings are applied, and none contradicts createbook, makebook or updatebook.
The one Important item is a gap in finding 2's exemption, not a regression against `main`, which
places no slide at all. So nothing blocks.

VERDICT: APPROVE

Next: decide question 1 with the operator. If the ruling extends, make the two-clause edit in
Important 1. Fold Suggestions 2 to 4 in as convenient, refresh the summary's CI line, and
proceed with `/pr:close`.
