#!/usr/bin/env bash
#
# Structural check for a /createbook folder.
#
# Checks only what is mechanically checkable: filenames, ordering, the H1 that
# /makebook reads, the H2 per part, the markdown a chapter still may not carry,
# the [chapter-paragraph] tags, and under the guide profile the 90-word
# paragraph stop. Chapter length is reported and never failed, because the spec
# sets none. Lines that need a reader rather than a rule, such as a long
# sentence or a summary copying its chapter, print as REPORT and fail nothing.
# It says nothing about whether the prose is any good or the facts are right.
#
# The prose rules it enforces are written in ../reference/chapter-prose.md, which
# every chapter follows, and in the profile files ../reference/guide.md and
# ../reference/narration.md. They are cited below by rule name rather than by
# line, so that editing the spec does not silently repoint every citation into
# it. At runtime it reads nothing but
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
# A report is something a human should read and no rule fails on: a sentence
# past the stop, a callout doing two jobs, a summary repeating the chapter. They
# are counted and printed on their own line so a run with reports still reads
# as a pass where it is one, and a pass with reports never reads as clean.
reports=0
report() { echo "REPORT  $*"; reports=$((reports + 1)); }

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
declared_ovw=""
# Both are read inside the jq block below, and both must exist before it: the
# no-jq fallback skips that block entirely and `set -u` turns an unset variable
# into a dead run rather than a degraded one. Initialising them here is what
# keeps the documented no-jq configuration working.
declared_profile=""
source_keys=""
display_keys=""
gloss_name="glossary.md"
fm_name="about-this-book.md"
# The trailing concept list, by the one name the spec fixes. It is matched
# exactly so that a chapter cannot quietly rename it and slip the check.
sugg_heading="## Suggested reading"
# The overview section, which opens the body where "## Suggested reading" closes it.
# Held in a variable for the same reason: the awks below match it by prefix and a
# literal repeated in six places is a literal that drifts in one of them.
ovw_heading="## In short"
# The carried-in line is found by this prefix and by nothing else
# (reference/chapter-prose.md § In short). Inferring the line from its first bolded
# term instead would swallow a walk that opens on a glossed term and skip a
# carried-in line whose first term lost its bold, and both read as a clean pass.
ovw_carried_prefix="Carried in: "
# The loose form exists only to catch a prefix that is nearly right. Matching
# on it and then requiring the exact form is what keeps a one-character typo
# from silently switching off the ceiling and the glossary cross-check.
ovw_carried_loose="Carried in:"
# The ceiling on the carried-in line. A ceiling and never a target: zero is legal
# and chapter 1 always has none.
ovw_carried_max=3
# The ceiling on callouts in one chapter, under the guide profile
# (reference/guide.md § Callouts).
callout_max=4
# The stops the spec calls hard (../reference/chapter-prose.md § Shape, § Voice).
# A paragraph is counted exactly, so the paragraph stop fails a guide book and
# is reported under narration, where every book written before the check
# existed has to keep passing. A sentence boundary is a guess a script makes,
# so the sentence stop is reported under both.
para_max=90
sent_max=45
# One idea per callout, in one to four sentences (../reference/guide.md
# § Callouts). Reported, because the count rests on the same sentence guess.
callout_sent_max=4
# The guide summary's length, and the shortest run it may share with the
# chapter below it before it counts as reuse (../reference/guide.md § In short).
ovw_words_max=120
ovw_shared_run=8
# A phrase recurring in this many chapters or more is reported as a possible
# template (../reference/guide.md § The wrong model). Four words is the unit:
# long enough that "of the" never fires, short enough to catch "the obvious
# move is".
phrase_chapters=3
phrase_len=4
phrase_report_max=10
# A tag at the head of a paragraph, written with bracket expressions rather
# than backslashes so it survives being passed to awk with -v.
tag_head_re='^[[]A?[0-9]+-[0-9]+[a-z]?[]] '
# jq missing is a supported configuration: the run falls back to inference and
# says so. jq present but unable to run is not, and it is the more dangerous of
# the two, because every `jq ... 2>/dev/null` below yields an empty string and
# every declaration in book.json reads as absent. The book is then checked in
# the weakest mode available while book.json plainly declares otherwise, and
# nothing on the summary line distinguishes that from a book that declared
# nothing. Found on an arm64 Mac carrying a stale x86_64 jq on PATH, where every
# book had been passing in the weakest mode for as long as the binary sat there.
if command -v jq >/dev/null 2>&1 && ! printf '{}' | jq -e . >/dev/null 2>&1; then
  echo "error: jq is on PATH at $(command -v jq) but will not run." >&2
  echo "       Every book.json declaration would read as absent and the book" >&2
  echo "       would be checked in the weakest mode while declaring otherwise." >&2
  echo "       Repair or remove that jq, or take it off PATH to use the" >&2
  echo "       documented no-jq fallback deliberately." >&2
  exit 2
fi
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
  # `overview` says every chapter opens with "## In short". Opt-in on the same
  # terms as the two above: a book written before the section existed is still a
  # correct book and must pass untouched.
  declared_ovw=$(jq -r 'if has("overview") then (.overview | tostring) else "" end' "$dir/book.json" 2>/dev/null)
  # `profile` selects the rule set: ../reference/guide.md or ../reference/narration.md,
  # each read on top of ../reference/chapter-prose.md. Absent means
  # the narration rules, which is every book written before the guide profile
  # existed, so the default cannot be anything else.
  declared_profile=$(jq -r '.profile // empty' "$dir/book.json" 2>/dev/null)
  # Source display names, for the repo-path check below. A `sources` value may
  # be a bare path, a list of them, or an object carrying a reader-facing name
  # beside the path; only the last form has a display name to check against.
  source_keys=$(jq -r '(.sources // {}) | keys[]' "$dir/book.json" 2>/dev/null)
  # The keys that carry a reader-facing name. /makebook prints that name in
  # place of the key in the chapter header and its endnotes, so a path-like key
  # there is only a problem when it has no name to be swapped for.
  display_keys=$(jq -r '(.sources // {}) | to_entries[] | select((.value | type) == "object" and ((.value.display // "") | length) > 0) | .key' "$dir/book.json" 2>/dev/null)
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
case "$declared_ovw" in
  true) ovw_mode=required ;;
  false|"") ovw_mode=off ;;
  *) echo "error: book.json \"overview\" must be true or false, not: $declared_ovw" >&2; exit 2 ;;
