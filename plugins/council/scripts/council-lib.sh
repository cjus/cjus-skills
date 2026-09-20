#!/bin/sh
# Shared POSIX `sh` helpers for council's mechanical layer. Sourced, never run:
#
#   . "${CLAUDE_PLUGIN_ROOT}/scripts/council-lib.sh"
#
# WHY A LIBRARY AND NOT A COPY IN EACH SCRIPT
#
# The key-resolution chain has two consumers that cannot share code with each
# other: `openrouter.mjs` needs the key's VALUE and is therefore Node, while
# `detect.sh` and `council-state.sh` must stay Node-free so a Claude-only council
# never needs a Node install. That is two implementations of one rule, and the
# only reason it is two rather than four is this file.
#
# Two is already the maximum tolerable. Drift between them is invisible in the
# worst way: the context block reports "absent -- do NOT seat OpenRouter members"
# while the member seats and spends anyway, or the reverse. `test-env.sh` holds
# the oracle table both implementations answer to; add a row there before adding
# a behaviour here.
#
# Nothing in this file ever emits the key itself -- presence and provenance only.
# A shell is a bad place to hold a secret: it leaks through `set -x`, through the
# process table if it ever reaches an argument, and through any trace a user
# pastes into a bug report. The value stays inside the Node process that uses it.

COUNCIL_KEY_NAME=COUNCIL_OPENROUTER_API_KEY

# Where this plugin's scripts live. A sourced POSIX sh file cannot discover its
# own path -- `$0` is the script doing the sourcing -- so a caller that lives
# elsewhere must set this before sourcing. The fallback is right for the normal
# case, where the sourcing script is a sibling.
: "${COUNCIL_SCRIPT_DIR:=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)}"

# Locate a binary even when PATH is truncated, which it is under a GUI-launched
# app. Same shape detect.sh already uses.
council_find_bin() {
  _c=$(command -v "$1" 2>/dev/null)
  for _p in "$_c" "/opt/homebrew/bin/$1" "$HOME/.local/bin/$1" "/usr/local/bin/$1"; do
    if [ -n "$_p" ] && [ -x "$_p" ]; then printf '%s' "$_p"; return 0; fi
  done
  return 1
}

# Never print basic-auth credentials a reverse-proxied endpoint might carry: this
# output goes verbatim into the model's context and the session transcript.
council_redact() { printf '%s' "$1" | sed 's|://[^/@]*@|://***:***@|'; }

# `$XDG_CONFIG_HOME/council`, else `~/.config/council`. Mirrors env.mjs:configDir.
council_config_dir() {
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then printf '%s/council' "$XDG_CONFIG_HOME"
  else printf '%s/.config/council' "$HOME"; fi
}

# The roster's path. $COUNCIL_ROSTER wins over the config dir unconditionally, so
# it overrides $XDG_CONFIG_HOME/council/roster.json and the ~/.config default
# alike. It is how both suites inject a fixture roster, and a test seam that
# shapes the public API is still public: anything that WRITES a roster has to
# resolve the path this way too, or the user configures a file nothing reads.
council_roster_path() {
  if [ -n "${COUNCIL_ROSTER:-}" ]; then printf '%s' "$COUNCIL_ROSTER"
  else printf '%s/roster.json' "$(council_config_dir)"; fi
}

# THE MODEL VALUES THE HARNESS ACCEPTS for a subagent pin, declared once.
#
# Verified 2026-09-19 against the live Agent tool schema: `model` is a CLOSED
# enum and these four are all of it. Passing anything else fails as an
# InputValidationError before a model runs -- which is the good case, because it
# cannot be mistaken for an answer.
#
# It matters because the roster's `model` field is free-form JSON. `"model":
# "opus-4.5"` or `"model": "claude-3-5-sonnet"` is easy to write and looks
# reasonable, and nothing in the roster schema rejects it. Catching it in the join
# turns a mid-fan-out crash -- after the council has begun spending -- into an
# unseated member with a reason, which is how every other unavailability is
# already reported.
#
# If the harness ever widens the enum, this list is what goes stale. Prefer
# widening it here over teaching a caller to guess.
COUNCIL_ACCEPTED_PINS='opus sonnet haiku fable'
COUNCIL_ACCEPTED_PINS_DISPLAY='opus|sonnet|haiku|fable'

