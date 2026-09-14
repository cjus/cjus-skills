#!/usr/bin/env bash
#
# Structural check for a /createbook folder.
#
# Checks only what is mechanically checkable: filenames, ordering, the H1 that
# /makebook reads, the H2 per part, the markdown a chapter still may not carry,
# and the [chapter-paragraph] tags. Chapter length is reported and never failed,
# because the spec sets none. It says nothing about whether the prose is any
# good or the facts are right.
#
# The prose rules it enforces are written in ../reference/chapter-prose.md and
# cited below by rule name rather than by line, so that editing the spec does
# not silently repoint every citation into it. At runtime it reads nothing but
# the book folder given to it; the build-book.py citations below say where a
# format constraint comes from, and are not files this script opens.
#
# Usage: check-book.sh [--require-tags | --no-tags] <book-folder>
# Exits 0 when everything passes, 1 on any failure.

set -uo pipefail
export LC_ALL=C

require_tags=0
no_tags=0
dir=""
for arg in "$@"; do
  case "$arg" in
    --require-tags) require_tags=1 ;;
    --no-tags) no_tags=1 ;;
    -*) echo "error: unknown option: $arg" >&2; exit 2 ;;
    *)
      if [ -n "$dir" ]; then
        echo "error: more than one folder given" >&2
        exit 2
      fi
      dir="$arg"
      ;;
  esac
done
if [ -z "$dir" ]; then
  echo "usage: check-book.sh [--require-tags | --no-tags] <book-folder>" >&2
  exit 2
fi
if [ "$require_tags" -eq 1 ] && [ "$no_tags" -eq 1 ]; then
  echo "error: --require-tags and --no-tags contradict each other" >&2
  exit 2
fi
if [ ! -d "$dir" ]; then
  echo "error: no such folder: $dir" >&2
  exit 2
fi

fail=0
problem() { echo "FAIL  $*"; fail=1; }

# A checker that can report OK without having run is worse than no checker, so
# every chapter that reaches the content checks increments `checked`, every
# chapter that does not is recorded in `unchecked` with its reason, and the two
# are reconciled against the chapter count before anything prints OK. This
# exists because an earlier version aborted its loop on an arithmetic error and
# exited 0 having examined nothing.
checked=0
unchecked=()

# A book is tagged or it is not, so the tag state is tracked across chapters and
# reconciled at the end. Auto-detection is what makes the rule self-enforcing:
# a book whose first chapter carries tags fails if a later one forgets them,
# with no flag to remember. --require-tags is for a book that must have them
# from the start, where every chapter forgetting would otherwise read as an
# untagged book and pass.
tagged_chapters=0
untagged_chapters=0

# Files /makebook will skip, so the checker skips them too: OUTLINE.md always,
# the glossary and the about-this-book front matter always because neither is a
# chapter, plus whatever book.json excludes.
skip="OUTLINE.md"
declared_tags=""
declared_gloss=""
declared_prov=""
declared_sugg=""
gloss_name="glossary.md"
fm_name="about-this-book.md"
# The trailing concept list, by the one name the spec fixes. It is matched
# exactly so that a chapter cannot quietly rename it and slip the check.
sugg_heading="## Suggested reading"
if [ -f "$dir/book.json" ] && command -v jq >/dev/null 2>&1; then
  extra=$(jq -r '(.exclude // [])[]' "$dir/book.json" 2>/dev/null)
  [ -n "$extra" ] && skip="$skip
