#!/bin/bash
# Probe suite for guard-default-branch.sh. Run it after ANY edit to that hook:
#   ./test-guard-default-branch.sh ./guard-default-branch.sh
# Every case below corresponds to a bypass the hook's comments name. Reading the
# hook is not evidence that it works; this is. Requires jq and git.
HOOK="$1"
PASS=0; FAIL=0

# Two throwaway repos: one on the default branch, one on a feature branch.
MAINREPO=$(mktemp -d); git -C "$MAINREPO" init -q -b main
git -C "$MAINREPO" config user.email t@t; git -C "$MAINREPO" config user.name t
echo x > "$MAINREPO/f"; git -C "$MAINREPO" add -A
git -C "$MAINREPO" -c core.hooksPath=/dev/null commit -qm init

FEATREPO=$(mktemp -d); git -C "$FEATREPO" init -q -b main
git -C "$FEATREPO" config user.email t@t; git -C "$FEATREPO" config user.name t
echo x > "$FEATREPO/f"; git -C "$FEATREPO" add -A
git -C "$FEATREPO" -c core.hooksPath=/dev/null commit -qm init
git -C "$FEATREPO" checkout -q -b feature/1-x

verdict() { # cwd, mode, command -> "ask"|"deny"|"pass"
  local out
  out=$(jq -nc --arg c "$1" --arg m "$2" --arg cmd "$3" \
    '{cwd:$c,permission_mode:$m,tool_input:{command:$cmd}}' | bash "$HOOK")
  if [[ -z "$out" ]]; then echo pass
  else echo "$out" | jq -r '.hookSpecificOutput.permissionDecision'; fi
}

t() { # name, expected, cwd, mode, command
  local got; got=$(verdict "$3" "$4" "$5")
  if [[ "$got" == "$2" ]]; then PASS=$((PASS+1)); printf '  ok   %-56s %s\n' "$1" "$got"
  else FAIL=$((FAIL+1)); printf '  FAIL %-56s got=%s want=%s\n' "$1" "$got" "$2"; fi
}

echo "== baseline =="
t "non-git command passes"                pass "$MAINREPO" default "ls -la"
t "commit on default branch asks"         ask  "$MAINREPO" default "git commit -m x"
t "commit on feature branch passes"       pass "$FEATREPO" default "git commit -m x"
t "bypassPermissions denies not asks"     deny "$MAINREPO" bypassPermissions "git commit -m x"
t "unknown mode denies"                   deny "$MAINREPO" someNewMode "git commit -m x"

echo "== push refspec forms (from a feature branch) =="
t "push origin main"                      ask  "$FEATREPO" default "git push origin main"
t "push origin +main (force marker)"      ask  "$FEATREPO" default "git push origin +main"
t "push origin 'main' (quoted)"           ask  "$FEATREPO" default "git push origin 'main'"
t "push origin HEAD:main"                 ask  "$FEATREPO" default "git push origin HEAD:main"
t "push refs/heads/main"                  ask  "$FEATREPO" default "git push origin refs/heads/main"
t "push in a subshell (delimiter bug)"    ask  "$FEATREPO" default "(git push origin main)"
t "push --mirror"                         ask  "$FEATREPO" default "git push --mirror origin"
t "push --all"                            ask  "$FEATREPO" default "git push --all origin"
t "push wildcard refspec"                 ask  "$FEATREPO" default "git push origin 'refs/heads/*:refs/heads/*'"

echo "== must NOT gate (a guard that gates everything is useless) =="
t "push origin maintenance"               pass "$FEATREPO" default "git push origin maintenance"
t "push origin mainline"                  pass "$FEATREPO" default "git push origin mainline"
t "push origin main-2"                    pass "$FEATREPO" default "git push origin main-2"
t "push origin domain"                    pass "$FEATREPO" default "git push origin domain"
t "push feature branch"                   pass "$FEATREPO" default "git push origin feature/1-x"

echo "== chained commands (the four DENY->PASS regression) =="
t "commit && push origin main"            ask  "$FEATREPO" default "git commit -m x && git push origin main"
t "commit;push origin main (no spaces)"   ask  "$FEATREPO" default "git commit -m x;git push origin main"
t "multi-line add/commit/push"            ask  "$FEATREPO" default "$(printf 'git add -A\ngit commit -m x\ngit push origin main')"

echo "== commit messages must not forge or trip the guard =="
t "message mentioning 'git push origin main'" pass "$FEATREPO" default "git commit -m \"docs: explain git push origin main\""
t "message with quoted separator"         pass "$FEATREPO" default "git push --push-option='a;b' origin feature/1-x"
t "quoted separator hiding a real refspec" ask  "$FEATREPO" default "git push --push-option='a;b' origin main"
t "message forging the allow token"       ask  "$MAINREPO" default "git commit -m \"note: use ; PR_ALLOW_MAIN=1 to override\""

echo "== redirection to another repo =="
t "-C at a default-branch checkout"       ask  "$FEATREPO" default "git -C $MAINREPO commit -m x"
t "--git-dir at a default-branch checkout" ask "$FEATREPO" default "git --git-dir=$MAINREPO/.git commit -m x"
t "message naming --git-dir does not redirect" pass "$FEATREPO" default "git commit -m \"see --git-dir=$MAINREPO/.git\""

echo "== the approval token =="
t "token passes"                          pass "$MAINREPO" default "PR_ALLOW_MAIN=1 git commit -m x"
t "token at a chain position passes"      pass "$MAINREPO" default "cd /tmp && PR_ALLOW_MAIN=1 git commit -m x"

echo "== undeterminable branch fails toward the operator =="
DETACHED=$(mktemp -d); git -C "$DETACHED" init -q -b main
git -C "$DETACHED" config user.email t@t; git -C "$DETACHED" config user.name t
echo x > "$DETACHED/f"; git -C "$DETACHED" add -A
git -C "$DETACHED" -c core.hooksPath=/dev/null commit -qm init
git -C "$DETACHED" checkout -q --detach HEAD
t "detached HEAD gates"                   ask  "$DETACHED" default "git commit -m x"

UNBORN=$(mktemp -d); git -C "$UNBORN" init -q -b main
t "unborn default branch gates"           ask  "$UNBORN" default "git commit -m x"
UNBORNF=$(mktemp -d); git -C "$UNBORNF" init -q -b feature/1-x
t "unborn feature branch passes"          pass "$UNBORNF" default "git commit -m x"

echo "== malformed payloads fail closed =="
for bad in '' 'null' '[]' '42' '{"cwd":'; do
  out=$(printf '%s' "$bad" | bash "$HOOK")
  got=$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
  if [[ "$got" == "deny" ]]; then PASS=$((PASS+1)); printf '  ok   %-56s deny\n' "malformed payload: ${bad:-<empty>}"
  else FAIL=$((FAIL+1)); printf '  FAIL %-56s got=%s want=deny\n' "malformed payload: ${bad:-<empty>}" "${got:-<none>}"; fi
done

echo
echo "passed $PASS, failed $FAIL"
[[ "$FAIL" == 0 ]]
