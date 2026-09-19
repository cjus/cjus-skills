#!/bin/bash
# Probe suite for council-lib.sh and council-state.sh. Run after ANY edit:
#   ./test-council-state.sh
# Requires node, jq and awk.
#
# PART 1 is the oracle. The key-resolution chain has two implementations --
# env.mjs for the Node side that needs the key's VALUE, and council-lib.sh for
# the sh side that must not require Node -- and they are checked against each
# other on every row rather than each against its own expectations. A row that
# agrees on the WRONG answer still fails, because each row also carries what the
# answer should be. Drift here is the failure that matters: the context block
# says "absent -- do NOT seat" while the member seats and spends.
#
# PART 2 is the join: roster consent crossed with local availability.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
LIB="$HERE/council-lib.sh"
ENVJS="$HERE/env.mjs"
STATE="$HERE/council-state.sh"
for f in "$LIB" "$ENVJS" "$STATE"; do [[ -r "$f" ]] || { echo "FAIL: cannot read $f" >&2; exit 1; }; done
command -v jq >/dev/null || { echo "FAIL: jq is required" >&2; exit 1; }

PASS=0; FAIL=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
K=COUNCIL_OPENROUTER_API_KEY

ok()   { PASS=$((PASS+1)); printf '  ok   %-50s %s\n' "$1" "$2"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %-50s %s\n' "$1" "$2"; }

# ── Part 1: the oracle ────────────────────────────────────────────────────────
# A fake HOME per case, so a real ~/.config/council/.env on the developer's
# machine cannot satisfy a case meant to find nothing.
fixture() { # project-body, user-body -> sandbox dir
  local dir; dir=$(mktemp -d "$TMP/case.XXXXXX")
  mkdir -p "$dir/project" "$dir/home/.config/council"
  [[ -n "${1:-}" ]] && printf '%s\n' "$1" > "$dir/project/.env"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" > "$dir/home/.config/council/.env"; chmod 600 "$dir/home/.config/council/.env"
  fi
  echo "$dir"
}

node_level() { # dir, [env...]
  local dir="$1"; shift
  ( cd "$dir/project" && env -u "$K" -u XDG_CONFIG_HOME -u COUNCIL_ROSTER \
      HOME="$dir/home" "$@" node "$ENVJS" --json 2>/dev/null ) | jq -r '.source // "none"'
}

sh_level() { # dir, [env...]
  local dir="$1"; shift
  ( cd "$dir/project" && env -u "$K" -u XDG_CONFIG_HOME -u COUNCIL_ROSTER \
      HOME="$dir/home" "$@" sh -c '. "$1"; council_resolve_key >/dev/null 2>&1
        printf "%s" "${COUNCIL_KEY_LEVEL:-none}"' _ "$LIB" 2>/dev/null )
}

oracle() { # name, expected-level, dir, [env...]
  local name="$1" want="$2"; shift 2
  local n s; n=$(node_level "$@"); s=$(sh_level "$@")
  if [[ "$n" != "$s" ]]; then
    bad "$name" "DRIFT node=$n sh=$s"
  elif [[ "$n" != "$want" ]]; then
    bad "$name" "agreed but wrong: $n (want $want)"
  else
    ok "$name" "$n"
  fi
}

echo "== oracle: node and sh must agree, and be right =="
oracle "env only"                    env     "$(fixture '' '')" "$K=sk-e"
oracle "project only"                project "$(fixture "$K=sk-p" '')"
oracle "user only"                   user    "$(fixture '' "$K=sk-u")"
oracle "env beats project and user"  env     "$(fixture "$K=sk-p" "$K=sk-u")" "$K=sk-e"
oracle "project beats user"          project "$(fixture "$K=sk-p" "$K=sk-u")"
oracle "nothing anywhere"            none    "$(fixture '' '')"
oracle "empty project falls through" user    "$(fixture "$K=" "$K=sk-u")"
oracle "whitespace project falls"    user    "$(fixture "$K=   " "$K=sk-u")"
oracle "export prefix accepted"      project "$(fixture "export $K=sk-p" '')"
oracle "commented out ignored"       user    "$(fixture "# $K=sk-p" "$K=sk-u")"
oracle "KEY: value not a form"       user    "$(fixture "$K: sk-p" "$K=sk-u")"
oracle "double quoted"               project "$(fixture "$K=\"sk-p\"" '')"
oracle "single quoted"               project "$(fixture "$K='sk-p'" '')"
oracle "quoted empty is absent"      user    "$(fixture "$K=\"\"" "$K=sk-u")"
oracle "hash inside value"           project "$(fixture "$K=sk-a#b" '')"
oracle "comment tail only"           user    "$(fixture "$K=  # note" "$K=sk-u")"
oracle "CRLF line endings"           project "$(fixture "$(printf '%s=sk-p\r' "$K")" '')"
oracle "indented"                    project "$(fixture "   $K=sk-p" '')"
oracle "unprefixed name ignored"     none    "$(fixture "OPENROUTER_API_KEY=sk-x" '')"
# Last assignment wins, so a file ending in an empty re-assignment has NO key.
# A grep that stops at the first hit reports the opposite.
oracle "last-wins: value then empty" user    "$(fixture "$(printf '%s=sk-1\n%s=' "$K" "$K")" "$K=sk-u")"
oracle "last-wins: empty then value" project "$(fixture "$(printf '%s=\n%s=sk-2' "$K" "$K")" '')"

