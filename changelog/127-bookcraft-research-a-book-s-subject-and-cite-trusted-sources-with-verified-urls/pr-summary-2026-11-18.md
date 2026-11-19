# bookcraft: research a book's subject and cite trusted sources with verified URLs

## Overview

A primer has to explain its subject, so the model needs to research how each idea is best taught and to bring in general facts the context does not state. Until now bookcraft treated anything read online as `fill` and never stored a URL. This PR adds:

- a research stage before the outline;
- an order of authority: the context, then cited trusted sources, then the model's own knowledge;
- citations to outside pages whose URLs are verified, never recalled.

The core rule: **a URL reaches a book only once it was fetched and its quoted words were found on the page.** `research-ledger.sh verify` enforces it. `check-provenance.sh` then holds every chapter to it: every cited entry is linked, and every linked URL is in the ledger.

**This branch is stacked on the #128 branch** and its PR targets that branch, so it should merge after #128's PR, which in turn follows #130's.

## Key changes

- `skills/createbook/scripts/research-ledger.sh` (new): `check`, `verify`, `list`, with `--file` for a research agent's own ledger; the only definition of `research/ledger.json`. `verify` fails a page that redirects off the trusted list.
- `skills/createbook/scripts/check-provenance.sh`: resolves `web <id>`, reserves the word, and checks each chapter's marks against the links in its prose. A URL in a fenced block or code span is code and is not read.
- `skills/createbook/reference/primer.md`: § Where facts come from, § Citing outside sources, the closing section's outside-source line.
- `skills/createbook/reference/chapter-prose.md`: `web <id>` and ledger links allowed under every profile.
- `skills/createbook/SKILL.md`:
  - new § Research the subject;
  - the URL paragraphs rewritten;
  - gate, prompt item 8, step 7 and the reserved words updated.
- `skills/updatebook/SKILL.md`: a new outside fact needs a verified ledger entry first.
- `skills/createbook/fixtures/research` (new), with manifest rows and a `run.sh`.
- `scripts/test-fixtures.sh`: the ledger tool's executable bit is checked with the others.
- README, NOTES.md, plugin 1.19.0.

## Code examples

The ledger format, from `research-ledger.sh`'s docstring:

```json
{
  "format": 1,
  "trusted": [{"domain": "docs.example.org", "for": "the project's own documentation"}],
  "entries": [{
    "id": 1, "url": "https://docs.example.org/guide/caching", "title": "Caching",
    "publisher": "Example project documentation", "accessed": "2026-11-18",
    "chapters": [3], "takes": "what the book takes from the page",
    "quotes": ["a run of six to forty words copied exactly from the page"]
  }]
}
```

Trusted-domain containment, `research-ledger.sh`, on a parsed host and path:

```python
parts = urllib.parse.urlsplit(url)
host = (parts.hostname or "").lower()
...
dhost, _, dpath = d.partition("/")
if dpath:
    prefix = "/" + dpath.strip("/")
    if host == dhost and (path == prefix or path.startswith(prefix + "/")):
        return True
elif host == dhost or host.endswith("." + dhost):
    return True
```

The link check, `check-provenance.sh`, per chapter:

```python
for u in sorted(urls):
    if u in by_url:
        linked |= by_url[u]
    else:
        problem(f"{base}: links {u}, which is not in {ledger.FILE}; ...")
for wid in sorted(web_cited - linked):
    problem(f"{base}: a mark cites web {wid}, and the chapter never links its URL, ...")
```

## Plan alignment

Every checklist item in the ticket is done.

- **The blocked-site question the ticket left open:** the operator saves the page into `research/pages/` and names it in `page_file`, which `verify` reads and reports as an operator-supplied copy. Otherwise the source is dropped.
- **The recheck:** this is `verify` run again later, not a separate command, since it is the same test.
- **An off-list domain** fails in `research-ledger.sh check`, not in `check-provenance.sh`. A ledger that fails its own check makes `check-provenance.sh` report it and skip the web resolution, the same way it treats an invalid `assertions.json`.

Not here, by design:

- No script checks that a chapter's sentence says what its ledger quote supports. That is the paraphrase gap `/check-claims` exists for, as with context sources.
- The research stage is required for a primer and optional for the handbook profiles.

## Testing

- `plugins/bookcraft/scripts/test-fixtures.sh --strict`: 26 passed, 0 failed, 0 skipped.
- `fixtures/research` under `check-book.sh`: passes as a primer.
- `fixtures/research` under `check-provenance.sh`: exits 1 with exactly three failures:
  - a mark citing `web 9`, which the ledger lacks;
  - a link to a page not in the ledger;
  - `web 2` cited and never linked.

  Chapter 1 draws none, though it carries URLs in a code span and a fenced block, and the census reads `web 4`.
- `fixtures/research/run.sh` covers:
  - `check` passing the fixture's ledger, and failing nine malformed copies, each with its message;
  - `verify --id 3` finding the quote in the saved page, failing a quote the page does not carry, and failing a page too short to search;
  - thirteen trusted-domain cases, including look-alikes by subdomain suffix, query, fragment, backslash and `..` that must be refused;
  - a plain-string trusted list, a user name before the host, an unknown `--id`, an agent's own ledger through `--file`, and a `--file` path out of the book;
  - a quote whose page had an inline tag before a comma;
  - folding of entities and typographic marks.
- No fixture fetches anything, so CI never depends on a remote site.

## Impact assessment

Seventeen files, about 750 lines added and 23 removed, before this plan folder. No new dependency: `verify` uses Python's standard library.

- An existing book without a ledger is unaffected unless a chapter carries a URL, which the old rules already banned. Such a URL now fails `check-provenance.sh`.
- `web` joins `assertion` as a reserved word for source keys and unsourced labels.

## Deferred work

None.
