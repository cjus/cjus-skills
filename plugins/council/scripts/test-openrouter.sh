#!/bin/bash
# Probe suite for openrouter.mjs. Run after ANY edit:
#   ./test-openrouter.sh
# Requires node. Makes NO network calls.
#
# WHY THE NETWORK IS STUBBED WITH A PRELOAD
#
# Three of the four exit paths are reachable offline, but exit 4 -- an HTTP failure,
# and a 200 carrying no usable content -- is not, because the endpoint is a
# hardcoded constant.
#
# The obvious fix, an env var to override the endpoint, is one this suite
# deliberately does NOT ask for. This script's whole reason to exist is that the key
# never leaves the process: an overridable endpoint on a script that attaches a
# bearer token means anyone who can set an environment variable can redirect that
# token to a host they control. A test seam is not worth that.
#
# So `node --import` installs a fetch stub BEFORE the script loads. No production
# code changes, no new interface, no new way to move the key. The stub also records
# what it was handed, which is how the cases below assert the key really was sent as
# a bearer token while never appearing in output -- a script that leaked nothing
# because it sent nothing would pass the leak case on its own.
#
# THE INVOCATION LIVES IN ONE FUNCTION ON PURPOSE
#
# `run_or` is the only thing here that knows how the script takes its arguments. It
# was written that way while the `M=`/`P=` interface was still under an operator
# decision, and when that decision landed as `--model`/`--prompt-file` this suite
# changed in one function rather than in thirty call sites. Keep it that way.
#
# The point of the flags is that the command now BEGINS with `node`, so an
# `allowed-tools` entry of `Bash(node:*)` matches it. A leading `M=` assignment did
# not match, because Claude Code strips one only for a known-safe set of variable
# names -- so every OpenRouter member used to prompt the user.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
OR="$HERE/openrouter.mjs"
for f in "$OR" "$HERE/env.mjs"; do
  [[ -r "$f" ]] || { echo "FAIL: cannot read $f" >&2; exit 1; }
done
command -v node >/dev/null || { echo "FAIL: node is required" >&2; exit 1; }

PASS=0; FAIL=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
K=COUNCIL_OPENROUTER_API_KEY

ok()  { PASS=$((PASS+1)); printf '  ok   %-52s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %-52s %s\n' "$1" "$2"; }

# ── the fetch stub ────────────────────────────────────────────────────────────
cat > "$TMP/stub.mjs" <<'JS'
import { writeFileSync } from "node:fs";
const log = process.env.STUB_LOG;
const mode = process.env.STUB_MODE ?? "ok";
const json = (payload) => ({
  ok: true, status: 200,
  json: async () => payload,
  text: async () => JSON.stringify(payload),
});
globalThis.fetch = async (url, init) => {
  if (log) {
    writeFileSync(log, JSON.stringify({
      url: String(url),
      auth: init?.headers?.Authorization ?? null,
      body: init?.body ?? null,
      argv: process.argv,
    }));
  }
  switch (mode) {
    case "http401":   return { ok: false, status: 401, text: async () => "insufficient credit" };
    case "http500":   return { ok: false, status: 500, text: async () => "upstream exploded" };
    case "empty":     return json({ choices: [{ message: { content: "   " } }] });
    case "nochoice":  return json({});
    case "nonstring": return json({ choices: [{ message: { content: 42 } }] });
    case "throw":     { const e = new Error("connect ECONNREFUSED"); e.cause = { code: "ECONNREFUSED" }; throw e; }
    case "timeout":   { const e = new Error("timed out"); e.name = "TimeoutError"; throw e; }
    case "badjson":   return { ok: true, status: 200,
                               json: async () => { throw new SyntaxError("Unexpected token <"); },
                               text: async () => "<html>portal</html>" };
    default:          return json({ choices: [{ message: { content: "stub answer" } }] });
  }
};
JS

# Reads one field out of what the stub recorded, without any shell quoting of JSON.
cat > "$TMP/field.mjs" <<'JS'
import { readFileSync } from "node:fs";
const rec = JSON.parse(readFileSync(process.env.STUB_LOG, "utf8"));
const body = rec.body ? JSON.parse(rec.body) : {};
const pick = {
  url: () => rec.url,
  auth: () => String(rec.auth),
  model: () => String(body.model),
  prompt: () => String(body.messages?.[0]?.content),
  argv: () => rec.argv.join(" "),
};
process.stdout.write(pick[process.argv[2]]());
JS
field() { STUB_LOG="$SENT" node "$TMP/field.mjs" "$1"; }

