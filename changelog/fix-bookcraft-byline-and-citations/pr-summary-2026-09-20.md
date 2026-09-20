# PR summary — name the model on a book's cover, and check every cross-reference

Closes #10.

## Overview

A skill file is a prompt an agent reads mid-run, so a wrong string in one is a
runtime fault with no stack trace: the agent reads whatever is there now and acts
on what it inferred. This branch fixes three such faults in `bookcraft` and adds
the check that would have caught two of them.

The one with user-visible consequences was the byline. `/createbook`'s
`book.json` template carried a hardcoded person's name directly under the
instruction **"Write it as it stands"**, so every book anyone generated from this
public plugin shipped that name under the title on the PDF cover and in the
EPUB's `dc:creator` field.

## Key changes

| File | Change |
|---|---|
| `skills/createbook/SKILL.md` | Byline template now names the model; three paragraphs make it a rule rather than a string to copy. Five `build-book.py:<line>` citations converted to symbols. `CLAUDE.md § Model Delegation` removed; this file's § 5 becomes the statement of record. |
| `skills/check-claims/SKILL.md` | Cites `createbook/SKILL.md § 5` instead of an absent CLAUDE.md section; the `CLAUDE.md § Plans` reference dropped, since the three bins it pointed at are stated in full directly below it. |
| `skills/updatebook/SKILL.md`, `NOTES.md` | Same substitution; the stale `createbook/SKILL.md:165-183` range replaced by a section name. |
| `skills/createbook/NOTES.md` | `SKILL.md:243` → `§ 5. Draft the chapters`; a cross-project `CLAUDE.md` citation generalised. |
| 7 × `fixtures/*/book.json` | Byline string. |
| `scripts/check-citations.py` | New. Resolves citations, refuses line numbers. |
| `.githooks/pre-commit` | New. Runs the checker ahead of each commit. |
| `README.md` | A "Working on the plugins" section documenting the one-time install. |

## Code examples

The byline rule, which is the part that stops the defect recurring rather than
just clearing it once:

```markdown
**The byline is the one field not written as it stands.** Write the name of the
model writing the chapters... The template carries a name instead of a
placeholder because a placeholder is a thing that gets copied onto a cover.

**Where the operator names a byline, use theirs without asking.**
```

A citation before and after. Both name the same code; only one survives an edit
above it:

```
before:  (`build-book.py:392-402`)      # CSS. cfg.get starts near line 1196.
after:   (`build-book.py:load_config`)
```

The checker's anchor matching, which had to learn the repo's real convention —
`chapter-prose.md` names its rules with bold leads, not headings:

```python
return bool(
    re.search(rf"^#{{1,6}} {name}\b", body, re.M)        # a heading
    or re.search(rf"^\*\*{name}[.,:]?\*\*", body, re.M)  # a bold rule lead
    or re.search(rf"^\*\*{name}\b", body, re.M)
)
```

## Plan alignment

**There is no `PLAN.md` for this branch.** It was not opened with `/pr:start`;
the work began as an investigation into the byline and widened as the audit found
the citation rot. Recorded here plainly rather than reconstructed after the fact.

Scope grew once during the branch, deliberately and with the operator's
agreement at each step: byline → the four dangling `CLAUDE.md` references → all
fifteen line citations → the checker and hook.

## Testing

- **Checker:** 121 citations resolve, 0 unresolved, 8 skipped as untracked.
- **Regression-tested against three real classes**, by breaking each and
  confirming the checker names every caller: renaming a cited heading
  (`### 5. Draft the chapters` → names all four callers), renaming a cited
  function (`load_chapters` → names both), and reintroducing a line number.
- **Hook verified with `git hook run`**, so git's own invocation path is what was
  tested, not just the script. It blocks on failure and passes when clean. It
  also caught its own README, where the example of the refused form looked real.
- **Bookcraft fixtures unchanged from baseline:** five pass, and the two that
  exit 1 are the documented negative fixtures. `provenance` still reports its
  asserted six failures; `jq-unrunnable`'s `run.sh` passes.
- **The repo's own audit pattern** for cross-project references comes back clean.

## Impact assessment

15 files, +259/−30. No behaviour change to `build-book.py` — it was not edited.
Books already bound keep their existing `book.json`; the change affects what
`/createbook` writes next.

**One thing to know rather than a breaking change:** `core.hooksPath` is
per-clone config, not a tracked file. It does not follow the merge, so each
clone needs `git config core.hooksPath .githooks` once. The hook exits 0 when
the checker is absent, so a branch without it still commits.

## Deferred work

- **`§ Anchor` matching is prefix-based**, so `§ 9. Report` still resolves against
  a heading renamed to `### 9. Report the run`. Left lenient deliberately — the
  citation still identifies the section — but a heading can drift somewhat
  without the checker noticing.
- **Two line citations were left as line numbers on purpose.**
  `course-outline.md:59` illustrates an in-book attribution signal rather than
  pointing anywhere, and `OUTLINE.md:42-43` points into the reference book's own
  outline, outside this repo.
- **`changelog/` is exempt from the checker.** Those notes were accurate the day
  they were written, and rewriting a record of what was true then to match what
  is true now would destroy the only thing such a record is for.