XD=$(fixture '' ''); mkdir -p "$XD/xdg/council"
printf '%s=sk-x\n' "$K" > "$XD/xdg/council/.env"; chmod 600 "$XD/xdg/council/.env"
oracle "XDG_CONFIG_HOME redirect"    user    "$XD" "XDG_CONFIG_HOME=$XD/xdg"

# ── Part 2: the join ──────────────────────────────────────────────────────────
roster() { # json -> path
  # No `.json` suffix on the template: BSD mktemp only substitutes X's at the
  # END of a template, so `roster.XXXXXX.json` is taken literally and every call
  # after the first fails with "File exists" -- leaving $rp empty, which silently
  # falls back to the REAL roster and makes the cases pass or fail on whatever
  # this machine happens to have configured.
  local f; f=$(mktemp "$TMP/roster.XXXXXX"); printf '%s\n' "$1" > "$f"; echo "$f"
}

CLAUDE4='"members":[
  {"id":"opus","kind":"claude","model":"opus","stance":"risk-first"},
  {"id":"sonnet","kind":"claude","model":"sonnet","stance":"simplicity-first"},
  {"id":"haiku","kind":"claude","model":"haiku","stance":"long-horizon"},
  {"id":"fable","kind":"claude","model":"fable","stance":"contrarian"}]'

state() { # roster-path, key-present(0|1), [extra args...]
  local rp="$1" keyp="$2"; shift 2
  local dir; dir=$(mktemp -d "$TMP/st.XXXXXX"); mkdir -p "$dir/home"
  # env(1) reads its OPTIONS before its NAME=value operands: after the first
  # assignment, a `-u` is taken as the utility to execute, not as an option. The
  # two branches are spelled out rather than assembled from an array so that
  # ordering constraint cannot be violated by accident.
  #
  # stderr is kept and replayed on an empty result, because suppressing it is how
  # the ordering bug above stayed invisible -- every case just read as "got=".
  local out err rc
  err="$TMP/state.err"
  if [[ "$keyp" == 1 ]]; then
    out=$( cd "$dir" && env -u XDG_CONFIG_HOME "$K=sk-test" HOME="$dir/home" \
             COUNCIL_ROSTER="$rp" sh "$STATE" --json --no-probe "$@" 2>"$err" )
  else
    out=$( cd "$dir" && env -u XDG_CONFIG_HOME -u "$K" HOME="$dir/home" \
             COUNCIL_ROSTER="$rp" sh "$STATE" --json --no-probe "$@" 2>"$err" )
  fi
  rc=$?
  # Empty output with a NON-zero status is the refusal path working as designed;
  # empty output with status 0 is a harness fault, and that is the only case
  # worth reporting. `printf` must not be the last command: its own status would
  # replace the script's, turning every refusal into rc=0.
  if [[ -z "$out" && $rc -eq 0 && -s "$err" ]]; then
    printf 'state() produced nothing; stderr: %s\n' "$(head -1 "$err")" >&2
  fi
  printf '%s' "$out"
  return $rc
}

j() { jq -r "$2" <<<"$1"; }

t() { # name, expected, actual
  if [[ "$3" == "$2" ]]; then ok "$1" "$3"; else bad "$1" "got=$3 want=$2"; fi
}