$extra"
  declared_gloss=$(jq -r 'if has("glossary") then (.glossary | tostring) else "" end' "$dir/book.json" 2>/dev/null)
  # glossary_file renames the glossary, and /makebook skips whatever it names.
  # Reading the same key is what keeps the two tools looking at one file: hard
  # coding glossary.md here would grade a renamed glossary as a chapter, leave
  # its entries unchecked, and report the default name missing from a book that
  # has a glossary.
  gname=$(jq -r '.glossary_file // empty' "$dir/book.json" 2>/dev/null)
  [ -n "$gname" ] && gloss_name="$gname"
  # Front matter is skipped for exactly the glossary's reason, and the key is
  # read from the same place /makebook reads it so the two tools never disagree
  # about which file is a chapter.
  fmname=$(jq -r '.front_matter_file // empty' "$dir/book.json" 2>/dev/null)
  [ -n "$fmname" ] && fm_name="$fmname"
  # `.tags // empty` would be wrong here: jq's alternative operator treats
  # `false` as absent, so a book that declares itself untagged would read as
  # one that declared nothing. Ask whether the key exists instead.
  declared_tags=$(jq -r 'if has("tags") then (.tags | tostring) else "" end' "$dir/book.json" 2>/dev/null)
  # Same reasoning for the two resource-first keys. `provenance` says every unit
  # on the page carries a src mark naming where it came from; `suggested_reading`
  # says every chapter ends with the concept list. Both are opt-in, because a
  # book written before they existed is still a correct book.
  declared_prov=$(jq -r 'if has("provenance") then (.provenance | tostring) else "" end' "$dir/book.json" 2>/dev/null)
  declared_sugg=$(jq -r 'if has("suggested_reading") then (.suggested_reading | tostring) else "" end' "$dir/book.json" 2>/dev/null)
fi
skip="$skip
$gloss_name
$fm_name"

# What this run expects of the tags. A flag wins; else book.json's declaration;
# else inference from the chapters themselves, which is the weakest of the three
# and says so on the summary line, because a check that quietly got weaker reads
# exactly like a check that passed.
case "$declared_tags" in
  true) tag_mode=required ;;
  false) tag_mode=forbidden ;;
  "") tag_mode=inferred ;;
  *)
    echo "error: book.json \"tags\" must be true or false, not: $declared_tags" >&2
    exit 2
    ;;
esac
[ "$require_tags" -eq 1 ] && tag_mode=required
[ "$no_tags" -eq 1 ] && tag_mode=forbidden

# The two resource-first modes have no inferred setting and no flag. A book
# either declares them or it is not held to them, because inferring "this book
# meant to carry provenance" from a chapter that happens to have one mark would
# fail every book written before the feature existed.
case "$declared_prov" in
  true) prov_mode=required ;;
  false|"") prov_mode=off ;;
  *) echo "error: book.json \"provenance\" must be true or false, not: $declared_prov" >&2; exit 2 ;;
esac
case "$declared_sugg" in
  true) sugg_mode=required ;;
  false|"") sugg_mode=off ;;
  *) echo "error: book.json \"suggested_reading\" must be true or false, not: $declared_sugg" >&2; exit 2 ;;
esac
is_skipped() {
  printf '%s\n' "$skip" | grep -qxF "$1"
}

chapters=()
while IFS= read -r path; do
  base=$(basename "$path")
  is_skipped "$base" || chapters+=("$path")
done < <(find "$dir" -maxdepth 1 -name '*.md' | sort)

if [ "${#chapters[@]}" -eq 0 ]; then
  echo "error: no chapter markdown files in $dir" >&2
  exit 2
fi

titles_file=$(mktemp)
trap 'rm -f "$titles_file"' EXIT

expected=1
total_words=0
total_struct=0
# The longest chapter, carried out to the summary. Nothing fails on it: it is
# the number a human reads first when asking whether the outline drew one
# chapter too wide, and finding that out from a column of eighteen numbers is
# work the script can do instead.
longest_words=-1
longest_chapter=""

