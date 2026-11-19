# bookcraft: research a book's subject and cite trusted sources with verified URLs

Start date: 2026-11-18 22:29:10 MST

Issue: https://github.com/cjus/cjus-skills/issues/127

## Changes

- **`scripts/research-ledger.sh`**, new, the only definition of `research/ledger.json`.
  - `check` is offline. It checks the format, unique IDs, required fields, dates, quotes of 6 to
    40 words, a `page_file` inside the book, and every URL under a trusted domain. A domain is a
    host with its subdomains, or a host and a path prefix.
  - `verify` runs `check`, then fetches each page (or reads its operator-saved `page_file`) and
    finds each quote after folding entities and typographic marks. A page too short to search
    fails with the remedy. Run again later, it is the link-rot recheck.
  - `list` prints the trusted list and the entries.
- **`check-provenance.sh`.**
  - It resolves `web <id>` against the ledger, reserves the word for source keys and unsourced
    labels, and counts `web` in its census.
  - Per chapter, it fails a cited entry whose URL the chapter never links, and any URL in the
    chapter that is not a ledger URL.
- **Rules.**
  - `primer.md` gains § Where facts come from, the order of authority, and § Citing outside
    sources.
  - It also gets the `web <id>` mark, the outside-source line in the closing section, and two
    before-finishing checks.
  - `chapter-prose.md` allows `web <id>` and links to ledger pages under every profile, and keeps
    the concept list URL-free.
- **`createbook/SKILL.md`.**
  - New § Research the subject: trusted list, research subagents, notes and ledger, verify, a
    privacy rule for searches, and `page_file`.
  - The URL paragraphs are rewritten. The gate shows the trusted list and every disagreement,
    and a ruling becomes an assertion.
  - Prompt item 8 hands over the notes and the ledger IDs. Step 7 reads the `web` count and
    re-verifies before binding. The reserved words now include `web`.
- **`updatebook/SKILL.md`:** a new outside fact needs a verified ledger entry before it is cited.
- **`fixtures/research`.**
  - Chapter 1 cites and links two entries. Chapter 2 carries one of each citation failure.
  - Entry 3 has a saved page.
  - Manifest rows assert check-book's pass and check-provenance's three failures. `run.sh` covers
    nine malformed ledgers, offline verify (found, not found, too short), eight trusted-domain
    cases and the text folding.
- **After the first review.**
  - The chapter URL check reads prose only, skipping fences and code spans, and reads link targets
    with balanced parentheses.
  - The ledger tool tolerates a plain-string trusted list with a message, folds the space a
    removed inline tag leaves before punctuation, fails `verify --id` on an unknown id, and
    refuses a user name before the host. It fails a redirect off the trusted list, and adds
    `--file` for a research agent's own ledger.
  - The fixture gains a code span and a fenced block carrying URLs. `run.sh` gains a case for
    each of these.
- **After the second review.** Link targets match one level of balanced parentheses, so a link
  inside a parenthesis passes. The trusted check parses the URL and refuses query, fragment,
  backslash and `..` look-alikes. `list` tolerates a malformed ledger. Fixture 01 and `run.sh`
  cover each case.
- README, NOTES.md "Research and verified citations, 2026-11-18", plugin 1.19.0. The README tree
  also gains `reference/primer.md`, missed in #128's branch.
