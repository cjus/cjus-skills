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

echo "== phase 1: a repo with no config at all =="
OUT=$(node "$S" --offline --text)
chk "derives owner/name from an SSH remote"     "repo     someone/their-project" "$OUT"
chk "reports the missing config as a gap"       "no-config"                      "$OUT"
chk "on the default branch, phase is correct"   "phase    default-branch"        "$OUT"
chk "recommends the queue skill from default"   "next     /pr:next"              "$OUT"

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

echo
echo "passed $PASS, failed $FAIL"
[ "$FAIL" = 0 ]
