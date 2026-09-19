#!/bin/bash
# Probe suite for detect.sh. Run after ANY edit:
#   ./test-detect.sh
# Requires node and jq.
#
# WHY THIS SUITE EXISTS SEPARATELY FROM test-council-state.sh
#
# Both replay the same oracle table, but they ask a different question of it.
# test-council-state.sh asks whether council-lib.sh's `COUNCIL_KEY_LEVEL` agrees
# with env.mjs -- the library's answer. This one asks whether the LINE detect.sh
# PRINTS agrees with env.mjs, because that line, and not a shell variable, is what
# gets injected into the model's context and acted on. A correct library reached
# through a wrong render is the same defect to the reader.
#
# So each row checks three separable things, and reports them as three distinct
# failures rather than one:
#
#   1. present/absent agrees with env.mjs        -- drift, the seat-and-spend bug
#   2. that shared answer is the RIGHT one       -- agreeing on a wrong answer
#   3. the printed provenance names the level
#      that actually won                         -- "which source won", phase 3's
#                                                   own requirement
#
# The oracle rows below run with no roster, so the endpoint is the localhost default
# and a closed port refuses immediately. The probe cases, which stand up a real
# loopback server, are in their own section further down.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
DETECT="$HERE/detect.sh"
ENVJS="$HERE/env.mjs"
LIB="$HERE/council-lib.sh"
for f in "$DETECT" "$ENVJS" "$LIB"; do
  [[ -r "$f" ]] || { echo "FAIL: cannot read $f" >&2; exit 1; }
done
command -v jq >/dev/null || { echo "FAIL: jq is required" >&2; exit 1; }

PASS=0; FAIL=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
K=COUNCIL_OPENROUTER_API_KEY

ok()  { PASS=$((PASS+1)); printf '  ok   %-50s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %-50s %s\n' "$1" "$2"; }

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

# OLLAMA_HOST is unset alongside the rest so the endpoint line cannot vary with
# the developer's own environment.
run_detect() { # dir, [env...] -> detect.sh's stdout
  local dir="$1"; shift
  ( cd "$dir/project" && env -u "$K" -u XDG_CONFIG_HOME -u COUNCIL_ROSTER -u OLLAMA_HOST \
      HOME="$dir/home" "$@" sh "$DETECT" 2>/dev/null )
}

node_level() { # dir, [env...] -> env|project|user|none
  local dir="$1"; shift
  ( cd "$dir/project" && env -u "$K" -u XDG_CONFIG_HOME -u COUNCIL_ROSTER \
      HOME="$dir/home" "$@" node "$ENVJS" --json 2>/dev/null ) | jq -r '.source // "none"'
}

# The `openrouter:` line, split into the two facts it asserts.
detect_state=''   # present | absent | unparseable
detect_src=''     # the text inside "(from ...)", empty when absent
read_detect() { # dir, [env...]
  local line
  line=$(run_detect "$@" | grep '^openrouter: ' | head -1)
  case "$line" in
    *' present (from '*) detect_state=present; detect_src=${line#*present (from }; detect_src=${detect_src%%)*} ;;
    *' absent'*)         detect_state=absent;  detect_src='' ;;
    *)                   detect_state=unparseable; detect_src='' ;;
  esac
}

# What detect.sh must print for "(from ...)" at each level. The project file is
# never under the fake HOME, so council_display_path leaves it absolute; the user
# file always is, so it always renders with a tilde.
want_src() { # level, dir
  case "$1" in
    env)     printf 'the environment' ;;
    project) printf '%s/project/.env' "$2" ;;
    user)    printf '~/.config/council/.env' ;;
    *)       printf '' ;;
  esac
}

oracle() { # name, want-level, dir, [env...]
  local name="$1" want="$2" dir="$3"; shift 2
  local n want_state
  n=$(node_level "$@")
  read_detect "$@"
  [[ "$n" == none ]] && want_state=absent || want_state=present
  local d_want; [[ "$want" == none ]] && d_want=absent || d_want=present

  if [[ "$detect_state" == unparseable ]]; then
    bad "$name" "detect.sh printed no openrouter: line"
  elif [[ "$detect_state" != "$want_state" ]]; then
    bad "$name" "DRIFT detect=$detect_state node=$n"
  elif [[ "$detect_state" != "$d_want" ]]; then
    bad "$name" "agreed but wrong: $detect_state (want $want)"
  elif [[ "$want" != none && "$n" != "$want" ]]; then
    bad "$name" "node level wrong: $n (want $want)"
  elif [[ "$want" != none && "$detect_src" != "$(want_src "$want" "$dir")" ]]; then
    bad "$name" "wrong source: $detect_src (want $(want_src "$want" "$dir"))"
  else
    ok "$name" "${detect_src:-absent}"
  fi
}

