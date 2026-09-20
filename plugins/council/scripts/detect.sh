#!/bin/sh
# Council capability probe. Runs at skill load via !`...` injection.
#
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/detect.sh"
#
# Exits 0 on every path it reports on, by design. An injected command that fails
# can abort the skill invocation, so there are two guards: the call sites append
# `|| echo "detection unavailable"`, and nothing below propagates a failure. Keep
# both -- belt and braces. `set -u` is the one thing that can still exit non-zero,
# and that trade is deliberate: a mistyped variable would otherwise expand to
# empty and print a confidently wrong availability line, which is the failure this
# whole layer exists to prevent. Aborting lands on the call sites' guard instead.
#
# Reports AVAILABILITY only. It never decides what gets seated -- that is the
# roster's job, and `/council:status` is what performs the join. Availability is
# not consent.
#
# WHY THIS SOURCES council-lib.sh
#
# The key-resolution chain has two implementations, not three: the Node side that
# needs the key's VALUE, and the sh side shared by this script and
# council-state.sh, which must not require a Node install. Re-deriving the chain
# here is what made the original diverge -- its `grep` did not accept
# `export KEY=value`, so it printed "absent -- do NOT seat" for a key the Node
# side resolved and spent. `test-detect.sh` replays test-env.sh's oracle table
# against what this script PRINTS, because the printed line is the artifact a
# model acts on.

set -u

# `$0` is this script: it is always run as `sh .../scripts/detect.sh`, never
# sourced, so a sourced file's inability to find its own path does not apply.
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || DIR=''
LIB="$DIR/council-lib.sh"
if [ -z "$DIR" ] || [ ! -r "$LIB" ]; then
  # Degrade exactly as the call sites' `|| echo` would, but name the cause: a
  # bare "detection unavailable" sends the reader looking at their own machine.
  echo "detection unavailable: cannot read council-lib.sh beside this script"
  exit 0
fi
COUNCIL_SCRIPT_DIR="$DIR"
. "$LIB"

ROSTER=$(council_roster_path)
ROSTER_DISPLAY=$(council_display_path "$ROSTER")

# ── Local CLIs ────────────────────────────────────────────────────────────────
for t in codex ollama; do
  if p=$(council_find_bin "$t"); then echo "$t-cli: FOUND $p"; else echo "$t-cli: absent"; fi
done

# ── Ollama endpoint: roster > $OLLAMA_HOST > localhost ────────────────────────
# The roster is SCRAPED here, not parsed. Parsing means jq or Node (see
# council_roster_rows), and this script runs on every skill load, where a machine
# with neither must still get a context block rather than an error. The scrape
# only ever selects what to probe; `/council:status` performs the authoritative
# read and refuses rather than guesses when the file will not parse.
RAW=''
if [ -f "$ROSTER" ] && [ -r "$ROSTER" ]; then
  RAW=$(sed -n 's/.*"endpoint"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROSTER" 2>/dev/null | head -1)
fi
SRC=roster
if [ -z "$RAW" ] && [ -n "${OLLAMA_HOST:-}" ]; then RAW="$OLLAMA_HOST"; SRC='$OLLAMA_HOST'; fi
if [ -z "$RAW" ]; then RAW='http://localhost:11434'; SRC=default; fi

# OLLAMA_HOST is BOTH the server-bind and the client-target variable, and its
# default port depends on whether a scheme is present: bare `host` -> :11434, but
# `http://host` -> :80. council_normalize_endpoint supplies the port for a bare
# host and deliberately leaves a scheme'd value alone, so a scheme WITHOUT a port
# is called out here rather than silently probed on the wrong port.
PORT_NOTE=''
case "$RAW" in
  http://*|https://*)
    hostpart=$(printf '%s' "$RAW" | sed 's|^https\{0,1\}://||; s|/.*$||; s|^[^@]*@||')
    case "$hostpart" in
      *:[0-9]*) : ;;
      *) PORT_NOTE=' [WARNING: no port given with a scheme -> defaults to :80/:443, NOT :11434]' ;;
    esac ;;
esac
ENDPOINT=$(council_normalize_endpoint "$RAW")

echo "ollama-endpoint: $(council_redact "$ENDPOINT") (from $SRC)$PORT_NOTE"

