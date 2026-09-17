---
name: qve
description: Quick visual explain — explain a topic as a single self-contained HTML page with diagrams, then open it in the default browser. The visual sibling of /explain:qe. Use when a concept is structural, sequential, or quantitative enough that prose alone is the wrong medium — e.g. "/explain:qve how does the gallery build pipeline work", "/explain:qve raft consensus".
argument-hint: <topic or question>
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
model: opus
---

# /explain:qve — quick visual explain

Explain the following as a single visual HTML page, then open it: $ARGUMENTS

If no topic was provided, ask the user what they'd like explained and stop.

## Relationship to `/explain:qe`

`/explain:qe` is the same job in ≤250 words of prose. `/explain:qve` is for when the answer's **shape** is the point — a flow, a state machine, a sequence across services, a comparison, a distribution. Same audience, same honesty bar; different medium.

**If the topic has no shape worth drawing, say so and fall back to `/explain:qe`.** A page of prose in a dark wrapper with one decorative box-and-arrow diagram is worse than a good paragraph. Bail out loudly rather than manufacture visuals.

## Audience and voice

Inherit `/explain:qe`'s rules (`${CLAUDE_PLUGIN_ROOT}/skills/qe/SKILL.md` — both skills ship in this plugin) — they still apply:

- **Audience:** a mid-level software engineer. Assume fluency in general programming, data structures, HTTP, databases, git, testing. Do **not** assume familiarity with the specific technology, pattern, protocol, or subsystem — nor with this repo's internals.
- **Jargon:** general engineering vocabulary needs no definition; define domain-specific terms the moment they appear, in one short clause.
- **Structure:** lead with the core idea, then the mechanism (how it actually works), then why it exists / what it buys you.
- **No padding:** no preamble, no summary recap, no "would you like me to elaborate?", no suggested next questions.
- **Accuracy over completeness:** simplifying is fine; saying something false is not. Note a sacrificed precision in a short clause ("roughly speaking"). Flag a misconception only when the reader is likely to hold it.

## Length

**The topic's complexity sets the length.** There is no word cap — but there is no license to pad either. Every paragraph, diagram, and card must carry something the reader would otherwise not know. Never lengthen a page to look thorough; never truncate a genuine insight to look brisk. A simple topic that lands in 200 words and one diagram is a *successful* `/explain:qve`, not a lazy one.

Practical shape: 2-5 numbered sections, 1-4 visuals. Beyond that, ask whether the topic actually wants a full project debrief instead — a `debrief` skill, where one is installed, is the better medium for that.

## Grounding

- **Repo topics** (a file, subsystem, ticket, or "our X"): read the actual code first and cite `file:symbol` in the page. Never diagram aspirational architecture — diagram only what the code evidences. `ASSERTIONS.md`, `continuity/`, and `changelog/<branch-slug>/` folders are fair game for history and invariants, but the code is source of truth.
- **General topics** (a pattern, protocol, algorithm): no repo reading needed. If a claim is load-bearing and you're unsure, verify or hedge — the evidence bar for a rendered page is the same as for a chat reply — state what you verified, mark what you inferred, and never let a diagram assert something the source does not. Where the host repo documents its own evidence rules, those apply here too. Do not invent numbers for a chart; label illustrative figures as schematic.

## Procedure

### 1. Decide the visual plan (before writing any HTML)

Name, in one line each, the visuals the page will carry and what each one shows that prose cannot. Then pick a renderer per visual:

| The thing you're showing | Renderer |
|---|---|
| Architecture, dataflow, dependency, decision tree, pipeline | Mermaid `flowchart` |
| An interaction across participants over time | Mermaid `sequenceDiagram` |
| Lifecycle / status transitions | Mermaid `stateDiagram-v2` |
| Table relationships | Mermaid `erDiagram` |
| Magnitudes, ratios, before/after quantities | `.bars` CSS component (no library) |
| Ordered mechanism, N discrete steps | `ol.steps` component |
| The 2-4 ideas the reader must hold | `.cards` component |
| Naive vs. correct, before vs. after code | `.compare` component |
| Anything geometric, spatial, or bespoke | Hand-authored inline `<svg>` in `.fig-svg` |

**Load the `dataviz` skill before writing any real chart** (anything with axes, series, or a palette choice) — it owns the chart-type heuristic and color rules. The `.bars` component is fine without it for simple magnitude comparisons.

Drop any visual you can't justify in that one line. Three good visuals beat six filler ones.

### 2. Resolve output path

```bash
OUT_DIR="$HOME/.claude/qve"
mkdir -p "$OUT_DIR"

# Prune first: this directory is scratch, and nothing else cleans it.
find "$OUT_DIR" -maxdepth 1 -type f \( -name '*.html' -o -name '*.png' \) -mtime +7 -delete

SLUG="<kebab-slug-of-topic>"          # ≤5 words, e.g. transactional-outbox
STAMP="$(date '+%Y%m%d-%H%M%S')"
HTML="$OUT_DIR/${SLUG}-${STAMP}.html"
echo "$HTML"
```

The timestamp means repeat runs never clobber. These files are **disposable** — the directory is a scratch area, not an archive. If the user asks for it somewhere specific (or says "put it in the changelog folder"), honor that instead.

**The prune is what makes "disposable" true — run it every time, before writing.** Deleting at the *start* of a run (never at the end) guarantees the page you just opened is never yanked out from under the browser, and `-mtime +7` can't touch anything from today. Say nothing about it in the report unless it removed something worth mentioning.