echo "== oracle: what detect.sh PRINTS must agree with env.mjs, and be right =="
oracle "env only"                    env     "$(fixture '' '')" "$K=sk-e"
oracle "project only"                project "$(fixture "$K=sk-p" '')"
oracle "user only"                   user    "$(fixture '' "$K=sk-u")"
oracle "env beats project and user"  env     "$(fixture "$K=sk-p" "$K=sk-u")" "$K=sk-e"
oracle "project beats user"          project "$(fixture "$K=sk-p" "$K=sk-u")"
oracle "nothing anywhere"            none    "$(fixture '' '')"
oracle "empty project falls through" user    "$(fixture "$K=" "$K=sk-u")"
oracle "whitespace project falls"    user    "$(fixture "$K=   " "$K=sk-u")"
# The divergence this port exists to close: the original grep rejected `export`,
# so detect.sh said "do NOT seat" for a key openrouter.mjs went on to spend.
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
oracle "last-wins: value then empty" user    "$(fixture "$(printf '%s=sk-1\n%s=' "$K" "$K")" "$K=sk-u")"
oracle "last-wins: empty then value" project "$(fixture "$(printf '%s=\n%s=sk-2' "$K" "$K")" '')"

echo "== the reported source must follow XDG_CONFIG_HOME, not just \$HOME =="
XD=$(fixture '' ''); mkdir -p "$XD/xdg/council"
printf '%s=sk-x\n' "$K" > "$XD/xdg/council/.env"; chmod 600 "$XD/xdg/council/.env"
read_detect "$XD" "XDG_CONFIG_HOME=$XD/xdg"
if [[ "$detect_state" != present ]]; then
  bad "XDG_CONFIG_HOME redirect" "$detect_state"
elif [[ "$detect_src" != "$XD/xdg/council/.env" ]]; then
  bad "XDG_CONFIG_HOME redirect" "wrong source: $detect_src"
else
  ok "XDG_CONFIG_HOME redirect" "$detect_src"
fi

echo "== a failing level is reported as failing, not as absent =="
BAD=$(fixture '' ''); rm -rf "$BAD/home/.config/council/.env"
mkdir -p "$BAD/home/.config/council/.env"   # a directory where the file belongs
out=$(run_detect "$BAD")
if grep -q '^openrouter: .* absent' <<<"$out" && grep -q 'warning:.*cannot read' <<<"$out"; then
  ok "unreadable user level warns" "absent + warning"
else
  bad "unreadable user level warns" "$(grep -c warning <<<"$out") warning line(s)"
fi

LOOSE=$(fixture '' "$K=sk-u"); chmod 644 "$LOOSE/home/.config/council/.env"
if run_detect "$LOOSE" | grep -q 'chmod 600'; then
  ok "mode 644 user file warns" "warned"
else
  bad "mode 644 user file warns" "silent"
fi
TIGHT=$(fixture '' "$K=sk-u")
if run_detect "$TIGHT" | grep -q 'warning:'; then
  bad "mode 600 user file does not warn" "warned anyway"
else
  ok "mode 600 user file does not warn" "silent"
fi

echo "== the key value never reaches the context block =="
LEAK=$(fixture "$K=sk-SECRET-p" '')
if run_detect "$LEAK" | grep -q 'sk-SECRET'; then
  bad "no key in detect.sh output" "LEAKED"
else
  ok "no key in detect.sh output" "clean"
fi
# `sh -x detect.sh` is what someone runs when this block misreports, and the trace
# is what they paste into an issue.
XLEAK=$(fixture "$K=sk-SECRET-x" '')
xout=$( ( cd "$XLEAK/project" && env -u "$K" -u XDG_CONFIG_HOME -u COUNCIL_ROSTER \
          HOME="$XLEAK/home" sh -x "$DETECT" ) 2>&1 )
if grep -q 'sk-SECRET' <<<"$xout"; then
  bad "no key in an xtrace" "LEAKED"
else
  ok "no key in an xtrace" "clean"
fi

echo "== exits 0 on every path it reports on =="
rc_of() { run_detect "$@" >/dev/null 2>&1; echo $?; }
EX=$(fixture '' '')
t_rc() { if [[ "$2" == 0 ]]; then ok "$1" "0"; else bad "$1" "exit $2"; fi; }
t_rc "no key, no roster"        "$(rc_of "$EX")"
t_rc "unreadable user level"    "$(rc_of "$BAD")"
ROSTDIR=$(fixture '' ''); mkdir -p "$ROSTDIR/home/.config/council/roster.json"
t_rc "roster path is a directory" "$(rc_of "$ROSTDIR")"
GARBAGE=$(fixture '' ''); printf 'not json at all\n' > "$GARBAGE/home/.config/council/roster.json"
t_rc "roster is not JSON"       "$(rc_of "$GARBAGE")"

