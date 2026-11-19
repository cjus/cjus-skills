# PR review: bookcraft: research a book's subject and cite trusted sources with verified URLs

Reviewed: the uncommitted working tree against `feature/128-bookcraft-a-primer-profile-subject-first-selected-and-sized-to-a-reading-budget` (stacked branch). Ticket: cjus/cjus-skills issue 127. First review of this branch; no prior `pr-review-*.md` in this plan folder.

## Summary

The PR adds a research stage before the outline. It adds `research/ledger.json` with its only definition, `scripts/research-ledger.sh` (`check`, `verify`, `list`), and `web <id>` marks that `check-provenance.sh` resolves against the ledger. A new per-chapter check fails a cited entry the chapter never links, and any URL in the chapter that is not a ledger URL. The rules in `primer.md`, `chapter-prose.md`, `createbook/SKILL.md` and `updatebook/SKILL.md` are rewritten to match, the old "never store a URL" rule is reversed with its reasoning in NOTES.md, and the PR adds a `fixtures/research` book with a `run.sh`.

`scripts/test-fixtures.sh --strict` passes 26 of 26 in the worktree. The audit of the added lines found no attribution, no cross-project term, no unexpected `org/repo` string and no em dash in fixture or reference text.

## What is working well

- **One owner for the format.** `research-ledger.sh` is the only parser of the ledger, and `check-provenance.sh` borrows it through `_borrow` rather than re-parsing. That is the same pattern `assertions.sh` uses, and it keeps the two tools from drifting.
- **The three ledger states are handled deliberately.** Missing, invalid and ok each do the right thing. An invalid ledger reports every problem and suppresses the dependent link check, so you never see a cascade of misleading "not in ledger" lines. I confirmed this with malformed JSON.
- **Trusted-domain containment is a real host test, not a string prefix.** `docs.example.org.evil.test`, `notdocs.example.org` and `github.com/example-orgs` are refused, and `run.sh` pins each case.
- **`page_file` path safety is right.** `resolve()` followed by a containment check against the resolved book folder refuses `../`, absolute paths and symlinks pointing out of the book.
- **Fails closed with a remedy.** A blocked fetch reads as a short page and the message names `page_file`, which turns a silent bot challenge into an actionable step.
- **The reserved word is enforced on both sides.** It covers source keys and unsourced labels, and the regex leaves a source called "website notes" alone.
- **The fixtures are offline by design**, and `verify` is still exercised end to end through the saved page.

## Issues found

### Critical

**1. The link check reads URLs inside code fences and code spans, so a correct book that passed on the base branch now fails**

Location: `plugins/bookcraft/skills/createbook/scripts/check-provenance.sh:2056-2071`, with the regex at `:362`

What I see:

```python
text = MARK.sub("", p.read_text(encoding="utf-8"))
urls = {u.rstrip(".,;:") for u in CHAPTER_URL.findall(text)}
```

This scans the raw chapter. `units_of` (line 705 onward) skips fenced content explicitly, "the way check-book.sh's own body sweeps skip it", but this sweep does not.

The risk: I built a one-chapter `provenance: true` primer with no ledger. It has a paragraph with `` `curl http://localhost:8080/status` `` and a fenced block holding `curl https://localhost:8080/health`. `check-book.sh` passes it. The base branch's `check-provenance.sh` exits 0. This branch exits 1 with two failures:

```
FAIL  ...: links http://localhost:8080/status`, which is not in research/ledger.json; ...
FAIL  ...: links https://localhost:8080/health, which is not in research/ledger.json; ...
```

The ledger offers no remedy: a localhost, example or placeholder URL can never be fetched and verified, so the only fix is to delete the code sample. Under `primer`, provenance is required, so this reaches every default-profile book that shows a command with a URL. That includes a `git clone` or `curl` copied from the context, which `primer.md` itself says to copy ("Command output ... copied from the context"). The handbook profiles are hit the same way. The rule text has the same overreach: `primer.md:46` "never write a URL that is not in the ledger" and `primer.md:64` and `:107` "every URL in the chapter is a ledger URL" forbid the code sample too.

The sanity check: a provenance book with a URL in a code sample passed `check-provenance.sh` on the base branch and fails it on this branch, with no way to satisfy it.

Suggested fix: scan prose only. Skip fenced lines with the same `book_model.Fence` that `units_of` uses, and blank out inline code spans before matching:

```python
fence = book_model.Fence()
prose = []
for line in MARK.sub("", p.read_text(encoding="utf-8")).splitlines():
    if fence.feed(line):          # or however Fence reports "inside / on a fence line"
        continue
    prose.append(re.sub(r"`[^`]*`", " ", line))
