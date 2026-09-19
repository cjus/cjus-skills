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
# An ABSENT roster is not an empty one. It seats the four default Claude members
# declared in council-lib.sh and projects HOMOGENEOUS (anthropic), which is the
# honest reading of four members from one vendor. `NONE` is reserved for a roster
# that is present and declares nobody.
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
  #
  # A pin the harness will not accept is caught HERE rather than at spawn time.
  # `model` is a closed enum (council-lib.sh:COUNCIL_ACCEPTED_PINS) while the
  # roster's `model` is free-form JSON, so an unacceptable pin is easy to write
  # and would otherwise surface as an InputValidationError partway through a
  # fan-out that has already started spending.
  #
  # `-` is the backends' marker for a member that declared NO model, and that is
  # not an error: it seats with no pin and runs on the session model, adding no
  # model diversity. "declared no pin" and "declared a pin that cannot exist" are
  # different facts and must not print alike.
  members claude | while IFS="$(printf '\t')" read -r stance model; do
    [ -n "${stance:-}" ] || continue
    if [ "$model" = "-" ] || council_pin_is_accepted "$model"; then
      seat "$stance" claude "$model" anthropic
    else
      unseat "$stance" claude "$model" "not a model this harness accepts ($COUNCIL_ACCEPTED_PINS_DISPLAY)"
    fi
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
        # The endpoint may carry basic-auth userinfo, and an argument is visible
        # in the process table to every other user on the box for the life of the
        # probe. `-K -` takes the URL on stdin instead, so it never reaches argv.
        if printf 'url = "%s"\n' "$ENDPOINT/api/tags" | "$CURL" -fsS -m 3 -K - >/dev/null 2>&1
        then REACH=up; else REACH=down; fi
      fi
    fi
    # `unknown` is a third state and has to survive into the report. Collapsing
    # it into the confident branch at render time is what turns a skipped probe
    # into a CROSS-VENDOR claim, which is an over-claim in the exact direction
    # the honesty contract exists to prevent. The member is still seated -- not
    # having a prober is no reason to unseat it -- but the uncertainty is stated.
    [ "$REACH" = unknown ] && PROBE_SKIPPED=1
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
  # An absent roster is the documented normal case, and it seats the four default
  # members rather than nobody. Reporting `0 seated` here contradicted the line
  # two rows above it -- `roster: NONE ... Claude-only council` -- and answered a
  # question nobody asks: people open this to learn what the next council will
  # do, not what a file says. The defaults are declared once in council-lib.sh so
  # this join and skills/ask cannot disagree about who is in the room, and they
  # arrive in the same `stance<TAB>model` shape as a declared member, so nothing
  # below this point needs a branch for them.
  MAXCONC=2
  council_default_members | while IFS="$(printf '\t')" read -r stance model; do
    [ -n "${stance:-}" ] && seat "$stance" claude "$model" anthropic
  done
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

# NONE is now reachable ONLY from a roster that is present and declares no
# members, which is what makes its message ("the roster declares no members")
# exactly true. It used to fire for an absent roster too, where it was false.
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
  # Every string here comes from the roster, which is user-authored, so it is
  # outside this program and must be escaped. A stance reading `the "paranoid"
  # one` otherwise closes the JSON string early and the consumer's parse fails --
  # and a parse failure at that layer is likely handled as "no seating
  # information", landing straight back on a confidently-wrong seating table.
  rows() { # file, name-of-fourth-field -> JSON array
    if [ -s "$1" ]; then
      awk -F'\t' -v f4="$2" '
        function esc(s) {
          gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
          gsub(/\t/, "\\t", s); gsub(/\r/, "\\r", s); gsub(/\n/, "\\n", s)
          return s
        }
        BEGIN { printf "[" }
        { printf "%s{\"stance\":\"%s\",\"kind\":\"%s\",\"model\":\"%s\",\"%s\":\"%s\"}",
                 (NR>1 ? "," : ""), esc($1), esc($2), esc($3), f4, esc($4) }
        END { printf "]" }' "$1"
    else printf '[]'; fi
  }
  # maxConcurrentExternal is emitted unquoted as a JSON number, so a roster that
  # types it as a string or a bool would produce `:two` or `:false`. Anything
  # that is not a plain integer falls back to the documented default.
  case "$MAXCONC" in ''|*[!0-9]*) MAXCONC=2 ;; esac
  printf '{"key":{"present":%s,"source":%s},"roster":{"path":"%s","state":"%s"},' \
    "$([ "$KEY_PRESENT" = 1 ] && echo true || echo false)" \
    "$([ "$KEY_PRESENT" = 1 ] && printf '"%s"' "$COUNCIL_KEY_SOURCE" || echo null)" \
    "$ROSTER_DISPLAY" "$ROSTER_STATE"
  printf '"seating":{"claude":%s,"openrouter":%s,"ollama":%s,"codex":%s,"total":%s},' \
    "$N_CLAUDE" "$N_OR" "$N_OLL" "$N_CODEX" "$N_SEATED"
  printf '"seated":%s,"notSeated":%s,' "$(rows "$SEATED" vendor)" "$(rows "$UNSEATED" reason)"
  printf '"projectedCorrelation":"%s","vendors":"%s","ollamaProbed":%s,"maxConcurrentExternal":%s}\n' \
    "$CLASS" "$VENDORS" "$([ "${PROBE_SKIPPED:-0}" = 1 ] && echo false || echo true)" "$MAXCONC"
  exit 0
fi

if [ "$KEY_PRESENT" = 1 ]; then
  printf 'key:      %s present (from %s)\n' "$COUNCIL_KEY_NAME" "$COUNCIL_KEY_SOURCE"
  [ -n "${COUNCIL_KEY_MODE_WARN:-}" ] && printf '          warning: %s\n' "$COUNCIL_KEY_MODE_WARN"
else
  printf 'key:      %s absent -- OpenRouter members cannot be seated\n' "$COUNCIL_KEY_NAME"
fi
[ -n "${COUNCIL_KEY_WARN:-}" ] && printf '          warning: %s\n' "$COUNCIL_KEY_WARN"

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

UNCONFIRMED=''
[ "${PROBE_SKIPPED:-0}" = 1 ] && UNCONFIRMED=' -- ollama was not probed, so this diversity is unconfirmed'
case "$CLASS" in
  NONE)         printf 'projected correlation: NONE -- the roster declares no members\n' ;;
  HOMOGENEOUS)  printf 'projected correlation: HOMOGENEOUS (%s) -- one vendor; agreement is weak evidence\n' "$VENDORS" ;;
  CROSS-VENDOR) printf 'projected correlation: CROSS-VENDOR (%s)%s\n' "$VENDORS" "$UNCONFIRMED" ;;
esac
printf 'concurrency: maxConcurrentExternal %s\n' "$MAXCONC"
printf 'note: projected. COLLAPSED -- every override failing onto one model -- is\n'
printf '      only observable after the members answer, so this cannot predict it.\n'