> Don't delegate this to the OS. On macOS there is **no `/etc/periodic`** (verified on Darwin 25.5), `com.apple.tmp_cleaner` declares no retention policy in its plist, and `/private/tmp` accumulates files older than a week — so `/tmp` is not a reliable cleaner. `$TMPDIR` *is* swept (`com.apple.bsd.dirhelper`, `CLEAN_FILES_OLDER_THAN_DAYS=3`), but its `/var/folders/…` path is opaque and unguessable, which defeats reopening or sharing a page. A stable directory plus an explicit prune beats both.

### 3. Write the page

Copy `${CLAUDE_PLUGIN_ROOT}/skills/qve/references/page-template.html` and fill it in. The template is dark-mode only, responsive, and already wires up Mermaid 11 + the explainer components. **Do not restyle it** — replace the `{{PLACEHOLDERS}}`, use the documented components, delete the component-reference comment block when done.

Placeholders: `{{TOPIC}}`, `{{ONE_SENTENCE_THESIS}}` (the whole answer in one sentence — if you can't write it, you don't understand the topic yet), `{{TAG}}` (one or two `<li>` chips, e.g. the stack or `pages/gallery`), `{{SECTION_TITLE}}` / `{{CONTENT}}`, `{{DATE}}`, `{{SOURCE_NOTE}}` (for repo topics: " Grounded in `<path>` @ `<short-sha>`." — else empty).

### 4. Mermaid mechanics (the failure modes that actually bite)

- Emit each diagram as `<pre class="mermaid">…</pre>` inside a `<figure>`, with a `<figcaption>` saying **what the reader should notice** — not a restatement of the title.
- **Quote any label containing parentheses, brackets, colons, or slashes**: `A["retrieve() → scorer"]`, not `A[retrieve() → scorer]`. Unquoted punctuation is the most common parse failure.
- **No `;` in note text** — it's a statement separator. Use a comma or `<br/>`.
- Keep node text short; the explanation belongs in the caption.
- The diagram source must be **flush-left inside the `<pre>`** — leading indentation from your HTML formatting breaks the parse.
- 8-14 nodes is the readable ceiling for a flowchart. Past that, split into two diagrams or raise the abstraction level.

Mermaid renders from the jsdelivr CDN at view time, so the page needs network when opened. If the CDN is unreachable the raw diagram source stays visible — degraded, not broken. For a guaranteed-offline page, render with `dot -Tsvg` instead (Graphviz must be on PATH) and inline the SVG into `.fig-svg`. If a `diagram-dot` skill is installed it owns the style rules for that path; without one the `dot` invocation still works.

### 5. Verify, then open

```bash
test -s "$HTML" && echo "written: $(wc -c < "$HTML") bytes"
open "$HTML"                          # macOS default browser
```

`open` is the last step — the page is the deliverable, so put it on screen without asking.

**Verify the diagrams actually render.** A Mermaid parse error shows as a red error box in the browser, which `open` will not tell you about. If the Claude-in-Chrome extension is connected, open the file there and screenshot it — that is the primary path and needs no setup. Otherwise drive Playwright headless against the `file://` URL and check for `.mermaid svg`. Playwright does not ship with this plugin; if it is not already available, one-time setup outside the plugin directory provides it:

```bash
VENV="${XDG_CACHE_HOME:-$HOME/.cache}/explain/venv"
python3 -m venv "$VENV"
"$VENV/bin/pip" install playwright
"$VENV/bin/python" -m playwright install chromium   # skip if ~/Library/Caches/ms-playwright/ is populated
```

The venv sits at a stable per-user path deliberately: `${CLAUDE_PLUGIN_ROOT}` is version-scoped and is discarded on every plugin update, so anything installed under it would be rebuilt each release. If neither is available, say plainly that rendering was not verified rather than implying it was.

> **Detect failure correctly.** A rendered diagram means one `svg` per `pre.mermaid`, with a node count matching your source. Do **not** grep the container's `innerHTML` for `error-icon` — Mermaid injects a stylesheet into every SVG that defines `.error-icon`, so that string is present on healthy diagrams and yields a guaranteed false positive (observed 2026-08-16). Grep the rendered text for `Syntax error`, or just compare node counts.

> **Layout gotcha:** a mostly-linear `flowchart TB` renders tall and narrow, leaving the wide container mostly empty. Use `LR` for pipelines and reserve `TB` for genuinely branching trees.

**Verification artifacts go to the session scratchpad, never next to the page.** A full-page screenshot runs 30-50× the size of the HTML it checks (observed: 476KB PNG beside a 15KB page). The screenshot is evidence that the work is correct, not the deliverable — write it, and any ad-hoc Playwright script, under the session scratchpad directory. `$OUT_DIR` holds pages only.

### 6. Report

Print the absolute path on its own line and a one-line description of what's on the page. **Do not restate the explanation in chat** — the page is the answer; duplicating it in prose defeats the point.

```
$HOME/.claude/qve/transactional-outbox-20260816-142301.html
Sequence diagram of the dual-write failure, then the outbox fix; 3 sections.
```

## Notes

- One page per invocation, fully self-contained (single file, no sidecar assets). Base64-inline any raster image rather than writing a second file.
- Don't fabricate data. Quantities in a chart come from a cited source (file, query, command output) or the figure is labeled illustrative.
- `securityLevel: 'strict'` in the template blocks HTML in Mermaid labels — that's deliberate; don't loosen it to sneak in markup.
