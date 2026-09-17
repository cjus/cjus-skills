#!/bin/sh
# Resolved council seating: who actually gets seated, on what, and what
# correlation that projects. Read-only; writes nothing, anywhere.
#
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/council-state.sh" [--text|--json] [--no-probe]
#
# WHY THIS EXISTS
#
# Seating is a JOIN across two sources that disagree in practice, and until now
# the model performed it by hand from a 40-line detection summary while a prose
# warning said that summary "is not the source of truth". Prose instructions are
# the ones that get skipped. This is the mechanical version.
#
#   availability  -- is there a key, does the endpoint answer, is the CLI installed
#   consent       -- the roster's `enabled` flags, which are the user's decision
#
# A member needs BOTH. The interesting case is not hypothetical: a roster can
# carry `"openrouter": { "enabled": true }` with four vetted models while no key
# resolves anywhere, and those four members are then silently not seated. The
# council still runs, still agrees with itself, and reports HOMOGENEOUS -- which
# is correct but reads like a roster problem rather than a key problem.
#
# WHY sh, AND WHY EITHER PARSER
#
# The driver is sh so that a status read never demands a Node install from
# someone whose council never leaves Claude. But nothing is installed when a
# plugin is installed -- the manifest has no dependency step -- so requiring jq
# instead would simply have moved that burden, and onto the same Claude-only path.
# The roster is read through jq OR Node, whichever is present (see
# council-lib.sh:council_roster_rows), and only the absence of BOTH is fatal.
# Either is a real parser; the pure-sh alternative is regex-scraping nested JSON,
# which is how you get a confident, wrong answer about what a council costs.
#
# Correlation here is always PROJECTED. `COLLAPSED` -- every model override
# failing so that N members all ran on the session model -- is only observable
# after the subagents land, so a script genuinely cannot predict it.

set -u

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COUNCIL_SCRIPT_DIR="$DIR"
. "$DIR/council-lib.sh"

FORMAT=text
PROBE=1
for arg in "$@"; do
  case "$arg" in
    --text) FORMAT=text ;;
    --json) FORMAT=json ;;
    --no-probe) PROBE=0 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) printf 'council-state: unknown argument %s\n' "$arg" >&2; exit 2 ;;
  esac
done

die() { printf 'council-state: %s\n' "$1" >&2; exit 2; }

ROSTER=$(council_roster_path)
ROSTER_DISPLAY=$(council_display_path "$ROSTER")

TMP=$(mktemp -d) || die "cannot create a temporary directory"
trap 'rm -rf "$TMP"' EXIT INT TERM
SEATED="$TMP/seated"; UNSEATED="$TMP/unseated"
: > "$SEATED"; : > "$UNSEATED"

seat()   { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$SEATED"; }
unseat() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$UNSEATED"; }

# ── key ───────────────────────────────────────────────────────────────────────
COUNCIL_KEY_MODE_WARN=''
if council_resolve_key; then KEY_PRESENT=1; else KEY_PRESENT=0; fi

# ── roster ────────────────────────────────────────────────────────────────────
# Absent is legitimate and means a Claude-only council. Malformed is NOT: it must
# fail rather than fall back, because a roster that fails to parse and a roster
# with no external members produce an identical Claude-only answer, and one of
# those is a file the user believes is in effect.
ROSTER_STATE=present
ROWS="$TMP/rows"; : > "$ROWS"
if [ ! -e "$ROSTER" ]; then
  ROSTER_STATE=absent
elif [ ! -r "$ROSTER" ]; then
  die "$ROSTER_DISPLAY exists but is not readable. Refusing to report seating that would look like a Claude-only council."
else
  ERRF="$TMP/rows.err"
  # Capture the status BEFORE any other command runs, and without wrapping the
  # call in `if !`: POSIX defines `!` as replacing the status with its logical
  # negation, so `$?` inside the `then` branch is 0 and the dispatch below would
  # never see a 3.
  council_roster_rows "$ROSTER" > "$ROWS" 2>"$ERRF"
  RC=$?
  if [ "$RC" -ne 0 ]; then
    case "$RC" in
      3) die "$(head -1 "$ERRF"). Install either and re-run; refusing to guess at seating." ;;
      *) die "$ROSTER_DISPLAY: $(head -1 "$ERRF"). Refusing to report seating that would look like a Claude-only council." ;;
    esac
  fi
