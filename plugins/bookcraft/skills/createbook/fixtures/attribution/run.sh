#!/usr/bin/env bash
#
# Which book a citation cites, and what check 2 reads a quotation against, in
# check-references.sh (#72). The book here is the Field Guide; the Companion
# Guide is only ever named. Every case below was reported differently, or not at
# all, before #72:
#
#   two-books.md        cites both books. A companion chapter reference is left
#                       to the companion's check; a missing chapter named in its
#                       own sentence fails; one whose block names this book only
#                       in another sentence reviews; a quotation of a companion
#                       chapter is not read against this book; a tag beside the
#                       companion's name is still this book's; `ch.` and `e.g.`
#                       end no sentence; and a key row whose book was read from
#                       another sentence reviews rather than fails
#   companion-notes.md  every tag is the companion's, so none resolves here
#   file-sourced.md     each quotation is read against the file it names: a
#                       misquote fails in a key row and reviews in prose, and a
#                       name two files share reads both
#   self-named.md       a quotation naming the quoting file's own name is never
#                       "found" in itself
#   fences.md           a ~~~ fence, a four-backtick fence holding a ``` line and
#                       a fenced declaration are code, not citations, and a line
#                       opening ```inline``` opens no fence
#   unclosed.md         a fence nothing closes is reported, not read as the end
#   undeclared.md       a file declaring nothing reads as it always did
#   no-default.md,      declarations this run cannot read against the book
#   not-this-book.md,   fail, and so does any declaration against a book whose
#   blank-name.md       book.json has no "cited_as"
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when every assertion holds, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
check="$here/../../scripts/check-references.sh"

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}
# expect <label> <exit> <output> <want-exit> <string>...; a leading ! means the
# output must NOT carry the string.
expect() {
  label=$1; rc=$2; out=$3; want=$4; shift 4
  bad=""
  [ "$rc" -eq "$want" ] || bad="exit $rc, wanted $want"
  for s in "$@"; do
    case "$s" in
      '!'*) if printf '%s\n' "$out" | grep -qF -- "${s#!}"; then bad="$bad; must not say: ${s#!}"; fi ;;
      *)    printf '%s\n' "$out" | grep -qF -- "$s" || bad="$bad; missing: $s" ;;
    esac
  done
  if [ -z "$bad" ]; then report 0 "$label"; else
    report 1 "$label: $bad"; printf '%s\n' "$out" | sed 's/^/      | /'
  fi
}
# Run from the book folder, so a copy installed outside any git repository
# still finds the named files: check 2 searches the book's repository, and the
# working directory when there is none.
run() {  # run <book folder> <referring file>
  out=$(cd "$1" && "$check" --no-baseline . "referring/$2.md" 2>&1); rc=$?
}

run "$here" two-books
expect "two-books: each citation is read against the book it names" "$rc" "$out" 1 \
  "FAIL  two-books.md:16: cites chapter 8, which the book does not have" \
  "REVIEW  two-books.md:18: cites chapter 9, which the book does not have; its block names this book" \
  "two-books.md:10: chapter 9 of The Companion Guide" \
  "two-books.md:12: chapter 7 of The Companion Guide" \
  "two-books.md:20: a quotation of chapter 2 of The Companion Guide" \
  "FAIL  two-books.md:24: cites chapter 8, which the book does not have" \
  "FAIL  two-books.md:26: cites chapter 7, which the book does not have" \
  "REVIEW  two-books.md:28: quotes text that is in no chapter of the book (this book read from a name outside the reference's sentence)" \
  "references: 9    quotations: 2" "tag citations: 3    unresolved: 0" \
  "!FAIL  two-books.md:10" "!FAIL  two-books.md:12" "!FAIL  two-books.md:18" \
  "!REVIEW  two-books.md:20" "!FAIL  two-books.md:28"

run "$here" companion-notes
expect "companion-notes: another book's tags are left to its own check" "$rc" "$out" 0 \
  "companion-notes.md: 2 paragraph-tag citations of Companion Guide" \
  "every paragraph-tag citation among these files is of another book" \
  "the citations of another book noted above were left to" \
  "references: 1" "!cites [4-12]" "!cites [1-9]"

run "$here" file-sourced
expect "file-sourced: a quotation is read against the file it names" "$rc" "$out" 1 \
  "REVIEW  file-sourced.md:5: quotes text that is not in attribution-notes.md, the file it names" \
  "FAIL  file-sourced.md:9: key row quotes text that is not in attribution-notes.md, the file it names" \
  "file-sourced.md:3: found in attribution-notes.md" \
  "file-sourced.md:11: found in shared-notes.md (read all 2 files with that name)" \
  "!could not check"

run "$here" self-named
expect "self-named: a file is never the source it quotes" "$rc" "$out" 0 \
  "self-named.md:1: sourced to self-named.md, which this run can see only as the file quoting it" \
  "OK*   nothing failed, and 1 quotation(s) were sourced to a named file this run could not check" \
  "!found in self-named.md"

run "$here" fences
expect "fences: a fence is what CommonMark says it is" "$rc" "$out" 0 \
  "references: 2" "tag citations: 1    unresolved: 0" \
  "!cites chapter 9" "!cites [9-9]" "!cites [9-8]" "!REVIEW" "!were left to"

run "$here" unclosed
expect "unclosed: a fence nothing closes is reported" "$rc" "$out" 0 \
  "REVIEW  unclosed.md:3: a fence opens here and nothing closes it, so nothing after it was checked" \
  "OK*" "!cites chapter 9"

run "$here" undeclared
expect "undeclared: a file declaring nothing cites only this book" "$rc" "$out" 1 \
  "FAIL  undeclared.md:1: cites chapter 5, which the book does not have" \
  "references: 2" "tag citations: 1    unresolved: 0"

run "$here" no-default
expect "no-default: two books and no default is refused" "$rc" "$out" 1 \
  "FAIL  no-default.md: declares 2 books and marks 0 of them (default)" \
  "nothing in it was checked" "references: 0"

run "$here" blank-name
expect "blank-name: a declaration naming no book is refused" "$rc" "$out" 1 \
  "FAIL  blank-name.md: line 1 declares a book with no name; nothing in it was checked"

run "$here" not-this-book
expect "not-this-book: a declaration naming neither of this book's names is refused" "$rc" "$out" 1 \
  "none is a name this book's \"cited_as\" lists (Field Guide, the field book)"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$here" "$tmp/plain"
printf '{ "tags": true }\n' >"$tmp/plain/book.json"
run "$tmp/plain" two-books
expect "no cited_as: a declared file cannot be matched to this book" "$rc" "$out" 1 \
  "lists no \"cited_as\" names to match one against; nothing in it was checked"

printf '{ "tags": true, "cited_as": "Field Guide" }\n' >"$tmp/plain/book.json"
run "$tmp/plain" undeclared
expect "cited_as must be a list" "$rc" "$out" 2 \
  "\"cited_as\" must be a list of names"

exit "$fails"