echo "== a roster that is not a readable file must not read as absent =="
out=$(run_detect "$ROSTDIR")
if grep -q '^roster: NONE' <<<"$out"; then
  bad "unreadable roster is not 'NONE'" "reported NONE"
elif grep -q '^roster: .*not a readable file' <<<"$out"; then
  ok "unreadable roster is not 'NONE'" "reported as unreadable"
else
  bad "unreadable roster is not 'NONE'" "$(grep '^roster:' <<<"$out")"
fi

echo "== the roster summary is redacted and its truncation is stated =="
CRED=$(fixture '' '')
printf '{"external":{"ollama":{"endpoint":"http://bob:hunter2@lan:11434"}}}\n' \
  > "$CRED/home/.config/council/roster.json"
out=$(run_detect "$CRED")
if grep -q 'hunter2' <<<"$out"; then
  bad "roster userinfo is redacted" "LEAKED"
else
  ok "roster userinfo is redacted" "clean"
fi
# The endpoint line is rendered by council_redact, the summary by the file filter;
# both must hide it, so assert the rendered endpoint separately from the summary.
if grep -q '^ollama-endpoint: .*\*\*\*:\*\*\*@lan:11434' <<<"$out"; then
  ok "endpoint line is redacted" "masked"
else
  bad "endpoint line is redacted" "$(grep '^ollama-endpoint:' <<<"$out")"
fi

LONG=$(fixture '' '')
{ echo '{'; for i in $(seq 1 60); do echo "  \"k$i\": $i,"; done; echo '  "last": 0'; echo '}'; } \
  > "$LONG/home/.config/council/roster.json"
if run_detect "$LONG" | grep -q 'truncated at 40 of'; then
  ok "over-40-line roster says it is partial" "stated"
else
  bad "over-40-line roster says it is partial" "silent"
fi

echo "== the endpoint's winning source is named =="
EP=$(fixture '' '')
printf '{"external":{"ollama":{"endpoint":"http://lan:11434"}}}\n' \
  > "$EP/home/.config/council/roster.json"
line=$(run_detect "$EP" | grep '^ollama-endpoint: ')
[[ "$line" == *'http://lan:11434 (from roster)'* ]] \
  && ok "roster endpoint wins, and says so" "from roster" \
  || bad "roster endpoint wins, and says so" "$line"

NOEP=$(fixture '' '')
line=$( ( cd "$NOEP/project" && env -u "$K" -u XDG_CONFIG_HOME -u COUNCIL_ROSTER \
          HOME="$NOEP/home" OLLAMA_HOST=lan:11434 sh "$DETECT" 2>/dev/null ) | grep '^ollama-endpoint: ')
[[ "$line" == *'http://lan:11434 (from $OLLAMA_HOST)'* ]] \
  && ok "OLLAMA_HOST wins when no roster, and says so" "from \$OLLAMA_HOST" \
  || bad "OLLAMA_HOST wins when no roster, and says so" "$line"

line=$(run_detect "$NOEP" | grep '^ollama-endpoint: ')
[[ "$line" == *'http://localhost:11434 (from default)'* ]] \
  && ok "localhost is the last resort, and says so" "from default" \
  || bad "localhost is the last resort, and says so" "$line"