fi

# The roster is now a flat TSV and nothing below this line knows it was JSON.
meta()    { awk -F'\t' -v k="$1" '$1=="meta" && $2==k {print $3; exit}' "$ROWS"; }
members() { awk -F'\t' -v k="$1" '$1=="member" && $2==k {print $3 "\t" $4}' "$ROWS"; }

if [ "$ROSTER_STATE" = present ]; then
  MAXCONC=$(meta maxConcurrentExternal); [ -n "$MAXCONC" ] || MAXCONC=2
  # Claude members carry no `enabled` flag: being listed IS the consent.
  members claude | while IFS="$(printf '\t')" read -r stance model; do
    [ -n "${stance:-}" ] && seat "$stance" claude "$model" anthropic
  done

  # OpenRouter: consent from the roster, availability from the key chain.
  if [ "$(meta openrouter.enabled)" = true ]; then
    members openrouter \
      | while IFS="$(printf '\t')" read -r stance id; do
          [ -n "${stance:-}" ] || continue
          vendor=${id%%/*}; [ "$vendor" = "$id" ] && vendor=openrouter
          if [ "$KEY_PRESENT" = 1 ]; then seat "$stance" openrouter "$id" "$vendor"
          else unseat "$stance" openrouter "$id" "no key resolves"; fi
        done
  fi

  # Ollama: local and free, so it stays seated when the OpenRouter key is absent,
  # which is what keeps a roster cross-vendor in exactly that case.
  if [ "$(meta ollama.enabled)" = true ]; then
    RAW_ENDPOINT=$(meta ollama.endpoint)
    [ -n "$RAW_ENDPOINT" ] || RAW_ENDPOINT="http://localhost:11434"
    ENDPOINT=$(council_normalize_endpoint "$RAW_ENDPOINT")
    REACH=unknown
    if [ "$PROBE" = 1 ]; then
      CURL=$(council_find_bin curl) || CURL=''
      if [ -n "$CURL" ]; then
        if "$CURL" -fsS -m 3 "$ENDPOINT/api/tags" >/dev/null 2>&1; then REACH=up; else REACH=down; fi
      fi
    fi
    members ollama \
      | while IFS="$(printf '\t')" read -r stance id; do
          [ -n "${stance:-}" ] || continue
          case "$REACH" in
            up)      seat "$stance" ollama "$id" local ;;
            down)    unseat "$stance" ollama "$id" "endpoint not answering" ;;
            unknown) seat "$stance" ollama "$id" local ;;
          esac
        done
  fi

  # Codex seats a single member and carries no model list.
  if [ "$(meta codex.enabled)" = true ]; then
    if council_find_bin codex >/dev/null 2>&1; then seat "-" codex "(cli)" openai
    else unseat "-" codex "(cli)" "codex CLI not installed"; fi
  fi
else
  MAXCONC=2
fi

N_SEATED=$(wc -l < "$SEATED" | tr -d ' ')
count_kind() { [ -s "$SEATED" ] && awk -F'\t' -v k="$1" '$2==k{n++} END{print n+0}' "$SEATED" || echo 0; }
N_CLAUDE=$(count_kind claude); N_OR=$(count_kind openrouter)
N_OLL=$(count_kind ollama);    N_CODEX=$(count_kind codex)

VENDORS=''
if [ -s "$SEATED" ]; then
  VENDORS=$(awk -F'\t' '{print $4}' "$SEATED" | sort -u | tr '\n' ' ' | sed 's/ $//')
fi
N_VENDORS=$(printf '%s' "$VENDORS" | wc -w | tr -d ' ')
# Count first, then make it readable: the count drives the correlation class and
# must not depend on how the list is punctuated.
VENDORS=$(printf '%s' "$VENDORS" | sed 's/ /, /g')

if [ "$N_SEATED" -eq 0 ]; then
  CLASS=NONE
elif [ "$N_VENDORS" -le 1 ]; then
  CLASS=HOMOGENEOUS
else
  CLASS=CROSS-VENDOR
fi

# ── report ────────────────────────────────────────────────────────────────────
if [ "$FORMAT" = json ]; then
  # The fourth column means different things in the two files -- a vendor for a
  # seated member, a reason for an unseated one -- so it is NAMED differently.
  # Calling both "note" would hand a consumer `.seated[].note == "anthropic"`.
  rows() { # file, name-of-fourth-field -> JSON array
    if [ -s "$1" ]; then
      awk -F'\t' -v q='"' -v f4="$2" 'BEGIN{printf "["} {printf "%s{%sstance%s:%s%s%s,%skind%s:%s%s%s,%smodel%s:%s%s%s,%s%s%s:%s%s%s}", (NR>1?",":""), q,q,q,$1,q, q,q,q,$2,q, q,q,q,$3,q, q,f4,q,q,$4,q} END{printf "]"}' "$1"
    else printf '[]'; fi
  }
  printf '{"key":{"present":%s,"source":%s},"roster":{"path":"%s","state":"%s"},' \
    "$([ "$KEY_PRESENT" = 1 ] && echo true || echo false)" \
    "$([ "$KEY_PRESENT" = 1 ] && printf '"%s"' "$COUNCIL_KEY_SOURCE" || echo null)" \
    "$ROSTER_DISPLAY" "$ROSTER_STATE"
  printf '"seating":{"claude":%s,"openrouter":%s,"ollama":%s,"codex":%s,"total":%s},' \
    "$N_CLAUDE" "$N_OR" "$N_OLL" "$N_CODEX" "$N_SEATED"
  printf '"seated":%s,"notSeated":%s,' "$(rows "$SEATED" vendor)" "$(rows "$UNSEATED" reason)"
  printf '"projectedCorrelation":"%s","vendors":"%s","maxConcurrentExternal":%s}\n' \
    "$CLASS" "$VENDORS" "$MAXCONC"
  exit 0
fi

if [ "$KEY_PRESENT" = 1 ]; then
  printf 'key:      %s present (from %s)\n' "$COUNCIL_KEY_NAME" "$COUNCIL_KEY_SOURCE"
  [ -n "${COUNCIL_KEY_MODE_WARN:-}" ] && printf '          warning: %s\n' "$COUNCIL_KEY_MODE_WARN"
else
  printf 'key:      %s absent -- OpenRouter members cannot be seated\n' "$COUNCIL_KEY_NAME"
fi

if [ "$ROSTER_STATE" = absent ]; then
  printf 'roster:   NONE at %s -- Claude-only council\n' "$ROSTER_DISPLAY"
else
  printf 'roster:   %s\n' "$ROSTER_DISPLAY"
fi

printf 'seating:  %s claude + %s openrouter + %s ollama + %s codex  (%s seated)\n' \
  "$N_CLAUDE" "$N_OR" "$N_OLL" "$N_CODEX" "$N_SEATED"
if [ -s "$SEATED" ]; then
  while IFS="$(printf '\t')" read -r stance kind model vendor; do
    printf '  %-18s %-11s %s\n' "$stance" "$kind" "$model"
  done < "$SEATED"
fi

if [ -s "$UNSEATED" ]; then
  printf 'not seated (consented in the roster, unavailable here):\n'
  while IFS="$(printf '\t')" read -r stance kind model why; do
    printf '  %-18s %-11s %-34s (%s)\n' "$stance" "$kind" "$model" "$why"
  done < "$UNSEATED"
fi

case "$CLASS" in
  NONE)         printf 'projected correlation: NONE -- no members would be seated\n' ;;
  HOMOGENEOUS)  printf 'projected correlation: HOMOGENEOUS (%s) -- one vendor; agreement is weak evidence\n' "$VENDORS" ;;
  CROSS-VENDOR) printf 'projected correlation: CROSS-VENDOR (%s)\n' "$VENDORS" ;;
esac
printf 'concurrency: maxConcurrentExternal %s\n' "$MAXCONC"
printf 'note: projected. COLLAPSED -- every override failing onto one model -- is\n'
printf '      only observable after the members answer, so this cannot predict it.\n'