# A sandbox per case: empty project dir plus a fake HOME, so a real
# ~/.config/council/.env on this machine cannot satisfy a no-key case.
sandbox() { # [project-env-body] -> dir
  local dir; dir=$(mktemp -d "$TMP/case.XXXXXX")
  mkdir -p "$dir/project" "$dir/home/.config/council"
  [[ -n "${1:-}" ]] && printf '%s\n' "$1" > "$dir/project/.env"
  printf 'the prompt\n' > "$dir/project/prompt.txt"
  echo "$dir"
}

# Results go through FILES, not variables. A caller wanting the output would
# otherwise run this in a command substitution, where any variable it set dies with
# the subshell -- and the caller silently reads the previous case's exit status.
OUT="$TMP/stdout"; ERR="$TMP/stderr"; RCF="$TMP/rc"; SENT="$TMP/sent.json"

# THE ONLY PLACE THAT KNOWS THE CALLING CONVENTION. See the header.
run_or() { # dir, model, prompt-path, [extra env...]
  local dir="$1" model="$2" prompt="$3"; shift 3
  # An array, so a value containing a space stays one argument. `${a[@]+"${a[@]}"}`
  # rather than `"${a[@]}"`: this is bash 3.2, where an empty array under `set -u`
  # is an unbound-variable error, and several cases below pass no flags at all.
  local -a flags=()
  [[ -n "$model" ]]  && flags+=(--model "$model")
  [[ -n "$prompt" ]] && flags+=(--prompt-file "$prompt")
  ( cd "$dir/project" && env -u "$K" -u XDG_CONFIG_HOME -u M -u P HOME="$dir/home" \
      STUB_LOG="${WANT_LOG:-}" "$@" \
      node --import "$TMP/stub.mjs" "$OR" ${flags[@]+"${flags[@]}"} ) >"$OUT" 2>"$ERR"
  printf '%s' $? > "$RCF"
}
# For cases that test the argument GRAMMAR rather than a normal call.
run_argv() { # dir, [literal args...]
  local dir="$1"; shift
  ( cd "$dir/project" && env -u "$K" -u XDG_CONFIG_HOME -u M -u P HOME="$dir/home" \
      node --import "$TMP/stub.mjs" "$OR" "$@" ) >"$OUT" 2>"$ERR"
  printf '%s' $? > "$RCF"
}

rc()  { cat "$RCF"; }
outp() { cat "$OUT"; }

rc_case() { # name, want-rc, dir, model, prompt, [env...]
  local name="$1" want="$2"; shift 2
  run_or "$@"
  if [[ "$(rc)" == "$want" ]]; then ok "$name" "exit $(rc)"
  else bad "$name" "exit $(rc), want $want -- $(head -1 "$ERR")"; fi
}

echo "== exit 5: bad usage, before anything else happens =="
D=$(sandbox)
rc_case "neither flag"                 5 "$D" ""    ""
rc_case "--model without --prompt-file" 5 "$D" "a/b" ""
rc_case "--prompt-file without --model" 5 "$D" ""    "./prompt.txt"
# Usage is checked BEFORE the key chain: a caller who mistyped the invocation must
# not be told their key is missing.
run_or "$D" "" ""
if grep -qi 'usage' "$ERR" && ! grep -q "$K" "$ERR"; then
  ok "a usage error does not blame the key chain" "usage only"
else
  bad "a usage error does not blame the key chain" "$(head -1 "$ERR")"
fi

echo "== the argument grammar =="
DK=$(sandbox "$K=sk-p")
run_argv "$DK" --model=a/b --prompt-file=./prompt.txt
[[ "$(rc)" == 0 ]] && ok "--flag=value is accepted" "exit 0" \
                   || bad "--flag=value is accepted" "exit $(rc) -- $(head -1 "$ERR")"
run_argv "$DK" --model a/b --prompt-file ./prompt.txt
[[ "$(rc)" == 0 ]] && ok "--flag value is accepted" "exit 0" \
                   || bad "--flag value is accepted" "exit $(rc) -- $(head -1 "$ERR")"
run_argv "$DK" --model a/b --prompt-file ./prompt.txt --colour never
[[ "$(rc)" == 5 ]] && ok "an unknown flag is refused" "exit 5" \
                   || bad "an unknown flag is refused" "exit $(rc)"
