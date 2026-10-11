## PR review: Verify which PDF viewers show makebook's attached scripts (close gate)

Draft PR #89, `feature/56-verify-which-pdf-viewers-show-makebook-s-attached-scripts` into `main`,
two commits (`3e566bd`, `fcf9569`). Ticket: issue #56 in this repo. This is the `/pr:close`
review. It covers the delta since the pre-test review (`pr-review-2026-10-11.md`, APPROVE at
`3e566bd`): commit `fcf9569`, plus the new, still untracked `pr-summary-2026-10-11.md`, which
becomes the PR body. Nothing that review settled or dropped is raised again.

### Summary

`fcf9569` applies both of the pre-test review's findings. The SKILL.md heading now reads "was
seen to", and the prose under the table names the four viewers that show nothing. It also says
Acrobat refuses the double-click and that its panel was not checked. The measured result is gone
from `attach_scripts`'s docstring, which now only points at SKILL.md. "Hand the scripts out
beside the book" now gives a `pdfdetach -saveall` command. The first fix holds completely. The
second holds for the fixture but not for a book where two chapters save the same filename
(Important 1).

### Verification done for this review

| Check | Result |
|---|---|
| `fcf9569` read in full | SKILL.md: 2 lines changed. `build-book.py`: docstring, 1 line net. CHANGELOG: +14. The pre-test review file was added |
| `plugins/bookcraft/scripts/test-fixtures.sh` at HEAD | Passed 18, failed 0, skipped 0 |
| `scripts/check-citations.py` at HEAD | 219 resolve, 10 skipped as untracked |
| Own bind of `fixtures/save-scripts/book` at HEAD, then the documented `pdfdetach -saveall -o <folder>` | 7 files, one per script. `pdftotext` finds the Firefox note under all 7 blocks |
| Own bind of a two-chapter book where both chapters save `game.py` with different content | Binds with no warning (`scripts: 2 attached to the PDF: game.py (p. 3), game.py (p. 4)`). `pdfdetach -list` gives 4 entries. The documented command exits 0 and writes **one** `game.py` holding chapter two's content (Important 1) |
| `pdfdetach -saveall -o` into a folder that does not exist | `I/O Error: Error saving embedded file as '<folder>/game.py'`, exit 2 |
| `pdfdetach -save <n>` on that book | Entries 1 and 2 are chapter one and chapter two, in book order. Entries 3 and 4 repeat them. On the fixture, `-list` gives the seven scripts in book order before repeating them |
| CI | `fixtures` and `iac` succeeded on both `3e566bd` and `fcf9569` |
| Summary's impact numbers against `git diff --numstat main...HEAD -- plugins/` | 3 files, 21 added, 8 removed. Matches |
| Summary's code examples | The Before and After note strings and the table are verbatim from the diff |
| Closing keyword in `pr-summary-2026-10-11.md` | None. The file has no `#<number>` reference at all, so `/pr:close` adds the closing reference, as designed |
| Attribution in the summary and commit messages | None. The only match for the tool name is the `.claude-plugin` directory path |
| Banned-term audit (CLAUDE.md pattern, extracted at run time and self-tested on a positive also taken from CLAUDE.md) | **Clean** across the branch diff, all four plan-folder files (including the untracked summary), both commit messages, the PR title and body, and this review file |
| Generic `org/repo`-shaped sweep of the diff and summary | One hit: this repo's own issue URL in `PLAN.md § About Ticket`. Not a cross-project reference |
| Commit message voice for `fcf9569` | Lowercase imperative subject, no trailer |

### The applied fixes hold

**Pre-test Important 1 (the prose claimed a negative the table left open): resolved.**

- `SKILL.md:457`: "only Firefox was seen to hand the reader the file."
- `SKILL.md:468`: names Preview, Safari, Chrome and Edge. Says Acrobat refuses the double-click
  and that its panel was not checked. Every clause matches its row in the table and in
  `PLAN.md` Phase 2. "Any other viewer" is gone, so the sentence no longer covers viewers
  nobody tried.
- `build-book.py:2962-2963`: "Which of the common ones does what is not measured here; SKILL.md
  records it." The result is no longer copied there. A search of `plugins/` finds no other copy
  of the "only Firefox" claim outside SKILL.md, so a re-measure updates one place.

**Pre-test Suggestion 1 (say how to hand the scripts out): applied, correct for the fixture,
incomplete in general.** See Important 1.

The `CHANGELOG.md` entry for `fcf9569` describes the diff accurately.

### What is working well

- **The fix is no bigger than the finding.** The delta is four lines of plugin change, and it
  takes the reviewer's wording where that wording was exact, without reopening anything else.
- **The docstring fix removes the duplicate instead of syncing it.** Keeping the measurement in
  one place, with code that points at it, is the durable fix. Matching two copies would only
  have lasted until the next re-measure.
- **The summary is candid about the one gap in the acceptance bar.** It says the bar asks for
  both routes on every viewer and calls Acrobat's panel cell "a stated deviation" rather than
  quietly calling Phase 2 done.
- **The summary's evidence holds up.** The before and after snippets are verbatim, the line
  counts match numstat, and the fixture claims reproduce on a fresh bind.

### Issues found

#### Critical

None.

#### Important

🟡 **1. The new `pdfdetach -saveall` advice silently drops a script when two chapters save the same filename**

📍 Location: `plugins/bookcraft/skills/makebook/SKILL.md:468` (added in `fcf9569`)