echo "== join: consent x availability =="
R_CLAUDE=$(roster "{$CLAUDE4}")
OUT=$(state "$R_CLAUDE" 0)
t "claude-only seats 4"              4              "$(j "$OUT" '.seating.claude')"
t "claude-only is HOMOGENEOUS"       HOMOGENEOUS    "$(j "$OUT" '.projectedCorrelation')"
t "claude-only vendor list"          anthropic      "$(j "$OUT" '.vendors')"
t "maxConcurrentExternal defaults 2" 2              "$(j "$OUT" '.maxConcurrentExternal')"

R_OR=$(roster "{$CLAUDE4,\"external\":{\"openrouter\":{\"enabled\":true,\"models\":[
  {\"id\":\"openai/gpt-5.6-sol\",\"stance\":\"risk-first\"},
  {\"id\":\"deepseek/deepseek-v4-pro\",\"stance\":\"contrarian\"}]}}}")

OUT=$(state "$R_OR" 1)
t "openrouter + key seats them"      2              "$(j "$OUT" '.seating.openrouter')"
t "openrouter + key is CROSS-VENDOR" CROSS-VENDOR   "$(j "$OUT" '.projectedCorrelation')"
t "vendor from author prefix"        "anthropic, deepseek, openai" "$(j "$OUT" '.vendors')"
t "nothing unseated"                 0              "$(j "$OUT" '.notSeated|length')"

OUT=$(state "$R_OR" 0)
t "openrouter, no key: not seated"   0              "$(j "$OUT" '.seating.openrouter')"
t "openrouter, no key: listed"       2              "$(j "$OUT" '.notSeated|length')"
t "openrouter, no key: reason given" "no key resolves" "$(j "$OUT" '.notSeated[0].reason')"
t "openrouter, no key: HOMOGENEOUS"  HOMOGENEOUS    "$(j "$OUT" '.projectedCorrelation')"

R_ORDIS=$(roster "{$CLAUDE4,\"external\":{\"openrouter\":{\"enabled\":false,\"models\":[
  {\"id\":\"openai/gpt-5.6-sol\",\"stance\":\"risk-first\"}]}}}")
OUT=$(state "$R_ORDIS" 1)
t "disabled + key: still not seated" 0              "$(j "$OUT" '.seating.openrouter')"
t "disabled is not 'unavailable'"    0              "$(j "$OUT" '.notSeated|length')"

R_BARE=$(roster "{$CLAUDE4,\"external\":{\"openrouter\":{\"enabled\":true,\"models\":[
  {\"id\":\"some-slugless-model\",\"stance\":\"risk-first\"}]}}}")
t "id with no author prefix"         "anthropic, openrouter" "$(j "$(state "$R_BARE" 1)" '.vendors')"

R_OLL=$(roster "{$CLAUDE4,\"external\":{\"ollama\":{\"enabled\":true,
  \"endpoint\":\"http://localhost:11434\",\"models\":[{\"id\":\"gemma4:26b\",\"stance\":\"long-horizon\"}]}}}")
OUT=$(state "$R_OLL" 0)
t "ollama seats without a key"       1              "$(j "$OUT" '.seating.ollama')"
t "ollama makes it cross-vendor"     "anthropic, local" "$(j "$OUT" '.vendors')"

R_CODEX=$(roster "{$CLAUDE4,\"external\":{\"codex\":{\"enabled\":true}}}")
OUT=$(state "$R_CODEX" 0)
if command -v codex >/dev/null 2>&1; then
  t "codex enabled + cli present"    1 "$(j "$OUT" '.seating.codex')"
else
  t "codex enabled, cli absent"      0 "$(j "$OUT" '.seating.codex')"
  t "codex absence explained"        "codex CLI not installed" "$(j "$OUT" '.notSeated[0].reason')"
fi

echo "== a roster that cannot be read must not look like Claude-only =="
BADJSON=$(roster '{"members": [ {"id": "opus" ')
out=$(state "$BADJSON" 0; echo "rc=$?")
if grep -q 'rc=2' <<<"$out" && ! grep -q '"seating"' <<<"$out"; then
  ok "malformed roster exits 2, prints no seating" "refused"
else
  bad "malformed roster exits 2, prints no seating" "$(tr -d '\n' <<<"$out" | cut -c1-60)"
fi

UNREAD=$(roster "{$CLAUDE4}"); chmod 000 "$UNREAD"
if [[ $(id -u) -eq 0 ]]; then
  printf '  skip %-50s (running as root)\n' "unreadable roster exits 2"
else
  out=$(state "$UNREAD" 0; echo "rc=$?")
  if grep -q 'rc=2' <<<"$out" && ! grep -q '"seating"' <<<"$out"; then
    ok "unreadable roster exits 2, prints no seating" "refused"
  else
    bad "unreadable roster exits 2, prints no seating" "$(tr -d '\n' <<<"$out" | cut -c1-60)"
  fi
fi
chmod 600 "$UNREAD"

echo "== an absent roster seats the DEFAULTS, not nobody =="
MISSING="$TMP/no-such-roster.json"
OUT=$(state "$MISSING" 0)
t "absent roster is legitimate"       absent      "$(j "$OUT" '.roster.state')"
t "absent roster seats the defaults"  4           "$(j "$OUT" '.seating.total')"
t "all four are claude"               4           "$(j "$OUT" '.seating.claude')"
t "absent roster is HOMOGENEOUS"      HOMOGENEOUS "$(j "$OUT" '.projectedCorrelation')"
t "one vendor, and it is named"       anthropic   "$(j "$OUT" '.vendors')"
t "nothing is listed as unavailable"  0           "$(j "$OUT" '.notSeated|length')"
t "concurrency still defaults to 2"   2           "$(j "$OUT" '.maxConcurrentExternal')"

# ONE DECLARATION, TWO READERS. The seating must be exactly what council-lib.sh
# declares, in the same order. A second copy of the defaults would satisfy every
# row above and still put a different council in the room -- which is the whole
# reason the list lives in the library rather than in each reader.
DECL=$(sh -c '. "$1"; council_default_members' _ "$LIB")
SEEN=$(j "$OUT" '.seated[] | "\(.stance)\t\(.model)"')
t "seating IS the single declaration" "$DECL" "$SEEN"

# The defect the decision names: `roster: NONE ... Claude-only council` printed
# two rows above `0 seated`, so the report contradicted itself in the text format
# a human actually reads.
TXTDIR=$(mktemp -d "$TMP/txt.XXXXXX"); mkdir -p "$TXTDIR/home"
TXT=$( cd "$TXTDIR" && env -u XDG_CONFIG_HOME -u "$K" HOME="$TXTDIR/home" \
       COUNCIL_ROSTER="$MISSING" sh "$STATE" --text --no-probe )
if grep -q 'Claude-only council' <<<"$TXT" && grep -q '(4 seated)' <<<"$TXT"; then
  ok "text report no longer contradicts itself" "Claude-only + 4 seated"
else
  bad "text report no longer contradicts itself" "$(grep -E '^roster:|^seating:' <<<"$TXT" | tr '\n' ' ')"
fi

echo "== the two ways to seat nobody do not print alike =="
R_EMPTY=$(roster '{"members":[]}')
OUT=$(state "$R_EMPTY" 0)
t "present-but-empty seats nobody"    0       "$(j "$OUT" '.seating.total')"
t "present-but-empty is NONE"         NONE    "$(j "$OUT" '.projectedCorrelation')"
t "present-but-empty is 'present'"    present "$(j "$OUT" '.roster.state')"

# A roster that declared members and had every one unseated ALSO reaches NONE -- the
# pin check is what made that reachable. Calling it "the roster declares no members"
# contradicts the `not seated` rows printed directly above it, and sends the user to
# rewrite a file whose only fault is one typo.
txt_of() { # roster-path -> --text output
  local d; d=$(mktemp -d "$TMP/txt.XXXXXX"); mkdir -p "$d/home"
  ( cd "$d" && env -u XDG_CONFIG_HOME -u "$K" HOME="$d/home" \
      COUNCIL_ROSTER="$1" sh "$STATE" --text --no-probe )
}
R_ALLBAD=$(roster '{"members":[{"id":"a","kind":"claude","model":"opus-4.5","stance":"risk-first"}]}')
OUT=$(state "$R_ALLBAD" 0)
t "all-unseated seats nobody"         0    "$(j "$OUT" '.seating.total')"
t "all-unseated is still NONE"        NONE "$(j "$OUT" '.projectedCorrelation')"
t "all-unseated lists the member"     1    "$(j "$OUT" '.notSeated|length')"
TXT=$(txt_of "$R_ALLBAD")
if grep -q 'declares no members' <<<"$TXT"; then
  bad "all-unseated is not called 'declares no members'" "contradicts its own notSeated rows"
else
  ok "all-unseated is not called 'declares no members'" "$(grep 'correlation' <<<"$TXT")"
fi
TXT=$(txt_of "$R_EMPTY")
grep -q 'declares no members' <<<"$TXT" \
  && ok "a genuinely empty roster still says so" "declares no members" \
  || bad "a genuinely empty roster still says so" "$(grep 'correlation' <<<"$TXT")"

echo "== a pin the harness will not accept is caught in the join =="
# `model` is a closed enum, but the roster's `model` field is free-form JSON, so
# this is a typo anyone can make. Catching it here turns a crash partway through a
# paid fan-out into an unseated member with a reason.
R_BADPIN=$(roster '{"members":[
  {"id":"a","kind":"claude","model":"opus","stance":"risk-first"},
  {"id":"b","kind":"claude","model":"opus-4.5","stance":"contrarian"}]}')
OUT=$(state "$R_BADPIN" 0)
t "the acceptable pin seats"          1 "$(j "$OUT" '.seating.claude')"
t "the unacceptable pin does not"     1 "$(j "$OUT" '.notSeated|length')"
t "and the offending value is shown"  "opus-4.5" "$(j "$OUT" '.notSeated[0].model')"
REASON=$(j "$OUT" '.notSeated[0].reason')
case "$REASON" in
  *"opus|sonnet|haiku|fable"*) ok "the reason names what IS accepted" "$REASON" ;;
  *) bad "the reason names what IS accepted" "$REASON" ;;
esac

# Declaring no model is NOT the same mistake: the member runs on the session
# model, contributing no diversity. It must seat, and must not be called an error.
R_NOPIN=$(roster '{"members":[{"id":"a","kind":"claude","stance":"risk-first"}]}')
OUT=$(state "$R_NOPIN" 0)
t "a member with no pin still seats"  1   "$(j "$OUT" '.seating.claude')"
t "no pin is not an unseated member"  0   "$(j "$OUT" '.notSeated|length')"
t "and its model reads as unpinned"   "-" "$(j "$OUT" '.seated[0].model')"

# If anyone edits council_default_members to a value the enum does not carry, the
# DEFAULT council would unseat itself -- a four-member roster reporting NONE. The
# two declarations are independent, so nothing but this row couples them.
DECL_PINS=$(sh -c '. "$1"; council_default_members | cut -f2' _ "$LIB")
BADDEFAULT=''
for pin in $DECL_PINS; do
  sh -c '. "$1"; council_pin_is_accepted "$2"' _ "$LIB" "$pin" || BADDEFAULT="$BADDEFAULT $pin"
done
if [[ -z "$BADDEFAULT" ]]; then
  ok "every default pin is an accepted pin" "$(tr '\n' ' ' <<<"$DECL_PINS")"
else
  bad "every default pin is an accepted pin" "rejected:$BADDEFAULT"
fi

echo "== the key value never appears in output =="
LEAKDIR=$(mktemp -d "$TMP/leak.XXXXXX"); mkdir -p "$LEAKDIR/home"
for fmt in --text --json; do
  out=$( cd "$LEAKDIR" && env "$K=sk-SECRET-VALUE" -u XDG_CONFIG_HOME HOME="$LEAKDIR/home" \
         COUNCIL_ROSTER="$R_OR" sh "$STATE" $fmt --no-probe 2>&1 )
  if grep -q 'sk-SECRET' <<<"$out"; then bad "no key value in $fmt output" "LEAKED"
  else ok "no key value in $fmt output" "clean"; fi
done

# ── Part 3: the two JSON backends ─────────────────────────────────────────────
# Nothing installs jq when the plugin installs, so the roster is read through
# whichever of jq/node is present. That is a second pair of implementations, held
# to the same rule as the key chain: they are diffed against each other rather
# than each against its own expectations.
echo "== backend parity: jq and node must produce identical output =="
have_jq=0; have_node=0
command -v jq   >/dev/null 2>&1 && have_jq=1
command -v node >/dev/null 2>&1 && have_node=1

backend_state() { # backend, roster-path, key-present
  local be="$1" rp="$2" keyp="$3"
  local dir; dir=$(mktemp -d "$TMP/be.XXXXXX"); mkdir -p "$dir/home"
  if [[ "$keyp" == 1 ]]; then
    ( cd "$dir" && env -u XDG_CONFIG_HOME "$K=sk-test" HOME="$dir/home" \
        COUNCIL_JSON_BACKEND="$be" COUNCIL_ROSTER="$rp" sh "$STATE" --json --no-probe 2>&1 )
  else
    ( cd "$dir" && env -u XDG_CONFIG_HOME -u "$K" HOME="$dir/home" \
        COUNCIL_JSON_BACKEND="$be" COUNCIL_ROSTER="$rp" sh "$STATE" --json --no-probe 2>&1 )
  fi
}

if [[ $have_jq -eq 1 && $have_node -eq 1 ]]; then
  R_FULL=$(roster "{$CLAUDE4,\"maxConcurrentExternal\":3,\"external\":{
    \"openrouter\":{\"enabled\":true,\"models\":[
      {\"id\":\"openai/gpt-5.6-sol\",\"stance\":\"risk-first\"},
      {\"id\":\"z-ai/glm-5.3\",\"stance\":\"simplicity-first\"}]},
    \"ollama\":{\"enabled\":true,\"endpoint\":\"http://localhost:11434\",
      \"models\":[{\"id\":\"gemma4:26b\",\"stance\":\"long-horizon\"}]},
    \"codex\":{\"enabled\":false}}}")
  R_SPARSE=$(roster '{"members":[{"id":"o","kind":"claude","model":"opus"}]}')
  R_EMPTY=$(roster '{}')
  R_NULLEXT=$(roster "{$CLAUDE4,\"external\":null}")
  R_ODDMEMBER=$(roster "{\"members\":[{\"model\":\"opus\"},null,\"junk\",{\"stance\":\"s\"}]}")

  names=(full sparse empty null-external odd-members)
  i=0
  for rp in "$R_FULL" "$R_SPARSE" "$R_EMPTY" "$R_NULLEXT" "$R_ODDMEMBER"; do
    for keyp in 0 1; do
      a=$(backend_state jq "$rp" "$keyp"); b=$(backend_state node "$rp" "$keyp")
      if [[ "$a" == "$b" ]]; then ok "${names[$i]} key=$keyp agrees" "identical"
      else bad "${names[$i]} key=$keyp agrees" "jq and node differ"; fi
    done
    i=$((i+1))
  done

  # Exact bytes, so a zero-length file is genuinely zero-length: `roster` appends
  # a newline and would make the empty case a whitespace case instead.
  roster_raw() { local f; f=$(mktemp "$TMP/raw.XXXXXX"); printf '%s' "$1" > "$f"; echo "$f"; }

  # jq given a file with NO JSON value in it runs the filter zero times, emits
  # nothing and exits 0 -- a no-op success a diff-based parity test cannot see,
  # because both sides must be ASKED the question before they can disagree.
  # These four rows are the coverage that was missing, not a new rule.
  EMPTYF=$(roster_raw '')
  WSF=$(roster_raw '   ')
  TWODOC=$(roster_raw '{"members":[{"model":"opus","stance":"a"}]}
{"members":[{"model":"sonnet","stance":"b"}]}')
  for pair in "empty:$EMPTYF" "whitespace-only:$WSF" "two-documents:$TWODOC"; do
    label=${pair%%:*}; path=${pair#*:}
    for be in jq node; do
      out=$(backend_state "$be" "$path" 0)
      if grep -q '"seating"' <<<"$out"; then
        bad "$be refuses $label roster" "reported seating"
      else ok "$be refuses $label roster" "refused"; fi
    done
  done

  # A roster string carrying a quote must not break the emitted JSON.
  HOSTILE=$(roster '{"members":[{"model":"opus","stance":"the \"paranoid\" one"}]}')
  for be in jq node; do
    out=$(backend_state "$be" "$HOSTILE" 0)
    if jq -e '.seated[0].stance' <<<"$out" >/dev/null 2>&1; then
      ok "$be emits valid JSON for a quoted stance" "parses"
    else bad "$be emits valid JSON for a quoted stance" "invalid JSON"; fi
  done

  # maxConcurrentExternal is emitted as a bare JSON number.
  ODDCONC=$(roster '{"members":[],"maxConcurrentExternal":"two"}')
  for be in jq node; do
    out=$(backend_state "$be" "$ODDCONC" 0)
    if jq -e '.maxConcurrentExternal|type=="number"' <<<"$out" >/dev/null 2>&1; then
      ok "$be keeps maxConcurrentExternal numeric" "number"
    else bad "$be keeps maxConcurrentExternal numeric" "not a number"; fi
  done

  BADJ=$(roster '{"members": [ {"id": "opus" ')
  for be in jq node; do
    out=$(backend_state "$be" "$BADJ" 0)
    if grep -q 'Refusing' <<<"$out" && ! grep -q '"seating"' <<<"$out"; then
      ok "$be refuses malformed JSON" "refused"
    else bad "$be refuses malformed JSON" "$(tr -d '\n' <<<"$out" | cut -c1-50)"; fi
  done

  for lit in '[1,2,3]' '"a string"' 'null'; do
    NOTOBJ=$(roster "$lit")
    for be in jq node; do
      out=$(backend_state "$be" "$NOTOBJ" 0)
      if grep -q '"seating"' <<<"$out"; then
        bad "$be refuses non-object roster $lit" "reported seating"
      else ok "$be refuses non-object roster $lit" "refused"; fi
    done
  done
else
  printf '  skip %-50s (jq=%s node=%s)\n' "backend parity" "$have_jq" "$have_node"
fi

echo "== an unprobed ollama member must not claim confirmed diversity =="
R_OLL_P=$(roster "{$CLAUDE4,\"external\":{\"ollama\":{\"enabled\":true,
  \"endpoint\":\"http://127.0.0.1:1\",\"models\":[{\"id\":\"g\",\"stance\":\"long-horizon\"}]}}}")
OUT=$(state "$R_OLL_P" 0)                       # --no-probe, so REACH is unknown
t "unprobed run records ollamaProbed=false" false "$(j "$OUT" '.ollamaProbed')"
t "unprobed ollama is still seated"          1     "$(j "$OUT" '.seating.ollama')"
dir=$(mktemp -d "$TMP/pr.XXXXXX"); mkdir -p "$dir/home"
TXT=$( cd "$dir" && env -u XDG_CONFIG_HOME -u "$K" HOME="$dir/home" \
         COUNCIL_ROSTER="$R_OLL_P" sh "$STATE" --text --no-probe 2>&1 )
if grep -q 'diversity is unconfirmed' <<<"$TXT"; then
  ok "text output states the diversity is unconfirmed" "stated"
else bad "text output states the diversity is unconfirmed" "silent"; fi

echo "== the key must not appear in an xtrace =="
dir=$(mktemp -d "$TMP/xt.XXXXXX"); mkdir -p "$dir/home"
XT=$( cd "$dir" && env -u XDG_CONFIG_HOME "$K=sk-XTRACE-SECRET" HOME="$dir/home" \
        COUNCIL_ROSTER="$R_CLAUDE" sh -x "$STATE" --json --no-probe 2>&1 )
if grep -q 'sk-XTRACE-SECRET' <<<"$XT"; then
  bad "sh -x trace does not contain the key" "LEAKED"
else ok "sh -x trace does not contain the key" "clean"; fi

echo "== a failing .env level is reported, not silently absent =="
dir=$(mktemp -d "$TMP/pe.XXXXXX"); mkdir -p "$dir/home/.config/council" "$dir/project"
printf '%s=sk-u\n' "$K" > "$dir/home/.config/council/.env"
chmod 000 "$dir/home/.config/council/.env"
if [[ $(id -u) -eq 0 ]]; then
  printf '  skip %-50s (running as root)\n' "unreadable .env level warns"
else
  ERR=$( cd "$dir/project" && env -u XDG_CONFIG_HOME -u "$K" HOME="$dir/home" \
           COUNCIL_ROSTER="$MISSING" sh "$STATE" --text --no-probe 2>&1 )
  if grep -q 'cannot read' <<<"$ERR"; then ok "unreadable .env level warns" "warned"
  else bad "unreadable .env level warns" "silent"; fi
fi
chmod 600 "$dir/home/.config/council/.env"

echo "== neither backend available =="
# council_find_bin is a shell function, so it can be redefined after sourcing --
# no test-only hook in the library is needed to simulate a bare machine.
out=$(sh -c '. "$1"; council_find_bin() { return 1; }
  council_roster_rows /dev/null >/dev/null 2>&1; echo "rc=$?"' _ "$LIB")
t "no jq and no node returns 3" "rc=3" "$out"
out=$(sh -c '. "$1"; council_find_bin() { return 1; }
  council_roster_rows /dev/null 2>&1 >/dev/null' _ "$LIB")
if grep -q 'neither jq nor node' <<<"$out"; then ok "and says which tools are missing" "named"
else bad "and says which tools are missing" "$out"; fi

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
