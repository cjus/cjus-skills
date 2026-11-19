# bookcraft: research a book's subject and cite trusted sources with verified URLs

Start date: 2026-11-18 22:29:10 MST

Issue: https://github.com/cjus/cjus-skills/issues/127

## Overview

Add a research stage before the outline, an order of authority for facts, and citations to trusted outside sources whose URLs are verified by fetching the page and finding the quoted words on it, never recalled.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

**Stacked branch.** This branch starts from the #128 branch, because the citation rules extend `reference/primer.md` and the primer section of `createbook/SKILL.md`. Its PR targets the #128 branch and should merge after it.

## About Ticket

### Order of authority
- [x] Context, then trusted outside sources with citations, then the model's own knowledge. A disagreement goes to the operator at the gate and is recorded as a ruling.

### The research stage
- [x] Runs after the context is read and before the outline, per group of chapters.
- [x] Per concept: the way in, the best example, beginner mistakes, prerequisites, a suggested device, disagreements.
- [x] Notes kept in the book folder and never bound.

### Trusted sources and the research ledger
- [x] A trusted-source list per book, approved or edited at the gate.
- [x] A ledger recording id, URL, title, publisher, date, chapters, what the book takes, and verbatim quotes.
- [x] A URL enters only if fetched and every quote found; a script checks.
- [x] A domain off the trusted list fails.
- [x] A site that blocks fetching: the operator can supply the page (`page_file`), or the source is dropped.

### Citations in the chapters
- [x] `web <id>` marks; `check-provenance.sh` fails a missing entry, and the ledger check fails an off-list domain.
- [x] Linked where the reader meets the fact, once per source per chapter.
- [x] Source named in the sentence only when it matters who said it.
- [x] Each chapter ends with its sources, the URL printed once as link text.
- [x] "Never store a URL" and the ban on links rewritten, reasoning in NOTES.md.
- [x] A recheck reports pages that are gone or no longer carry their quotes (`verify`, run again).

## Plan

- [x] `scripts/research-ledger.sh` with `check`, `verify` and `list`, and its format.
- [x] `check-provenance.sh`: borrow the ledger module, resolve `web <id>`, reserve the word, and check each chapter's marks against its links.
- [x] `reference/primer.md` and `reference/chapter-prose.md`: authority order, citation rules, the closing section's outside-source line.
- [x] `createbook/SKILL.md`: § Research the subject, the URL paragraphs, gate, prompt item 8, step 7, reserved words.
- [x] `updatebook/SKILL.md`: a new outside fact needs a verified ledger entry first.
- [x] `fixtures/research` with manifest rows and a `run.sh`; README; NOTES.md; plugin 1.19.0.

## Status

Done. `scripts/test-fixtures.sh --strict` passes 26 of 26. The first review requested changes (pr-review-2026-11-18-first.md), and every blocking and important finding was fixed:

- The chapter URL check reads prose only. Fenced blocks and inline code spans are skipped, so a URL in a command is code, not a citation. Link targets may carry balanced parentheses, and bare URLs stop at emphasis and backticks.
- A `trusted` list of plain strings is reported, not a crash.
- Quote matching closes the space a removed inline tag leaves before punctuation.
- `verify --id N` fails when the ledger has no entry N.
- `--file` checks and verifies a research agent's own ledger file before the merge, and refuses a path out of the book folder.
- From the suggestions: a URL with a user name before its host is refused, and `verify` fails a page that redirects off the trusted list.

The second review approved (pr-review-2026-11-18.md). Its one important finding is fixed: a link inside a parenthesis in the prose was read with the prose's `)` attached, so link targets now match one level of balanced parentheses, and fixture 01 carries that case. From its suggestions, the trusted check takes host and path from a URL parse and refuses query, fragment, backslash and `..` tricks, `list` no longer crashes on a malformed ledger, and three wording leftovers are fixed.

## Deferred

- None.