for path in "${chapters[@]}"; do
  base=$(basename "$path")

  # Filename: lowercase, dashes only, zero-padded chapter number in the middle.
  # The BOOK slug may not contain a digit. The chapter number is found by taking
  # the first digit run, so a digit in the book slug makes that read ambiguous,
  # and the ambiguity used to surface as an arithmetic error rather than as a
  # failure. The chapter slug may still hold digits (`...-07-from-1nf-to-bcnf`),
  # because everything after the number is unambiguous.
  if ! printf '%s' "$base" | grep -qE '^[a-z]+(-[a-z]+)*-[0-9]{2,}-[a-z0-9]+(-[a-z0-9]+)*\.md$'; then
    problem "$base: filename does not match <book-slug>-<NN>-<chapter-slug>.md (lowercase and dashes; no digit in the book slug)"
    unchecked+=("$base — filename rejected, so its content was never examined")
    continue
  fi

  num=$(printf '%s' "$base" | sed -E 's/^[^0-9]*-([0-9]{2,})-.*/\1/')

  # sed returns its input unchanged when the pattern does not match, so a failed
  # read yields the whole filename rather than an error. Catch that here instead
  # of letting it reach the arithmetic below.
  if ! printf '%s' "$num" | grep -qE '^[0-9]+$'; then
    problem "$base: could not read a chapter number from the filename"
    unchecked+=("$base — chapter number unreadable, so its content was never examined")
    continue
  fi

  # Sorted position must be the chapter number, which is the whole point of the
  # padding. This catches a gap, a duplicate, and a book that starts at 00.
  if [ "$((10#$num))" -ne "$expected" ]; then
    problem "$base: is chapter $((10#$num)) but sits at position $expected in filename sort order"
  fi
  expected=$((expected + 1))

  # /makebook reads the title from line 1 only (build-book.py:406).
  first=$(head -n 1 "$path")
  case "$first" in
    "# "*) printf '%s\n' "${first#\# }" >>"$titles_file" ;;
    *) problem "$base: first line is not an H1, so /makebook will title the chapter from the filename" ;;
  esac

  body=$(tail -n +2 "$path")

  # Prose and structure are counted apart, and neither is capped. The spec sets
  # no chapter length at all (../reference/chapter-prose.md § Length): a chapter
  # is as long as it has to be, and whether a long one earned the room is a
  # judgment about the prose that no threshold could make. Both figures are
  # reported so a human can make it.
  #
  # The tags come off before the count. Left in, each one scores as a word and a
  # chapter's reported length drifts up by its paragraph count. A standalone
  # figure reference is not prose either, and neither is a provenance mark: the
  # mark is stripped at bind time and never reaches a reader, so counting it
  # would charge the prose budget for something nobody reads.
  #
  # A list, a table and a fenced block are counted, but as structure rather than
  # prose. They are on the page and cost the reader time, so they are reported;
  # they are kept out of the prose figure because they are consulted rather than
  # read line by line, and a table of ten facts is not ten sentences' worth of
  # attention. Table pipes score as words too, which is one more reason to keep
  # them out of a figure meant to measure sentences.
  #
  # Whether a given table earns its place is a judgment about the prose around
  # it, the same judgment this script already declines to make below, and the
  # spec's own rule is that the default stays prose. Both figures reach the
  # summary line so a human can see a chapter turning into a briefing, which is
  # the failure a number here could not catch anyway.
  # Headings count as prose, unchanged, because they are sentences a reader reads.
  read -r words struct_words <<<"$(printf '%s\n' "$body" | awk '
    /^[[:space:]]*```/ {
      struct += NF; inpara = 0; inblock = 0; blankrun = 0; infence = !infence; next
    }
    infence { struct += NF; next }
    /^[[:space:]]*<!--/ { inpara = 0; next }
    /^[[:space:]]*$/ { inpara = 0; if (inblock) blankrun = 1; next }
    /^[[:space:]]*#/ { inpara = 0; inblock = 0; blankrun = 0; prose += NF; next }
    /^[[:space:]]*!\[[^]]*\]\([^)]*\)[[:space:]]*$/ {
      inpara = 0; inblock = 0; blankrun = 0; next
    }
    /^[[:space:]]*([-*+][[:space:]]|[0-9]+\.[[:space:]]|\|)/ {
      inpara = 0; inblock = 1; blankrun = 0; struct += NF; next
    }
    inblock && !blankrun { struct += NF; next }
    inblock && blankrun && /^[[:space:]]+[^[:space:]]/ { blankrun = 0; struct += NF; next }
    {
      inblock = 0; blankrun = 0; inpara = 1
      sub(/^\[[0-9]+-[0-9]+\] /, "")
      prose += NF
      next
    }
    END { printf "%d %d\n", prose + 0, struct + 0 }
  ')"
  total_words=$((total_words + words))
  total_struct=$((total_struct + struct_words))
  if [ "$words" -gt "$longest_words" ]; then
    longest_words=$words
    longest_chapter=$base
  fi

  # Paragraph tags: [<chapter>-<paragraph>] and one space, at the head of every
  # paragraph. A paragraph starts on a non-blank line that is not a heading and
  # that follows a blank line or the top of the body. Headings take no tag.
  #
  # Neither does a figure. A line holding nothing but `![alt](path)` is a figure
  # reference, which /makebook numbers and captions itself, so it is skipped the
  # way a heading is and does not advance the counter. Without this a chapter
  # with figures fails every tag after its first one: the figure is counted as a
  # paragraph, so the numbering runs one ahead of the tags for the rest of the
  # chapter. This went unseen because the only book with figures predates tags.
  #
  # A list or a table is skipped for the same reason and it matters more. A tag
  # is an address other files cite, so a list dropped into the middle of a
  # chapter must not renumber the paragraphs after it: the reference book's tags
  # alone are cited fifty-six times outside the book. Tagging a table row is
  # also meaningless, since the address a reader wants is the prose that
  # introduced the table. So a list or table block advances nothing, exactly
  # like a figure, and the paragraph before it keeps its number.
  #
  # The trailing concept list takes no tags and the counter stops at it. Its
  # items are a list, which advances nothing anyway, but the sentence above them
  # is an ordinary paragraph that would otherwise be counted and found untagged.
  # Nothing cites into that section: it names concepts the book does not cover,
  # so there is no claim in it for another file to point at.
  #
  # A provenance mark is skipped for the same reason and it is the case that
  # would have hurt most: a book carrying one after every paragraph would score
  # each mark as an untagged paragraph, so the count would run at twice the tag
  # numbers and every tag after the first would be reported wrong. The mark is a
  # single-line HTML comment, it is stripped before the bind, and it advances
  # nothing.
  #
  # `inblock` runs from the first marker line to the end of the block. A blank
  # line inside a list does not end it, which is what `blankrun` tracks: after a
  # blank, an indented line continues the block and an unindented one starts a
  # paragraph. Before a blank, every line continues the block, because
  # CommonMark reads an unindented line under a list item as lazy continuation.
  # A fenced code block is skipped whole, for the tag reason and for a second
  # one: its contents are not markdown at all, so a line inside it that happens
  # to start with a dash or a pipe is code rather than a list or a table. The
  # fence rules come first so that a blank line inside a fence never reaches the
  # blank-line case. Block quotes need no case here; they are still rejected
  # outright below, so they never reach this counter.
  tag_report=$(printf '%s\n' "$body" | awk -v sugg="$sugg_heading" '
    index($0, sugg) == 1 { stop = 1 }
    stop { next }
    /^[[:space:]]*```/ {
      inpara = 0; inblock = 0; blankrun = 0; infence = !infence; next
    }
    infence { next }
    /^[[:space:]]*<!--/ { inpara = 0; inblock = 0; blankrun = 0; next }
    /^[[:space:]]*$/ { inpara = 0; if (inblock) blankrun = 1; next }
    /^[[:space:]]*#/ { inpara = 0; inblock = 0; blankrun = 0; next }
    /^[[:space:]]*!\[[^]]*\]\([^)]*\)[[:space:]]*$/ {
      inpara = 0; inblock = 0; blankrun = 0; next
    }
    /^[[:space:]]*([-*+][[:space:]]|[0-9]+\.[[:space:]]|\|)/ {
      inpara = 0; inblock = 1; blankrun = 0; next
    }
    inblock && !blankrun { next }
    inblock && blankrun && /^[[:space:]]+[^[:space:]]/ { blankrun = 0; next }
    {
      inblock = 0
      blankrun = 0
      if (!inpara) {
        inpara = 1
        n++
        if (match($0, /^\[[0-9]+-[0-9]+\] /)) {
          print "TAG", substr($0, 2, RLENGTH - 3), n
        } else {
          print "UNTAGGED", n
        }
      }
    }
  ')
  n_tagged=$(printf '%s\n' "$tag_report" | grep -c '^TAG ' || true)
  n_untagged=$(printf '%s\n' "$tag_report" | grep -c '^UNTAGGED ' || true)

  if [ "$n_tagged" -gt 0 ] && [ "$n_untagged" -gt 0 ]; then
    first_bare=$(printf '%s\n' "$tag_report" | awk '$1 == "UNTAGGED" { print $2; exit }')
    problem "$base: $n_untagged of $((n_tagged + n_untagged)) paragraphs carry no tag (first at paragraph $first_bare); a chapter is tagged throughout or not at all"
  fi

  if [ "$n_tagged" -gt 0 ]; then
    tagged_chapters=$((tagged_chapters + 1))
    # The chapter half must be this chapter, and the paragraph half must run
    # 1, 2, 3 with no gap and no repeat. Both are how a tag stays a unique
    # address for the paragraph it names.
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      tag=$(printf '%s' "$line" | awk '{print $2}')
      seq=$(printf '%s' "$line" | awk '{print $3}')
      tag_ch=${tag%%-*}
      tag_p=${tag##*-}
      # One spelling per address. The filename pads its chapter number so a
      # lexicographic sort orders the book; a tag is typed into a conversation
      # instead, so it does not pad, and [03-7] alongside [3-8] would give one
      # paragraph two names.
      if [ "$tag_ch" != "$((10#$tag_ch))" ] || [ "$tag_p" != "$((10#$tag_p))" ]; then
        problem "$base: paragraph $seq is tagged [$tag]; tag numbers carry no leading zeros"
      fi
      if [ "$((10#$tag_ch))" -ne "$((10#$num))" ]; then
        problem "$base: paragraph $seq is tagged [$tag] but this is chapter $((10#$num))"
      fi
      if [ "$((10#$tag_p))" -ne "$seq" ]; then
        problem "$base: paragraph $seq is tagged [$tag]; the paragraph number must count 1, 2, 3 through the chapter"
      fi
    done < <(printf '%s\n' "$tag_report" | grep '^TAG ')
  else
    untagged_chapters=$((untagged_chapters + 1))
  fi

  # Provenance. In a book that declares it, every unit a reader sees carries a
  # mark naming where it came from: each prose paragraph, each table, each list,
  # each fenced block. The unit boundaries are read with the same state machine
  # as the tags above, so the two agree by construction rather than by luck.
  #
  # Two exemptions, both deliberate. Anything before the first tagged paragraph
  # is the chapter header, whose sources are the ones the whole chapter draws on
  # and which names them in its own rows. Anything from the concept list onward
  # is by definition what the sources did not cover, so a mark there would say
  # `fill` on every line and carry nothing.
  #
  # A figure takes no mark either. Its provenance is the one sentence per figure
  # that /makebook already requires in diagrams/README.md, and duplicating that
  # here would give one figure two records that can disagree.
  if [ "$prov_mode" = required ]; then
    prov_report=$(printf '%s\n' "$body" | awk -v sugg="$sugg_heading" '
      function newunit(label) { if (started) pending = label }
      function flush() {
        if (pending != "") { print pending; missing++; pending = "" }
      }
      index($0, sugg) == 1 || $0 ~ ("^[[:space:]]*" sugg "[[:space:]]*$") { stop = 1 }
      stop { next }
      /^[[:space:]]*```/ {
        if (!infence) { flush(); newunit("a fenced block at line " NR) }
        inpara = 0; inblock = 0; blankrun = 0; infence = !infence; next
      }
      infence { next }
      /^[[:space:]]*<!--/ { pending = ""; inpara = 0; inblock = 0; blankrun = 0; next }
      /^[[:space:]]*$/ { inpara = 0; if (inblock) blankrun = 1; next }
      /^[[:space:]]*#/ { flush(); inpara = 0; inblock = 0; blankrun = 0; next }
      /^[[:space:]]*!\[[^]]*\]\([^)]*\)[[:space:]]*$/ {
        inpara = 0; inblock = 0; blankrun = 0; next
      }
      # Only the first line of a block opens a unit. Without the guard every
      # table row would flush the row above it and the whole table would report
      # as one unmarked unit per line.
      /^[[:space:]]*([-*+][[:space:]]|[0-9]+\.[[:space:]]|\|)/ {
        if (!inblock) { flush(); newunit("a table or list at line " NR) }
        inpara = 0; inblock = 1; blankrun = 0; next
      }
      inblock && !blankrun { next }
      inblock && blankrun && /^[[:space:]]+[^[:space:]]/ { blankrun = 0; next }
      {
        inblock = 0; blankrun = 0
        if (!inpara) {
          inpara = 1
          flush()
          started = 1
          if (match($0, /^\[[0-9]+-[0-9]+\] /)) {
            newunit("paragraph " substr($0, 2, RLENGTH - 3))
          } else {
            newunit("the paragraph at line " NR)
          }
        }
        next
      }
      END { flush(); if (missing) printf "%d\n", missing }
    ')
    if [ -n "$prov_report" ]; then
      n_missing=$(printf '%s\n' "$prov_report" | tail -n 1)
      first_missing=$(printf '%s\n' "$prov_report" | head -n 1)
      problem "$base: $n_missing units carry no provenance mark (first is $first_missing); each needs a <!-- src: ... --> line after it"
    fi
  fi

  # A chapter heads each of its parts with an H2 and carries no other heading
  # (reference/chapter-prose.md § Headings). So H2s are expected here; nothing else is.

  # Both heading tests skip fenced content, the way the other five body sweeps
  # already do. A fenced block is not markdown: a python comment opens with a
  # hash and a banner comment with three, so a lab stub a chapter shows the
  # reader reads as an H1 and an H3 to a sweep that does not track the fence.
  # While these were bare greps a chapter needing a hash comment drew a failure
  # it could only clear by rewriting working code, which is why chapter 4 of the
  # reference book rendered a sample as a docstring; and because every fenced hash
  # raised the same message, a genuine second H1 was indistinguishable from a
  # false alarm, so the failure could not be trusted either way. A `#` inside a
  # fence is code rather than a heading, and /makebook reads the chapter title
  # from the first H1, which a fenced line never renders as. So there is nothing
  # in a fence for this rule to protect, and it now correctly ignores one.
  # fixtures/fence/ holds the two-chapter case.
  #
  # awk rather than grep because the fence state needs carrying across lines.
  # `[[:space:]]` rather than `\s` is deliberate and must not be "simplified"
  # back: `\s` is a GNU extension that BSD awk does not read as whitespace.
  # Verified 2026-09-13 against the greps these replace, on `# Title`, `## Part`,
  # a bare `#`, `###`, `### x`, an indented `  # x`, `#no-space` and a plain
  # line: the two agree on all eight.
  #
  # A second H1 would fight the chapter title /makebook reads from line 1.
  if printf '%s\n' "$body" | awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    infence { next }
    /^[[:space:]]*#([^#]|$)/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
  '; then
    problem "$base: body carries an H1; the chapter title is line 1 and nothing else"
  fi
  # Headings mark parts and only parts, so there is no level below H2.
  if printf '%s\n' "$body" | awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    infence { next }
    /^[[:space:]]*###/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
  '; then
    problem "$base: body carries an H3 or deeper; headings mark parts only"
  fi
  # The trailing concept list is an H2 and it is not a part, so it comes out of
  # the count before the shape rule runs. Without this every chapter carrying one
  # reads as having a fourth part and fails on a section the spec requires.
  # It has to be the last H2 in the file, because a part heading after it would
  # mean the chapter went on teaching past the point where it said it had stopped.
  sugg_present=0
  if printf '%s\n' "$body" | grep -qE "^[[:space:]]*${sugg_heading}[[:space:]]*$"; then
    sugg_present=1
    last_h2=$(printf '%s\n' "$body" | grep -E '^[[:space:]]*## ' | tail -n 1 | sed -E 's/[[:space:]]+$//;s/^[[:space:]]+//')
    if [ "$last_h2" != "$sugg_heading" ]; then
      problem "$base: \"$sugg_heading\" is not the last section; nothing follows the concept list"
    fi
    # An empty section is worse than none, because it reads as a book that
    # checked its edges and found nothing beyond them.
    sugg_items=$(printf '%s\n' "$body" | sed -n "/^[[:space:]]*${sugg_heading}[[:space:]]*$/,\$p" | grep -cE '^[[:space:]]*[-*+][[:space:]]' || true)
    if [ "$sugg_items" -eq 0 ]; then
      problem "$base: \"$sugg_heading\" carries no items"
    fi
  elif [ "$sugg_mode" = required ]; then
    problem "$base: book.json declares suggested_reading but the chapter has no \"$sugg_heading\" section"
  fi

  # One H2 per part, and a chapter's shape is two or three parts, never one or
  # four (reference/chapter-prose.md § Shape). Zero also passes: chapters written
  # before parts were headed at all are still correct prose and still bind.
  h2=$(printf '%s\n' "$body" | grep -cE '^\s*## ' || true)
  h2=$((h2 - sugg_present))
  case "$h2" in
    0|2|3) ;;
    *) problem "$base: body has $h2 part headings; a chapter's shape is two or three parts (0 for a chapter written before headings)" ;;
  esac

  # Markdown a chapter still may not carry: block quotes and italics. Bulleted
  # and numbered lists, tables, fenced code blocks, bold and inline code spans
  # are permitted (reference/chapter-prose.md § Never), for the passages where a shape
  # carries the idea better than a sentence does. Whether a given one earns its
  # place is a judgment about the prose around it, so nothing here counts or
  # rations them; the spec's own rule is that the default stays prose.
  #
  # The inline-span ban was lifted with the resource-first work. A book whose
  # value is pointing at its sources has to be able to name a file, a column or a
  # command the way a reader would type it, and spelling `grading-outline.md` as
  # plain prose was the rule's cost rather than its benefit.
  if printf '%s\n' "$body" | grep -qE '^\s*> '; then
    problem "$base: body carries a block quote; a chapter is prose, part headings, and the lists, tables and fenced blocks that earn their place"
  fi

  # An unclosed fence is its own failure: everything after it would be swallowed
  # as code, and every check that reads the fence state would then report clean.
  if printf '%s\n' "$body" | awk '
    /^[[:space:]]*```/ { infence = !infence }
    END { exit(infence ? 0 : 1) }
  '; then
    problem "$base: body has an unclosed code fence"
  fi

  # A provenance mark is a single-line HTML comment and the only comment a
  # chapter carries. Both halves are checked because both fail silently: a
  # comment left open swallows the rest of the file into markup nobody renders,
  # and a mark that misses the `src:` grammar is invisible to the sweep that
  # asks what a book filled in.
  bad_comment=$(printf '%s\n' "$body" | awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    infence { next }
    /<!--/ {
      if ($0 !~ /-->/) { print "unterminated"; exit }
      if ($0 !~ /^[[:space:]]*<!--[[:space:]]*src:[[:space:]]*[^[:space:]].*-->[[:space:]]*$/) {
        print "grammar"; exit
      }
    }
  ')
  case "$bad_comment" in
    unterminated) problem "$base: body has an HTML comment left open; a provenance mark is one line" ;;
    grammar) problem "$base: body has a comment that is not a provenance mark; the only comment a chapter carries reads <!-- src: ... -->" ;;
  esac

  # Em dash, banned by the chapter spec and by the repo's writing rules.
  if grep -q '—' "$path"; then
    problem "$base: contains an em dash"
  fi

  checked=$((checked + 1))
done

dupes=$(sort "$titles_file" | uniq -d)
if [ -n "$dupes" ]; then
  while IFS= read -r t; do
    problem "duplicate chapter title: $t"
  done <<<"$dupes"
fi

# The glossary. It is back matter rather than a chapter, so none of the chapter
# rules above apply to it: no filename number, no H1 title, no part headings, no
# paragraph tags, and it reaches neither word figure.
#
# /makebook's own parser is the authority on this format and rejects the same
# faults at bind time. This check is here because bind time is too late: step 6
# runs long before anyone binds, and the skill says not to bind unless asked, so
# a glossary broken here would otherwise sit undetected until the PDF was wanted.
# If the two ever disagree, /makebook is right and this needs updating.
gloss_terms=0
gloss_file="$dir/$gloss_name"
if [ "$declared_gloss" = "true" ] && [ ! -f "$gloss_file" ]; then
  problem "book.json declares a glossary but $gloss_name is not in $dir"
fi
if [ -f "$gloss_file" ]; then
  gloss_report=$(awk -v maxch="$checked" -v gname="$gloss_name" '
    BEGIN { RS = ""; n = 0 }
    /^[[:space:]]*#/ { next }
    {
      entry = $0
      gsub(/\n/, " ", entry)
      sub(/^[[:space:]]+/, "", entry)
      if (!match(entry, /^\*\*[^*]+\*\*/)) {
        printf "P %s: entry does not read \"**term** (ch. N) definition\": %s\n", gname, substr(entry, 1, 72)
        next
      }
      term = substr(entry, 3, RLENGTH - 4)
      rest = substr(entry, RLENGTH + 1)
      sub(/^[[:space:]]+/, "", rest)
      ch = 0
      sawch = 0
      if (match(rest, /^\(ch\.[[:space:]]*[0-9]+\)/)) {
        chtxt = substr(rest, 1, RLENGTH)
        gsub(/[^0-9]/, "", chtxt)
        ch = chtxt + 0
        sawch = 1
        rest = substr(rest, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", rest)
      }
      if (rest == "") {
        printf "P %s: \"%s\" carries no definition\n", gname, term
        next
      }
      # A chapter reference has to name a chapter this book has, or a reader
      # following it lands nowhere. Zero is not a chapter either, and catching
      # it needs sawch rather than ch: ch is also 0 for an entry that carried no
      # reference at all, so a bare "ch > 0 && ch < 1" can never be true.
      if (sawch && (ch < 1 || ch > maxch)) {
        printf "P %s: \"%s\" points at chapter %d and this book has %d\n", gname, term, ch, maxch
      }
      key = tolower(term)
      if (key in seen) {
        printf "P %s: \"%s\" is defined more than once, so one of them is unreachable\n", gname, term
      }
      seen[key] = 1
      n++
    }
    END { printf "N %d\n", n }
  ' "$gloss_file")
  while IFS= read -r gline; do
    case "$gline" in
      "P "*) problem "${gline#P }" ;;
      "N "*) gloss_terms="${gline#N }" ;;
    esac
  done <<<"$gloss_report"
  if [ "$gloss_terms" -eq 0 ]; then
    problem "$gloss_name holds no glossary entries"
  fi
fi

# A tag is an address a reader cites, so half a tagged book is worse than none:
# the chapters without tags look like chapters nobody can point at. Any tagged
# chapter therefore obliges the rest.
if [ "$tagged_chapters" -gt 0 ] && [ "$untagged_chapters" -gt 0 ]; then
  problem "$untagged_chapters of $checked chapters carry no paragraph tags while $tagged_chapters do; a book is tagged throughout or not at all"
fi
case "$tag_mode" in
  required)
    if [ "$tagged_chapters" -eq 0 ]; then
      problem "this book is expected to carry paragraph tags and no chapter does"
    fi
    ;;
  forbidden)
    if [ "$tagged_chapters" -gt 0 ]; then
      problem "$tagged_chapters of $checked chapters carry paragraph tags and this book is declared untagged"
    fi
    ;;
esac

echo
gloss_note="none"
[ -f "$gloss_file" ] && gloss_note="$gloss_terms terms"
# Both word figures are reported and neither is capped. They are here so a human
# can see a book drifting toward a briefing, or one chapter the outline drew too
# wide, and neither of those is a judgment a threshold could make for them.
echo "chapters: ${#chapters[@]}    content-checked: $checked    tagged: $tagged_chapters/$checked ($tag_mode)    prose: $total_words    structure: $total_struct    provenance: $prov_mode    suggested reading: $sugg_mode    glossary: $gloss_note    folder: $dir"
# Guarded because a run where every chapter's filename was rejected reaches here
# with nothing counted, and a mean over zero chapters would abort the script one
# line before it reports what went wrong.
if [ "$checked" -gt 0 ]; then
  # Rounded to nearest, not truncated, so this agrees with the average quoted in
  # SKILL.md and NOTES.md rather than sitting a word below it.
  echo "chapter prose: mean $(((total_words + checked / 2) / checked))    longest $longest_words in $longest_chapter"
fi
if [ "$tag_mode" = "inferred" ]; then
  echo "note: this book neither declares \"tags\" in book.json nor was given a flag,"
  echo "      so the tag state was inferred from the chapters. A book where every"
  echo "      chapter forgot its tags is indistinguishable from an untagged book."
fi

# Say out loud what was not examined. A checker's silence about a file it never
# opened reads exactly like a pass.
if [ "$checked" -ne "${#chapters[@]}" ]; then
  echo
  echo "NOT CONTENT-CHECKED:"
  for u in ${unchecked[@]+"${unchecked[@]}"}; do echo "  $u"; done
  problem "only $checked of ${#chapters[@]} chapters reached the content checks, so this run says nothing about the rest"
fi

if [ "$fail" -eq 0 ]; then
  echo "OK    structure is sound; read the seams for continuity"
fi
exit "$fail"