# Taking the next flag as a value would send the string "--prompt-file" to
# OpenRouter as a model id, and bill a request for it.
run_argv "$DK" --model --prompt-file ./prompt.txt
[[ "$(rc)" == 5 ]] && ok "a flag swallowing the next flag is refused" "exit 5" \
                   || bad "a flag swallowing the next flag is refused" "exit $(rc)"
run_argv "$DK" --model= --prompt-file ./prompt.txt
[[ "$(rc)" == 5 ]] && ok "an empty --flag= is refused" "exit 5" \
                   || bad "an empty --flag= is refused" "exit $(rc)"

# The retired interface must fail LOUDLY and say what changed, not look like a typo.
( cd "$DK/project" && env -u "$K" -u XDG_CONFIG_HOME HOME="$DK/home" \
    M=a/b P=./prompt.txt node --import "$TMP/stub.mjs" "$OR" ) >"$OUT" 2>"$ERR"
retired_rc=$?
if [[ "$retired_rc" == 5 ]] && grep -q 'M=/P=' "$ERR" && grep -q -- '--prompt-file' "$ERR"; then
  ok "the retired M=/P= form names what replaced it" "exit 5, migration named"
else
  bad "the retired M=/P= form names what replaced it" "exit $retired_rc -- $(head -1 "$ERR")"
fi

echo "== exit 3: no key resolves anywhere =="
rc_case "no key at any level"          3 "$(sandbox)" "a/b" "./prompt.txt"
run_or "$(sandbox)" "a/b" "./prompt.txt"
# "Not set" without the chain sends the caller looking in one place, which is how a
# key ends up in the file the tool does not read.
miss=""
for want in 'the environment' '/.env' 'Checked, in order'; do
  grep -q "$want" "$ERR" || miss="$miss [$want]"
done
[[ -z "$miss" ]] && ok "exit 3 names every level it checked" "all three" \
                 || bad "exit 3 names every level it checked" "missing:$miss"
grep -q 'Do not seat this member' "$ERR" \
  && ok "exit 3 tells the caller not to seat" "stated" \
  || bad "exit 3 tells the caller not to seat" "$(head -1 "$ERR")"
grep -q 'OPENROUTER_API_KEY' "$ERR" && grep -q 'COUNCIL_ name' "$ERR" \
  && ok "exit 3 says to set the COUNCIL_ name" "stated" \
  || bad "exit 3 says to set the COUNCIL_ name" "$(head -1 "$ERR")"

echo "== the key is USED but never printed =="
WANT_LOG="$SENT"
run_or "$(sandbox "$K=sk-SECRET-project")" "openai/gpt-5.6-sol" "./prompt.txt"
[[ "$(rc)" == 0 ]] && ok "a resolved key produces a 0 exit" "exit 0" \
                   || bad "a resolved key produces a 0 exit" "exit $(rc) -- $(head -1 "$ERR")"
if grep -q 'sk-SECRET' "$OUT" "$ERR"; then
  bad "the key never reaches stdout or stderr" "LEAKED"
else
  ok "the key never reaches stdout or stderr" "clean"
fi
[[ "$(field auth)" == "Bearer sk-SECRET-project" ]] \
  && ok "the key IS sent, as a bearer token" "Bearer sk-..." \
  || bad "the key IS sent, as a bearer token" "got '$(field auth)'"
[[ "$(outp)" == "stub answer" ]] \
  && ok "the answer goes to stdout, alone" "stub answer" \
  || bad "the answer goes to stdout, alone" "got '$(outp)'"

# The arguments moved into argv, which every other user on the box can read from
# the process table. That is fine for a model id and a path, and is exactly what
# must never happen to the key -- so assert both halves rather than trusting the
# split.
[[ "$(field argv)" == *"openai/gpt-5.6-sol"* && "$(field argv)" == *"prompt.txt"* ]] \
  && ok "argv carries the model and the prompt path" "both present" \
  || bad "argv carries the model and the prompt path" "$(field argv)"
[[ "$(field argv)" != *"sk-SECRET"* ]] \
  && ok "argv never carries the key" "clean" \
  || bad "argv never carries the key" "LEAKED INTO ARGV"

echo "== the request is shaped the way the skill promises =="
[[ "$(field url)" == "https://openrouter.ai/api/v1/chat/completions" ]] \
  && ok "posts to /api/v1/..., not /v1/..." "$(field url)" \
  || bad "posts to /api/v1/..., not /v1/..." "$(field url)"
