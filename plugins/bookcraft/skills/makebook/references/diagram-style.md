# Diagrams for makebook

Figures in a makebook PDF are **hand-authored SVG**. Nothing renders them but
Chromium, which the builder already runs, so a book with diagrams needs no
diagram toolchain: no graphviz binary, no mermaid bundle, no network access at
build time. That is what keeps the skill self-contained and shareable.

## Why hand-authored, and not a layout engine

| Approach | Why not here |
|---|---|
| Graphviz DOT | Places nodes to satisfy a graph layout, not to make a point. Cannot express a banner, a callout, an inset, or a side-by-side comparison. Needs the `dot` binary. |
| Mermaid | Same auto-layout limit, plus a multi-megabyte JS bundle or a CDN fetch during the build. |
| Raster (PNG, screenshots) | Fixed resolution. Fuzzy in print, and unreadable when a reader zooms. The builder accepts one and measures what it can, but it cannot measure the type inside it. See **Raster figures** below. |
| **Hand-authored SVG** | Vector, so sharp at any zoom and in print. Full control of composition. Zero dependencies. |

A teaching figure earns its page by composing an argument: the claim, the case
that breaks it, and the label that names what changed. A layout engine cannot
do that, which is why every course diagram this style came from is authored
by hand.

Use a layout engine when you want a *topology* dump and the specific placement
does not matter. Use these rules when the figure is part of an explanation.

## The sizing rule, which is the one that bites

An SVG scales to the width of its container, so a font size written in the SVG
is **not** the size that reaches the page. The rendered size is:

```
rendered_pt = svg_font_px × (measure_pt ÷ viewBox_width)
```

`measure_pt` is **432** for a normal figure (6.0in text column) and **504** for
a wide one (7.0in). Body text in the book is 11.8pt, and **8pt is the floor for
a figure label**. That is one number, not a recommendation sitting above a
looser tool threshold: `MIN_LEGIBLE_PT` in `build-book.py` is the same 8.0, so
what this file asks for is what the builder fails you on.

**"Smallest that clears 8pt" is the column to design against**, because it is
where a figure usually goes wrong: the size looks fine in the source and lands
under the floor only after the SVG scales to the column. It is the true minimum
in half-pixel steps, so anything below it fails the build.

| viewBox width | Multiplier (normal) | 14px reads as | Smallest that clears 8pt | For ~10pt, write |
|---|---|---|---|---|
| 640 | 0.675 | 9.5pt | 12px | 15px |
| 720 | 0.600 | 8.4pt | 13.5px | 17px |
| 900 | 0.480 | 6.7pt | 17px | 21px |
| 1200 | 0.360 | 5.0pt | 22.5px | 28px |
| 1360 | 0.318 | 4.5pt | 25.5px | 31px |

**Design at a viewBox width of 640 to 900.** Slide-sized art (1280 and up) with
14px labels renders around 4.5pt in a book column, which is unreadable. Diagrams
built for a deck usually need their type scaled up before they work in print.

The builder measures this for you. It reports every figure whose smallest label
will print below 8pt, with the measured size and the viewBox width:

```
  12 figure(s) will print text below 8pt and need their type scaled up:
    Figure 1.1: smallest label 3.2pt (viewBox 1340 wide) - The seven-stage ...
```

Widening the figure does not rescue art at 3pt; going from the 6.0in column to
the 7.0in bleed buys 17 percent, and 3.2pt becomes 3.7pt. The type has to be
redesigned against a smaller viewBox. Treat the warning as work to do, not as
something to raise the threshold past.

## Wide figures

A figure whose viewBox is at least **2.6 times wider than it is tall** is
detected automatically and given the wider measure: it bleeds 0.5in into each
page margin, while its caption stays aligned to the text column. Nothing needs
to be declared.

The page area is 7.1in wide and Chromium clips print content at that boundary,
so a figure cannot bleed further than this whatever margins it is given.

Height is capped at 6.9in (6.4in for wide figures) so a tall diagram never
pushes its own caption onto the next page.

## Raster figures

A `.png`, `.jpg`, `.gif` or `.webp` referenced as a figure binds and is
packaged into the EPUB. It is not the recommended form, and the reason is
narrower than "rasters are fuzzy": **the builder cannot check a raster's type,
and the build says so rather than passing it silently.**

