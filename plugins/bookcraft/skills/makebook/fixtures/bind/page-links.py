"""Check that a bound PDF's listings link to the pages they print.

    page-links.py <book.pdf> <listing>...

A listing is Contents, Figures or Index, found as the page whose first line is
its title. Prints one line per listing, and exits 1 when a listing named is
missing or any of its links is wrong.

- Contents and Figures: the page numbers the rows print, read top to bottom out
  of `pdftotext -layout`, must equal the pages their links open, sorted by
  height on the page. That also proves every row has a link. Only the
  listing's first page is read, which holds for the fixture books.
- Index: every link from the index's first page to the end of the book must open
  the page whose number is printed under the link. That is read by cropping
  `pdftotext` to the link's own rectangle. The line also prints the count, so a
  caller can hold it to the bind's own count of page references.

Named and explicit destinations both resolve. Shared by bind/run.sh and
save-scripts/run.sh. The second exists because only that book carries
attachments, so only its PDF goes through attach_scripts' rewrite as well as
build_outline's and link_pages'.
"""
import re
import subprocess
import sys

from pypdf import PdfReader

pdf, wanted = sys.argv[1], sys.argv[2:]
reader = PdfReader(pdf)
named = reader.named_destinations
by_ref = {p.indirect_reference.idnum: i for i, p in enumerate(reader.pages)}


def opens(annot):
    dest = annot.get("/Dest")
    if dest is None and annot.get("/A") is not None:
        dest = annot["/A"].get_object().get("/D")
    if dest is None:
        return None
    if isinstance(dest, str):
        found = named.get(dest) or named.get("/" + dest.lstrip("/"))
        return reader.get_destination_page_number(found) + 1 if found else None
    page = by_ref.get(dest[0].idnum)
    return page + 1 if page is not None else None


def text(i, *crop):
    box = []
    if crop:
        box = ["-x", str(crop[0]), "-y", str(crop[1]), "-W", str(crop[2]),
               "-H", str(crop[3])]
    return subprocess.run(
        ["pdftotext", "-f", str(i + 1), "-l", str(i + 1), "-layout", *box, pdf,
         "-"], capture_output=True, text=True, check=True).stdout


def links(page):
    found = [a.get_object() for a in page.get("/Annots") or []]
    return [a for a in found if a.get("/Subtype") == "/Link"
            and (a.get("/Dest") is not None or "/D" in (a.get("/A") or {}))]


seen, bad = [], 0
for i, page in enumerate(reader.pages):
    lines = [ln for ln in text(i).splitlines() if ln.strip()]
    if not lines or lines[0].strip() not in wanted:
        continue
    title = lines[0].strip()
    seen.append(title)
    if title == "Index":
        checked, wrong = 0, []
        for j in range(i, len(reader.pages)):
            top = float(reader.pages[j].mediabox.top)
            for a in links(reader.pages[j]):
                x0, y0, x1, y1 = (float(v) for v in a["/Rect"])
                under = text(j, int(x0) - 1, int(top - y1) - 1,
                             int(x1 - x0) + 2, int(y1 - y0) + 2).strip()
                m = re.search(r"(\d+)\D*$", under)
                checked += 1
                if not m or int(m.group(1)) != opens(a):
                    wrong.append(f"page {j + 1}: {under!r} opens {opens(a)}")
        ok = checked > 0 and not wrong
        bad += not ok
        print(f"{'ok  ' if ok else 'FAIL'} page {i + 1}, Index: {checked} links, "
              f"{len(wrong)} opening a page other than the one printed under "
              f"them {wrong[:4]}")
        continue
    # A row's number sits across the leader from its title, so it follows a run
    # of spaces; a wrapped caption ending in "week 3" does not. The last line is
    # the running footer, whose number is this page's own.
    printed = [int(m.group(1)) for ln in lines[1:-1]
               if (m := re.search(r"\s{2,}(\d+)\s*$", ln))]
    rows = sorted(links(page), key=lambda a: -float(a["/Rect"][3]))
    opened = [opens(a) for a in rows]
    ok = bool(printed) and printed == opened
    bad += not ok
    print(f"{'ok  ' if ok else 'FAIL'} page {i + 1}, {title}: rows print "
          f"{printed}, their links open {opened}")
for title in wanted:
    if title not in seen:
        bad += 1
        print(f"FAIL no page opens on {title}")
sys.exit(1 if bad else 0)