council_pin_is_accepted() { # model -> 0 accepted, 1 not
  for _ap in $COUNCIL_ACCEPTED_PINS; do
    [ "$1" = "$_ap" ] && return 0
  done
  return 1
}

# THE DEFAULT COUNCIL, declared exactly once, here.
#
# An absent roster is the documented normal case rather than a fault, and it
# seats these four rather than nobody. Both readers take them from this one
# declaration: council-state.sh joins them like any other member, and skills/ask
# seats whatever that join returns. A second copy would drift exactly the way two
# key chains did, and the drift would be a member list where the status report
# and the council itself disagree about who is in the room.
#
# Emitted as `stance<TAB>model`, which is what `members claude` yields from
# council_roster_rows, so the join cannot tell a default from a declared member
# and needs no branch for them.
#
# The four models are pins, not guarantees: nothing here can verify that a plan
# resolves `opus`/`sonnet`/`haiku`/`fable`, and council-state.sh reports seating
# as PROJECTED for that reason.
council_default_members() { # -> stance<TAB>model, one per line
  printf '%s\t%s\n' \
    risk-first       opus \
    simplicity-first sonnet \
    long-horizon     haiku \
    contrarian       fable
}

# Render a path with $HOME as `~`, matching env.mjs:displayPath.
council_display_path() {
  case "$1" in
    "$HOME"/*) printf '~%s' "${1#$HOME}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Is KEY present in this .env file, by the same rules env.mjs:parseEnvFile applies?
#
# awk rather than grep, because presence is not a line match. The last assignment
# wins, so a file with `K=sk-live` followed by `K=` has NO key -- a grep that
# stops at the first hit reports the opposite. Quotes are stripped, a ` #` tail is
# a comment while `ab#cd` is a value, and an empty or all-whitespace result is
# absent so it falls through the chain instead of reaching the provider as a 401.
#
# `export K=v` IS accepted here. env.mjs accepts it because dotenv does, and the
# original detect.sh grep did not -- verified divergence: on `export K=sk-test`
# detect.sh said "absent, do NOT seat" while the Node side returned the key.
_council_env_file_has_key() { # path -> 0 present, 1 absent
  # ENOENT is the ordinary case: that level is simply not in use. A level that
  # EXISTS but cannot be read is configured and FAILING, which is not the same
  # thing and must not look like it. env.mjs says so and warns; this side was
  # silent, and this side is what prints the human-facing "key: ... absent" line.
  [ -e "$1" ] || return 1
  if [ -d "$1" ] || [ ! -r "$1" ]; then
    COUNCIL_KEY_WARN="cannot read $(council_display_path "$1") -- skipping this level"
    return 1
  fi
  _hit=$(awk -v KEY="$COUNCIL_KEY_NAME" '
    function unq(s,   q, i, end, c) {
      sub(/^[ \t]*/, "", s)
      q = substr(s, 1, 1)
      if ((q == "\"" || q == "'"'"'") && length(s) >= 2) {
        end = 0
        for (i = length(s); i > 1; i--) if (substr(s, i, 1) == q) { end = i; break }
        if (end > 1) return substr(s, 2, end - 2)
      }
      # An unquoted value beginning with "#" is a comment, not a value -- the
      # whitespace that marks it was already consumed above. Mirrors env.mjs.
      if (substr(s, 1, 1) == "#") return ""
      c = match(s, /[ \t]#/)
      if (c > 0) s = substr(s, 1, c - 1)
      sub(/[ \t]+$/, "", s)
      return s
    }
    {
      line = $0; sub(/\r$/, "", line)
      if (match(line, /^[ \t]*(export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*=/)) {
        head = substr(line, 1, RLENGTH); rest = substr(line, RLENGTH + 1)
        name = head
        sub(/^[ \t]*/, "", name); sub(/^export[ \t]+/, "", name); sub(/[ \t]*=$/, "", name)
        if (name == KEY) { found = 1; val = unq(rest) }
      }
    }
    END { if (found) { t = val; gsub(/[ \t]/, "", t); if (t != "") print "present" } }
  ' "$1" 2>/dev/null)
  [ -n "$_hit" ]
}

# Walk the three-level chain. Returns 0 when a key resolves, 1 when none does,
# and sets two variables:
#
#   COUNCIL_KEY_LEVEL   env | project | user | none   -- the machine token
#   COUNCIL_KEY_SOURCE  a display string for "(from ...)"
#
# The token exists so a caller never has to string-match the display text to
# learn which level won; it is also what the oracle table in test-env.sh compares
# against env.mjs's `.source`, and those two must stay spelled identically.
#
#   1. $COUNCIL_OPENROUTER_API_KEY in the environment   (per-invocation)
#   2. ./.env in the current project                     (per-project)
#   3. $XDG_CONFIG_HOME/council/.env, else
#      ~/.config/council/.env                            (per-user default)
council_resolve_key() {
  COUNCIL_KEY_WARN=''
  COUNCIL_KEY_SOURCE=''
  COUNCIL_KEY_LEVEL=none

  # `sh -x council-state.sh` is exactly what someone runs when this tool
  # misreports, and the trace is exactly what they paste into an issue. Reading
  # the key into a variable and testing it echoes the value into that trace --
  # three times, in the earlier form. POSIX has no function-local `set`, so the
  # option is saved, cleared for the read, and restored.
  _xt=0; case "$-" in *x*) _xt=1; set +x ;; esac
  eval "_v=\${$COUNCIL_KEY_NAME:-}"
  _present=0
  case "$_v" in *[![:space:]]*) _present=1 ;; esac
  _v=''                                  # do not leave it set for the rest of the run
  [ "$_xt" = 1 ] && set -x

  if [ "$_present" = 1 ]; then
    COUNCIL_KEY_LEVEL=env; COUNCIL_KEY_SOURCE='the environment'; return 0
  fi
  if _council_env_file_has_key "./.env"; then
    COUNCIL_KEY_LEVEL=project
    COUNCIL_KEY_SOURCE="$(council_display_path "$PWD/.env")"; return 0
  fi
  _user_env="$(council_config_dir)/.env"
  if _council_env_file_has_key "$_user_env"; then
    COUNCIL_KEY_LEVEL=user
    COUNCIL_KEY_SOURCE="$(council_display_path "$_user_env")"
    # The user-level file holds a credential and nothing else, so it should be
    # 600. Read the mode from `ls -l`'s permission field by position -- group is
    # characters 5-7, other is 8-10 -- because `stat`'s format flags differ
    # between BSD and GNU and this has to run on both. A trailing `@` or `+` for
    # xattrs or an ACL sits at character 11 and does not disturb either slice.
    COUNCIL_KEY_MODE_WARN=''
    _perm=$(ls -l "$_user_env" 2>/dev/null | awk 'NR==1{print $1}')
    if [ -n "$_perm" ]; then
      _grp=$(printf '%s' "$_perm" | cut -c5-7)
      _oth=$(printf '%s' "$_perm" | cut -c8-10)
      if [ "$_grp" != "---" ] || [ "$_oth" != "---" ]; then
        COUNCIL_KEY_MODE_WARN="$(council_display_path "$_user_env") is readable beyond its owner -- chmod 600 it."
      fi
    fi
    return 0
  fi
  return 1
}