| What the builder reads | From | Reported as |
|---|---|---|
| Aspect, so a wide raster takes the bleed measure | The pixel dimensions | Nothing; it just applies, as it does for a viewBox |
| Effective print resolution | Pixel width ÷ the measure it prints at | A warning under **150 DPI** |
| The size of the text inside it | **Nothing. It cannot.** | Listed as *not checked* against the 8pt floor |

The third row is the one to understand. `MIN_LEGIBLE_PT` works by reading the
`font-size` declarations in an SVG's markup and scaling them to the column. A
raster declares none: its glyphs are pixels, so recovering a type size needs
OCR, and there is no image library in this skill at all.

**Resolution and legibility are independent, and a passing DPI number is not a
legibility pass.** A finely sampled render of small type clears any DPI floor
and still prints as a smudge. That is not hypothetical: a faithful raster
render of a 16pt slide puts its body text at **7.20pt** in the 6.0in column,
under the floor, at whatever resolution it was exported at.

So the build prints two separate blocks:

```
  1 raster figure(s) print below 150 DPI and will look soft on paper:
    Figure 1.2: 50 DPI (300px wide, needs 900px) - A small raster, far below ...
  3 raster figure(s) were NOT checked against the 8pt legibility floor:
    Figure 1.2: 300x200px - A small raster, far below the resolution floor
```

Treat the second block as a list of figures **you** have to check, by opening
the built PDF and reading them. Redrawing as SVG is the way to hand that job
back to the builder.

## Required scaffolding

Every figure carries these, matching the 32 diagrams this style was derived from:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 520" width="900" height="520"
     role="img" aria-labelledby="xx-t xx-d">
  <title id="xx-t">One sentence naming what the figure shows</title>
  <desc id="xx-d">A few sentences describing the content for someone who cannot
    see it. Say what the parts are and what the figure demonstrates.</desc>
  ...
</svg>
```

- **`<title>` becomes the printed caption** and the entry in the book's list of
  figures. Write it as a claim, not a label: "A foreign key holds only where the
  connection asked for it", not "Foreign keys".
- **`<desc>`** is the accessible description. It never prints.
- Give every figure's ids a unique prefix (`xx-`), since several inline SVGs
  share one HTML document.
- Set a white background rect first: `<rect width="900" height="520" fill="#FFFFFF"/>`.

## Palette

Counted from the committed diagrams, so a new figure sits beside the old ones.

The **Grey** column is where each colour lands once the colour is gone: a
16-level scale, which is what a common e-ink panel renders and roughly what a
monochrome printer resolves. Two roles at the same grey are the same mark to
that reader. See **Colour on an e-ink screen** below.

| Role | Colour | Grey (of 16) |
|---|---|---|
| Ink, primary text | `#1F2937` | 2.5 |
| Secondary text | `#4B5563` | 5.2 |
| Muted text, arrowheads | `#6B7280` | 7.1 |
| Hairlines, borders | `#D1D5DB` | 13.3 |
| Panel tint | `#F9FAFB`, `#F3F4F6` | 15.7, 15.3 |
| Accent blue, structure and flow | `#2F5FA0` (fill `#EBF0F6`, `#BCCFEC`) | 5.5 (15.0, 12.8) |
| Accent amber, the thing being highlighted | `#C08A1E` (fill `#F7D9A5`) | 8.9 (13.8) |
| Red, the failure or the wrong answer | `#B4261E` | 5.0 |
| Page | `#FFFFFF` | 16.0 |

Use red only for the thing that is wrong. If two figures on facing pages both
use amber for emphasis, they are competing; pick one.

## Colour on an e-ink screen

Every book this skill binds ships as an EPUB as well as a PDF, and an EPUB is
usually read on a greyscale device. A figure that separates two things by hue
alone separates nothing there. The same is true of the PDF the moment anyone
prints it on a monochrome printer, which is how a bound course reader is
normally produced.

**This palette has real collapses in it.** Measured by converting each colour
to its Rec.601 grey and comparing on the 16-level scale above:

| Pair | Apart | On a grey screen |
|---|---|---|
| Accent blue vs Red | 0.5 steps | **the same mark** |
| Accent blue vs Secondary text | 0.3 steps | **the same mark** |
| Red vs Secondary text | 0.3 steps | **the same mark** |
| Blue fill `#BCCFEC` vs Hairlines | 0.5 steps | **the same mark** |
| Panel `#F3F4F6` vs Blue fill `#EBF0F6` | 0.3 steps | **the same mark** |
| Accent amber vs Muted text | 1.8 steps | tight, usable for fills, not for adjacent strokes |
| Amber fill vs Blue fill `#EBF0F6` | 1.2 steps | tight, only with a border to separate them |