esac
# The profile is the rule set, not a mode with an inferred setting: a book either
# names one or gets the narration rules. Inferring "this book meant to be a
# guide" from a chapter that happens to carry an H3 would turn a failure into a
# silent reclassification, which is the same shape as the jq bug above.
case "$declared_profile" in
  ""|narration) profile=narration ;;
  guide) profile=guide ;;
  *)
    echo "error: book.json \"profile\" must be \"guide\" or absent, not: $declared_profile" >&2
    exit 2
    ;;
esac
# Under the guide profile the overview section is required rather than opt-in
# (../reference/guide.md § In short). It is the chapter's only summary, so a
# guide chapter without one has lost the reader who opened the book at that
# chapter. An explicit
# "overview": false is still an error rather than an override, because a guide
# that declares the section off is two declarations that contradict each other.
if [ "$profile" = guide ]; then
  if [ "$declared_ovw" = false ]; then
    echo "error: book.json sets \"profile\": \"guide\" and \"overview\": false;" >&2
    echo "       the guide profile requires the \"## In short\" section." >&2
    exit 2
  fi
  ovw_mode=required
fi
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
# Each chapter's prose, one line per unit, for the recurring-phrase report that
# can only run once every chapter has been read.
phrases_file=$(mktemp)
trap 'rm -f "$titles_file" "$phrases_file"' EXIT

expected=1
# Appendices are numbered in their own sequence, so they need their own counter.
# Sharing `expected` would make appendix 1 read as chapter 19 of an 18-chapter
# book, which is exactly the kind of off-by-one that reads as a real failure.
expected_app=1
total_words=0
total_struct=0
total_ovw=0
# Chapters whose overview ended at a part heading rather than at a tag or a
# mark. In a book carrying provenance that is a paragraph whose mark went
# unchecked, and the run says so rather than letting the gap read as a pass.
ovw_fallback=0
# Carried-in terms, held until the glossary has been parsed: the chapter loop
# runs long before the glossary map exists, so the cross-check cannot happen in
# place. One record per term, as <chapter>|<file>|<term>.
carried_records=()
# The longest chapter, carried out to the summary. Nothing fails on it: it is
# the number a human reads first when asking whether the outline drew one
# chapter too wide, and finding that out from a column of eighteen numbers is
# work the script can do instead.
longest_words=-1
longest_chapter=""