urls = {u.rstrip(".,;:!?*_") for u in CHAPTER_URL.findall("\n".join(prose))}
```

Then say so in the rules, in one line in `primer.md § Citing outside sources` and in `chapter-prose.md § Provenance`: "A URL inside a code sample is code, not a citation, and is not checked." Add a manifest case or a `run.sh` case: a chapter with a fenced `curl https://localhost/...` and an inline code URL passes `check-provenance.sh`. A fixture like that would have caught this.

Learning note: when a second checker sweeps the same file, it has to agree with the first on what counts as content. The repo already decided that fenced content is code (`units_of`, check-book's sweeps). A new sweep that ignores that decision creates false failures exactly where technical books are densest.

### Important

**2. A `trusted` list written as plain strings crashes both tools with a traceback**

Location: `plugins/bookcraft/skills/createbook/scripts/research-ledger.sh:115`, reached from `validate`

What I see: `validate` notes `trusted[0] must be an object` and carries on. It then calls `trusted(url, tl)` for each entry, and that calls `t.get("domain")` on a `str`.

The risk: `"trusted": ["docs.example.org"]` is the likeliest shape for a model to write. `research-ledger.sh check` and `check-provenance.sh` (which calls `ledger.load`) both die with `AttributeError: 'str' object has no attribute 'get'`, and neither names the fault. I confirmed this on both tools.

Suggested fix: in `trusted()`, `if not isinstance(t, dict): continue`. Alternatively, filter `tl` down to dicts in `validate` before the entry loop. Add the case to `run.sh`'s `mutated` list.

Learning note: a validator should never crash on the input it is validating. Every later step has to tolerate whatever an earlier step already reported as wrong.

**3. Quote matching fails on punctuation after an inline tag, which is common on documentation pages**

Location: `research-ledger.sh:96-100` (`visible_text`)

What I see: every tag becomes a space, so `<p>Set <code>max-age</code>, then ...</p>` reads as `set max-age , then ...`. The quote `Set max-age, then the response is cached for that many seconds.` is reported as not on the page. I confirmed this with the module.

The risk: this fails closed, so no false citation gets through. But the SKILL tells each research agent to "fix or drop its own entries until they pass". Documentation sites, the most likely trusted domains, wrap identifiers in `<code>`, `<a>` and `<em>` constantly. Good sources get dropped, or an agent burns turns hunting for a quote that avoids every inline element.

Suggested fix: in `norm`, after collapsing whitespace, also remove a space before closing punctuation and after an opening bracket, e.g. `re.sub(r"\s+([,.;:!?)\]])", r"\1", s)` and `re.sub(r"([(\[])\s+", r"\1", s)`. Both the quote and the page go through `norm`, so the comparison stays symmetric. Add `<code>x</code>,` to the folding case in `run.sh`.

**4. `verify --id N` with an ID the ledger lacks reports success**

Location: `research-ledger.sh:262` and `:272`

What I see: `verify <book> --id 42` on the fixture prints `verified the named entry: 0 failing` and exits 0.

The risk: `updatebook/SKILL.md:111` tells the operator flow to "run `research-ledger.sh verify --id <id>` until it passes". A mistyped ID passes on the first run and the new entry is never fetched. Nothing in `/updatebook` re-verifies before the edit is done.

Suggested fix: before the loop, `unknown = ids - {e["id"] for e in doc["entries"]}`. If it is not empty, print `FAIL  no entry web N` for each and return 1.

**5. The parallel research path cannot run the verify step it prescribes**

Location: `createbook/SKILL.md:355`

What I see: each agent "runs `research-ledger.sh verify` and fixes or drops its own entries until they pass". The same paragraph then says that agents running at once each write their own ledger file and merge into `research/ledger.json` afterwards. `verify` only ever reads `research/ledger.json`.

The risk: an agent following the parallel option has nothing it can verify until after the merge, so the "fix your own entries" loop cannot happen where the procedure puts it. The merge then becomes the first point anyone learns that an agent's entries fail.

Suggested fix: pick one. Either let the tool take the file (`research-ledger.sh verify <book> --file research/ledger-ch1-4.json`), or rewrite the paragraph so the orchestrator verifies after merging and hands failures back to the agent that wrote them. The second is a doc-only change.

### Suggestions

**6. URL extraction is not markdown-aware at the edges.**
- `check-provenance.sh:362`. A ledger URL containing parentheses, such as `.../wiki/Cache_(computing)`, is cut at the `)`. That gives two failures, "links ...Cache_(computing" and "never links its URL".
- A bare URL in bold, `**https://...**`, is read with the `**` attached.
- An inline code URL keeps its trailing backtick (seen in finding 1).

At minimum, add `*_!?` to the `rstrip` set. Prefer pulling markdown link targets, `](...)` with balanced parentheses, and autolinks `<...>` explicitly, and treating bare URLs as the fallback. Otherwise, document that a ledger URL with parentheses is stored percent-encoded.

**7. Trusted containment can be bypassed with userinfo or dot segments.**
- `research-ledger.sh:111-125`. `https://docs.example.org:pw@evil.test/x` is accepted for `docs.example.org`, because the host is cut at the first `:`.
- `https://github.com/example-org/../other/x` is accepted for `github.com/example-org`.

A model is unlikely to write either, so this is hardening and not a live defect. Parsing with `urllib.parse.urlsplit` and using `.hostname`, and refusing `..` path segments and userinfo outright, closes both and also fixes the explicit-port false failure (`github.com:443/example-org`).

**8. A cited entry "linked" only inside a code fence counts as linked.** This is the mirror image of finding 1, and fixed by the same change.

**9. `verify` does not check where a redirect lands.** `urlopen` follows redirects. A trusted URL that redirects off-list verifies against the off-list page. Comparing `resp.geturl()` against `trusted()` in `fetch` is a few lines.

**10. A wording leftover.** `createbook/SKILL.md:355` says "every checker ... read the book folder one level deep, so `research/` is invisible to them". `check-provenance.sh` now reads `research/ledger.json`. Narrow it to "never bound, and no checker reads the notes".

**11. The `run.sh` header overstates one case.** It says entry 3's quote is found "whatever its HTML, entities and typographic quotes". `research/pages/3.html` carries no entities or typographic quotes, though the separate `visible_text` case covers them. Either add an `&rsquo;` to the saved page or soften the header.

**12. Handbook profiles never print the URL in full.** `chapter-prose.md:211` sends a handbook chapter's outside source to the prose link and the Draws on row, and the Suggested reading list stays URL-free. The plan's "each chapter ends with its sources, the URL printed once as link text" is met under `primer` only. That may be intended, since research is optional off `primer`. If so, one sentence saying so would settle it.

### Deferred to follow-up

These do not affect the verdict.

- None. Every finding above is in code or text this PR authored.

## Questions

1. Is it intended that a primer cannot show a context command containing a URL (finding 1)? If the intent really is "no URL anywhere, code included", the rules need to say so, and the provenance and primer fixtures need to show how a chapter presents such a command. I assume not, given "Command output ... copied from the context".
2. Should a quotation inside a unit marked only `web <id>` be checked against that entry's `quotes`? Today `quotations checked 0` for such a unit, which is consistent with the plan but leaves an easy check unused.

## Verdict

VERDICT: REQUEST_CHANGES

Restrict the chapter URL sweep to prose: skip fences and code spans, say so in the rules, and add a fixture case. Fixing findings 2 to 5 at the same time is cheap.