# Normalize an Ollama endpoint. ALWAYS write the port explicitly in the roster:
# a bare `host` defaults to :11434, but `http://host` is a URL and defaults to
# :80, which is the single most common way to point this at nothing.
council_normalize_endpoint() { # raw -> normalized URL
  _e=$(printf '%s' "$1" | sed 's|/*$||')
  case "$_e" in
    http://*|https://*) ;;
    *) case "$_e" in *:[0-9]*) _e="http://$_e" ;; *) _e="http://$_e:11434" ;; esac ;;
  esac
  printf '%s' "$_e"
}

# ── roster reading ────────────────────────────────────────────────────────────
#
# NOTHING IS INSTALLED WHEN A PLUGIN IS INSTALLED. A Claude Code plugin manifest
# has no dependency-resolution step: `requires` and `postInstall` are ignored at
# load time (verified against `claude plugin validate --strict`). Every binary
# this plugin touches is therefore one the user already has, or one it must do
# without.
#
# So the roster is read through EITHER jq or Node, whichever is present. Making
# jq a hard requirement would have put a dependency on the exact path that
# choosing sh over Node existed to protect: a Claude-only council needs no key
# and no Node, and would have been unable to read its own status. Requiring
# either is strictly weaker than requiring one.
#
# Both backends emit the same normalized TSV, and `test-council-state.sh` diffs
# them against each other on every fixture -- the same two-implementations-one-
# oracle discipline the key chain is held to.
#
#   meta   maxConcurrentExternal  <n>
#   meta   openrouter.enabled     true|false
#   meta   ollama.enabled         true|false
#   meta   ollama.endpoint        <string, possibly empty>
#   meta   codex.enabled          true|false
#   member claude|openrouter|ollama  <stance>  <model-or-id>
#
# `codex` seats a single member with no model list, so it appears only as meta.