**What I see:**

```markdown
When readers may not use it, hand the scripts out beside the book as well: `pdfdetach -saveall -o <folder> <book>.pdf` writes each one once.
```

**The risk:** each attachment's filespec carries only the bare filename
(`build-book.py:2985`, `name = Path(sc["name"]).name`). The binder explicitly allows two
chapters to save a file of the same name: the comment at `build-book.py:3059-3061` says so, and
it keys the name tree by book order for exactly that reason. A guide that builds one script up
across chapters is this case, for example "Save the script below as `game.py`" in chapter 2 and
again in chapter 4. `pdfdetach -saveall` writes every entry under its filespec name, so a later
entry overwrites an earlier one. I reproduced it with a two-chapter book in which both chapters
save `game.py`. It binds with no warning. The documented command exits 0 and leaves one
`game.py`, holding chapter two's version. Chapter one's script is gone, with no message. A maker
who follows the advice hands out a folder in which a chapter-one reader gets chapter-two code.

A smaller point in the same clause: `-o <folder>` has to exist already. If it does not,
pdfdetach prints `I/O Error` and exits 2. That fails loudly, so it costs a retry, not a wrong
file.

**Scope:** in scope, because this branch added the clause in `fcf9569`, and `main` gives no
extraction advice at all. It does not block. The viewer results that the objective asks for are
unaffected, and `main` only said "Not checked". It is a one-sentence fix, worth taking before
merge, because it is the only text in the PR that can lead someone to hand out the wrong file.

**Suggested fix** (the `-save <n>` numbering was checked on the repro book and on the fixture):

```markdown
When readers may not use it, hand the scripts out beside the book as well: `mkdir <folder> && pdfdetach -saveall -o <folder> <book>.pdf` writes each one once. Two chapters that save a file of the same name come out as one file, the later chapter's: `pdfdetach -list <book>.pdf` numbers the scripts in book order before it repeats them, and `pdfdetach -save <n> -o <file> <book>.pdf` writes one at a time.
```

Then bring the summary's matching Key changes bullet (`pr-summary-2026-10-11.md:28-31`) and
its Edge cases paragraph (`:102-105`) into line. A warning from the binder about a repeated
name would be new behavior. It belongs with the hand-out work already under `PLAN.md §
Deferred`, not on this branch.

**Learning note:** "this command does X" in documentation is a claim about every input, not
only the fixture it was tried on. When the code being documented has a comment about a case it
deliberately supports, here the name-tree comment, check the advice against that case. The code
already marks where the edge is.

#### Suggestions

🟢 **1. Three spots in the PR summary drift from the diff or from the table**

📍 Location: `changelog/56-verify-which-pdf-viewers-show-makebook-s-attached-scripts/pr-summary-2026-10-11.md:25-27`, `:86-87`, `:100`

**What I see and why it matters:**

- **`:25-27`** says "The docstring no longer says the viewer behavior is unmeasured." The
  docstring at HEAD still reads "Which of the common ones does what is not measured here;
  SKILL.md records it." The meaning did change. It used to say "unmeasured, see SKILL.md" when
  SKILL.md said "Not checked", and now it says the result is recorded elsewhere. But someone who
  reads the bullet next to the diff will see "not measured here" is still there and conclude the
  summary is wrong. Suggest: "The docstring now says SKILL.md records which viewer does what,
  and keeps no copy of the result, so a re-measure updates one place."
- **`:86-87`** says "The note promised two routes that fail in five of the six viewers". The
  double-click fails in five. The panel was seen to fail in four, and Acrobat's is
  undetermined. This is the overreach the pre-test review removed from SKILL.md, back again in
  the PR body. Suggest: "The note promised two routes. The double-click fails in five of the six
  viewers and the panel in four, with Acrobat's undetermined, so the note was reworded." The
  Overview (`:13`, "Only Firefox gives the reader the file") and Deferred work (`:118`) could
  borrow SKILL.md's "was seen to" for the same reason. Both are qualified within a sentence or
  two, so that change is optional.
- **`:100`** says "CI passed on all five jobs for the first commit." Both commits pass now, so
  say so.

**Learning note:** the PR body is the record a later reader finds first. Hold it to the same
precision as the documentation it summarizes, especially where the review has just tightened
that documentation.

#### ⏭️ Deferred to follow-up

These do not affect the verdict.

- **A hand-out route has to handle two scripts with the same filename.** Relevant code:
  `build-book.py:2985` and `:3059-3061`. Symptom: a folder of scripts handed out beside the book
  silently keeps one of two same-named scripts. Occasion: when the hand-out work already under
  `PLAN.md § Deferred` is picked up. Fold it into that item as one checklist line, not a ticket
  of its own. The binder's acceptance of repeated names is pre-existing on `main`. Theme: script
  hand-out.
- **DROP.** The `PLAN.md` Phase 3 status line does not mention the `pdfdetach` clause added in
  `fcf9569`. Status only, and the CHANGELOG records it. Theme: plan status.

### Questions

- None blocking. `PLAN.md § Open Questions` still holds the one item outside this repo: whether
  the first guide went to students before the note was right.

### Verdict

VERDICT: APPROVE

Nothing regresses against the `PLAN.md` objective. The applied fixes hold. Before merge, take
Important 1, a one-sentence SKILL.md fix plus the matching summary lines, and the three summary
corrections.
