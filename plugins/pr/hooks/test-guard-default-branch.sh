#!/bin/bash
# Probe suite for guard-default-branch.sh. Run it after ANY edit to that hook:
#   ./test-guard-default-branch.sh ./guard-default-branch.sh
# Every case below corresponds to a bypass the hook's comments name. Reading the
# hook is not evidence that it works; this is. Requires jq and git.
HOOK="$1"

# Resolve to an absolute path once. Several cases below invoke the hook from a
# DIFFERENT working directory, and a relative $HOOK simply vanishes there -- producing
# a failure textually identical to the fail-open those very cases exist to catch. The
# documented invocation is relative (`./test-guard-default-branch.sh ./guard-...`), so
# this is the normal case, not an exotic one.
case "$HOOK" in
  /*) ;;
  *)  HOOK="$PWD/$HOOK" ;;
esac

# Invoke the hook DIRECTLY, never via `bash "$HOOK"`. A PreToolUse hook is run as a
# command, so a non-executable file is a guard that silently never runs, which is
# fail-open in the one place that must fail closed. Invoking through bash would
# mask exactly that, and once did.
if [[ ! -x "$HOOK" ]]; then
  echo "FAIL: $HOOK is not executable. The harness runs it as a command, so it would never fire." >&2
  exit 1
fi
PASS=0; FAIL=0

# Mark a throwaway repo as having opted INTO the workflow. The hook is ambient: it
# ships with the plugin and a user-scope plugin reaches every repo on the machine, so
# it is inert unless `.claude/pr-config.json` exists at the repo root. Every fixture
# below that expects a gate must therefore opt in, and the no-config section at the
# end is what proves the inert case.
optin() { mkdir -p "$1/.claude"; printf '{"repo":"t/t"}\n' > "$1/.claude/pr-config.json"; }

# Two throwaway repos: one on the default branch, one on a feature branch.
MAINREPO=$(mktemp -d); git -C "$MAINREPO" init -q -b main
git -C "$MAINREPO" config user.email t@t; git -C "$MAINREPO" config user.name t
echo x > "$MAINREPO/f"; git -C "$MAINREPO" add -A
git -C "$MAINREPO" -c core.hooksPath=/dev/null commit -qm init
optin "$MAINREPO"

FEATREPO=$(mktemp -d); git -C "$FEATREPO" init -q -b main
git -C "$FEATREPO" config user.email t@t; git -C "$FEATREPO" config user.name t
echo x > "$FEATREPO/f"; git -C "$FEATREPO" add -A
git -C "$FEATREPO" -c core.hooksPath=/dev/null commit -qm init
git -C "$FEATREPO" checkout -q -b feature/1-x
optin "$FEATREPO"

verdict() { # cwd, mode, command -> "ask"|"deny"|"pass"
  local out
  out=$(jq -nc --arg c "$1" --arg m "$2" --arg cmd "$3" \
    '{cwd:$c,permission_mode:$m,tool_input:{command:$cmd}}' | "$HOOK")
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
optin "$DETACHED"
t "detached HEAD gates"                   ask  "$DETACHED" default "git commit -m x"

UNBORN=$(mktemp -d); git -C "$UNBORN" init -q -b main
optin "$UNBORN"
t "unborn default branch gates"           ask  "$UNBORN" default "git commit -m x"
UNBORNF=$(mktemp -d); git -C "$UNBORNF" init -q -b feature/1-x
optin "$UNBORNF"
t "unborn feature branch passes"          pass "$UNBORNF" default "git commit -m x"

# The activation rule. A repo with no `.claude/pr-config.json` never opted in, so the
# hook must leave it exactly as it was -- including on the paths that otherwise fail
# TOWARD the operator, since "fail toward the operator" presumes a repo that wanted a
# guard at all. Without these cases, installing the plugin silently gates commits in
# every repo on the machine.
echo "== an unconfigured repo is untouched =="
NOCFG=$(mktemp -d); git -C "$NOCFG" init -q -b main
git -C "$NOCFG" config user.email t@t; git -C "$NOCFG" config user.name t
echo x > "$NOCFG/f"; git -C "$NOCFG" add -A
git -C "$NOCFG" -c core.hooksPath=/dev/null commit -qm init
t "commit on default branch passes"       pass "$NOCFG" default "git commit -m x"
t "bypassPermissions still passes"        pass "$NOCFG" bypassPermissions "git commit -m x"
t "push origin main passes"               pass "$NOCFG" default "git push origin main"
t "push --mirror passes"                  pass "$NOCFG" default "git push --mirror origin"
t "unknown mode passes"                   pass "$NOCFG" someNewMode "git commit -m x"

NOCFGD=$(mktemp -d); git -C "$NOCFGD" init -q -b main
git -C "$NOCFGD" config user.email t@t; git -C "$NOCFGD" config user.name t
echo x > "$NOCFGD/f"; git -C "$NOCFGD" add -A
git -C "$NOCFGD" -c core.hooksPath=/dev/null commit -qm init
git -C "$NOCFGD" checkout -q --detach HEAD
t "detached HEAD does not gate"           pass "$NOCFGD" default "git commit -m x"

NOCFGU=$(mktemp -d); git -C "$NOCFGU" init -q -b main
t "unborn default branch does not gate"   pass "$NOCFGU" default "git commit -m x"

# The config must be found from the MAIN checkout's root, not the worktree's own dir.
# A linked worktree has no `.claude/` of its own, so a cwd-relative test would read
# every worktree as unconfigured and silently disarm the guard exactly where this
# workflow does its work.
WTBASE=$(mktemp -d); git -C "$WTBASE" init -q -b main
git -C "$WTBASE" config user.email t@t; git -C "$WTBASE" config user.name t
echo x > "$WTBASE/f"; git -C "$WTBASE" add -A
git -C "$WTBASE" -c core.hooksPath=/dev/null commit -qm init
optin "$WTBASE"
WT="$(mktemp -d)/wt"
# On a FEATURE branch, so the gate can only come from the refspec naming the default
# branch. A detached checkout would gate via the undeterminable-branch path instead and
# prove nothing about where the config was found.
git -C "$WTBASE" worktree add -q -b feature/1-wt "$WT" 2>/dev/null
if [[ -d "$WT" ]]; then
  t "linked worktree resolves main config"  ask  "$WT" default "git push origin main"
  t "linked worktree, feature commit passes" pass "$WT" default "git commit -m x"
else
  printf '  skip %-56s (worktree add failed)\n' "linked worktree resolves main config"
fi

# A malformed payload carries no cwd, so the activation check falls back to the
# session's project dir. These cases therefore have to CONTROL that directory: run
# from wherever the suite happened to be invoked, they would assert the runner's
# working directory rather than the hook, and silently flip with it.
#
# CLAUDE_PROJECT_DIR is what the harness exports and what the hook prefers, so it is
# set explicitly here rather than leaned on implicitly.
echo "== malformed payloads fail closed, in a configured repo =="
for bad in '' 'null' '[]' '42' '{"cwd":'; do
  out=$(printf '%s' "$bad" | CLAUDE_PROJECT_DIR="$MAINREPO" "$HOOK")
  got=$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
  if [[ "$got" == "deny" ]]; then PASS=$((PASS+1)); printf '  ok   %-56s deny\n' "malformed payload: ${bad:-<empty>}"
  else FAIL=$((FAIL+1)); printf '  FAIL %-56s got=%s want=deny\n' "malformed payload: ${bad:-<empty>}" "${got:-<none>}"; fi
done

# The mirror. An unparseable payload is the one path whose contract is to deny, so if
# activation is ever resolved from something other than the session's project dir this
# is where it fails OPEN -- the defect class this plugin exists to prevent, on the path
# built to prevent it. Denying here would be equally wrong: the repo never opted in.
echo "== malformed payloads stay inert in an unconfigured repo =="
for bad in '' 'null' '{"cwd":'; do
  out=$(printf '%s' "$bad" | CLAUDE_PROJECT_DIR="$NOCFG" "$HOOK")
  if [[ -z "$out" ]]; then PASS=$((PASS+1)); printf '  ok   %-56s pass\n' "malformed payload: ${bad:-<empty>}"
  else FAIL=$((FAIL+1)); printf '  FAIL %-56s got=%s want=<no output>\n' "malformed payload: ${bad:-<empty>}" "$out"; fi
done

# And the property both halves depend on: the verdict must come from the session's
# project dir, NOT from wherever the hook process happens to be running.
out=$( (cd "$NOCFG" && printf '' | CLAUDE_PROJECT_DIR="$MAINREPO" "$HOOK") )
got=$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
if [[ "$got" == "deny" ]]; then PASS=$((PASS+1)); printf '  ok   %-56s deny\n' "cwd outside the repo does not disarm the guard"
else FAIL=$((FAIL+1)); printf '  FAIL %-56s got=%s want=deny\n' "cwd outside the repo does not disarm the guard" "${got:-<none>}"; fi

# The PARSEABLE sibling of the case above, and it needs its own case because it takes a
# different code path. A payload can parse perfectly and still carry an empty cwd; that
# path ASSIGNS $CWD before the activation check runs, so the CLAUDE_PROJECT_DIR fallback
# has to be spelled at the assignment as well as inside pr_repo_configured. Spelling it
# in only one of the two places fails open here while every other case stays green.
out=$( (cd "$NOCFG" && jq -nc '{cwd:"",permission_mode:"default",tool_input:{command:"git commit -m x"}}' | CLAUDE_PROJECT_DIR="$MAINREPO" "$HOOK") )
got=$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
if [[ "$got" == "ask" ]]; then PASS=$((PASS+1)); printf '  ok   %-56s ask\n' "empty payload cwd resolves to the project dir"
else FAIL=$((FAIL+1)); printf '  FAIL %-56s got=%s want=ask\n' "empty payload cwd resolves to the project dir" "${got:-<none>}"; fi

# ...and it must not gate a repo that never opted in, whichever way the dir was resolved.
out=$( (cd "$MAINREPO" && jq -nc '{cwd:"",permission_mode:"default",tool_input:{command:"git commit -m x"}}' | CLAUDE_PROJECT_DIR="$NOCFG" "$HOOK") )
if [[ -z "$out" ]]; then PASS=$((PASS+1)); printf '  ok   %-56s pass\n' "empty payload cwd, unconfigured project dir"
else FAIL=$((FAIL+1)); printf '  FAIL %-56s got=%s want=<no output>\n' "empty payload cwd, unconfigured project dir" "$out"; fi

echo
echo "passed $PASS, failed $FAIL"
[[ "$FAIL" == 0 ]]