for path in "${chapters[@]}"; do
  base=$(basename "$path")

  # An appendix is a chapter-kind file holding reference matter, bound after the
  # chapters and before the glossary (../reference/guide.md § Appendices).
  # It is recognised before the chapter filename rule because it deliberately does
  # not match it: `-appendix-N-` in place of `-NN-`. Sorting still puts it after
  # every chapter, because `a` sorts after every digit, so a plain filename sort
  # is still the reading order.
  #
  # Guide-only. Under narration such a file is not a kind the profile has, so it
  # falls through to the chapter rule and fails there by name, which is the right
  # answer: a narration book that grew an appendix has either mis-set its profile
  # or mis-named a chapter, and both are worth stopping on.
  is_appendix=0
  app_num=""
  if [ "$profile" = guide ] && printf '%s' "$base" | grep -qE '^[a-z]+(-[a-z]+)*-appendix-[0-9]+-[a-z0-9]+(-[a-z0-9]+)*\.md$'; then
    is_appendix=1
    app_num=$(printf '%s' "$base" | sed -E 's/^.*-appendix-([0-9]+)-.*/\1/')
    if [ "$app_num" != "$((10#$app_num))" ]; then
      problem "$base: appendix numbers carry no leading zeros"
    elif [ "$((10#$app_num))" -ne "$expected_app" ]; then
      problem "$base: is appendix $((10#$app_num)) but sits at position $expected_app among the appendices"
    fi
    expected_app=$((expected_app + 1))
  fi

  # Filename: lowercase, dashes only, zero-padded chapter number in the middle.
  # The BOOK slug may not contain a digit. The chapter number is found by taking
  # the first digit run, so a digit in the book slug makes that read ambiguous,
  # and the ambiguity used to surface as an arithmetic error rather than as a
  # failure. The chapter slug may still hold digits (`...-07-from-1nf-to-bcnf`),
  # because everything after the number is unambiguous.
  if [ "$is_appendix" -eq 0 ] && ! printf '%s' "$base" | grep -qE '^[a-z]+(-[a-z]+)*-[0-9]{2,}-[a-z0-9]+(-[a-z0-9]+)*\.md$'; then
    problem "$base: filename does not match <book-slug>-<NN>-<chapter-slug>.md (lowercase and dashes; no digit in the book slug)"
    unchecked+=("$base — filename rejected, so its content was never examined")
    continue
  fi

  if [ "$is_appendix" -eq 1 ]; then
    # The tag's chapter half for an appendix is A<N>, so the numeric `num` the
    # tag check compares against is not a number here. It is set to the appendix
    # number and the tag check below branches on `is_appendix` rather than
    # parsing it back out of the tag.
    num="$app_num"
  else
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
  fi

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
  # Where the overview section starts and stops, computed once for every sweep
  # below rather than three times inside them. Its start is the heading. Its end
  # is the chapter's opening paragraph, and finding that is the whole difficulty:
  # the opening paragraph carries no heading of its own, so the next H2 is the
  # part heading below it and stopping there would swallow it.
  #
  # Three things can mark it, in whichever order they arrive. A paragraph tag is
  # exact, and the opening paragraph carries the chapter's first one. Failing
  # that, a provenance mark names the paragraph immediately above it, and the
  # overview carries none, so the first marked paragraph is the opening one. The
  # next H2 is the last resort. A book with neither tags nor marks lands there
  # and counts its opening paragraph in the overview figure, which costs a
  # reported number and no check: with nothing to tag and nothing to mark, the
  # two sweeps that care have nothing to exempt.
  # Recognising the section is structural, and the declaration is not part of
  # it. "## In short" is the section when it is the first H2 and the chapter
  # header table is the last thing with content before it, because a normal
  # chapter has its opening paragraph in that gap and a part heading cannot sit
  # there. A book that uses those two words for an ordinary part heading later
  # on fails both tests and is counted and swept exactly as it was.
  #
  # Structural rather than declared, because book.json is only readable where
  # jq is, and the no-jq fallback is a supported configuration. Gating the
  # exemptions on the declaration made a declared book fail on a machine
  # without jq: the key read as absent, the section became ordinary prose, and
  # every paragraph in it was reported as missing its tag.
  ovw_seen=0
  ovw_present=0
  ovw_start=0
  ovw_end=0
  if printf '%s\n' "$body" | grep -qE "^[[:space:]]*${ovw_heading}[[:space:]]*\$"; then
    ovw_seen=1
    ovw_first_h2=$(printf '%s\n' "$body" | grep -E '^[[:space:]]*## ' | head -n 1 | sed -E 's/[[:space:]]+$//;s/^[[:space:]]+//')
    ovw_before=$(printf '%s\n' "$body" | sed -n "1,/^[[:space:]]*${ovw_heading}[[:space:]]*\$/p" | sed '$d' | grep -vE '^[[:space:]]*$' | tail -n 1)
    if [ "$ovw_first_h2" = "$ovw_heading" ] && printf '%s' "$ovw_before" | grep -qE '^[[:space:]]*\|'; then
      ovw_present=1
    fi
  fi
  if [ "$ovw_present" -eq 1 ]; then
    ovw_start=$(printf '%s\n' "$body" | grep -nE "^[[:space:]]*${ovw_heading}[[:space:]]*\$" | head -n 1 | cut -d: -f1)
    ovw_end=$(printf '%s\n' "$body" | awk -v start="$ovw_start" '
      NR <= start { next }
      /^[[:space:]]*## / { print NR; found = 1; exit }
      /^\[A?[0-9]+-[0-9]+[a-z]?\] / { print NR; found = 1; exit }
      /^[[:space:]]*<!--/ { if (pstart) { print pstart; found = 1; exit } next }
      /^[[:space:]]*$/ { pstart = 0; next }
      { if (!pstart) pstart = NR; next }
      END { if (!found) print 0 }
    ')
    # Which of the three marked the end, and whether anything did. A part
    # heading means neither a tag nor a mark was found first, so the chapter's
    # opening paragraph sits inside the range. Nothing at all means the range
    # runs to the end of the file and swallows the whole chapter, which shows up
    # as a chapter reporting almost no prose. Both are disclosed, because a
    # figure that quietly moved reads exactly like a figure that was measured.
    if [ "$ovw_end" -eq 0 ]; then
      ovw_fallback=$((ovw_fallback + 1))
    elif printf '%s\n' "$body" | sed -n "${ovw_end}p" | grep -qE '^[[:space:]]*## '; then
      ovw_fallback=$((ovw_fallback + 1))
    fi
  fi

  # The overview is a third figure, kept apart from both. It is a summary of the
  # chapter rather than part of its argument, so folding it into the prose count
  # would make every chapter read as longer than it argues. Its rules sit after
  # the fence rules so that fence state still tracks correctly through it, and
  # the heading line itself is counted nowhere: the figure is the section's body.
  read -r words struct_words ovw_words <<<"$(printf '%s\n' "$body" | awk -v ovws="$ovw_start" -v ovwe="$ovw_end" '
    /^[[:space:]]*```/ {
      struct += NF; inpara = 0; inblock = 0; blankrun = 0; infence = !infence; next
    }
    infence { struct += NF; next }
    ovws && NR >= ovws && (ovwe == 0 || NR < ovwe) {
      inpara = 0; inblock = 0; blankrun = 0
      if (NR > ovws) ovw += NF
      next
    }
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
      sub(/^\[A?[0-9]+-[0-9]+[a-z]?\] /, "")
      prose += NF
      next
    }
    END { printf "%d %d %d\n", prose + 0, struct + 0, ovw + 0 }
  ')"
  total_words=$((total_words + words))
  total_struct=$((total_struct + struct_words))
  total_ovw=$((total_ovw + ovw_words))
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
  tag_report=$(printf '%s\n' "$body" | awk -v sugg="$sugg_heading" -v ovws="$ovw_start" -v ovwe="$ovw_end" '
    index($0, sugg) == 1 { stop = 1 }
    stop { next }
    # The overview takes no tag and advances no count, the way the header table
    # and the concept list do not. A tag here would shift every tag after it,
    # and a tag is an address other files cite.
    ovws && NR >= ovws && (ovwe == 0 || NR < ovwe) { inpara = 0; inblock = 0; blankrun = 0; next }
    /^[[:space:]]*```/ {
      inpara = 0; inblock = 0; blankrun = 0; infence = !infence; next
    }
    infence { next }
    /^[[:space:]]*<!--/ { inpara = 0; inblock = 0; blankrun = 0; next }
    /^[[:space:]]*$/ { inpara = 0; if (inblock) blankrun = 1; next }
    /^[[:space:]]*#/ { inpara = 0; inblock = 0; blankrun = 0; next }
    # A block quote is a callout under the guide profile and a failure under
    # narration, and it is not a prose paragraph under either: it takes no tag
    # and advances no paragraph number. Skipping it here rather than letting it
    # count keeps the narration failure to one line instead of reporting the
    # same quote again as an untagged paragraph.
    /^[[:space:]]*>/ { inpara = 0; inblock = 0; blankrun = 0; next }
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
        if (match($0, /^\[A?[0-9]+-[0-9]+[a-z]?\] /)) {
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
    #
    # A revision may add a paragraph without renumbering anything by giving it
    # a letter: [5-12a] follows [5-12], then [5-12b], and [5-13] comes next
    # (../reference/chapter-prose.md § Paragraph tags). So a plain tag counts on
    # from the last plain tag, and a lettered one repeats the number of the
    # paragraph it follows with the next letter, starting at a. Each tag is
    # checked against the one before it rather than against its position, and
    # the count resyncs to what is written, so one wrong tag is reported once
    # instead of failing every tag after it.
    prev_n=0
    prev_s=""
    lettered=""
    alphabet=abcdefghijklmnopqrstuvwxyz
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      tag=$(printf '%s' "$line" | awk '{print $2}')
      seq=$(printf '%s' "$line" | awk '{print $3}')
      tag_ch=${tag%%-*}
      tag_p=${tag##*-}
      # An appendix addresses its paragraphs [A<N>-<n>]
      # (../reference/guide.md § Appendices). The chapter half is checked
      # against the appendix's own number, and the leading-zero rule applies to
      # the digits after the A.
      if [ "$is_appendix" -eq 1 ]; then
        case "$tag_ch" in
          A*) tag_ch=${tag_ch#A} ;;
          *)
            problem "$base: paragraph $seq is tagged [$tag]; an appendix tags its paragraphs [A$((10#$num))-$seq]"
            continue
            ;;
        esac
      else
        case "$tag_ch" in
          A*)
            problem "$base: paragraph $seq is tagged [$tag]; only an appendix carries an A tag"
            continue
            ;;
        esac
      fi
      tag_n=${tag_p%[a-z]}
      tag_s=${tag_p#"$tag_n"}
      # One spelling per address. The filename pads its chapter number so a
      # lexicographic sort orders the book; a tag is typed into a conversation
      # instead, so it does not pad, and [03-7] alongside [3-8] would give one
      # paragraph two names.
      if [ "$tag_ch" != "$((10#$tag_ch))" ] || [ "$tag_n" != "$((10#$tag_n))" ]; then
        problem "$base: paragraph $seq is tagged [$tag]; tag numbers carry no leading zeros"
      fi
      if [ "$((10#$tag_ch))" -ne "$((10#$num))" ]; then
        if [ "$is_appendix" -eq 1 ]; then
          problem "$base: paragraph $seq is tagged [$tag] but this is appendix $((10#$num))"
        else
          problem "$base: paragraph $seq is tagged [$tag] but this is chapter $((10#$num))"
        fi
      fi
      tag_half=${tag%-*}
      if [ -z "$tag_s" ]; then
        if [ "$((10#$tag_n))" -ne "$((prev_n + 1))" ]; then
          problem "$base: paragraph $seq is tagged [$tag]; the paragraph number must count 1, 2, 3 through the chapter, so this one is [$tag_half-$((prev_n + 1))]"
        fi
        prev_n=$((10#$tag_n))
        prev_s=""
      else
        if [ -z "$prev_s" ]; then
          want=a
        else
          want_rest=${alphabet#*"$prev_s"}
          want=${want_rest:0:1}
        fi
        if [ "$prev_n" -eq 0 ] || [ "$((10#$tag_n))" -ne "$prev_n" ] || [ "$tag_s" != "$want" ]; then
          if [ "$prev_n" -eq 0 ]; then
            problem "$base: paragraph $seq is tagged [$tag]; a lettered tag follows the paragraph it was added after, and nothing comes before the first"
          else
            problem "$base: paragraph $seq is tagged [$tag]; a paragraph added after [$tag_half-$prev_n$prev_s] is [$tag_half-$prev_n$want]"
          fi
        fi
        prev_n=$((10#$tag_n))
        prev_s=$tag_s
        lettered="$lettered${lettered:+, }[$tag]"
      fi
    done < <(printf '%s\n' "$tag_report" | grep '^TAG ')
    # Lettered tags are how a revision adds a paragraph without moving anyone's
    # citation, and each one is a patch on the chapter as first written. They
    # are reported so the count stays visible: a chapter collecting them is a
    # chapter due a rewrite, which is what renumbers them away
    # (../../updatebook/SKILL.md § When to stop editing in place).
    if [ -n "$lettered" ]; then
      report "$base: carries added paragraphs $lettered; rewriting the chapter renumbers them"
    fi
  else
    untagged_chapters=$((untagged_chapters + 1))
  fi

  # The paragraph and sentence stops, the callout length, and the text the two
  # repetition reports read. The walk is the tag sweep's state machine, so the
  # two agree on what a paragraph is: the header, "## In short", the concept
  # list, lists, tables, fences, figures, marks and headings are none of them.
  # A callout is read as its own unit, with its label taken off before its
  # sentences are counted, because "**Decide.**" would otherwise count as one.
  #
  # A sentence ends at a word ending in . ! or ? when the next word does not
  # start in lowercase, and never at a short abbreviation a citation uses
  # ("p. 4", "ch. 3", "e.g."). That is a guess, which is why the sentence and
  # callout figures are reported and never fail a run.
  unit_report=$(printf '%s\n' "$body" | awk -v sugg="$sugg_heading" -v ovws="$ovw_start" -v ovwe="$ovw_end" -v tagre="$tag_head_re" '
    function ends_sentence(w, nx,   core) {
      core = w
      gsub(/["\047)*`_]+$/, "", core)
      gsub(/[]]+$/, "", core)
      if (core !~ /[.!?]$/) return 0
      if (tolower(core) ~ /^(p|pp|ch|e\.g|i\.e|vs|cf|fig|dr|mr|mrs|ms)\.$/) return 0
      if (nx ~ /^[a-z]/) return 0
      return 1
    }
    # Sets nsent and slen[1..nsent]; returns the word count.
    function sentences(text,   n, i, cur, total) {
      nsent = 0; cur = 0; total = 0
      n = split(text, W, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (W[i] == "") continue
        cur++; total++
        if (i < n && ends_sentence(W[i], W[i + 1])) { slen[++nsent] = cur; cur = 0 }
      }
      if (cur > 0) slen[++nsent] = cur
      return total
    }
    function flush_para(   words, i) {
      if (!inpara) return
      words = sentences(ptext)
      print "PARA", plabel, words
      for (i = 1; i <= nsent; i++) if (slen[i] > 0) print "SENT", plabel, slen[i]
      print "TEXT", plabel, ptext
      inpara = 0; ptext = ""
    }
    function flush_quote(   i) {
      if (!inquote) return
      sentences(qtext)
      gsub(/ /, "_", qlabel)
      print "CALLOUT", qline, qlabel, nsent
      print "TEXT", "callout@" qline, qtext
      inquote = 0; qtext = ""
    }
    index($0, sugg) == 1 { flush_para(); flush_quote(); stop = 1 }
    stop { next }
    ovws && NR >= ovws && (ovwe == 0 || NR < ovwe) { flush_para(); flush_quote(); inblock = 0; blankrun = 0; next }
    /^[[:space:]]*```/ { flush_para(); flush_quote(); inblock = 0; blankrun = 0; infence = !infence; next }
    infence { next }
    /^[[:space:]]*<!--/ { flush_para(); flush_quote(); inblock = 0; blankrun = 0; next }
    /^[[:space:]]*$/ { flush_para(); flush_quote(); if (inblock) blankrun = 1; next }
    /^[[:space:]]*#/ { flush_para(); flush_quote(); inblock = 0; blankrun = 0; next }
    /^[[:space:]]*>/ {
      flush_para()
      line = $0
      sub(/^[[:space:]]*>[[:space:]]?/, "", line)
      if (!inquote) {
        inquote = 1; qline = NR; qtext = ""; qlabel = "unlabelled"
        if (match(line, /^\*\*[^*]+\.\*\*[[:space:]]*/)) {
          qlabel = substr(line, 3, RLENGTH - 3)
          sub(/\*\*[[:space:]]*$/, "", qlabel)
          sub(/\.$/, "", qlabel)
          line = substr(line, RLENGTH + 1)
        }
      }
      qtext = qtext " " line
      inblock = 0; blankrun = 0
      next
    }
    { flush_quote() }
    /^[[:space:]]*!\[[^]]*\]\([^)]*\)[[:space:]]*$/ { flush_para(); inblock = 0; blankrun = 0; next }
    /^[[:space:]]*([-*+][[:space:]]|[0-9]+\.[[:space:]]|\|)/ { flush_para(); inblock = 1; blankrun = 0; next }
    inblock && !blankrun { next }
    inblock && blankrun && /^[[:space:]]+[^[:space:]]/ { blankrun = 0; next }
    {
      inblock = 0; blankrun = 0
      line = $0
      if (!inpara) {
        inpara = 1; n++; ptext = ""
        plabel = "paragraph " n
        if (match(line, tagre)) {
          plabel = "[" substr(line, 2, RLENGTH - 3) "]"
          line = substr(line, RLENGTH + 1)
        }
        gsub(/ /, "_", plabel)
      }
      ptext = ptext " " line
    }
    END { flush_para(); flush_quote() }
  ')
  while read -r ukind ua ub uc; do
    case "$ukind" in
      PARA)
        ulabel=${ua//_/ }
        if [ "$ub" -gt "$para_max" ]; then
          if [ "$profile" = guide ]; then
            problem "$base: $ulabel runs $ub words; a paragraph stops at $para_max"
          else
            report "$base: $ulabel runs $ub words; a paragraph stops at $para_max"
          fi
        fi
        ;;
      SENT)
        ulabel=${ua//_/ }
        if [ "$ub" -gt "$sent_max" ]; then
          report "$base: a sentence in $ulabel runs $ub words; a sentence stops at $sent_max"
        fi
        ;;
      CALLOUT)
        if [ "$profile" = guide ] && [ "$uc" -gt "$callout_sent_max" ]; then
          report "$base: the ${ub//_/ } callout at body line $ua runs $uc sentences; a callout holds one idea in one to $callout_sent_max"
        fi
        ;;
    esac
  done < <(printf '%s\n' "$unit_report" | grep -E '^(PARA|SENT|CALLOUT) ')
  # Every chapter's prose goes to the recurring-phrase report, keyed by the
  # chapter so a phrase used twice in one chapter counts once.
  if [ "$is_appendix" -eq 1 ]; then ukey="A$((10#$num))"; else ukey="$((10#$num))"; fi
  printf '%s\n' "$unit_report" | awk -v k="$ukey" '$1 == "TEXT" { $1 = ""; $2 = ""; print k "\t" $0 }' >>"$phrases_file"

  # The guide summary: its length, and any run it shares with the chapter
  # below it (../reference/guide.md § In short). The carried-in line is left
  # out of both, because its words come from the glossary rather than from
  # this chapter. Guide only, because only the guide profile states either rule.
  if [ "$profile" = guide ] && [ "$ovw_present" -eq 1 ]; then
    ovw_summary=$(printf '%s\n' "$body" | awk -v start="$ovw_start" -v stop="$ovw_end" -v pfx="$ovw_carried_loose" '
      NR <= start { next }
      stop > 0 && NR >= stop { exit }
      /^[[:space:]]*<!--/ { next }
      NF == 0 { if (inpara) { inpara = 0; first = 0 } next }
      {
        if (!inpara) { inpara = 1; paras++; first = (paras == 1 && index($0, pfx) == 1) }
        if (!first) printf "%s ", $0
      }
    ')
    ovw_n=$(printf '%s' "$ovw_summary" | wc -w | tr -d ' ')
    if [ "$ovw_n" -gt "$ovw_words_max" ]; then
      report "$base: \"$ovw_heading\" runs $ovw_n words past its carried-in line; the summary stops near $ovw_words_max"
    fi
    shared=$( { printf '%s\n' "$unit_report" | awk '$1 == "TEXT" { $1 = ""; $2 = ""; print "B " $0 }'; printf 'S %s\n' "$ovw_summary"; } | awk -v run="$ovw_shared_run" '
      function toks(s, arr,   n) {
        s = tolower(s)
        gsub(/[^a-z0-9\047]+/, " ", s)
        return split(s, arr, / +/)
      }
      $1 == "B" {
        n = toks(substr($0, 3), T); m = 0
        for (i = 1; i <= n; i++) if (T[i] != "") U[++m] = T[i]
        for (i = 1; i + run - 1 <= m; i++) {
          g = U[i]; for (j = 1; j < run; j++) g = g " " U[i + j]
          seen[g] = 1
        }
        next
      }
      $1 == "S" {
        n = toks(substr($0, 3), T); m = 0
        for (i = 1; i <= n; i++) if (T[i] != "") U[++m] = T[i]
        i = 1
        while (i + run - 1 <= m) {
          g = U[i]; for (j = 1; j < run; j++) g = g " " U[i + j]
          if (g in seen) {
            k = i
            while (k + run <= m) {
              g2 = U[k + 1]; for (j = 2; j <= run; j++) g2 = g2 " " U[k + j]
              if (!(g2 in seen)) break
              k++
            }
            len = k - i + run
            out = U[i]; for (j = i + 1; j < i + run; j++) out = out " " U[j]
            print len "|" out
            i = k + run
          } else i++
        }
      }
    ')
    while IFS='|' read -r slen stext; do
      [ -n "$slen" ] || continue
      report "$base: \"$ovw_heading\" repeats $slen words of the chapter, from \"$stext ...\"; write the summary fresh"
    done <<<"$shared"
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
    prov_report=$(printf '%s\n' "$body" | awk -v sugg="$sugg_heading" -v ovws="$ovw_start" -v ovwe="$ovw_end" '
      function newunit(label) { if (started) pending = label }
      function flush() {
        if (pending != "") { print pending; missing++; pending = "" }
      }
      index($0, sugg) == 1 || $0 ~ ("^[[:space:]]*" sugg "[[:space:]]*$") { stop = 1 }
      stop { next }
      # The overview carries no mark. It is derived from the finished chapter
      # rather than from a source, so it has nothing to name, which is the same
      # reason the concept list carries none. flush() first, or the paragraph
      # before the section would be judged by the section that follows it.
      ovws && NR == ovws { flush(); inpara = 0; inblock = 0; blankrun = 0; next }
      ovws && NR > ovws && (ovwe == 0 || NR < ovwe) { inpara = 0; inblock = 0; blankrun = 0; next }
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
          if (match($0, /^\[A?[0-9]+-[0-9]+[a-z]?\] /)) {
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
  # Under narration, headings mark parts and only parts, so there is no level
  # below H2. Under guide, H3 is allowed for a named division inside a part and
  # H4 is not (../reference/guide.md § Headings):
  # two levels give a scanning reader something to land on, and three are a
  # table of contents inside a chapter.
  if [ "$profile" = guide ]; then
    if printf '%s\n' "$body" | awk '
      /^[[:space:]]*```/ { infence = !infence; next }
      infence { next }
      /^[[:space:]]*####/ { found = 1; exit }
      END { exit(found ? 0 : 1) }
    '; then
      problem "$base: body carries an H4 or deeper; the guide profile allows H2 for a part and H3 inside one, and nothing below"
    fi
  else
    if printf '%s\n' "$body" | awk '
      /^[[:space:]]*```/ { infence = !infence; next }
      infence { next }
      /^[[:space:]]*###/ { found = 1; exit }
      END { exit(found ? 0 : 1) }
    '; then
      problem "$base: body carries an H3 or deeper; headings mark parts only"
    fi
  fi
  # The overview is the other H2 that is not a part, and it comes out of the
  # count for the same reason. Where the concept list must be the last H2, this
  # one must be the first: it exists for a reader who has not read the chapter,
  # so anything of the chapter's own above it has already spent what they do not
  # have. The header table has to sit immediately before it, which is what makes
  # "first H2" a position rather than just an ordering.
  # The position rules are checks rather than recognition, so they need the
  # declaration: only a book that says it carries the section can be wrong
  # about where the section sits.
  ovw_carried=""
  if [ "$ovw_mode" = required ] && [ "$ovw_seen" -eq 1 ]; then
    if [ "$ovw_first_h2" != "$ovw_heading" ]; then
      problem "$base: \"$ovw_heading\" is not the first section; \"$ovw_first_h2\" comes before it"
    fi
    # The last thing with content before the heading must be a table row, which
    # is the chapter header and nothing else: the header is the only table that
    # may sit that high in a chapter.
    if ! printf '%s' "$ovw_before" | grep -qE '^[[:space:]]*\|'; then
      if [ -z "$ovw_before" ]; then
        problem "$base: \"$ovw_heading\" has no chapter header table before it"
      else
        problem "$base: \"$ovw_heading\" does not follow the chapter header table; found: $(printf '%s' "$ovw_before" | cut -c1-48)"
      fi
    fi
    # The carried-in line is read only from a section that is where it belongs.
    # A misplaced one has already been reported above and has no usable range,
    # so reading it here would scan the whole chapter for bolded terms.
    if [ "$ovw_present" -eq 1 ]; then
    # The carried-in line is the section's first paragraph and it is found by
    # its prefix (reference/chapter-prose.md § In short). A section whose first
    # paragraph does not carry the prefix at all is a chapter carrying nothing
    # in, which is legal and common, so absence is never a fault here. A prefix
    # that is nearly right is a different thing and is reported: without that,
    # one missing space turns both the ceiling and the glossary cross-check off
    # and a line of five terms with a forward reference passes clean.
    # The carried-in line is a paragraph, not a physical line, so it is read to
    # the blank line that ends it and joined. Reading only the first physical
    # line would count the terms on it and silently ignore the rest, which
    # passes a line of five terms whose first two happen to wrap.
    carried_line=$(printf '%s\n' "$body" | awk -v start="$ovw_start" -v stop="$ovw_end" '
      NR <= start { next }
      stop > 0 && NR >= stop { exit }
      NF == 0 { if (seen) exit; next }
      { seen = 1; printf "%s ", $0 }
    ')
    case "$carried_line" in
      "$ovw_carried_prefix"*)
        # Count the bolded terms rather than the (ch. N) references: an entry
        # typed without its reference would otherwise slip the cap and the
        # glossary cross-check together, and go unseen by both.
        ovw_carried=$(printf '%s' "$carried_line" | grep -oE '\*\*[^*]+\*\*' | sed -E 's/^\*\*//;s/\*\*$//')
        carried_n=0
        [ -n "$ovw_carried" ] && carried_n=$(printf '%s\n' "$ovw_carried" | grep -c .)
        if [ "$carried_n" -eq 0 ]; then
          problem "$base: the carried-in line names no term in bold"
        elif [ "$carried_n" -gt "$ovw_carried_max" ]; then
          problem "$base: the carried-in line names $carried_n terms and the ceiling is $ovw_carried_max"
        fi
        while IFS= read -r cterm; do
          # An appendix binds after every chapter, so it has no position in
          # the chapter sequence to compare against. Stamping it with its own
          # appendix number graded it as though it were that chapter: an
          # appendix carrying in a term taught in chapter 2 failed as "not
          # earlier than chapter 1" on a book that was correct.
          if [ "$is_appendix" -eq 1 ]; then
            [ -n "$cterm" ] && carried_records+=("A|$base|$cterm")
          else
            [ -n "$cterm" ] && carried_records+=("$((10#$num))|$base|$cterm")
          fi
        done <<<"$ovw_carried"
        ;;
      "$ovw_carried_loose"*)
        problem "$base: the carried-in line begins \"$(printf '%s' "$carried_line" | cut -c1-14)\" and the prefix must read exactly \"$ovw_carried_prefix\""
        ;;
    esac
    fi
  fi
  # An appendix carries the overview and the concept list only where they earn
  # their place, and neither is required of it
  # (../reference/guide.md § Appendices). Where one IS present it is
  # still checked, above and below, because a section that exists and sits in
  # the wrong place is a defect whatever kind of file it is in.
  if [ "$ovw_mode" = required ] && [ "$ovw_seen" -eq 0 ] && [ "$is_appendix" -eq 0 ]; then
    problem "$base: book.json declares overview but the chapter has no \"$ovw_heading\" section"
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
  elif [ "$sugg_mode" = required ] && [ "$is_appendix" -eq 0 ]; then
    problem "$base: book.json declares suggested_reading but the chapter has no \"$sugg_heading\" section"
  fi

  # One H2 per part, and a chapter's shape is two or three parts, never one or
  # four (reference/chapter-prose.md § Shape). Zero also passes: chapters written
  # before parts were headed at all are still correct prose and still bind.
  #
  # An appendix is reference matter rather than an argument: no parts, no
  # opening paragraph, no close and no handoff noun
  # (../reference/guide.md § Appendices). It carries whatever headings
  # the material wants, so the shape rule does not apply to it.
  if [ "$is_appendix" -eq 0 ]; then
    h2=$(printf '%s\n' "$body" | grep -cE '^\s*## ' || true)
    h2=$((h2 - sugg_present - ovw_present))
    case "$h2" in
      0|2|3) ;;
      *) problem "$base: body has $h2 part headings; a chapter's shape is two or three parts (0 for a chapter written before headings)" ;;
    esac
  fi

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
  #
  # Under the guide profile the ban lifts for exactly four labelled shapes and
  # stays for everything else (../reference/guide.md § Callouts). The label is matched literally, for the reason § In short gives
  # about the carried-in prefix: a checker left to infer which quotes were meant
  # as callouts has to guess, and both of its guesses read as a clean pass.
  #
  # Only the line that OPENS a quote is checked. A callout runs to four
  # sentences and its later lines carry no label, so testing every `>` line
  # would fail every callout longer than one line.
  if [ "$profile" = guide ]; then
    callout_report=$(printf '%s\n' "$body" | awk '
      /^[[:space:]]*```/ { infence = !infence; inquote = 0; next }
      infence { next }
      /^[[:space:]]*>/ {
        if (!inquote) {
          inquote = 1
          n++
          if ($0 !~ /^[[:space:]]*> \*\*(Decide|Warning|In the room|Grade this)\.\*\* [^[:space:]]/) {
            print "BAD", NR
          }
        }
        next
      }
      { inquote = 0 }
      END { print "COUNT", n + 0 }
    ')
    while IFS= read -r cline; do
      case "$cline" in
        "BAD "*)
          problem "$base: the block quote at body line ${cline#BAD } is not a callout; the guide profile allows only \"> **Decide.**\", \"> **Warning.**\", \"> **In the room.**\" and \"> **Grade this.**\", each with its label first and a sentence after"
          ;;
        "COUNT "*)
          n_callouts=${cline#COUNT }
          # A ceiling rather than a budget. A chapter with a callout every page
          # has turned the signal off: the reader stops seeing them exactly when
          # one matters. Nothing requires a chapter to carry any.
          if [ "$n_callouts" -gt "$callout_max" ]; then
            problem "$base: carries $n_callouts callouts and the ceiling is $callout_max; above that the reader stops seeing them"
          fi
          ;;
      esac
    done < <(printf '%s\n' "$callout_report")
  elif printf '%s\n' "$body" | grep -qE '^\s*> '; then
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

  # A mark key that looks like a repo path, reaching the reader's page.
  #
  # A key in book.json's `sources` map is chosen for the tooling: it is what
  # `check-provenance.sh` opens and what the marks cite. Where that key is a
  # repo path, prose citing the same string prints a path the reader cannot
  # open, in monospace, in a book they are reading on paper. The fix is a
  # display name (SKILL.md § 4), and this is the check that finds the case.
  #
  # The provenance marks are exempt by construction: they are stripped before
  # the grep, because citing the key is exactly what a mark is for. The header
  # table is exempt too, because its Draws-on row is an inventory written for
  # the operator and the reading edition moves it to the endnotes anyway.
  # What is left is prose, headings, lists and callouts, which is the page.
  if [ -n "$source_keys" ]; then
    # Fenced blocks come out too. A chapter showing the reader what a mark or a
    # book.json entry looks like has to be able to print the key verbatim, and
    # that is a quotation of the key rather than prose citing it as a source.
    readable=$(printf '%s\n' "$body" | awk '
      /^[[:space:]]*```/ { infence = !infence; next }
      infence { next }
      /^[[:space:]]*<!--/ { next }
      /^[[:space:]]*\|/ { next }
      { print }
    ')
    while IFS= read -r skey; do
      [ -n "$skey" ] || continue
      # Only a key that looks like a path. A key reading "the syllabus" or
      # "Week 5 deck" is already a name for a reader and is meant to be cited.
      printf '%s' "$skey" | grep -qE '(\.(md|py|sh|json|ya?ml|txt|csv)([^a-z0-9]|$)|/)' || continue
      if printf '%s\n' "$readable" | grep -qF "$skey"; then
        problem "$base: names the source key \"$skey\" on the page; that key is a repo path, so give the source a \"display\" name in book.json and cite that in the prose"
      fi
    done < <(printf '%s\n' "$source_keys")

    # The header is exempt above, and it still reaches the page: the default
    # edition prints the Draws-on row and the reading edition prints the same
    # text as an endnote. /makebook swaps a key for its display name in both
    # places, so a path-like key there is a problem only when it has no display
    # name. Reported, because the header is the operator's inventory and a path
    # in it is a thing to fix before binding, not a malformed book.
    header_rows=$(printf '%s\n' "$body" | awk '
      /^[[:space:]]*$/ { if (seen) exit; next }
      /^[[:space:]]*\|/ { seen = 1; print; next }
      { exit }
    ')
    if [ -n "$header_rows" ]; then
      while IFS= read -r skey; do
        [ -n "$skey" ] || continue
        printf '%s' "$skey" | grep -qE '(\.(md|py|sh|json|ya?ml|txt|csv)([^a-z0-9]|$)|/)' || continue
        printf '%s\n' "$display_keys" | grep -qxF -- "$skey" && continue
        if printf '%s\n' "$header_rows" | grep -qF -- "$skey"; then
          report "$base: the chapter header names the source key \"$skey\", a repo path with no \"display\" name in book.json, so the bound book prints the path"
        fi
      done < <(printf '%s\n' "$source_keys")
    fi
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
gloss_map=""
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
      printf "T %s|%d\n", key, ch
      n++
    }
    END { printf "N %d\n", n }
  ' "$gloss_file")
  while IFS= read -r gline; do
    case "$gline" in
      "P "*) problem "${gline#P }" ;;
      "N "*) gloss_terms="${gline#N }" ;;
      "T "*) gloss_map="$gloss_map${gline#T }
" ;;
    esac
  done <<<"$gloss_report"
  if [ "$gloss_terms" -eq 0 ]; then
    problem "$gloss_name holds no glossary entries"
  fi
fi

# The carried-in line is a reminder, so every term on it has to have been taught
# already. This is the one check that needs both declarations: the line is only
# required where the book declares `overview`, and only a glossary says which
# chapter taught what. A book with the section and no glossary keeps its prefix,
# its ceiling and its position rule, and this check goes quiet having nothing to
# resolve against.
if [ "$ovw_mode" = required ] && [ "$declared_gloss" = "true" ] && [ -f "$gloss_file" ]; then
  # bash 3.2 treats "${arr[@]}" on an empty array as unbound under `set -u`, so
  # a book where no chapter carries a term in would abort the run here with no
  # summary line at all. Same idiom as the unchecked-chapter loop below.
  for rec in ${carried_records[@]+"${carried_records[@]}"}; do
    rec_ch="${rec%%|*}"
    rec_rest="${rec#*|}"
    rec_base="${rec_rest%%|*}"
    rec_term="${rec_rest#*|}"
    rec_key=$(printf '%s' "$rec_term" | tr '[:upper:]' '[:lower:]')
    # Match the whole term, never a substring: grep -F would resolve "star
    # schema" against an entry for "binary star schema" and report a pass.
    hit_ch=$(printf '%s' "$gloss_map" | awk -F'|' -v k="$rec_key" '$1 == k { print $2; exit }')
    if [ -z "$hit_ch" ]; then
      problem "$rec_base: the carried-in line names \"$rec_term\", which $gloss_name does not define"
      continue
    fi
    if [ "$hit_ch" -eq 0 ]; then
      problem "$rec_base: the carried-in line names \"$rec_term\", which $gloss_name defines without a chapter number"
    elif [ "$rec_ch" = A ]; then
      # An appendix is after every chapter, so every chapter is earlier than it
      # and the ordering check has nothing left to say. The two checks above
      # still apply: the term must be defined, and defined against a chapter.
      :
    elif [ "$hit_ch" -ge "$rec_ch" ]; then
      problem "$rec_base: the carried-in line names \"$rec_term\", taught in chapter $hit_ch, which is not earlier than chapter $rec_ch"
    fi
  done
fi

# Phrases recurring across chapters. A wrong-model passage written from a
# template comes out in the same words each time ("suggests itself", "the
# obvious move is"), and so does any other stock move. A four-word run is
# counted once per chapter, and only runs holding at least two words that are
# not function words, so "at the end of" never fires. Reported and never
# failed: a book's own vocabulary recurs by design, and only a reader can tell
# a term from a tic (../reference/guide.md § The wrong model).
if [ -s "$phrases_file" ]; then
  phrase_lines=$(awk -F'\t' -v len="$phrase_len" -v minch="$phrase_chapters" '
    BEGIN {
      n = split("a an the and or but so of to in on at by for with from as is are was were be been being it its this that these those there here which who whom what when where how why not no do does did has have had will would can could should may might must you your they their them he she his her we our i me my if than then into out up down over about all each every any some more most other only also just same such own both before after once again very s t", SW, " ")
      for (i = 1; i <= n; i++) stop[SW[i]] = 1
    }
    {
      ch = $1
      text = tolower($2)
      gsub(/[^a-z0-9\047]+/, " ", text)
      m = split(text, T, / +/)
      k = 0
      for (i = 1; i <= m; i++) { w = T[i]; gsub(/^\047+|\047+$/, "", w); if (w != "") U[++k] = w }
      for (i = 1; i + len - 1 <= k; i++) {
        content = 0
        g = ""
        for (j = 0; j < len; j++) {
          g = g (j ? " " : "") U[i + j]
          if (!(U[i + j] in stop)) content++
        }
        if (content < 2) continue
        if ((g, ch) in seen) continue
        seen[g, ch] = 1
        count[g]++
        chs[g] = chs[g] (chs[g] == "" ? "" : ", ") ch
      }
    }
    END { for (g in count) if (count[g] >= minch) print count[g] "\t" g "\t" chs[g] }
  ' "$phrases_file" | sort -t'	' -k1,1nr -k2,2)
  if [ -n "$phrase_lines" ]; then
    phrase_total=$(printf '%s\n' "$phrase_lines" | grep -c .)
    shown=0
    while IFS='	' read -r pcount pgram pchs; do
      [ -n "$pcount" ] || continue
      [ "$shown" -lt "$phrase_report_max" ] || break
      report "\"$pgram\" recurs in $pcount chapters ($pchs); read them for a phrase written from a template"
      shown=$((shown + 1))
    done <<<"$phrase_lines"
    if [ "$phrase_total" -gt "$phrase_report_max" ]; then
      echo "        and $((phrase_total - phrase_report_max)) more recurring phrases, not listed"
    fi
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
# The profile leads the summary line because it decides what every figure after
# it was graded against. A run that silently applied the wrong rule set is the
# failure this makes visible, the way "(inferred)" does for the tag mode.
echo "profile: $profile    chapters: ${#chapters[@]}    content-checked: $checked    tagged: $tagged_chapters/$checked ($tag_mode)    prose: $total_words    structure: $total_struct    overview: $total_ovw ($ovw_mode)    provenance: $prov_mode    suggested reading: $sugg_mode    glossary: $gloss_note    folder: $dir"
# Guarded because a run where every chapter's filename was rejected reaches here
# with nothing counted, and a mean over zero chapters would abort the script one
# line before it reports what went wrong.
if [ "$checked" -gt 0 ]; then
  # Rounded to nearest, not truncated, so this agrees with the average quoted in
  # SKILL.md and NOTES.md rather than sitting a word below it.
  echo "chapter prose: mean $(((total_words + checked / 2) / checked))    longest $longest_words in $longest_chapter"
fi
# Reports are counted apart from failures, so a run that passes with ten of
# them is not mistaken for a clean one, and a run that fails says how many of
# its lines were only reports.
if [ "$reports" -gt 0 ]; then
  echo "reports: $reports    none of them fails the run; each is a thing to read"
fi
if [ "$tag_mode" = "inferred" ]; then
  echo "note: this book neither declares \"tags\" in book.json nor was given a flag,"
  echo "      so the tag state was inferred from the chapters. A book where every"
  echo "      chapter forgot its tags is indistinguishable from an untagged book."
fi
# A book.json that exists and could not be read is the case worth naming, and
# the profile is the half that fails loudest: without jq the declaration reads
# as absent, the narration rules apply, and a guide book fails on every H3 and
# every callout it was written to carry. Those failures are true of the rules
# that ran and say nothing about the book, so the run says which rules ran and
# why rather than leaving the operator to read a screen of them and guess.
if [ -f "$dir/book.json" ] && ! command -v jq >/dev/null 2>&1; then
  echo "note: book.json is present and jq is not, so no declaration in it was read."
  echo "      This run used the $profile rules because that is the default, not"
  echo "      because the book asked for them. Install jq before trusting a"
  echo "      failure list from this run: a guide-profile book checked under the"
  echo "      narration rules fails on every construct the profile exists to allow."
fi
# The overview has no end marker of its own, so the sweeps find its end at the
# chapter's first paragraph tag, or failing that at the first paragraph a
# provenance mark names. A chapter offering neither ends the section at its
# first part heading, which puts the opening paragraph inside it. In a book
# carrying provenance that is one paragraph per chapter whose mark nothing
# checked, and a missing mark there is self-concealing: it is the very thing
# the sweep would have used to find the boundary.
if [ "$ovw_fallback" -gt 0 ]; then
  echo "note: $ovw_fallback chapter(s) carry no paragraph tag and no provenance mark to"
  echo "      end \"$ovw_heading\", so it was ended at the next part heading, or at the"
  echo "      end of the file where there was none. Everything inside that span counts"
  echo "      as overview rather than prose and is exempt from the tag and provenance"
  echo "      sweeps and from the paragraph stop, so the figures above understate the"
  echo "      prose, a chapter's opening paragraph went unswept, and under the guide"
  echo "      profile its words count toward the summary's length and shared-run"
  echo "      reports. Declaring \"tags\" ends the section exactly."
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