The first row is the expensive one. Blue means structure and red means the
failure, so a figure that marks the wrong answer in red and the right path in
blue is exactly the figure that stops making its point. Nothing about it looks
broken on the screen it was drawn on.

**The rule: never let hue be the only difference between two marks that mean
different things.** Give each one a second signal that survives the conversion.

- **A written label** is the strongest and the cheapest. If the reader can tell
  the two apart by reading, the colour is decoration and it can collapse safely.
- **A dash pattern** on strokes: `stroke-dasharray="6 4"` against a solid one.
- **A shape difference**: a square node against a round one, a doubled border,
  an arrowhead that differs.
- **Separation in grey**, when colour must carry it alone: keep at least **2
  steps** between the two greys in the table. Blue at 5.5 against amber at 8.9
  is 3.4 steps and works; blue against red is 0.5 and does not.
- **A hairline around every tint.** The five tints all sit between 12.8 and
  15.7, so any two of them touching become one shape. A `#D1D5DB` border keeps
  the boundary visible.

**Check it without a device.** Convert one figure and look:

```bash
sips -s format png --matchTo /System/Library/ColorSync/Profiles/Generic\ Gray\ Profile.icc \
  diagrams/thing.png --out /tmp/grey.png
```

For an SVG, the faster check is to open it in a browser with
`filter: grayscale(1)` on the root element, or simply to ask of each pair of
coloured marks: *if these were both mid-grey, would the figure still say what
it says?* If the answer is no, add a label.

**Red keeps its meaning through a label, not through being red.** Mark the
failure with the word, an X, or a broken stroke, and let the colour be the
thing a sighted reader on a colour screen gets for free. This is the same rule
accessibility asks for, and the e-ink case is what makes it bite here.

## Type

```css
.hd  { font: 700 15px "Helvetica Neue", Helvetica, Arial, sans-serif; letter-spacing: .1em; }
.lbl { font: 400 15px "Helvetica Neue", Helvetica, Arial, sans-serif; }
.cd  { font: 400 15px "SF Mono", Menlo, Consolas, monospace; }
.note{ font: italic 400 14px "Helvetica Neue", Helvetica, Arial, sans-serif; }
```

Sizes above assume a 640-wide viewBox. Scale them by the table in **The sizing
rule** for any other width. Sans for labels, mono for anything that is code,
italic for the aside that names what just happened.

**The builder rewrites each inline figure's `<style>` to be scoped to that
figure**, so two figures may both define `.lbl` differently without colliding.
Referenced figures are isolated by the browser anyway.

## Authoring forms

Three, all equivalent to the builder.

1. **Fenced block** (recommended for inline art) — tolerates blank lines:

   ~~~
   ```svg
   <svg ...>...</svg>
   ```
   ~~~

2. **Raw element** — must stay on contiguous lines, or the markdown parser
   splits it across paragraphs.

3. **File reference** — `![Caption](diagrams/thing.svg)`. The alt text is the
   caption; leave it empty and the file's own `<title>` is used. The diagrams
   folder must travel with the markdown.

Inline keeps a chapter to one file. Referenced keeps the prose readable and
lets one diagram serve several documents. Prefer referenced when a diagram is
long enough to bury the text around it.

Only a **standalone** image becomes a figure. An image inside a sentence stays
inline and is not numbered.

## Checklist

- [ ] viewBox width 640–900, and every label at least 8pt once scaled
- [ ] `role="img"`, `aria-labelledby`, `<title>`, `<desc>` all present
- [ ] `<title>` reads as a claim and works as a caption
- [ ] ids prefixed uniquely
- [ ] white background rect
- [ ] palette drawn from the table above, red reserved for the failure
- [ ] no two marks that mean different things separated by hue alone: each pair
      carries a label, a dash pattern, a shape, or 2 grey steps between them
- [ ] every tint bordered, since all five sit within 3 grey steps of each other
- [ ] still says what it says in grey, checked rather than assumed
- [ ] no external references: no `<image href>` to a URL, no webfont
- [ ] renders correctly at 6.0in wide, checked in the built PDF rather than assumed