# Require the top-level "models" key: /api/tags emits it unconditionally, so this
# distinguishes a real Ollama from any other service answering 200 on the port --
# and does NOT reject a healthy server that has no models pulled yet.
CURL=$(council_find_bin curl) || CURL=''
if [ -z "$CURL" ]; then
  # Not probed and not reachable are different facts, and collapsing them reports
  # a down server for one that was never asked. council-state.sh keeps the same
  # third state rather than folding it into the confident branch.
  echo "ollama-server: NOT PROBED -- no curl on this machine"
else
  # The endpoint may carry basic-auth userinfo, and an argument is visible in the
  # process table to every other user on the box for the life of the probe.
  # `-K -` takes the URL on stdin instead, so it never reaches argv.
  BODY=$(printf 'url = "%s"\n' "$ENDPOINT/api/tags" | "$CURL" -fsS -m 3 -K - 2>/dev/null)
  case "$BODY" in
    *'"models"'*)
      n=$(printf '%s' "$BODY" | tr ',' '\n' | grep -c '"name"' 2>/dev/null)
      echo "ollama-server: UP (~${n:-?} models)" ;;
    '') echo "ollama-server: not reachable" ;;
    *)  echo "ollama-server: something answered but it is not Ollama" ;;
  esac
fi

# ── OpenRouter ────────────────────────────────────────────────────────────────
# The council seats on COUNCIL_OPENROUTER_API_KEY and never on OPENROUTER_API_KEY.
# Presence and provenance are reported here; the value never is, by any path.
COUNCIL_KEY_MODE_WARN=''
if council_resolve_key; then
  echo "openrouter: $COUNCIL_KEY_NAME present (from $COUNCIL_KEY_SOURCE) -- one key, many vendors"
  [ -n "$COUNCIL_KEY_MODE_WARN" ] && echo "  warning: $COUNCIL_KEY_MODE_WARN"
else
  echo "openrouter: $COUNCIL_KEY_NAME absent -- do NOT seat OpenRouter members"
fi
# A level that EXISTS but cannot be read is configured and FAILING, which is not
# the same as absent and must not print the same way.
[ -n "$COUNCIL_KEY_WARN" ] && echo "  warning: $COUNCIL_KEY_WARN"

if [ -n "${OPENROUTER_API_KEY:-}" ]; then
  echo "  note: OPENROUTER_API_KEY is also set. It is NOT a fallback and the council"
  echo "        never seats on it. It belongs to whatever else on this machine uses"
  echo "        OpenRouter; keeping the two separate is what keeps council spend"
  echo "        separable and leaves that key's own retention guardrail undisturbed."
fi

# ── Consent ───────────────────────────────────────────────────────────────────
if [ ! -e "$ROSTER" ]; then
  echo "roster: NONE at $ROSTER_DISPLAY -- Claude-only council; run /council:setup to add external members"
elif [ ! -f "$ROSTER" ] || [ ! -r "$ROSTER" ]; then
  # Distinct from absent on purpose. /council:status REFUSES on this rather than
  # reporting a Claude-only council, and the two must not read alike here either.
  echo "roster: $ROSTER_DISPLAY exists but is not a readable file -- /council:status will refuse to report seating"
else
  echo "roster: $ROSTER_DISPLAY"
  # Capped at 40 lines and userinfo-redacted; a trailing echo guarantees a newline
  # even if the file has none. This is a SUMMARY -- the skill re-reads the file.
  #
  # Not council_redact: that takes one URL as an argument, while this filters a
  # JSON file, so the host class must also stop at `"` and the substitution must
  # be global to catch more than one endpoint on a line.
  sed -n '1,40p' "$ROSTER" 2>/dev/null | sed 's|://[^/@"]*@|://***:***@|g'
  LINES=$(wc -l < "$ROSTER" 2>/dev/null | tr -d ' ')
  case "$LINES" in ''|*[!0-9]*) LINES=0 ;; esac
  # 40 lines of a longer file is a PARTIAL member list, and a partial list read as
  # a whole one is how a member gets silently dropped from the seating.
  [ "$LINES" -gt 40 ] && echo "  ... truncated at 40 of $LINES lines -- re-read the file before seating"
  echo ""
fi

exit 0
