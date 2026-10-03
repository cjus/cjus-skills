"""Check that every row of a bound PDF's listings links to the page it prints.

    contents-links.py <book.pdf> <listing>...

A listing is a page whose first line is its title, Contents or Figures. For
each one named, the page numbers its rows print, read top to bottom out of
`pdftotext -layout`, must equal the pages their link annotations open, sorted
by height on the page. Named and explicit destinations both resolve. Exits 1
when a listing named is missing, has no rows, or any row's link opens another
page, and prints one line per listing either way.

Shared by bind/run.sh and save-scripts/run.sh. The second exists because only
that book carries attachments, so only its PDF goes through attach_scripts'
rewrite as well as build_outline's.
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


seen, bad = [], 0
for i, page in enumerate(reader.pages):
    text = subprocess.run(
        ["pdftotext", "-f", str(i + 1), "-l", str(i + 1), "-layout", pdf, "-"],
        capture_output=True, text=True, check=True).stdout
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if not lines or lines[0].strip() not in wanted:
        continue
    title = lines[0].strip()
    seen.append(title)
    # A row's number sits across the leader from its title, so it follows a run
    # of spaces; a wrapped caption ending in "week 3" does not. The last line is
    # the running footer, whose number is this page's own.
    printed = [int(m.group(1)) for ln in lines[1:-1]
               if (m := re.search(r"\s{2,}(\d+)\s*$", ln))]
    links = [a.get_object() for a in page.get("/Annots") or []]
    links = sorted((a for a in links if a.get("/Subtype") == "/Link"),
                   key=lambda a: -float(a["/Rect"][3]))
    opened = [opens(a) for a in links]
    ok = bool(printed) and printed == opened
    bad += not ok
    print(f"{'ok  ' if ok else 'FAIL'} page {i + 1}, {title}: rows print "
          f"{printed}, their links open {opened}")
for title in wanted:
    if title not in seen:
        bad += 1
        print(f"FAIL no page opens on {title}")
sys.exit(1 if bad else 0)