# OpenRouter treats `model` as optional and silently falls back to the account
# default, which would misreport which member answered.
[[ "$(field model)" == "openai/gpt-5.6-sol" ]] \
  && ok "model is always sent explicitly" "$(field model)" \
  || bad "model is always sent explicitly" "got '$(field model)'"

# Reading the prompt from a FILE is the reason this is a script rather than a curl
# pipeline. The fixture is a quoted heredoc: a case that exists to prove shell
# quoting is not involved should not depend on getting shell quoting right.
D=$(sandbox "$K=sk-p")
cat > "$D/project/nasty.txt" <<'NASTY'
he said "$(rm -rf /)" and `backticks` and 'single quotes'
a trailing $VAR, a literal \n, and a tab	here
NASTY
run_or "$D" "a/b" "./nasty.txt"
if [[ "$(field prompt)" == "$(cat "$D/project/nasty.txt")" ]]; then
  ok "a prompt of shell metacharacters survives" "byte-identical"
else
  bad "a prompt of shell metacharacters survives" "mangled"
fi
unset WANT_LOG

echo "== exit 4: the provider answered, but not usefully =="
rc_case "HTTP 401"                     4 "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=http401
rc_case "HTTP 500"                     4 "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=http500
# A 200 with nothing usable in it leaves the caller exactly where a 500 does: this
# member has no answer. Exiting 0 with empty stdout would read as a member that
# answered with silence, and silence is not a position.
rc_case "200, whitespace-only content"   4 "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=empty
rc_case "200, no choices at all"         4 "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=nochoice
rc_case "200, content is not a string"   4 "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=nonstring

# The request never completing is the most ordinary failure this script has, and it
# used to reject unhandled and exit 1 -- outside its own documented contract.
rc_case "the network refuses the connection" 4 "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=throw
rc_case "the request times out"              4 "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=timeout
rc_case "a 200 that is not JSON"             4 "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=badjson
run_or "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=throw
grep -q 'ECONNREFUSED' "$ERR" && ok "the network error names the cause" "ECONNREFUSED" \
                             || bad "the network error names the cause" "$(head -1 "$ERR")"

run_or "$(sandbox "$K=sk-p")" "a/b" "./prompt.txt" STUB_MODE=http401
grep -q '401' "$ERR" && ok "the HTTP status is named" "401" \
                     || bad "the HTTP status is named" "$(head -1 "$ERR")"
run_or "$(sandbox "$K=sk-SECRET-p")" "a/b" "./prompt.txt" STUB_MODE=http401
grep -q 'sk-SECRET' "$ERR" && bad "an HTTP failure does not leak the key" "LEAKED" \
                           || ok "an HTTP failure does not leak the key" "clean"
[[ ! -s "$OUT" ]] && ok "a failed member writes nothing to stdout" "empty" \
                  || bad "a failed member writes nothing to stdout" "$(head -c 40 "$OUT")"

echo "== a prompt file that cannot be read =="
# This used to reject unhandled and exit 1 with a stack trace -- a code the caller
# does not know and cannot act on. It is a usage error in the same sense a missing
# --prompt-file is, so it is exit 5 and names the path.
run_or "$(sandbox "$K=sk-p")" "a/b" "./no-such-prompt.txt"
[[ "$(rc)" == 5 ]] && ok "a missing prompt file is exit 5" "exit 5" \
                   || bad "a missing prompt file is exit 5" "exit $(rc)"
grep -q 'no-such-prompt.txt' "$ERR" \
  && ok "and the message names the path" "named" \
  || bad "and the message names the path" "$(head -1 "$ERR")"
UNREADABLE=$(sandbox "$K=sk-p"); chmod 000 "$UNREADABLE/project/prompt.txt"
if [[ $(id -u) -eq 0 ]]; then
  printf '  skip %-52s (running as root)\n' "an unreadable prompt file is exit 5"
else
  run_or "$UNREADABLE" "a/b" "./prompt.txt"
  [[ "$(rc)" == 5 ]] && ok "an unreadable prompt file is exit 5" "exit 5" \
                     || bad "an unreadable prompt file is exit 5" "exit $(rc)"
fi
chmod 600 "$UNREADABLE/project/prompt.txt"
grep -q "$K" "$ERR" && bad "a missing prompt file is not blamed on the key" "blamed the key" \
                    || ok "a missing prompt file is not blamed on the key" "clean"
[[ ! -s "$OUT" ]] && ok "and writes nothing to stdout" "empty" \
                  || bad "and writes nothing to stdout" "$(head -c 40 "$OUT")"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