# jq program producing the contract above. Kept beside the Node file that must
# match it, so neither can be edited without the other being in view.
COUNCIL_ROSTER_JQ='
# Read under `jq -s`, so the whole file arrives as an ARRAY of the JSON values
# it contained. That is what makes the two guards below reachable.
#
# Without the slurp, a file containing no JSON value at all -- zero bytes, only
# whitespace -- gives jq nothing to run the filter on, so it produces no output
# and exits 0. The caller then reports a confident, authoritative "0 seated"
# table for a roster that failed to parse, which is the precise outcome this
# design forbids: "failed to parse" and "no external members" must never print
# the same answer. A file holding TWO concatenated documents was worse still --
# jq ran the filter once per document and the members of both were merged into
# one council. jq is tried first, so this was the default path.
#
# `length != 1` covers empty, whitespace-only and multi-document. The type guard
# then covers a single value that is not an object: an array or a string already
# errors on the first index, but `null` would slip through every `// default`
# below, since `null | .foo` is null in jq. The Node backend refuses all of these
# by construction; these two lines are what make the backends agree.
if length != 1 then error("roster must contain exactly one JSON value") else .[0] end |
if type != "object" then error("roster is not a JSON object") else . end |
[ "meta\tmaxConcurrentExternal\t\(.maxConcurrentExternal // 2)",
  "meta\topenrouter.enabled\t\(.external.openrouter.enabled == true)",
  "meta\tollama.enabled\t\(.external.ollama.enabled == true)",
  "meta\tollama.endpoint\t\(.external.ollama.endpoint // "")",
  "meta\tcodex.enabled\t\(.external.codex.enabled == true)" ]
+ [ (.members // [])[] | select(type == "object")
    | "member\tclaude\t\(.stance // "-")\t\(.model // "-")" ]
+ [ (.external.openrouter.models // [])[] | select(type == "object")
    | "member\topenrouter\t\(.stance // "-")\t\(.id // "-")" ]
+ [ (.external.ollama.models // [])[] | select(type == "object")
    | "member\tollama\t\(.stance // "-")\t\(.id // "-")" ]
| .[]'

# Which backend will be used: "jq", "node", or empty when neither is available.
# $COUNCIL_JSON_BACKEND forces one, which is how the suite runs every fixture
# through both.
council_json_backend() {
  case "${COUNCIL_JSON_BACKEND:-}" in
    jq)   council_find_bin jq   >/dev/null 2>&1 && { printf 'jq';   return 0; }; return 1 ;;
    node) council_find_bin node >/dev/null 2>&1 && { printf 'node'; return 0; }; return 1 ;;
  esac
  council_find_bin jq   >/dev/null 2>&1 && { printf 'jq';   return 0; }
  council_find_bin node >/dev/null 2>&1 && { printf 'node'; return 0; }
  return 1
}

# Emit the normalized TSV for a roster. Non-zero on anything that is not a
# readable, parseable JSON object -- the caller must refuse rather than report an
# empty roster, which is indistinguishable from a Claude-only council.
council_roster_rows() { # roster-path -> TSV on stdout
  _rp="$1"
  _be=$(council_json_backend) || {
    echo "neither jq nor node is available; the roster cannot be read" >&2; return 3; }
  case "$_be" in
    jq)
      _jq=$(council_find_bin jq)
      "$_jq" -s -r "$COUNCIL_ROSTER_JQ" "$_rp" 2>/dev/null || {
        echo "not valid JSON, or not a JSON object" >&2; return 2; } ;;
    node)
      _node=$(council_find_bin node)
      "$_node" "$COUNCIL_SCRIPT_DIR/roster-rows.mjs" "$_rp" ;;
  esac
}