# A scheme with no port is the single most common way this points at nothing.
line=$( ( cd "$NOEP/project" && env -u "$K" -u XDG_CONFIG_HOME -u COUNCIL_ROSTER \
          HOME="$NOEP/home" OLLAMA_HOST=http://lan sh "$DETECT" 2>/dev/null ) | grep '^ollama-endpoint: ')
[[ "$line" == *'WARNING: no port given with a scheme'* ]] \
  && ok "scheme without a port is called out" "warned" \
  || bad "scheme without a port is called out" "$line"

echo "== the probe: what actually answered on the endpoint =="
# Phase 3 deliberately left these out; this is phase 8. A real loopback server is
# used rather than a mocked curl, because the thing under test is the shape of the
# reply detect.sh accepts -- and a mock would just restate the assertion.
cat > "$TMP/server.mjs" <<'JS'
import { createServer } from "node:http";
import { writeFileSync } from "node:fs";
const status = Number(process.argv[2]);
const body = process.argv[3];
const pathLog = process.argv[4];
const srv = createServer((req, res) => {
  if (pathLog) writeFileSync(pathLog, req.url);
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(body);
});
srv.listen(0, "127.0.0.1", () => console.log(srv.address().port));
JS

# The port and the pid travel through FILES and start_server is never called in a
# command substitution, because a variable it set there would die with the subshell
# -- which is how a "stopped" server went on answering the next case.
PORTF="$TMP/port"; PIDF="$TMP/pid"; SRV_PORT=''
start_server() { # status, body, [path-log] -> sets $SRV_PORT
  : > "$PORTF"
  node "$TMP/server.mjs" "$1" "$2" "${3:-}" > "$PORTF" 2>/dev/null &
  echo $! > "$PIDF"
  # Drop it from the job table. Otherwise bash announces "Terminated" on every
  # stop_server, interleaved with the results, where it reads like a failure.
  disown 2>/dev/null || true
  local i
  SRV_PORT=''
  for ((i = 0; i < 200; i++)); do
    SRV_PORT=$(tr -d '[:space:]' < "$PORTF")
    [[ -n "$SRV_PORT" ]] && return 0
    command sleep 0.05
  done
  return 1
}
stop_server() {
  local pid; pid=$(cat "$PIDF" 2>/dev/null)
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
  : > "$PIDF"
}
# A killed listener can linger for a moment, and asserting "not reachable" while it
# is still up would be a flake that looks like a defect.
wait_closed() { # port
  local i
  for ((i = 0; i < 200; i++)); do
    curl -fsS -m 1 "http://127.0.0.1:$1/api/tags" >/dev/null 2>&1 || return 0
    command sleep 0.05
  done
  return 1
}

probe_line() { # dir, port -> the ollama-server: line
  ( cd "$1/project" && env -u "$K" -u XDG_CONFIG_HOME -u COUNCIL_ROSTER \
      HOME="$1/home" OLLAMA_HOST="127.0.0.1:$2" sh "$DETECT" 2>/dev/null ) \
    | grep '^ollama-server: '
}

PD=$(fixture '' '')
PATHLOG="$TMP/reqpath"

start_server 200 '{"models":[{"name":"a:1b"},{"name":"b:2b"}]}' "$PATHLOG" || bad "server start" "timed out"
line=$(probe_line "$PD" "$SRV_PORT")
[[ "$line" == *'UP (~2 models)'* ]] \
  && ok "an Ollama-shaped reply is UP, with a count" "$line" \
  || bad "an Ollama-shaped reply is UP, with a count" "$line"
# /api/tags emits `models` unconditionally, which is what makes that key a usable
# fingerprint. Assert the probe actually asked that endpoint.
[[ "$(cat "$PATHLOG" 2>/dev/null)" == "/api/tags" ]] \
  && ok "the probe asks /api/tags" "/api/tags" \
  || bad "the probe asks /api/tags" "'$(cat "$PATHLOG" 2>/dev/null)'"
stop_server

# A healthy server with nothing pulled yet must NOT read as down. That is why the
# fingerprint is the `models` key rather than a non-empty model list.
start_server 200 '{"models":[]}'
line=$(probe_line "$PD" "$SRV_PORT")
[[ "$line" == *'UP'* ]] \
  && ok "a server with no models pulled is still UP" "$line" \
  || bad "a server with no models pulled is still UP" "$line"
stop_server

# Something else on the port is a different fact from nothing on the port, and
# seating on it would send council prompts to whatever that service is.
start_server 200 '{"status":"ok","service":"not-ollama"}'
line=$(probe_line "$PD" "$SRV_PORT")
[[ "$line" == *'not Ollama'* ]] \
  && ok "a non-Ollama 200 is called out, not accepted" "$line" \
  || bad "a non-Ollama 200 is called out, not accepted" "$line"
stop_server

# curl -fsS turns a 5xx into a non-zero exit and an empty body, so a proxy's error
# page never gets parsed as an answer.
start_server 500 '<html>bad gateway</html>'
line=$(probe_line "$PD" "$SRV_PORT")
[[ "$line" == *'not reachable'* ]] \
  && ok "an HTTP 500 is not reachable, not an answer" "$line" \
  || bad "an HTTP 500 is not reachable, not an answer" "$line"
stop_server

# Nothing listening at all. Bind a port, learn it, release it -- asking for a port
# nobody is on is otherwise a guess that can collide with a real service.
start_server 200 '{"models":[]}'
CLOSED_PORT="$SRV_PORT"
stop_server
if wait_closed "$CLOSED_PORT"; then
  line=$(probe_line "$PD" "$CLOSED_PORT")
  [[ "$line" == *'not reachable'* ]] \
    && ok "a closed port is not reachable" "$line" \
    || bad "a closed port is not reachable" "$line"
else
  bad "a closed port is not reachable" "the listener never went away"
fi

echo "== a missing library degrades instead of half-reporting =="
ORPHAN="$TMP/orphan"; mkdir -p "$ORPHAN"; cp "$DETECT" "$ORPHAN/detect.sh"
out=$(sh "$ORPHAN/detect.sh" 2>/dev/null); rc=$?
if [[ $rc -eq 0 && "$out" == *"cannot read council-lib.sh"* ]]; then
  ok "no council-lib.sh: names the cause, exits 0" "rc=0"
else
  bad "no council-lib.sh: names the cause, exits 0" "rc=$rc out=$out"
fi

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
