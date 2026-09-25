#!/bin/bash
# Acceptance suite for the pr plugin. Drives its mechanical substrate through the
# lifecycle in throwaway repos that have never seen this workflow.
#
#   ./test-acceptance.sh "$(claude plugin list --json \
#      | jq -r '.[] | select(.id | startswith("pr@")) | .installPath')"
#
# Point it at an INSTALLED copy, not the source tree: that is what catches
# packaging defects, and it already caught one (a guard hook shipped without its
# executable bit, which made a PreToolUse guard silently never fire).
#
# What this covers: config discovery and defaults, repo derivation from the
# remote, a custom ticket prefix, renamed doc roots, disabled conventions, the
# worktree-free path, phase transitions including the undeterminable case, and
# all three hooks. What it does NOT cover: anything needing a live GitHub repo,
# and the skills themselves, which are instructions for a model rather than code.
#
# Requires jq, git and node. Writes only under the system temp directory.
P="${1:?usage: acceptance.sh <plugin install path>}"

# Resolve to an absolute path once, for the reason test-guard-default-branch.sh
# does the same: every case below runs from a throwaway repo under the system temp
# directory, and a relative $P vanishes there. The failure is not a clean one --
# each case reports `No such file or directory` against a path that plainly exists,
# which reads as a broken plugin rather than a mistyped argument.
case "$P" in
  /*) ;;
  *)  P="$PWD/$P" ;;
esac

if [[ ! -d "$P" ]]; then
  echo "FAIL: $P is not a directory. Pass the plugin's install path." >&2
  exit 1
fi

S="$P/scripts/pr-lifecycle-state.mjs"
PASS=0; FAIL=0

chk() { # label, expected-substring, actual
  if printf '%s' "$3" | grep -qF -- "$2"; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n       want substring: %s\n       got: %s\n' "$1" "$2" "$(printf '%s' "$3" | tr '\n' '|')"; fi
}
chk_empty() { # label, actual
  if [ -z "$2" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected no output)\n' "$1"; fi
}

R=$(mktemp -d)/proj; mkdir -p "$R"; cd "$R" || exit 1
git init -q -b main; git config user.email t@t; git config user.name t
git remote add origin git@github.com:someone/their-project.git
echo x > app.txt; git add -A; git -c core.hooksPath=/dev/null commit -qm init
# Seed the remote-tracking ref the way a clone would, without contacting a remote.
git update-ref refs/remotes/origin/main "$(git rev-parse main)"
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

echo "== phase 0: the hooks ship with the plugin, not with a settings fragment =="
HJ="$P/hooks/hooks.json"
HOOKLIST=$(mktemp)   # outside the repo under test, so it cannot dirty its status
if [ -f "$HJ" ]; then PASS=$((PASS+1)); printf '  ok   hooks.json is present\n'
else FAIL=$((FAIL+1)); printf '  FAIL hooks.json is missing, so the hooks are declared nowhere that CLAUDE_PLUGIN_ROOT resolves\n'; fi
chk "declares all three events"                 "PreToolUse,SessionStart,Stop"   "$(jq -r '.hooks | keys | join(",")' "$HJ" 2>/dev/null)"
chk "the guard is matched to Bash tool calls"   "Bash"                           "$(jq -r '.hooks.PreToolUse[0].matcher // ""' "$HJ" 2>/dev/null)"
chk "commands resolve through the plugin root"  '${CLAUDE_PLUGIN_ROOT}'          "$(jq -r '.hooks[][].hooks[].command' "$HJ" 2>/dev/null | head -1)"

# Every declared command must name a file that EXISTS and is EXECUTABLE. The harness
# runs a hook as a command, so a lost executable bit is a hook that silently never
# fires. That is the exact packaging defect this suite exists to catch, and it has
# shipped before.
jq -r '.hooks[][].hooks[].command' "$HJ" 2>/dev/null | while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  f=${cmd//\"/}
  f=${f//\$\{CLAUDE_PLUGIN_ROOT\}/$P}
  printf '%s\n' "$f"
done > "$HOOKLIST"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=${f#"$P"/}
  if [ -x "$f" ]; then PASS=$((PASS+1)); printf '  ok   %s is present and executable\n' "$n"
  else FAIL=$((FAIL+1)); printf '  FAIL %s is missing or not executable, so that hook would never fire\n' "$n"; fi
done < "$HOOKLIST"
rm -f "$HOOKLIST"

# The README must not have drifted back to telling operators to wire hooks by hand.
if grep -q '"hooks"' "$P/hooks/README.md" 2>/dev/null; then
  FAIL=$((FAIL+1)); printf '  FAIL hooks/README.md still carries a settings.json hook fragment, which never fires\n'
else
  PASS=$((PASS+1)); printf '  ok   hooks/README.md offers no settings.json fragment\n'
fi

echo "== phase 1: a repo with no config at all =="
OUT=$(node "$S" --offline --text)
chk "derives owner/name from an SSH remote"     "repo     someone/their-project" "$OUT"
chk "reports the missing config as a gap"       "no-config"                      "$OUT"
chk "on the default branch, phase is correct"   "phase    default-branch"        "$OUT"
chk "recommends the queue skill from default"   "next     /pr:next"              "$OUT"

# And the hooks must be INERT here. They arrive with the plugin, and a plugin enabled
# at user scope reaches every repo on the machine, so without an activation rule this
# repo -- which never opted into the workflow -- would have its default-branch commits
# gated by a plugin installed for some other repo entirely.
OUT=$(jq -nc --arg c "$R" '{cwd:$c,permission_mode:"bypassPermissions",tool_input:{command:"git commit -m x"}}' | "$P/hooks/guard-default-branch.sh")
chk_empty "the branch guard is inert with no config" "$OUT"
# NOT an activation assertion, and must not be labelled as one: this hook is scoped by
# its sentinel and deliberately has no config gate, so it is silent here because no
# close is in flight. Phase 6 is what exercises it with a sentinel armed.
OUT=$(echo "{\"cwd\":\"$R\",\"stop_hook_active\":false}" | "$P/hooks/verify-close-landed.sh")
chk_empty "the close gate is silent with no close in flight" "$OUT"
# `changelog/` is an ordinary directory name, so its presence must not be mistaken for
# an opt-in: this exact shape once injected the plugin's context into every session of
# an unconfigured repo.
git checkout -q -b feature/1-probe
mkdir -p changelog/1-probe && printf '# Plan\n' > changelog/1-probe/PLAN.md
OUT=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$R" "$P/hooks/on-session-start.sh")
chk_empty "session-start is inert with no config, changelog folder notwithstanding" "$OUT"
rm -rf changelog/1-probe
git checkout -q main; git branch -q -D feature/1-probe

echo "== phase 2: /pr:init's artifact, custom prefix, worktrees off, renamed doc roots =="
mkdir -p .claude
cat > .claude/pr-config.json <<'JSON'
{
  "ticketPrefix": "abc",
  "worktrees": { "enabled": false },
  "checks": { "lint": "true", "test": "true" },
  "docs": { "changelogRoot": "notes", "continuityRoot": null, "assertionsFile": null },
  "closeGate": { "requiredArtifacts": ["pr-summary"] },
  "mainGuard": { "approvalToken": "THEIR_ALLOW_MAIN" }
}
JSON
OUT=$(node "$S" --offline --text)
chk "config is found, so the gap clears"        "gaps     none"                  "$OUT"
chk "repo still derives from the remote"        "repo     someone/their-project" "$OUT"

echo "== phase 3: /pr:start's artifacts, prefixed branch, no worktree =="
git checkout -q -b feature/abc-42-add-a-widget
mkdir -p notes/abc-42-add-a-widget
printf '# Add a widget\n\n## Plan\n- [ ] do it\n' > notes/abc-42-add-a-widget/PLAN.md
printf '# Add a widget\n\n## Changes\n' > notes/abc-42-add-a-widget/CHANGELOG.md
OUT=$(node "$S" --offline --text)
chk "parses the ticket through a custom prefix" "ticket   #42"                   "$OUT"
chk "finds the plan under a renamed doc root"   "PLAN.md yes"                    "$OUT"
chk "start step reads as done"                  "[x] /pr:start"                  "$OUT"
chk "a disabled continuity root reads as n/a"   "continuity -"                   "$OUT"
chk "phase is fresh before any commit"          "phase    fresh"                 "$OUT"

echo "== phase 4: work committed =="
echo change >> app.txt; git add -A; git -c core.hooksPath=/dev/null commit -qm "add a widget"
OUT=$(node "$S" --offline --text)
chk "phase advances once commits exist"         "phase    in-development"        "$OUT"
chk "one commit ahead of the default branch"    "1 ahead"                        "$OUT"

echo "== phase 4b: an undeterminable comparison must not read as 'fresh' =="
BROKE=$(mktemp -d)/nodef; mkdir -p "$BROKE"; cd "$BROKE" || exit 1
git init -q -b main; git config user.email t@t; git config user.name t
git remote add origin git@github.com:someone/other.git
echo y > f; git add -A; git -c core.hooksPath=/dev/null commit -qm init
git checkout -q -b feature/7-thing
echo z >> f; git add -A; git -c core.hooksPath=/dev/null commit -qm work
OUT=$(node "$S" --offline --text)   # no origin/main ref exists at all
chk "phase is unknown, not fresh"               "phase    unknown"               "$OUT"
chk "next says undetermined, not 'no commits'"  "undetermined"                   "$OUT"
cd "$R" || exit 1

echo "== phase 5: the branch guard, under this repo's renamed token =="
G="$P/hooks/guard-default-branch.sh"
v() { # empty output from the hook means "no decision", i.e. pass
  local out
  out=$(jq -nc --arg c "$1" --arg m "default" --arg cmd "$2" \
    '{cwd:$c,permission_mode:$m,tool_input:{command:$cmd}}' | "$G")
  if [ -z "$out" ]; then echo pass
  else printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'; fi
}
chk "feature-branch commit passes"              "pass" "$(v "$R" 'git commit -m x')"
chk "push naming the default branch gates"      "ask"  "$(v "$R" 'git push origin main')"
chk "the repo's renamed token is honoured"      "pass" "$(v "$R" 'THEIR_ALLOW_MAIN=1 git push origin main')"
chk "the plugin default token is NOT honoured"  "ask"  "$(v "$R" 'PR_ALLOW_MAIN=1 git push origin main')"

echo "== phase 6: the close gate, with continuity dropped from requiredArtifacts =="
H="$P/hooks/verify-close-landed.sh"
"$H" --arm >/dev/null
OUT=$(echo "{\"cwd\":\"$R\",\"stop_hook_active\":false}" | "$H")
chk "blocks while the summary is missing"       '"decision":"block"'             "$OUT"
chk "names the configured doc root"             "notes/abc-42-add-a-widget"      "$OUT"
if printf '%s' "$OUT" | grep -q "continuity"; then FAIL=$((FAIL+1)); echo "  FAIL gate demanded a disabled artifact"; else PASS=$((PASS+1)); echo "  ok   gate skips the disabled continuity artifact"; fi

printf 'summary\n' > notes/abc-42-add-a-widget/pr-summary-2026-09-14.md
git add -A; git -c core.hooksPath=/dev/null commit -qm "add the summary"
OUT=$(echo "{\"cwd\":\"$R\",\"stop_hook_active\":false}" | "$H")
chk "still blocks on an unpushed tip"           "no upstream"                    "$OUT"
OUT=$(echo "{\"cwd\":\"$R\",\"stop_hook_active\":true}" | "$H")
chk_empty "loop guard: silent once already blocked" "$OUT"
"$H" --disarm >/dev/null
OUT=$(echo "{\"cwd\":\"$R\",\"stop_hook_active\":false}" | "$H")
chk_empty "silent with no close in flight" "$OUT"

echo "== phase 7: session-start rehydration under the renamed doc root =="
OUT=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$R" "$P/hooks/on-session-start.sh")
chk "loads the branch folder (summary wins over plan)" "### pr-summary"          "$OUT"
chk "names the branch"                          "feature/abc-42-add-a-widget"    "$OUT"
git checkout -q main
OUT=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$R" "$P/hooks/on-session-start.sh")
chk_empty "emits nothing on the default branch" "$OUT"

echo "== phase 8: the pr line names both numbers, against a stub gh =="
# GitHub numbers issues and PRs from one sequence, so PR 57 closing ticket 42 is the
# normal case, and a line showing only "#57" leaves the reader to guess. A stub gh
# first on PATH stands in for GitHub; GIT_SSH_COMMAND=false makes the script's fetch
# fail fast instead of reaching for a remote that does not exist.
FAKE=$(mktemp -d)
cat > "$FAKE/gh" <<'SH'
#!/bin/bash
case "$1 $2" in
  "issue view") echo '{"number":42,"title":"Add a widget","state":"OPEN","labels":[{"name":"status:in-progress"}]}' ;;
  "pr list")    echo "[{\"number\":57,\"state\":\"OPEN\",\"isDraft\":true,\"body\":\"x\",\"closingIssuesReferences\":${FAKE_CLOSES:-[]}}]" ;;
  "pr checks")  echo '[]' ;;
  *)            exit 1 ;;
esac
SH
chmod +x "$FAKE/gh"
git checkout -q feature/abc-42-add-a-widget
OUT=$(FAKE_CLOSES='[{"number":42}]' PATH="$FAKE:$PATH" GIT_SSH_COMMAND=false node "$S" --text)
chk "a linked PR reads PR #n -> closes #ticket"  "pr       PR #57 → closes #42"   "$OUT"
OUT=$(PATH="$FAKE:$PATH" GIT_SSH_COMMAND=false node "$S" --text)
chk "an unlinked PR names the missing ref"       "PR #57 → no closing ref to #42" "$OUT"
git checkout -q main
rm -rf "$FAKE"

echo
echo "passed $PASS, failed $FAIL"
[ "$FAIL" = 0 ]
