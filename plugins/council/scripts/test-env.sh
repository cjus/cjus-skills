#!/bin/bash
# Probe suite for env.mjs. Run it after ANY edit to that file:
#   ./test-env.sh ./env.mjs
# Requires node and jq.
#
# WHY THIS SUITE IS SHAPED THE WAY IT IS
#
# The precedence chain will end up with TWO implementations: this one, and the
# POSIX `sh` re-implementation inside `detect.sh`, which must stay Node-free and
# therefore cannot call into here. Two implementations of one rule drift, and the
# drift is invisible -- detect.sh reports "absent" in the context block while
# openrouter.mjs seats the member anyway, or the reverse.
#
# So the presence cases below are a TABLE, not a pile of assertions, and the
# table is the oracle both implementations answer to. The sh side now lives in
# council-lib.sh, and `test-council-state.sh` replays this same table against it,
# failing a row when the two DISAGREE and also when they agree on a wrong answer.
# That second half is not decoration: `K=  # note` was resolved as the literal
# key "# note" by both sides at once, and only the expected-value column caught it.
#
# The value-fidelity cases are separate and node-only, because the CLI
# deliberately has no flag that prints a key -- they call parseEnvFile directly.
set -u
ENVJS="$1"
case "$ENVJS" in /*) ;; *) ENVJS="$PWD/$ENVJS" ;; esac
[[ -r "$ENVJS" ]] || { echo "FAIL: cannot read $ENVJS" >&2; exit 1; }

PASS=0; FAIL=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# A fake HOME per case, so a real ~/.config/council/.env on the developer's
# machine can never satisfy a case that is supposed to find nothing. Without
# this the suite passes on the one machine that already has a key and nowhere
# else -- which is precisely the class of bug it exists to catch.
fixture() { # -> prints a fresh sandbox dir with $1=project .env body, $2=user .env body
  local dir; dir=$(mktemp -d "$TMP/case.XXXXXX")
  mkdir -p "$dir/project" "$dir/home/.config/council"
  [[ -n "${1:-}" ]] && printf '%s\n' "$1" > "$dir/project/.env"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" > "$dir/home/.config/council/.env"
    chmod 600 "$dir/home/.config/council/.env"
  fi
  echo "$dir"
}

probe() { # dir, [extra env assignments...] -> JSON on stdout, stderr discarded
  local dir="$1"; shift
  ( cd "$dir/project" && env -u COUNCIL_OPENROUTER_API_KEY -u XDG_CONFIG_HOME \
      HOME="$dir/home" "$@" node "$ENVJS" --json 2>/dev/null )
}

# The same invocation keeping stderr and dropping stdout. Three cases below
# assert on a WARNING, and `probe` discards stderr inside its own subshell -- an
# outer `2>&1 >/dev/null` cannot recover what has already been dropped at the
# source, so it silently reports "no warning" for a warning that did fire.
stderr_of() { # dir, [extra env assignments...] -> whatever went to stderr
  local dir="$1"; shift
  ( cd "$dir/project" && env -u COUNCIL_OPENROUTER_API_KEY -u XDG_CONFIG_HOME \
      HOME="$dir/home" "$@" node "$ENVJS" --json 2>&1 >/dev/null )
}

source_of() { probe "$@" | jq -r '.source // "none"'; }

t() { # name, expected-source, dir, [extra env...]
  local name="$1" want="$2"; shift 2
  local got; got=$(source_of "$@")
  if [[ "$got" == "$want" ]]; then PASS=$((PASS+1)); printf '  ok   %-54s %s\n' "$name" "$got"
  else FAIL=$((FAIL+1)); printf '  FAIL %-54s got=%s want=%s\n' "$name" "$got" "$want"; fi
}

K=COUNCIL_OPENROUTER_API_KEY

echo "== precedence: most-specific wins =="
t "env only"                        env     "$(fixture '' '')"            "$K=sk-e"
t "project .env only"               project "$(fixture "$K=sk-p" '')"
t "user .env only"                  user    "$(fixture '' "$K=sk-u")"
t "env beats project and user"      env     "$(fixture "$K=sk-p" "$K=sk-u")" "$K=sk-e"
t "project beats user"              project "$(fixture "$K=sk-p" "$K=sk-u")"
t "nothing anywhere"                none    "$(fixture '' '')"

echo "== absent-vs-empty: an empty key must fall through, not 401 =="
t "empty project value falls to user"    user "$(fixture "$K=" "$K=sk-u")"
t "whitespace project value falls to user" user "$(fixture "$K=   " "$K=sk-u")"
t "empty env value falls to project" project "$(fixture "$K=sk-p" '')" "$K="
t "empty everywhere is absent"      none    "$(fixture "$K=" "$K=")"

echo "== line forms recognised =="
t "plain KEY=value"                 project "$(fixture "$K=sk-p" '')"
t "indented"                        project "$(fixture "   $K=sk-p" '')"
t "export prefix"                   project "$(fixture "export $K=sk-p" '')"
t "double quoted"                   project "$(fixture "$K=\"sk-p\"" '')"
t "single quoted"                   project "$(fixture "$K='sk-p'" '')"
t "CRLF line endings"               project "$(fixture "$(printf '%s=sk-p\r' "$K")" '')"
t "key among other vars"            project "$(fixture "$(printf 'A=1\n%s=sk-p\nB=2' "$K")" '')"

echo "== line forms deliberately NOT recognised =="
t "commented out"                   user    "$(fixture "# $K=sk-p" "$K=sk-u")"
t "commented with indent"           user    "$(fixture "  #$K=sk-p" "$K=sk-u")"
t "KEY: value (dotenv alt form)"    user    "$(fixture "$K: sk-p" "$K=sk-u")"
t "unprefixed OPENROUTER_API_KEY"   none    "$(fixture "OPENROUTER_API_KEY=sk-x" '')"

echo "== XDG_CONFIG_HOME =="
XDGDIR=$(fixture '' ''); mkdir -p "$XDGDIR/xdg/council"
printf '%s=sk-x\n' "$K" > "$XDGDIR/xdg/council/.env"; chmod 600 "$XDGDIR/xdg/council/.env"
t "XDG_CONFIG_HOME redirects user file" user "$XDGDIR" "XDG_CONFIG_HOME=$XDGDIR/xdg"
XDGONLY=$(fixture '' "$K=sk-u")
t "XDG set but empty there = absent"    none "$XDGONLY" "XDG_CONFIG_HOME=$XDGONLY/empty"

echo "== a failing level must not look like an absent one =="
BADDIR=$(fixture '' ''); rm -rf "$BADDIR/home/.config/council/.env"
mkdir -p "$BADDIR/home/.config/council/.env"   # a directory where the file belongs
t "user path is a directory -> absent, not crash" none "$BADDIR"
if [[ -n "$(stderr_of "$BADDIR")" ]]; then
  PASS=$((PASS+1)); printf '  ok   %-54s warned\n' "unreadable level warns on stderr"
else
  FAIL=$((FAIL+1)); printf '  FAIL %-54s silent\n' "unreadable level warns on stderr"
fi

UNREAD=$(fixture "$K=sk-p" ''); chmod 000 "$UNREAD/project/.env"
if [[ $(id -u) -eq 0 ]]; then
  printf '  skip %-54s (running as root)\n' "unreadable project .env falls through"
else
  t "unreadable project .env falls through" none "$UNREAD"
fi
chmod 600 "$UNREAD/project/.env"

echo "== mode warning on the user-level key file =="
LOOSE=$(fixture '' "$K=sk-u"); chmod 644 "$LOOSE/home/.config/council/.env"
if stderr_of "$LOOSE" | grep -q 'chmod 600'; then
  PASS=$((PASS+1)); printf '  ok   %-54s warned\n' "mode 644 user file warns"
else
  FAIL=$((FAIL+1)); printf '  FAIL %-54s no warning\n' "mode 644 user file warns"
fi
TIGHT=$(fixture '' "$K=sk-u")
if [[ -z "$(stderr_of "$TIGHT")" ]]; then
  PASS=$((PASS+1)); printf '  ok   %-54s silent\n' "mode 600 user file does not warn"
else
  FAIL=$((FAIL+1)); printf '  FAIL %-54s warned anyway\n' "mode 600 user file does not warn"
fi

echo "== the CLI never prints the value =="
LEAK=$(fixture "$K=sk-SECRET-p" "")
for flag in "" "--json"; do
  out=$( ( cd "$LEAK/project" && env -u COUNCIL_OPENROUTER_API_KEY -u XDG_CONFIG_HOME \
           HOME="$LEAK/home" node "$ENVJS" $flag 2>&1 ) )
  if grep -q 'sk-SECRET' <<<"$out"; then
    FAIL=$((FAIL+1)); printf '  FAIL %-54s LEAKED\n' "no key in output ${flag:-(default)}"
  else
    PASS=$((PASS+1)); printf '  ok   %-54s clean\n' "no key in output ${flag:-(default)}"
  fi
done

echo "== exit status: 0 present, 3 absent (mirrors openrouter.mjs) =="
EXP=$(fixture "$K=sk-p" ''); probe "$EXP" >/dev/null
( cd "$EXP/project" && env -u COUNCIL_OPENROUTER_API_KEY -u XDG_CONFIG_HOME HOME="$EXP/home" \
    node "$ENVJS" >/dev/null 2>&1 )
[[ $? -eq 0 ]] && { PASS=$((PASS+1)); printf '  ok   %-54s 0\n' "present exits 0"; } \
               || { FAIL=$((FAIL+1)); printf '  FAIL %-54s not 0\n' "present exits 0"; }
EXA=$(fixture '' '')
( cd "$EXA/project" && env -u COUNCIL_OPENROUTER_API_KEY -u XDG_CONFIG_HOME HOME="$EXA/home" \
    node "$ENVJS" >/dev/null 2>&1 )
[[ $? -eq 3 ]] && { PASS=$((PASS+1)); printf '  ok   %-54s 3\n' "absent exits 3"; } \
               || { FAIL=$((FAIL+1)); printf '  FAIL %-54s not 3\n' "absent exits 3"; }

# ── value fidelity ────────────────────────────────────────────────────────────
# These call parseEnvFile directly. They are the cases where presence is not the
# question -- a truncated or expanded key is PRESENT and wrong, and reaches the
# provider as a 401 that points nowhere near the file that caused it.
echo "== value fidelity (parseEnvFile) =="
pv() { # env-file-body -> the parsed value as JSON, or __ABSENT__
  printf '%s\n' "$1" > "$TMP/unit.env"
  # The module path travels in the ENVIRONMENT, not in argv. Under `node -e` the
  # first trailing argument lands at process.argv[1], so passing env.mjs there
  # makes its own is-this-the-main-module guard fire: the CLI runs, prints
  # "absent", exits 3, and every case below reads as a parser failure.
  COUNCIL_ENVJS="$ENVJS" node -e '
    const fs = require("fs");
    import(process.env.COUNCIL_ENVJS).then((m) => {
      const v = m.parseEnvFile(fs.readFileSync(process.argv[1], "utf8")).get(m.KEY_NAME);
      process.stdout.write(v === undefined ? "__ABSENT__" : JSON.stringify(v));
    });
  ' "$TMP/unit.env"
}

v() { # name, expected-json, body
  local got; got=$(pv "$3")
  if [[ "$got" == "$2" ]]; then PASS=$((PASS+1)); printf '  ok   %-54s %s\n' "$1" "$got"
  else FAIL=$((FAIL+1)); printf '  FAIL %-54s got=%s want=%s\n' "$1" "$got" "$2"; fi
}

v "plain value"                  '"sk-p"'      "$K=sk-p"
v "trailing comment dropped"     '"sk-p"'      "$K=sk-p # prod key"
v "hash inside value KEPT"       '"sk-a#b"'    "$K=sk-a#b"
# A value that is nothing but a comment is EMPTY, not the comment's text. The
# whitespace that marks the comment is consumed as the gap after `=`, so the
# "whitespace must precede #" rule cannot see it and needs this case to pin it.
v "comment-only tail is empty"   '""'          "$K=  # note"
v "value starting with # empty"  '""'          "$K=#note"
v "quote a value that needs #"   '"#note"'     "$K=\"#note\""
v "hash inside quotes kept"      '"sk-a#b"'    "$K=\"sk-a#b\""
v "surrounding space trimmed"    '"sk-p"'      "$K=   sk-p   "
v "quotes preserve inner space"  '" sk-p "'    "$K=\" sk-p \""
v "no interpolation of \${VAR}"  '"${HOME}"'   "$K=\${HOME}"
v "no interpolation of \$VAR"    '"$HOME"'     "$K=\$HOME"
v "last assignment wins"         '"sk-2"'      "$(printf '%s=sk-1\n%s=sk-2' "$K" "$K")"
v "no trailing newline"          '"sk-p"'      "$(printf '%s=sk-p' "$K")"
v "empty value is empty string"  '""'          "$K="

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
